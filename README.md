# Canonical Model Switcher v2

Reference implementation of the model switcher for Hermes boxes. Single source of truth, replacing custom per-box implementations.

## Architecture

Three-layer design:

1. **Decision Core** (`DecisionCore`): Pure logic, side-effect-free
   - Routing table → determines which model to try based on job type
   - Soft timeout (5s): stall detection, retry same model
   - Hard timeout (30s): escalate to next in fallback chain
   - Special cases: cron alerts escalate immediately

2. **Actuator** (`Actuator`): Idempotent execution
   - HTTP POST to /api/load, /api/unload endpoints
   - Retry with exponential backoff on transient failures
   - Unload guard: requires timeout context OR external approval (Invariant 45)

3. **Event Outbox** (`EventOutbox`): Async ledger writer
   - In-memory queue + background thread
   - Decouples decision execution from I/O
   - Prevents hot-path stalls on ledger writes

## Quick Start

```bash
python3 reference_switcher_v2.py
```

Smoke test: creates `/tmp/deliveries_v2.db` with schema, runs 4 example decisions.

## Testing

```bash
python3 test_harness_v2.py
```

Runs all 10 fixtures against decision core. Status: **10/10 passing**.

Fixtures include:
- E5: normal request, soft timeout (stall), hard timeout (escalate), rate limit, local lane
- Chris: warm local, cold stall, vision stall, GPU repair, alert failure

## Deployment

### E5 Xeon Box

1. Copy to `/opt/hermes/reference_switcher/reference_switcher_v2.py`
2. Replace current model switcher cron job:
   ```
   python3 /opt/hermes/reference_switcher/reference_switcher_v2.py
   ```
3. Collect baselines for: qwen3.5:4b, qwen3.5:9b, openrouter_free (cold load, warm TTFB, warm total)
4. Let run for 24h, export ledger to JSON for analysis

### Chris GPU Box

1. Copy to `~/hermes/reference_switcher/reference_switcher_v2.py`
2. Wire In-Process Ledger Writer (critical — Chris uses in-process delivery, starves deliveries.db)
3. Fix ntfy v2.31.1 flag drift (--config must be global flag)
4. Replace current model switcher call
5. Collect baselines for: qwen3.5:4b, qwen3.5:9b, openrouter_paid (cold load, warm TTFB, warm total)
6. Let run for 24h, export ledger to JSON for analysis

## Phase 1 Adapters (Week 1)

After deploying reference switcher and collecting 24h of baselines:

1. **In-Process Ledger Writer (Chris)** — Critical, enables observability on Chris's box
2. **Rate Limit Detection (E5)** — Quick win, detect HTTP 429 and escalate immediately
3. **Struggling Model Detection (Core)** — Foundational, identify slow models without timeout

## Phase 2 Adapters (Week 2, if needed)

- **Adaptive Unload Tuning (E5)** — Measure residency, unload co-residents when struggling
  - Requires network health check guard (skip unload tuning if GPU box unreachable)
- **ntfy v2.31.1 Compatibility (Chris)** — Isolated fix for flag order
- **Approval System (Optional)** — Gate non-timeout unload requests

## Key Design Decisions

- **Soft before hard**: Don't escalate on first sign of trouble. Soft timeout retries, hard timeout escalates.
- **Timeout context is implicit authorization**: Unload during timeout requires no external approval (Invariant 45).
- **Per-box adapters remain local**: Chris and E5 have different hardware, workloads, deployments.
- **Measure before tuning**: Record latency, residency, reason codes. Don't guess.
- **Special cases bypass rules**: Cron alerts, payments, experiments have different thresholds.

## Ledger Schema

```sql
CREATE TABLE deliveries (
  id INTEGER PRIMARY KEY,
  job_id TEXT NOT NULL UNIQUE,
  model_id TEXT NOT NULL,
  action TEXT NOT NULL,  -- 'load', 'unload', 'fallback', 'escalate'
  timestamp TEXT NOT NULL,  -- ISO 8601
  status TEXT NOT NULL,  -- 'success', 'transient_error', 'permanent_error'
  attempt_count INTEGER,
  error_reason TEXT,
  decision_context TEXT,  -- JSON: timeout_context, residency_ms, fallback_depth
  created_at TEXT NOT NULL
);
```

## Monitoring

Export ledger after 24h:
```bash
sqlite3 /path/to/deliveries.db \
  "SELECT job_id, action, timeout_context, decision_context FROM deliveries" \
  > decisions_24h.json
```

Analyze:
- How many timeouts (soft vs hard)?
- How many rate limits detected?
- Range of residency_ms?
- Any errors or stuck states?

## Questions?

See `per-box-adapters-roadmap-2026-10-17.md` for implementation order, baseline measurements, and lessons learned.
