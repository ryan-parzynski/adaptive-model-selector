# Rule card: quota-reserve

**Status:** PROPOSED card. Consolidates §3.27, §4.9, §4.13, §6.5, invariants 6 and 17.

## Purpose

Do not start or continue work on a bounded free allowance when the remaining allowance is likely to run out partway through a session. Running out mid-session produces a 429 in the middle of a conversation or tool loop, which is worse than starting the session on another tier.

## Applies when

| Condition | Questionnaire |
|---|---|
| The main session uses a model with a bounded free allowance | C1 = `present` |
| The remaining allowance can be read, or meaningfully estimated, without spending it | C3 = `present` (if `absent`, the rule is applicable but its checks are `cannot-observe`) |

If C1 is `absent` (paid only, or local only), the rule is **not applicable**.

Whether a paid tier exists (C2) does not decide applicability; it decides what the rule *does* (see Decision).

## Evidence

- **OBSERVED (reference deployment, §3.27, Record 3 #3):** one turn costs one request per tool round, so a turn with five tool calls costs five requests. Sessions parked on the last few requests failed mid-turn.
- **OBSERVED (§4.13):** a single session could consume the entire daily allowance in one tool loop. A reserve sized to an average turn did not protect against it. The unit that matters is the **session**.
- **Limitation:** within one account, every window draws from the same allowance. A reserve cannot stop a session that is already bound to the free model from continuing to draw (§4.13, "shared budget"). The reserve only governs where *new* sessions start.

## Measurement

| Value | Unit | How to collect | Uncertainty |
|---|---|---|---|
| Per-session draw | requests per session | Count requests per session id from the runtime's logs or state over the last N days | Sessions vary widely; the distribution is long-tailed |
| Reserve | requests | See below | — |
| Allowance cap | requests per period | Read it every tick, not just `remaining` | Some providers change the cap with account state (handoff E9) |

**Sizing the reserve.** The reserve should exceed what a single heavy session draws, so use the high end of the per-session distribution:

- With **fewer than 59 sessions** recorded, use a conservative fixed reserve and label it **provisional** in logs and in the box record.
- With **59 or more sessions**, use the **largest observed per-session draw** as the reserve. With 59 samples, there is a 95% chance that the largest one is at or above the true 95th percentile, because 0.95⁵⁹ < 0.05. This is the correct reading of the spec's "sample floor of 59". It is not an instruction to compute a p95 from 59 points, which would be noisy, and it is not the "rule of three" (a different 3/n bound).
- Re-derive the reserve on a schedule; a workload change makes old samples misleading.

## Decision

Evaluated each tick, for **new sessions only**:

| Condition | Action |
|---|---|
| `remaining > reserve` | Free model is eligible as the default. |
| `remaining ≤ reserve`, and an eligible paid tier exists (C2) | Move the default to the paid tier until reset. |
| `remaining ≤ reserve`, and no eligible alternative exists | **Hold** the current default and **alert**: "free allowance at reserve; new sessions may fail mid-turn; resets at «recovery instant»." Do not switch to another free model that shares the same account-level allowance (C1a). |
| The allowance cannot be read | Follow §4.9's failure-class routing; the reserve check is `cannot-observe`. |

**Returning to free** after reset requires sustained healthy reads (§4.13 hysteresis), not a single read at the reset instant.

**What counts as an eligible alternative.** A model that does not share the exhausted dependency. When the free limit's scope is unknown (C1a = `unknown`), treat it as account-level, so other free models on the same account are **not** eligible alternatives.

## Verification (read-only)

1. Read `remaining`, `cap`, `reserve`, and the current default's tier.
2. If any of them is missing, empty, or non-numeric → `cannot-observe`. (The illustrative §10.16 check returns `pass` on a non-numeric value; that is a known defect, D10.)
3. If `remaining ≤ reserve` and the default is free → `fail`.
4. If `remaining > reserve`, the default is paid, and the reason recorded for being on paid is not a policy or operator choice → `fail` (the selector failed to return to free).
5. Otherwise → `pass`.
6. Report whether the reserve is **provisional** and the sample count.

## Exceptions

- **Rolling-window allowances (C1b = rolling):** there is no reset instant. Replace "until reset" with "until `remaining` is above the reserve on sustained reads".
- **Non-text work types:** the reserve protects free text turns. Do not apply it to image, video, or audio routing (§4.16).
- **A deliberately free-only operator** may set the reserve to 0 and accept mid-turn failures. That is a valid choice. Record it explicitly so the check does not report it as a defect.

## Spec references

§3.27, §4.9, §4.13, §4.13a, §4.13b, §6.5, invariants 6, 17, 20, 37. Corrects the wording behind handoff T3 (sample floor) and T4 (per-turn vs per-session).
