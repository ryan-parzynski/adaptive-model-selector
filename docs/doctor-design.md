# Design: `switcher doctor`, `plan`, `apply`

**Status:** PROPOSED. Nothing here is implemented.

The first runnable deliverable is read-only. `doctor` discovers what the box is and which rules apply; `plan` shows what the selector would do. Neither touches Hermes. `apply` comes later, after both are tested.

**Language:** Python, with a thin shell launcher for cron or systemd. Logic does not live in shell or in Markdown.

## Layers

```text
Provider adapter     catalog · quota observation · limit scope · error classification
        │
Decision engine      rule cards + capabilities + policy → applicability → checks → selection or hold
        │
Hermes adapter       inspect config · report switch mechanisms and scopes · apply an approved change
```

The decision engine never sees a provider's JSON field names or a Hermes helper's filename. The first provider adapter is `openrouter`: an implementation, not the interface. It reports limits and their structure live every tick (invariant 42); dated notes on the fields it reads are in `docs/adapters/openrouter-notes.md`. Until a field is verified on the running account, the capability that depends on it reports `unknown`.

## Inputs

| File | Owner | Contents |
|---|---|---|
| `policy.yaml` | operator | Declared policies (questionnaire P-rows), tolerances, reserve overrides |
| `deployment.yaml` | operator, seeded by `doctor --init` | Hermes home, config path, provider adapter, capability answers that cannot be detected |
| `state/` | the selector (single writer) | Last decision, last written model, observations, manual-override record, heartbeat, run ledger |

## `doctor`

Read-only. Never writes Hermes config. Any probe that spends quota or writes anything requires an explicit flag and a scratch `HERMES_HOME`.

**Steps**

1. Resolve the Hermes home from the runtime environment, not from the shell's `$HOME` (§1.3).
2. Answer every capability question it can detect (`docs/capability-questionnaire.md`); mark the rest `unknown`.
3. Load the declared policies; mark undeclared ones `unknown`.
4. Resolve each rule card's applicability.
5. Run read-only checks for applicable rules only.
6. Print the report.

**Output.** Human-readable by default; `--json` for machines. The JSON output also serves as the box's self-report (§20.19).

```text
UNRESOLVED (answer these first — they decide what the rest means)
  C5a  local latency profile           unknown   → `switcher measure local`
  P2   local allowed for main?         unknown   → set policy.local_for_main

CAPABILITIES
  C1   bounded free allowance          present
  C1a  free limit scope                unknown   (treated as account-level)
  C2   paid tier                       present
  C5   local models                    present

RULES
  quota-reserve    applicable       pass             reserve=12 (provisional, 31/59 sessions)
  local-as-main    unknown          not run          needs C5a, P2
  inference-ports  applicable       cannot-observe   no disallowed test device

exit 2   (no failures; 1 cannot-observe, 1 unknown)
```

Exit codes follow `docs/two-axis-reporting.md`: 0 all applicable rules pass and nothing is unknown; 1 any failure; 2 otherwise.

**Self-test.** `doctor` runs against fixture boxes in its own test suite, including a fixture where every read fails. That fixture must exit 2, never 0. This guards against the defect class found in the embedded scripts (handoff D2, D9–D11), where a failed read produced a pass or a false match.

## `plan`

Read-only. Computes the selection the selector would make right now and explains it.

- Prints the chosen model, the rule that chose it, the observations it used, and every candidate rejected with its reason.
- Writes a **plan file** to `state/plans/` containing the decision and a fingerprint of the inputs it depended on.

**What the fingerprint covers.** Only the inputs that would change the decision:

- the policy file hash;
- the current Hermes default and provider, exactly as read;
- the chosen model's presence in the catalog and its price class (free / paid), not its exact price;
- the quota observation **bucketed** relative to the reserve (above / at or below / unreadable), not the raw count;
- the manual-override state.

The whole catalog and the raw quota count are deliberately excluded. Prices and counts change constantly, so fingerprinting them would invalidate every plan within minutes and make `apply` refuse almost always. Operators would then learn to bypass the check.

## `apply`

Writes only an approved plan, and only through the mechanism `doctor` reported as available.

1. Re-read the fingerprinted inputs. If any differs from the plan file → refuse, and print what changed.
2. If the manual-override state is `paused` → refuse.
3. If the box is not the recorded owner of the default → refuse.
4. Take a `flock` on a dedicated lock file (not on the config).
5. Write through the sanctioned Hermes path where one exists. Otherwise write with a round-trip-preserving YAML library, so comments and key order survive (handoff E1), as one atomic rename (§4.14). `doctor` must have confirmed C12 first.
6. Record what was written in `state/` as `selector_last_written_model`.
7. Re-read and confirm the write landed (§7.7). A write that did not land is a failure, not a success.

A scheduled run is `plan` then `apply` on the same plan file, in one invocation.

## Manual-override handling

Specified in §4.14a and invariant 41. On every run, before planning:

- If the current default differs from both `selector_last_written_model` and the plan's choice, someone else changed it. Enter the pause and record:

```yaml
manual_override:
  detected_at:
  observed_model:
  selector_last_written_model:
  hold: false              # true when the operator ran `switcher hold`
  pause_expires_at:        # detected_at + manual_override_hours (default 4); empty when hold is true
  resume_source:           # manual | timeout, set on exit
```

- While paused, the selector **never writes** and never reverts the change. `doctor` and `plan` show the pause and its expiry on every run.
- **Exit:** `switcher resume` at any time; otherwise when `pause_expires_at` passes, unless `hold` is true. On expiry the selector logs the resume, announces it through a verified alert path if one exists, and re-plans.
- After any exit, a change is written only if the current policy still selects a different model.
- A new foreign write during the pause restarts the window.

## Build order

1. `deployment.yaml` / `policy.yaml` schema, plus example setups: free-only, single paid key, paid plus local GPUs, several independent boxes.
2. `doctor` (read-only) with fixture tests, including the all-reads-fail fixture.
3. `plan` (read-only).
4. `openrouter` provider adapter, verified against current documentation; one Hermes adapter for a named, tested build.
5. `apply` with ownership, locking, round-trip-safe writing, and manual-override handling.
6. Optional: fleet reporting over declared-shared properties; more adapters.
