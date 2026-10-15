# Two-axis reporting: applicability vs. check result

**Status:** ADOPTED in v3.3 — replaced the "N/A is PASS with a note" convention. The spec text now lives in §0.6, invariant 33, the §10 header, §12 and §18; the draft wording that used to be at the end of this file has been applied.

## The problem with the current convention

The specification reports three check results — PASS, FAIL, CANNOT-OBSERVE — and folds "this rule does not apply here" into PASS with a note (§0.6, invariant 33). That merges two different questions:

1. **Does this rule apply to this box?** (a fact about the box's resources and policy)
2. **Does the box satisfy the rule?** (a fact about the box's current state)

When they are merged, a free-only box and a box whose paid tier is broken can print the same word, and a reader scanning for problems cannot tell a deliberate absence from a missing check.

## The model

Every rule is reported on three fields. The first two decide whether the third is evaluated.

| Field | Values | Answers |
|---|---|---|
| **capability** | `present` · `absent` · `unknown` | Does the box have the resource the rule depends on? Detected by `doctor` or declared by the operator. |
| **applicability** | `applicable` · `not-applicable` · `unknown` | Given the capabilities and the declared policy, does the rule bind on this box? |
| **check** | `pass` · `fail` · `cannot-observe` · *(not run)* | Did the box satisfy the rule? Evaluated only when applicability is `applicable`. |

### Deriving applicability

Applicability is computed from the rule card's `applies_when` against the capability questionnaire answers and the declared policy:

- Every condition in `applies_when` is met → `applicable`.
- Any condition is definitely not met, **because a capability is `absent` or the policy explicitly excludes it** → `not-applicable`.
- Any condition depends on a capability that is `unknown` → `unknown`.

### The rules that keep this honest

1. **`not-applicable` has only two sources:** a capability detected as absent, or a policy that explicitly excludes the resource. It is never inferred because a check was inconvenient or failed to run.
2. **`unknown` is never silent.** `doctor` lists every rule whose applicability is unknown, together with the capability question that would resolve it.
3. **A check is never run on an `unknown` or `not-applicable` rule.** It is reported as *not run*, with the reason.
4. **A read error is `cannot-observe`, never `pass`** (unchanged from invariant 33).
5. **A required capability that is unavailable is `fail`, not `not-applicable`.** If the policy says "fall back to paid" and the paid tier cannot be reached, the fallback rule is applicable and fails. If the policy says "no paid tier", the rule is not applicable.

### Worked examples

| Situation | capability | applicability | check |
|---|---|---|---|
| No free-tier routing configured | free tier: `absent` | `not-applicable` | not run |
| Free tier configured, quota endpoint unreadable | free tier: `present`; quota observable: `present`, read failed | `applicable` | `cannot-observe` |
| Paid fallback required by policy, provider returns 402 | paid tier: `present` | `applicable` | `fail` |
| Paid fallback deliberately excluded by policy | paid tier: policy-excluded | `not-applicable` | not run |
| Box has local models, but nobody has measured their latency | local models: `present`; latency profile: `unknown` | `unknown` | not run — `doctor` asks the latency question |

## Exit codes

For a single rule check, exit codes are unchanged: 0 pass, 1 fail, 2 cannot-observe. A check is not invoked for rules that are not applicable or unknown.

For an aggregate report (`doctor`, or a scheduled run of all checks):

| Exit | Meaning |
|---|---|
| 0 | Every applicable rule passed; no applicability is unknown. |
| 1 | At least one applicable rule failed. |
| 2 | No failures, but at least one rule is `cannot-observe` or has `unknown` applicability. |

Failure outranks cannot-observe, because a known problem should not be masked by an unrelated gap.

## Where this lives in the spec

§0.6 (definitions and aggregate exit codes), invariant 33, the §10 header, §12 (applicability recorded per row), §18 (Applicability, Capability, N/A), and §29.2 (`not-applicable` instead of `N/A` in the ledger).
