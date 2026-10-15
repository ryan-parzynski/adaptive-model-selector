# Rule card: local-as-main

**Status:** Adopted in v3.3. Reframes §3.17, §3.18, §6.1, §6.3, §6.3a, §6.4, invariants 2, 9, 10.

The specification states this as a blanket ban: "local is never a main model." That conclusion came from one kind of setup. This card keeps the **concern** and states **when it holds**, so an operator with fast local hardware can evaluate it instead of inheriting it.

## Purpose

A user's turn must not silently wait on a model much slower than they expect. The failure this prevents: the main session, or its fallback after a 429, lands on a slow local model. The turn then takes minutes instead of seconds, and nothing tells the user why.

## Applies when

| Condition | Questionnaire |
|---|---|
| The box has local or self-hosted models | C5 = `present` |
| A local endpoint is reachable from a main-session path: the default, or any fallback entry the runtime might use for main traffic | Config inspection; C11 |

If C5 is `absent`, the rule is **not applicable**.

## Evidence

- **OBSERVED (reference deployment, §6.4):** a running session whose primary returned 429 moved to the head of its fallback chain for the rest of the day. The head was local, so the session crawled on a slow card and looked hung.
- **OBSERVED (Record 6):** local cards answered correctly but took longer than the runtime's per-chain timeout. On that hardware, the model itself, not the routing, was the constraint.
- **OBSERVED (§3.18):** the main default was an API model, but the fallback list contained local entries. The default alone did not show the risk.
- **Limitation:** all of this was observed on consumer GPUs serving reasoning models over a tailnet. It says nothing about a box with local hardware fast enough for interactive use. That gap is why this is now a conditional rule.

## Measurement

| Value | Unit | How to collect | Uncertainty |
|---|---|---|---|
| Time to first answer chunk, per local model | seconds, p95 | Probe with a budget sized for the model class (§7.2). For reasoning models, measure the first *answer* chunk, not the first thinking token | Load-dependent; re-measure when models or hardware change |
| User latency tolerance | seconds | Operator declaration (policy P2) | — |
| Runtime falls through on timeout | yes / no | §10.28: source check plus a black-box test | — |
| Stream-stale timeout | seconds | Config (C10) | — |

## Decision

Local may serve a main-session path only when **all** of these hold:

1. Policy P2 is `when-measured-fast-enough`, not `never`.
2. Its measured p95 time to first answer chunk is within the operator's declared tolerance, measured recently. An unmeasured latency counts as **not met**.
3. A stream-stale timeout is set, so a stall is bounded rather than open-ended.
4. Either the runtime falls through on timeout (C9 = `present`), or the user can see that the session is on a local model.

When any condition is unmet or `unknown`:

| Path | Action |
|---|---|
| Main default | API model only. |
| First fallback after the primary | API model only. If a free primary hit an **account-level** limit, the fallback must not be another model sharing that limit (see `quota-reserve.md`). |
| Later fallback entries | Local permitted, for **non-blocking auxiliary work only** (§6.3a). |
| All API routes unreachable | Log, hold, alert. Do not fall back to local for the main session. |

The last row holds even when conditions 1–4 are met, unless the operator declares local an explicit offline fallback. A box that silently shifts to local during an outage turns an alert-worthy event into an invisible slowdown.

**User choice is out of scope.** A user who types `/model «local-id» --session` has chosen local for their own session. This rule governs what the selector does, not what users may do.

## Verification (read-only)

1. Classify every main-path endpoint (default, plus each fallback the runtime may use for main traffic) by **address**, not by name (§3.16).
2. No main-path endpoint is local → `pass`.
3. A local main-path endpoint exists and conditions 1–4 are recorded as met, with a measurement inside the freshness window → `pass`, reporting the measurement and its age.
4. A local main-path endpoint exists and any condition is unmet → `fail`.
5. The config or fallback list cannot be read, or the runtime's fallback behavior (C11) is unknown → `cannot-observe`.

## Exceptions

- **Fast local hardware:** conditions 1–4 exist for exactly this case. Measure, declare tolerance, and the rule permits local.
- **Local-only boxes** (no API provider at all): the main session is necessarily local. The rule's purpose then reduces to conditions 3 and 4: bounded stalls and visibility. Record the box as local-only.
- **Peer-hosted local models** (C5b): they share their host's failure domain. They are never an *independent* route for §4.9's escalation, even when fast.

## Spec references

§3.16, §3.17, §3.18, §4.15, §4.18, §6.1, §6.3, §6.3a, §6.4, §6.4a, §7.2, §10.28, invariants 2, 3, 9, 10, 38. Resolves handoff T1 for the fallback-head case.
