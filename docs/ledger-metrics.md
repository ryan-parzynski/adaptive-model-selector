# Ledger metric cards

**Status:** Adopted in v3.4 (§30). Every metric the ledgers record has a card. A metric with no rule it informs and no review question does not ship.

All metrics follow invariant 43: counts, ids, classes, durations, timestamps and reason codes only. No conversation content.

Retention for every raw record is `ledger_raw_retention_days` (default 90); rollups are kept indefinitely.

---

### free_requests_per_session

| | |
|---|---|
| Purpose | Size and validate the reserve |
| Ledger | observation |
| Collected | at session end |
| Unit | requests, tagged with work type and whether a fallback was used |
| Sampling | **every session, never sampled** — the reserve is the largest observed draw |
| Informs | `quota-reserve` (§4.13) |
| Review question | Is the largest draw in the window still at or below the reserve? |
| Prune if | no reserve policy is enabled (C1 absent) |

### limit_snapshot

| | |
|---|---|
| Purpose | Read limits live; notice when the provider changes them |
| Ledger | observation |
| Collected | every tick |
| Unit | cap, remaining, window type, reset instant, scope, hash of the limit structure |
| Sampling | every tick; consecutive identical snapshots may be collapsed to a count |
| Informs | invariant 42; `quota-reserve`; §4.9a-bis |
| Review question | Did the limit structure change, and did the selector notice on the same tick? |
| Prune if | never, while any provider limit is in use |

### switch_decision

| | |
|---|---|
| Purpose | Make every switch and hold reviewable |
| Ledger | decision |
| Collected | on every switch or hold |
| Unit | policy hash, rule fired, reason code, chosen model, rejected alternatives with reason codes, observation ids |
| Sampling | every decision |
| Informs | all selection rules; flapping detection (§4.13 write cap) |
| Review question | Did each rule fire for the reason it exists? Is any rule firing far more often than expected? |
| Prune if | never |

### decision_outcome

| | |
|---|---|
| Purpose | Attach what actually happened to each decision |
| Ledger | decision |
| Collected | when the next session on the chosen model ends, or after a timeout |
| Unit | status (`completed` / `failed` / `timeout` / `user_override` / `unknown`), time to first answer, total duration, rate-limited, fallback used |
| Sampling | every switch or hold |
| Informs | weekly review only — **not scored automatically** (§30.3) |
| Review question | Which decisions were followed by failures or overrides? |
| Prune if | never |

### fallback_event

| | |
|---|---|
| Purpose | Test the fallback rule (§6.4) against reality |
| Ledger | decision |
| Collected | when a session moves to its fallback |
| Unit | failure class (§4.9), from model, to model, **shared the failed dependency: yes / no / unknown**, time spent on the fallback |
| Sampling | every event |
| Informs | §6.4; `local-as-main` |
| Review question | Did any fallback fail the same way the primary did? |
| Prune if | no fallback chain is configured |

### manual_override

| | |
|---|---|
| Purpose | Check that the override window fits how the operator actually works |
| Ledger | decision |
| Collected | on pause entry and exit |
| Unit | entry time, expiry, hold flag, resume source (`manual` / `timeout`), duration, whether the selector later adopted or replaced the human's choice |
| Sampling | every override |
| Informs | `manual_override_hours` (§4.14a) |
| Review question | Do overrides usually end by timeout or by resume? Do people change the model again soon after a timed resume? |
| Prune if | never, while the selector writes config |

### time_to_first_answer

| | |
|---|---|
| Purpose | Latency profile per model and class |
| Ledger | observation |
| Collected | per request |
| Unit | milliseconds, tagged with model, class (chat / reasoning) and tool-heavy vs. plain |
| Sampling | **sampled** (for example 1 in 10, plus every request on a local model) |
| Informs | `local-as-main`; probe budgets (§7.2); latency thresholds (§7.4) |
| Review question | Is each local model's p95 within the declared tolerance for the work it actually serves? |
| Prune if | no local models and no latency-based rule is enabled |

### aux_overlap

| | |
|---|---|
| Purpose | Measure θ, the share of an aux chain's calls on the user's critical path |
| Ledger | observation |
| Collected | per auxiliary call |
| Unit | chain, whether the call overlapped a user turn, overlap fraction |
| Sampling | sampled per chain until its overlap bound is tight enough to decide (§4.15) |
| Informs | aux-chain head choice (§4.18) |
| Review question | For each chain, is the overlap bound low enough to move it to a local head? |
| Prune if | no local models (the API head is the only option) |

### spend_daily

| | |
|---|---|
| Purpose | Cost of the policy, by tier |
| Ledger | observation (daily rollup) |
| Collected | once a day |
| Unit | spend by tier; count of paid ticks taken while at or below the reserve |
| Sampling | daily rollup only — no per-request spend records |
| Informs | the reserve's shadow price (§4.13, §4.18) |
| Review question | Is the reserve costing more in paid ticks than the mid-turn failures it prevents? |
| Prune if | no paid tier |

### struggle_signal

| | |
|---|---|
| Purpose | Find out whether struggle signals predict anything |
| Ledger | observation |
| Collected | when S1–S5 (§5.1) fire |
| Unit | signal id, session id (opaque), what happened next in that session |
| Sampling | every occurrence |
| Informs | escalation thresholds (§5.2) — **descriptive only** until validated (invariant 44) |
| Review question | Are sessions with two or more signals actually worse off than sessions without? |
| Prune if | the operator disables struggle detection |

### tier_escalation

| | |
|---|---|
| Purpose | Learn whether escalating to the capacity tier helps |
| Ledger | decision |
| Collected | on every escalation to, or fallback from, the capacity tier |
| Unit | trigger reason code (`explicit_request`, `deep_work_type`, `fast_tier_hard_failure`, `background`, `resource_blocked`, `too_slow`), from model, to model, outcome link |
| Sampling | every event |
| Informs | `local-capacity-tiers` (§31.3, §31.4) |
| Review question | Do escalations finish work the fast tier could not? How often is the capacity tier blocked by resources? |
| Prune if | the box has a single local tier |

### local_resource_snapshot

| | |
|---|---|
| Purpose | See how close the box runs to its memory limits |
| Ledger | observation |
| Collected | just before each capacity-tier load, and at admission |
| Unit | free GPU memory, free RAM (MB), loaded models, requested context |
| Sampling | every capacity-tier load |
| Informs | resource guards (§31.5, invariant 45); the capability profile |
| Review question | How often was a load refused or downgraded for lack of memory, and which model was resident at the time? |
| Prune if | no capacity tier |

### capability_change

| | |
|---|---|
| Purpose | Keep `doctor`'s picture of the box current |
| Ledger | observation |
| Collected | whenever a capability's value changes, even with no switch |
| Unit | capability id, old value, new value |
| Sampling | every change |
| Informs | applicability of every rule (§0.6) |
| Review question | Did a capability change without anyone noticing? |
| Prune if | never |
