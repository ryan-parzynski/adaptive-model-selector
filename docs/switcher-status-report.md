# Switcher status report — a recurring, read-only "switcher in action" report

**For:** any Hermes box running a model switcher, whether or not it has adopted this specification yet.
**Purpose:** show what the switcher actually did, what it cost, how the local lanes are used, and where the switcher's beliefs disagree with reality. Run it periodically; daily is plenty. Run it again whenever the operator asks "is the switcher working?"

Operators can paste this file to the agent as-is, followed by a short box-specific addendum if there is one.

---

## Rules

- **Read-only.** Change no config, routing, chain, scheduled job, owner field, preference file, or loaded model, on this box or any lane. Do not restart anything.
- **Cheap.** Use logs, runtime state, and zero-cost provider endpoints. The only inference allowed is **one tiny request per local lane** in Part 5 (a five-word title, thinking off). Skip it if the operator says so.
- **Evidence, not memory.** Every number comes from a command run during this report, labelled **OBSERVED** with its source. Something from an earlier report or another agent is **REPORTED**. A likely explanation you didn't confirm is **HYPOTHESIS**, with the test that would settle it.
- **No silent skips.** Every section appears in the report. Anything that couldn't be measured says **CANNOT-OBSERVE** and why.
- **Privacy.** Counts, ids, durations, costs, and status classes only. No prompt or response text, no key material (invariants 31, 43).
- End with **COMPLETE** or **INCOMPLETE**, after a final pass that re-verifies each section from fresh evidence (`AGENT-GUIDE.md` §9).

Save the report as `state/switcher-status-<date>.md`, plus a small machine-readable summary, `state/switcher-status-<date>.json` (Part 10).

---

## Part 0 — Identity and versions

- Box name; Hermes runtime version; this box's **switcher code version**: a git commit if under version control, otherwise a hash of each switcher script. This lets reports from different boxes show whether they run the same code, and the same bugs.
- If the box tracks this specification: the adopted version (`state/switcher-adoption.yaml`) vs. the current `VERSION` upstream.
- Time zone of the scheduler vs. UTC; whether daylight saving applies (§4.13b).

## Part 1 — The switcher in action

**1a. Every component that switches, checks, or probes.** One row each:

| Component | Schedule | Last run (UTC) | Exit | Run time | What it did last | Right given its inputs? |
|---|---|---|---|---|---|---|

Read each component's last exit code and its first log line before interpreting its output (§10.23). A job that couldn't start produced an error, not a decision. Flag overlapping runs, run times near the schedule period, and any component re-reading the same thing several times per tick.

**1b. Current state:** default model, provider, tier; why it's on that tier (policy, budget, failure, manual); since when.

**1c. Writers and owner.** Every component that can write the default, the provider, a fallback chain, or the preference file; which are enabled; the owner field's value. Two or more enabled writers, or an empty owner, is a finding (§3.7a, invariant 47).

## Part 2 — Limits: what the switcher believes vs. what the provider says

For each provider with a bounded allowance, read the provider's own zero-cost endpoint (for OpenRouter, `GET /api/v1/key`; key via stdin, never argv) and put both views side by side:

| Value | Provider says | Switcher believes | Match? |
|---|---|---|---|
| Free allowance used / limit / remaining | | | |
| Window and reset instant | | | |
| Credit or spend limit, remaining | | | |
| Bring-your-own-key usage (if the provider reports it) | | | |

**Sanity checks — each failure is a finding:**

- `used > limit`, or `remaining < 0`: an impossible reading. Find where the switcher's limit comes from. A hardcoded number violates invariant 42.
- A **reset instant in the past** that the switcher still prints: the stored reset isn't advancing at its window boundary.
- The switcher reading the same limit **several times per tick**.
- The switcher treating the allowance as spent while the provider reports headroom, or the reverse.

**Reserve:** its value; provisional or measured; the largest per-session draw observed and the sample count (§4.13).

## Part 3 — Measured spend

Per provider account:

- Today, and a rolling 3–7-day window: draw, from balance changes or the provider's usage counters, **with top-ups excluded**.
- Run rate per day and the implied runway.
- **Scope:** is the key shared with other boxes? If so, this is an upper bound for this box, not an invoice.
- **Reconcile two sources** where they exist, such as the runtime's own ledger vs. the provider's counter. If they disagree, say which you trust and why. Bring-your-own-key routing, UTC vs. local day boundaries, and unpriced models are common causes.

## Part 4 — Unit economics by model and by task

**4a. By model:** sessions, calls, tokens in / cache-read / out, cost, $ per million tokens, $ per call. Note models your spend tooling marks unpriced or books at $0; that's a tooling defect, not free usage.

**4b. Where the money goes:**

- the split between output, fresh input, and cache reads, by cost and by token count;
- **the share of output that is reasoning ("thinking") tokens**, if the runtime records it. It is often the largest lever.

**4c. By task type** (main session, compression, title generation, approval, background review, vision, embeddings, other): calls, tokens, cost, and **which lane served it** (paid API, free API, or a local lane). This shows which auxiliary chains cost money on the API and could move to a local lane.

## Part 5 — Local lanes: one row per machine and card

From **this box's** point of view; don't assume another box's view applies here:

| Machine | Card | Tailnet node id / address | Online? Last seen | Direct or relayed | Port reachable | Loaded models (on-lane `ollama ps`) | On GPU? (VRAM size > 0) | Loaded size vs. weights |
|---|---|---|---|---|---|---|---|---|

- **The address the switcher's config uses vs. the lane's current tailnet address.** A mismatch is a finding. Lanes should be identified by node id (§26.2).
- `size_vram: 0` means the model is running on CPU. A loaded size far above the weights means a large context allocation.
- **One tiny request per lane** (a five-word title, thinking off): time to first token and total time, **from this box**. That's the cost this box pays, including the network.

And per lane, from this box's own logs:

| Machine | Task types served | Calls today / 7 days / all-time | Tokens in / out | Last call | Imputed cost if served by the paid tier |
|---|---|---|---|---|---|

- **Local share of all calls:** today vs. 7 days vs. all-time. A collapse is a finding.
- **Silent lanes:** any lane with no calls in 24 h that the config still lists. Say whether requests stopped being sent, or were sent and failed (fallback and health-check logs).
- **Fallback events:** count by lane and failure class; whether each fallback shared the failed dependency (§6.4).

## Part 6 — Health and conformance

| Item | State | Evidence |
|---|---|---|
| Alert delivery | absent / configured-failing / verified; last *successful* delivery | §0.6 |
| Sessions bound to a lane nobody chose (free, local, or a delisted model) | id, model, calls, last activity | §3.5 |
| Probe outcomes in 24 h | ok / timeout / budget-too-small / http errors | §7.2 |
| Stream-stale timeout | value, in range? | §3.2 |
| Writer registry and single owner | | §3.7a |
| Limits read live (from Part 2) | | inv. 42 |
| Local models admitted, with capability profiles | | inv. 46 |
| Resource guards | anything that unloads, pulls, or enables swap outside an operator path | inv. 45 |
| Live routing unchanged by this report | config and job-file hashes at start and end | |

## Part 7 — Anomalies and contradictions

List every place where two sources disagree, a value is impossible or stale, or the switcher's belief differs from what you observed. Each anomaly gets a label (OBSERVED / HYPOTHESIS) and the test that would settle it.

## Part 8 — Caveats

Scope of keys, what local work can and cannot replace, numbers inferred rather than measured, and anything this box cannot see.

## Part 9 — Proposals (not applied)

Ordered by impact. Each with the expected effect, what would confirm it, risk, rollback, and whether it needs the operator's decision. Separate **code bugs** (the switcher's logic), **box configuration** (this deployment), and **lane issues** (a card or its host).

## Part 10 — Machine-readable summary

`switcher-status-<date>.json`, small and sanitized: box, code version, spec version, current tier, limits (provider vs. switcher), spend today and run rate, local share (today / 7 d / all-time), per-lane `{online, on_gpu, last_call, ttft_s}`, alert state, writer count, owner set yes/no, anomaly count, status. This is what boxes can compare as **lessons** without sharing raw state (§8.0, §30.6).

## Verification log

Each Part: state (VERIFIED / FAILED / SKIPPED / CANNOT-OBSERVE / MISSING), command, timestamp. Then **COMPLETE** or **INCOMPLETE**, with each missing item, why existing evidence isn't enough, and the exact command to obtain it.
