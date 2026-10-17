# E5 Overnight Deployment & Baseline Collection Prompt

**Goal:** Deploy reference switcher + Phase 1 adapters to E5 box and collect baseline measurements.

**Context:** You are running on the E5 Xeon box. Reference switcher v2 (Python, 534 lines) is the canonical model switcher with decision core, actuator, ledger writer, and event outbox. You have 10 test fixtures (5 E5-specific) proving the logic works offline.

## Phase 1 Tasks (in order, as much as possible overnight)

### 1. Deploy Reference Switcher

- Copy `reference_switcher_v2.py` to `/opt/hermes/reference_switcher/`
- Verify imports (sqlite3, json, threading, all stdlib)
- Smoke test: run `reference_switcher_v2.py main()` once, check `/tmp/deliveries_v2.db` created with schema
- Check no errors in stderr

### 2. Wire into Hermes Cron

- Identify where current model switcher runs (likely a cron job or external-worker trigger)
- Replace call with: `python3 /opt/hermes/reference_switcher/reference_switcher_v2.py`
- Keep stderr/stdout redirected to `hermes-switcher.log` for observability
- Run one manual trigger test to confirm it works

### 3. Baseline Measurements (24h cycle)

Measure cold load + warm latency for each model in routing table:
- qwen3.5:4b (if present)
- qwen3.5:9b (if present)
- openrouter_free (if present)
- Any other primary/fallback models

For each model:
- **Cold load**: time from `/api/load` until first response from a trivial query
- **Warm TTFB**: time to first token on a standard 256-token prompt
- **Warm total**: end-to-end generation time (256 tokens)

Record in `/opt/hermes/reference_switcher/baselines_e5.json`:
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

### 4. Enable Ledger Recording

- Verify `/opt/hermes/reference_switcher/deliveries.db` exists and has schema from smoke test
- Check first few rows after 1h of traffic (should see job records)
- If ledger is empty after 1h, investigate why (check `hermes-switcher.log`)

### 5. Collect First 24h of decision_context

- Let reference switcher run for at least 24h
- After 24h, export ledger to JSON:
  ```bash
  sqlite3 /opt/hermes/reference_switcher/deliveries.db \
    "SELECT job_id, action, timeout_context, decision_context FROM deliveries" \
    > /opt/hermes/reference_switcher/decisions_24h.json
  ```
- Parse `decision_context` to count:
  - How many timeouts (soft vs hard) occurred
  - How many rate limits detected (reason_code)
  - Range of residency_ms values
- Store summary in `/opt/hermes/reference_switcher/summary_24h.txt`

### 6. Quick Health Check (after 24h)

- Are any models timing out consistently? (should see fallback_depth > 0)
- Are any models fast? (soft timeouts < 5 calls)
- Any errors in `hermes-switcher.log`? (check for SQL errors, HTTP failures)
- Note surprises in `/opt/hermes/reference_switcher/observations.txt`

## Expected Outcome

Reference switcher deployed, running, collecting data, baselines captured.

## Deliverables (push to GitHub)

- `reference_switcher_v2.py` (no changes, already in repo)
- `baselines_e5.json` (new, baseline measurements)
- `decisions_24h.json` (new, first 24h of ledger export)
- `summary_24h.txt` (new, analysis of patterns)
- `observations.txt` (new, any anomalies or surprises)
- `hermes-switcher.log` (updated, for debugging)

## Blockers

If you hit blockers (model not deployed, cron job location unknown, ledger not writing), document in `observations.txt` and skip that task, move to next. Report final status in a summary at the end.
