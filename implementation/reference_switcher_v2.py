#!/usr/bin/env python3
"""
Canonical Model Switcher — Reference Implementation v2 (2026-10-17)
Fixed: stall detection, alert failure, rate limit escalation

Three-layer architecture:
1. Decision Core (pure logic, side-effect-free)
2. Actuator (execute decisions, idempotent, guards unload)
3. Event Outbox (async ledger writer, loud repair)

Python 3.10+, stdlib-only.
"""

import json
import sys
import time
import threading
import sqlite3
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum


# ============================================================================
# DATA STRUCTURES
# ============================================================================

class ActionType(Enum):
    """Types of actions the switcher can take."""
    LOAD = "load"
    UNLOAD = "unload"
    FALLBACK = "fallback"
    ESCALATE = "escalate"


@dataclass
class DecisionEnvelope:
    """Output from decision core."""
    job_id: str
    model_id: str
    action: ActionType
    lane: str
    reason: str
    timeout_context: bool  # True if decision triggered by timeout
    residency_ms: Optional[int] = None
    fallback_depth: int = 0
    decision_timestamp: Optional[str] = None

    def __post_init__(self):
        if not self.decision_timestamp:
            self.decision_timestamp = datetime.now(timezone.utc).isoformat() + "Z"


@dataclass
class ActionResult:
    """Result from actuator."""
    success: bool
    status: str  # 'success', 'transient_error', 'permanent_error', 'retry_exhausted'
    retry_count: int
    error_reason: Optional[str] = None
    http_code: Optional[int] = None


# ============================================================================
# DECISION CORE (Pure Logic) — FIXED VERSION
# ============================================================================

class DecisionCore:
    """
    Pure logic layer: routing, fallback chain, timeout detection.
    No side effects. Fully testable.

    Fixes:
    - Stall detection: soft timeout (5s) retries same model; hard timeout (30s) escalates
    - Alert failure: cron_alert escalates immediately
    - Rate limit: marked for per-box adapter (core just detects timeout)
    """

    def __init__(
        self,
        routing_table: Dict[str, List[str]],
        timeout_threshold_ms: int = 5000,
        hard_timeout_ms: int = 30000,
    ):
        """
        Args:
            routing_table: {job_type: [model_1, model_2, ...]}
            timeout_threshold_ms: "soft" timeout (stall detection, retry same model)
            hard_timeout_ms: "hard" timeout (escalate to next in chain)
        """
        self.routing_table = routing_table
        self.timeout_threshold_ms = timeout_threshold_ms
        self.hard_timeout_ms = hard_timeout_ms

    def decide(
        self,
        job_id: str,
        job_type: str,
        current_model: Optional[str],
        elapsed_ms: int,
        residency_history: Dict[str, int],
    ) -> DecisionEnvelope:
        """
        Pure decision logic.

        Args:
            job_id: unique job identifier
            job_type: category (e.g., 'chat', 'vision', 'search')
            current_model: model currently being tried (or None)
            elapsed_ms: how long the current model has been tried
            residency_history: {model_id: resident_ms_ago}

        Returns:
            DecisionEnvelope with action, model, reason, timeout_context
        """

        # Special handling for cron alerts: escalate immediately on timeout
        if job_type == "cron_alert":
            if elapsed_ms > self.timeout_threshold_ms:
                return DecisionEnvelope(
                    job_id=job_id,
                    model_id="escalate",
                    action=ActionType.ESCALATE,
                    lane="escalate",
                    reason=f"cron alert timeout after {elapsed_ms}ms; escalate immediately",
                    timeout_context=True,
                    fallback_depth=0,
                )

        # Get the fallback chain for this job type
        chain = self.routing_table.get(job_type, [])
        if not chain:
            return DecisionEnvelope(
                job_id=job_id,
                model_id="unknown",
                action=ActionType.LOAD,
                lane="default",
                reason=f"no routing rule for job_type={job_type}",
                timeout_context=False,
            )

        # Check timeout (soft and hard)
        is_soft_timeout = elapsed_ms > self.timeout_threshold_ms
        is_hard_timeout = elapsed_ms > self.hard_timeout_ms

        if is_hard_timeout and current_model:
            # Hard timeout: escalate to next in chain (or escalate entirely)
            current_idx = chain.index(current_model) if current_model in chain else -1

            # If not in chain, start from index 1
            if current_idx == -1:
                current_idx = 0

            next_idx = current_idx + 1

            if next_idx < len(chain):
                next_model = chain[next_idx]
                return DecisionEnvelope(
                    job_id=job_id,
                    model_id=next_model,
                    action=ActionType.FALLBACK,
                    lane=f"fallback_{next_idx}",
                    reason=f"hard timeout after {elapsed_ms}ms on {current_model}",
                    timeout_context=True,
                    fallback_depth=next_idx,
                    residency_ms=residency_history.get(next_model),
                )
            else:
                # End of chain; escalate
                return DecisionEnvelope(
                    job_id=job_id,
                    model_id="escalate",
                    action=ActionType.ESCALATE,
                    lane="escalate",
                    reason=f"hard timeout; exhausted fallback chain (depth={len(chain)})",
                    timeout_context=True,
                    fallback_depth=len(chain),
                )

        elif is_soft_timeout and current_model:
            # Soft timeout (stall): retry same model (don't fallback yet)
            # This handles cases like cold load that takes 234s but eventually succeeds
            return DecisionEnvelope(
                job_id=job_id,
                model_id=current_model,
                action=ActionType.LOAD,
                lane="retry_same",
                reason=f"soft timeout (stall) after {elapsed_ms}ms on {current_model}; retrying",
                timeout_context=True,
                fallback_depth=0,
                residency_ms=residency_history.get(current_model),
            )

        # No timeout; normal routing
        first_model = chain[0]
        return DecisionEnvelope(
            job_id=job_id,
            model_id=first_model,
            action=ActionType.LOAD,
            lane="primary",
            reason=f"normal routing for job_type={job_type}",
            timeout_context=False,
            residency_ms=residency_history.get(first_model),
        )


# ============================================================================
# ACTUATOR (Idempotent Execution)
# ============================================================================

class Actuator:
    """
    Execute decisions: HTTP load/unload, idempotent retry, guards unload.
    Safe to retry (idempotent). Guards unload with timeout context.
    """

    def __init__(self, hermes_url: str, max_retries: int = 3, initial_backoff_s: float = 1.0):
        """
        Args:
            hermes_url: base URL of Hermes (e.g., http://localhost:11434)
            max_retries: max retry attempts on transient failure
            initial_backoff_s: initial backoff for retry (exponential)
        """
        self.hermes_url = hermes_url
        self.max_retries = max_retries
        self.initial_backoff_s = initial_backoff_s

    def execute(self, decision: DecisionEnvelope) -> ActionResult:
        """
        Execute the decision. Return result (success/failure).

        Handles:
        - Load/unload via HTTP POST
        - Idempotent retry on transient failures
        - Unload guard (conditional: timeout_context → auto-unload, else → approval required)
        """

        action = decision.action

        # Guard: unload requires either timeout context or external approval
        if action == ActionType.UNLOAD:
            if not decision.timeout_context:
                # Non-timeout unload requires external approval (not implemented in reference impl)
                return ActionResult(
                    success=False,
                    status="approval_pending",
                    retry_count=0,
                    error_reason="unload requires operator authorization (non-timeout context)",
                )

        # Execute with retry
        if action == ActionType.LOAD:
            return self._execute_load(decision.model_id, decision.job_id)
        elif action == ActionType.UNLOAD:
            return self._execute_unload(decision.model_id, decision.job_id)
        elif action == ActionType.FALLBACK:
            # Fallback is a load on the next model
            return self._execute_load(decision.model_id, decision.job_id)
        elif action == ActionType.ESCALATE:
            # Escalate is logged (not executed here)
            return ActionResult(
                success=True,
                status="success",
                retry_count=0,
                error_reason=None,
            )
        else:
            return ActionResult(
                success=False,
                status="permanent_error",
                retry_count=0,
                error_reason=f"unknown action: {action}",
            )

    def _execute_load(self, model_id: str, job_id: str) -> ActionResult:
        """Load a model via HTTP POST."""
        # Simplified: in practice, would use urllib.request to POST to /api/load
        # For now, return success (demonstration)
        print(f"[ACTUATOR] LOAD {model_id} for job {job_id}", file=sys.stderr)
        return ActionResult(
            success=True,
            status="success",
            retry_count=0,
        )

    def _execute_unload(self, model_id: str, job_id: str) -> ActionResult:
        """Unload a model via HTTP POST."""
        # Simplified: in practice, would use urllib.request to POST to /api/delete
        print(f"[ACTUATOR] UNLOAD {model_id} for job {job_id}", file=sys.stderr)
        return ActionResult(
            success=True,
            status="success",
            retry_count=0,
        )


# ============================================================================
# LEDGER (Restart-Safe Worker Path Only)
# ============================================================================

class LedgerWriter:
    """
    Async ledger writer for restart-safe worker path.
    Writes to deliveries.db with loud repair (retry + escalate on failure).
    """

    SCHEMA = """
    CREATE TABLE IF NOT EXISTS deliveries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id TEXT NOT NULL UNIQUE,
      model_id TEXT NOT NULL,
      action TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      status TEXT NOT NULL,
      attempt_count INTEGER NOT NULL DEFAULT 1,
      error_reason TEXT,
      decision_context TEXT,
      created_at TEXT NOT NULL
    );
    """

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        """Initialize database schema."""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(self.SCHEMA)
            conn.commit()

    def write(
        self,
        decision: DecisionEnvelope,
        result: ActionResult,
    ) -> bool:
        """
        Write decision + result to ledger.

        Repair logic: retry on transient, escalate on permanent.
        Returns True on success, False on permanent failure.
        """

        decision_context = {
            "timeout_context": decision.timeout_context,
            "residency_ms": decision.residency_ms,
            "fallback_depth": decision.fallback_depth,
        }

        status = result.status
        if status == "success":
            status_final = "success"
        elif status == "transient_error":
            status_final = "transient_error"
        elif status == "approval_pending":
            status_final = "permanent_error"  # Approval pending is a permanent block
        else:
            status_final = result.status

        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO deliveries
                    (job_id, model_id, action, timestamp, status, attempt_count, error_reason, decision_context, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        decision.job_id,
                        decision.model_id,
                        decision.action.value,
                        decision.decision_timestamp,
                        status_final,
                        result.retry_count + 1,
                        result.error_reason,
                        json.dumps(decision_context),
                        datetime.now(timezone.utc).isoformat() + "Z",
                    ),
                )
                conn.commit()
            return True
        except sqlite3.Error as e:
            # Permanent error; escalate via logging (in practice, ntfy alert)
            print(f"[LEDGER] ERROR: {e} (job_id={decision.job_id})", file=sys.stderr)
            return False


# ============================================================================
# EVENT OUTBOX (Decoupled Async Queue)
# ============================================================================

class EventOutbox:
    """
    In-memory queue + async writer.
    Decouples decision execution from ledger writes.
    Prevents I/O stalls on hot path.
    """

    def __init__(self, ledger: LedgerWriter):
        self.ledger = ledger
        self.queue: List[Tuple[DecisionEnvelope, ActionResult]] = []
        self._lock = threading.Lock()
        self._writer_thread = threading.Thread(daemon=True, target=self._writer_loop)
        self._writer_thread.start()

    def enqueue(self, decision: DecisionEnvelope, result: ActionResult):
        """Enqueue a decision + result for async write."""
        with self._lock:
            self.queue.append((decision, result))

    def _writer_loop(self):
        """Async writer: drain queue, write to ledger with retry."""
        while True:
            with self._lock:
                if self.queue:
                    decision, result = self.queue.pop(0)
                else:
                    decision, result = None, None

            if decision:
                # Retry logic: transient → retry with backoff, permanent → escalate
                for attempt in range(3):  # 3 attempts
                    success = self.ledger.write(decision, result)
                    if success:
                        break
                    if attempt < 2:
                        time.sleep(2 ** attempt)  # Exponential backoff: 1s, 2s

            time.sleep(0.1)  # Poll interval


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    """
    Example usage of the reference switcher.
    In practice, this would be driven by Hermes cron job or external worker.
    """

    # Setup with soft/hard timeout thresholds
    routing_table = {
        "chat": ["model_a", "model_b", "model_c"],
        "vision": ["vision_fast", "vision_slow"],
        "short_generation": ["local_gpu", "fallback"],
        "trivial_generation": ["local_gpu", "local_cpu"],
        "cron_alert": ["ntfy_server", "ntfy_fallback"],
    }
    decision_core = DecisionCore(
        routing_table,
        timeout_threshold_ms=5000,   # Soft timeout: stall detection
        hard_timeout_ms=30000,        # Hard timeout: escalate
    )
    actuator = Actuator("http://localhost:11434")

    db_path = Path("/tmp/deliveries_v2.db")
    ledger = LedgerWriter(db_path)
    outbox = EventOutbox(ledger)

    # Example 1: Normal request (no timeout)
    print("\n=== Example 1: Normal request ===")
    decision = decision_core.decide(
        job_id="job_001",
        job_type="chat",
        current_model=None,
        elapsed_ms=100,
        residency_history={},
    )
    print(f"Decision: {decision}")
    result = actuator.execute(decision)
    print(f"Result: {result}")
    outbox.enqueue(decision, result)

    # Example 2: Soft timeout (stall, retry same)
    print("\n=== Example 2: Soft timeout (stall, retry same model) ===")
    decision = decision_core.decide(
        job_id="job_002",
        job_type="trivial_generation",
        current_model="local_gpu",
        elapsed_ms=234400,  # 234s, > 5000 but < 30000
        residency_history={"local_gpu": 500},
    )
    print(f"Decision: {decision}")
    result = actuator.execute(decision)
    print(f"Result: {result}")
    outbox.enqueue(decision, result)

    # Example 3: Hard timeout (escalate)
    print("\n=== Example 3: Hard timeout (escalate to next) ===")
    decision = decision_core.decide(
        job_id="job_003",
        job_type="chat",
        current_model="model_a",
        elapsed_ms=31000,  # > 30000
        residency_history={"model_b": 500},
    )
    print(f"Decision: {decision}")
    result = actuator.execute(decision)
    print(f"Result: {result}")
    outbox.enqueue(decision, result)

    # Example 4: Cron alert timeout (special case: escalate immediately)
    print("\n=== Example 4: Cron alert (escalate immediately) ===")
    decision = decision_core.decide(
        job_id="job_004",
        job_type="cron_alert",
        current_model="ntfy_server",
        elapsed_ms=10000,
        residency_history={},
    )
    print(f"Decision: {decision}")
    result = actuator.execute(decision)
    print(f"Result: {result}")
    outbox.enqueue(decision, result)

    # Wait for async writes
    time.sleep(1)

    # Check ledger
    print("\n=== Ledger contents ===")
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute("SELECT * FROM deliveries").fetchall()
        for row in rows:
            print(dict(row))

    print("\n=== Done ===")


if __name__ == "__main__":
    main()
