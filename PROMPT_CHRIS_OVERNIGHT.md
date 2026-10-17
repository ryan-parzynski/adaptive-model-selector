# Chris GPU Box Overnight Deployment & Baseline Collection Prompt

**Goal:** Deploy reference switcher + Phase 1 adapters to Chris box and collect baseline measurements.

**Context:** You are running on Chris's GPU box. Reference switcher v2 is the canonical model switcher. Your box has in-process delivery (starves deliveries.db), so Phase 1 includes wiring the In-Process Ledger Writer.

## Phase 1 Tasks (in order, as much as possible overnight)

### 1. Deploy Reference Switcher

- Copy `reference_switcher_v2.py` to `~/hermes/reference_switcher/`
- Verify imports (sqlite3, json, threading, all stdlib)
- Smoke test: run `reference_switcher_v2.py main()` once, check `~/hermes/reference_switcher/deliveries_v2.db` created with schema
- Check no errors in stderr

### 2. Wire In-Process Ledger Writer (CRITICAL FOR CHRIS)

Chris's box uses in-process delivery (not external worker), which starves the ledger (decisions are made but not recorded).

Create `InProcessLedgerWriter` class that writes synchronously:
```python
class InProcessLedgerWriter:
    def write(self, decision, result):
        try:
            with sqlite3.connect(Path.home() / "hermes/reference_switcher/deliveries.db") as conn:
                conn.execute("""
                    INSERT OR REPLACE INTO deliveries
                    (job_id, model_id, action, timestamp, status, attempt_count, error_reason, decision_context, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    decision.job_id,
                    decision.model_id,
                    decision.action.value,
                    decision.decision_timestamp,
                    result.status,
                    result.retry_count + 1,
                    result.error_reason,
                    json.dumps({
                        "timeout_context": decision.timeout_context,
                        "residency_ms": decision.residency_ms,
                        "fallback_depth": decision.fallback_depth,
                    }),
                    datetime.now(timezone.utc).isoformat() + "Z",
                ))
                conn.commit()
            return True
        except Exception as e:
            print(f"[LEDGER] ERROR: {e}", file=sys.stderr)
            return False
```

Wire into reference switcher's event outbox (or call synchronously from actuator).

Test: run `reference_switcher_v2.py main()` and verify `deliveries.db` has 4 rows (from the 4 examples in main).

### 3. Fix ntfy v2.31.1 Flag Drift

- Check: `ntfy --version`
- If v2.31.1 or later:
  - Update any ntfy setup calls in hermes config to use global flag:
  - OLD: `ntfy user add --config /path/to/config user@host`
  - NEW: `ntfy --config /path/to/config user add user@host`

Create `~/hermes/reference_switcher/ntfy_compat.py`:
```python
import subprocess

def get_ntfy_version():
    result = subprocess.run(["ntfy", "--version"], capture_output=True, text=True)
    return result.stdout.strip()

def ntfy_user_add(config_path, user, host):
    version = get_ntfy_version()
    if "2.31.1" in version or "2.32" in version:
        # v2.31.1+: global flag first
        return subprocess.run(["ntfy", "--config", config_path, "user", "add", f"{user}@{host}"])
    else:
        # older: local flag
        return subprocess.run(["ntfy", "user", "add", "--config", config_path, f"{user}@{host}"])
```

Document the fix in `~/hermes/reference_switcher/ntfy_compat.md`.

### 4. Wire into Hermes Cron

- Identify where current model switcher runs (likely a local cron job or hermes job scheduler)
- Replace call with: `python3 ~/hermes/reference_switcher/reference_switcher_v2.py`
- Keep stderr/stdout redirected to `~/hermes/reference_switcher/hermes-switcher.log`
- Run one manual trigger test to confirm it works

### 5. Baseline Measurements (24h cycle)

Measure cold load + warm latency for each model in routing table:
- qwen3.5:4b (primary local)
- qwen3.5:9b (local fallback)
- openrouter_paid (remote fallback)
- Any other models

For each model:
- **Cold load**: time from `/api/load` until first response from a trivial query
- **Warm TTFB**: time to first token on a standard 256-token prompt
- **Warm total**: end-to-end generation time (256 tokens)

Record in `~/hermes/reference_switcher/baselines_chris.json`:
```json
{
  "collected_at": "2026-10-17T...Z",
  "baselines": {
    "model_name": {
      "cold_load_ms": 7910,
      "warm_ttfb_ms": 30,
      "warm_total_ms": 450
    }
  }
}
```

- Take 3 samples per model, use median
- If any model not yet deployed, note it as "not available"

### 6. Enable Ledger Recording

- Verify `~/hermes/reference_switcher/deliveries.db` exists and has schema
- Check first few rows after 1h of traffic (should see job records)
- If ledger is empty after 1h, investigate why (check `hermes-switcher.log`)
- This proves the In-Process Ledger Writer is working (unlike current state)

### 7. Collect First 24h of decision_context

- Let reference switcher run for at least 24h
- After 24h, export ledger to JSON:
  ```bash
  sqlite3 ~/hermes/reference_switcher/deliveries.db \
    "SELECT job_id, action, timeout_context, decision_context FROM deliveries" \
    > ~/hermes/reference_switcher/decisions_24h.json
  ```
- Parse `decision_context` to count:
  - How many timeouts (soft vs hard) occurred
  - How many cold loads happened (and how long)
  - Range of residency_ms values
- Store summary in `~/hermes/reference_switcher/summary_24h.txt`

### 8. Quick Health Check (after 24h)

- Are any models timing out consistently? (should see fallback_depth > 0)
- Are any models fast? (soft timeouts < 5 calls)
- Did cold loads behave as expected? (which model, how long)
- Any errors in `hermes-switcher.log`? (check for SQL errors, HTTP failures, ntfy issues)
- Note surprises in `~/hermes/reference_switcher/observations.txt`

## Expected Outcome

Reference switcher deployed, in-process ledger writer working, running, collecting data, baselines captured.

## Deliverables (push to GitHub)

- `reference_switcher_v2.py` (no changes, already in repo)
- `ntfy_compat.py` (new, ntfy v2.31.1 flag drift fix)
- `ntfy_compat.md` (new, documentation of the fix)
- `baselines_chris.json` (new, baseline measurements)
- `decisions_24h.json` (new, first 24h of ledger export)
- `summary_24h.txt` (new, analysis of patterns)
- `observations.txt` (new, any anomalies or surprises)
- `hermes-switcher.log` (updated, for debugging)

## Blockers

If you hit blockers (cron job location unknown, ledger not writing, ntfy not working), document in `observations.txt` and skip that task, move to next. Report final status in a summary at the end.
