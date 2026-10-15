# v3.3 — rule pass from 3.2c

Changes in this pass:
- **Two-axis reporting.** Applicability (`applicable` / `not-applicable` / `unknown`) is separate from the check result (`pass` / `fail` / `cannot-observe`). Replaces "N/A is PASS with a note" in §0.6, invariants 9 and 33, §3.16, §10, §12, §18, §29.2
- **T1** fallback head must not share the failed dependency (§6.4)
- **T2** local-inventory heartbeat refreshed every tick; the material-change gate applies to the resolved set (§26.5, §26.6)
- **T3** sample floor restated: reserve = largest observed per-session draw once ≥59 sessions; "rule of three" removed (§4.13, invariant 17, §18, §20.5, registry)
- **T4** reserve measured per session, not per turn (§28.2)
- **T5** struggle scoring acts only through a reachable session lever; otherwise advisory (§5.2)
- **T6** return to free after reset follows §4.13 hysteresis (§6.5)
- **T7** edge conditions of the aux-head inequality (§4.18)
- **E1** config rewrites must preserve comments and key order (§3.37, §4.14)
- **E2** credit and spend-limit exhaustion added to the failure-class table (§4.9, §6.3, invariant 30)
- **E3** foreign writes enter a time-boxed manual-override pause (§3.38, §4.14a, invariant 41, §10.34)
- **Limits are read, not remembered** — provider limits and their structure are discovered live every tick; numbers in this guide are examples (§3.39, §4.9a-bis, invariant 42, §10.35)
- Local-as-main becomes a default with a measured, conditional exception (§6.1, §6.3, invariant 9; rule card `docs/rule-cards/local-as-main.md`)

---

# v3.2c — housekeeping pass from 3.2b

Changes in this pass:
- Line endings converted from CRLF to LF; `.gitattributes` enforces LF
- Every embedded `bash` block marked illustrative and untested; document-level notice added
- Private deployment record filename removed from Record 6 and from the v3.2b notes
- Whole-repository GPL-3.0 licensing stated in the README

---

# v3.2b — patch pass from 3.2a

Changes in this pass:
- §6.5 completed with the session-unit sentence
- All "Producing in parts" and "Fixes applied" markers removed
- Hash line replaced with integrity sidecar reference
- All broken §26.2/§27/§28/§29 cross-references fixed to point to existing sections
- §26.10 added; invariant 40 added
- Tier terminology unified to Cheap/Medium/Expensive; "Rule tier" glossary entry
- Invariant 36 collapsed to reference §4.9; invariant 21/39 empty-owner deduplicated
- "Applies to both boxes" / "Neither box's alert path" removed from Part I
- Probe timeout +5s; mawk-safe `[[:space:]]`; accepted-differences file
- §10.27 explicit exit codes; hysteresis W→config_writes_per_hour
- private deployment record referenced in Record 6
- Registry: switch_cooldown_min/switch_max_per_hour removed; card-1/2/3 split; hyphenated placeholders → underscores; same_id added
- §14 duplicates removed; "no match"→"match"; divisibility line deleted
- §24 "Each rule has one defining sentence" deleted
- §4.13 "on the order of ten" deleted
- Record 6 dated alert-path status; Record 7 A5/A7/A9 described
- R-n tags added to all §9 invariants
- §2.6/§3.35 fresh-install wording clarified
- `{{hermes_home}}`/`{{scripts_dir}}` placeholders for paths

---

# Hermes Model Switcher — Operator's Guide

**Version:** 3.3
**Last updated:** 2026-10-15
**Purpose:** How to keep one or more Hermes boxes switching models safely, audibly, and without the failure modes this guide names.
**Audience:** Operators of Hermes boxes. Anyone maintaining model routing on a box running the Hermes stack.
**Scope:** Portable. Rules travel; values are per-box and live in the registry file.
**License:** GPL-3.0.

**Authoritative file.** The canonical text of this guide is `HERMES-MODEL-SWITCHER.md`. The companion registry is `HERMES-MODEL-SWITCHER.registry.yaml`. Where a deployment has its own copy, the deployment's copy governs that deployment — but the shape of the guide is this file.

**Integrity:** see `HERMES-MODEL-SWITCHER.sha256`.

**Embedded scripts are illustrative.** Every code block in this document shows the shape of a check or procedure. None is a tested script; several are known to be defective. Do not copy them onto a live box. Tested implementations will ship as files in the repository.

**How to use this document.**

- **Part I — Rules.** The portable rule set. Read this first. It is what a forker adapts.
- **Part II — Runbook.** Checks and procedures. Referenced from Part I by section number.
- **Part III — Record.** Incident history, decisions, box findings. Read it or don't; the rules stand alone.

**Read in this order:** §0 (summary), §0.5 (failure classes), §0.6 (claim discipline), §4 (selection), §6 (escalation), §9 (invariants).

**Registry.** Every config key, path, number, and cadence used in this guide lives in `HERMES-MODEL-SWITCHER.registry.yaml`. Prose refers to them by name (`{{reserve}}`, `{{stream_stale_timeout}}`). Fill the registry before deployment; the guide is incomplete without it.

**Provenance.** Composed from two independently-developed switchers and the reviews that tested them against running deployments. Rule sources are cited where a fact is deployment-specific. The name `Hermes` in this document refers to the agent runtime, its gateway, its dashboard, and its TUI clients, and the config file they read.

---

## PART I — RULES

## §0 — Summary

The Hermes model switcher does not work the way its documentation says. This guide collects what was learned across multiple deployments, in a form that applies to any Hermes box.

Four principles drive everything below:

1. **Fail loud.** A silent degradation is worse than a loud failure. "Loud" is defined in §0.6.
2. **Never route a decision through the failure domain.** Fixes must originate outside the system they're fixing.
3. **Classify claims.** Every statement about the system is OBSERVED, HYPOTHESIS, REPORTED, PROPOSED, or BLOCKED. Do not confuse them.
4. **Keep boxes aligned by contract, not by hope.** Drift between "the same" boxes is the default. Alignment is a check, not an assumption.

**Terminology used throughout.** Definitions in §18:

- **Box** — one Hermes deployment.
- **Selector** — the component that reads the model catalog and writes the model choice.
- **Tick** — one scheduled run of the selector.
- **Owner** — the single component authorized to write `{{model_default}}`.
- **Ladder** — the ordered list of models the selector considers.
- **Hot path** — the code executed inside a user prompt; does no I/O (box-owned code; §27.2).
- **Tick path** — the code executed on the selector's schedule; does the network work.
- **Event path** — the code executed on a material change; writes config.

**Where each concern lives:**

| Concern | Section |
|---|---|
| Failure classes | §0.5 |
| Claim discipline and "loud" | §0.6 |
| Environment, switch mechanisms, trap doors | §1–§3 |
| Model selection, escalation, chains | §4–§6 |
| Health, alignment, invariants, checks | §7–§12 |
| Onboarding, do-not list, quick reference | §13–§15 |
| Open questions, failure patterns, glossary | §16–§18 |
| Failure-domain isolation | §19 |
| Further work, document meta, provenance | §20–§25 |
| Local inventory (dynamic) | §26 |
| Hot-path discipline | §27 |
| Parameter structure | §28 |
| Weekly review ledger | §29 |

---

## §0.5 — Failure classes

These recur across deployments. Each has a signature and a fix.

**Class numbering:** 1, 2, 3, 4, 6, 7, 8. **Class 5 is skipped.** Do not renumber.

### Class 1 — Silent stall

**Signature:** a session hangs for minutes with no user-visible output. No error, no timeout, no indicator.

**Common causes:**

- Free-tier daily request budget exhausted. The provider returns 429; the client retries silently instead of surfacing it.
- Streaming stale. A response begins but stops producing chunks; the client waits for a threshold that may be long or unset.
- Auxiliary call in the critical path. Compression, extraction, or parsing hangs on a slow provider.
- Client-side retry loop. A previous transient error left the session in a retry state.

**Fix patterns:**

- Set a streaming stale timeout low enough to matter (§3.2).
- Emit a visible log line and a user-visible indicator when a request exceeds an expected ceiling.
- Do not route blocking auxiliary work to slow providers without a hard timeout.
- Probe liveness from outside the failing path (§7).

### Class 2 — Wrong default, unattended

**Signature:** `{{model_default}}` changes without a human decision. New sessions start on a model nobody chose.

**Common causes:**

- Multiple writers to the config file. A dashboard or a `--global` TUI action writes the shared config. No lock, no ownership.
- A scheduled job whose policy sets a specific tier when a condition is met.
- Startup resolution reading a file a previous session left in a certain state.

**Fix patterns:**

- Treat the config file as advisory, not authoritative.
- Inventory every writer, including scheduled jobs, TUIs, and dashboards.
- Classify jobs by their effect on the default: **CLOBBER** (moves toward paid or a specific tier), **SAFETY** (moves toward free or cheap), **NEUTRAL**.
- Disable only CLOBBER jobs, and only after verifying the policy.
- Gate writes on a material change so the log shows only real changes (§4.14).
- Confirm the single owner (§3.7, §9 invariant 21).

**Note on TUI scope.** On builds where the plain `/model` form is session-scoped (§2.6), a TUI action does not rewrite the shared config. An operator who expects a TUI `/model` to write the config is reading an older build's behavior. Verify on the running build (§10.19).

### Class 3 — Error masquerading as health

**Signature:** a monitor reports "healthy" while the system is failing.

**Common causes:**

- Latency-based health checks that classify a fast-but-failed response (e.g., a 429) as good.
- Validators whose tests validate the validator's own assumptions, not the real schema.
- Alert paths whose delivery target resolves to nothing. Jobs run; output discarded.
- **An observer that measures a different quantity than the one that is failing.** A session stuck on a slow local card is a *cost saving* to a spend tool and a *stall* to the user. Both readings are true; only one is the fact that matters. No amount of fixing the delivery channel will surface it — by the existing observer's own measure, nothing is wrong.

**Class 3 causes, enumerated:**

- **Latency-based health** — a fast response is treated as healthy; a fast 429 is fast and dead.
- **Cost-based health** — a card-bound session is recorded as a saving; the user experiences a stall.
- **Quota-based health** — a 300-second model looks acceptable because its quota is fine.
- **Shared-budget instance** — one session bound past its scope keeps drawing from the account pool; the observer sees the pool draining, not the session draining it.

All four are the same shape: the observer measured a different quantity than the one failing. **When a failure is invisible, ask which question nobody is asking — not which alert isn't firing.**

The companion shape — a correct decision that failed to apply — is **Class 8**, a separate class, not a fifth Class 3 cause. The fix is a capability probe, not a new sensor.

**Fix patterns:**

- Health signals must be status-based first, latency-based second. A 429 is fast and dead.
- Validate against real schema, not against the shape you assumed.
- Test the alert delivery path end-to-end, not just its config.
- Write the detector for the unasked question.

### Class 4 — Fix attempted from inside the failure

**Signature:** an agent is asked to design or apply a fix for the failure it is currently experiencing.

**Common causes:**

- Stuck session prompts. The user asks the hung agent to unstick itself.
- Circular dependencies. The monitoring system runs on the tier it monitors.

**Fix patterns:**

- Every fix must originate outside the failure domain. See §19.
- A stuck session cannot unstick itself. It needs a manual command in its own window, or a restart.

### Class 6 — Verification step tests the wrong surface

**Signature:** a runbook or guide tells the operator to verify a capability with a command that cannot observe that capability. The check passes or fails for reasons unrelated to what it claims to test.

**Worked example (illustrative).** A guide's verification step greps a command's `--help` output for slash-command flags. Those flags are parsed inside the slash command, not exposed at the top level. `--help` can never list them. The check silently returns nothing.

**Root cause:** a general rule ("verify flags exist before using them") was applied to a surface that doesn't expose the fact being checked.

**Fix pattern:** before writing a verification step, ask *what surface exposes this fact?* CLI flag → `--help`. Slash-command flag → source or live probe. Config value → read the config. Runtime behavior → observe the runtime. **A check that cannot observe the fact is a ritual, not a check.**

**Second instance, same session (illustrative).** During the work that produced this class, two system states were asserted from memory rather than probed. Both were caught by probing. **Two instances in one session is a pattern: the agent writing the rule commits the rule.** Counter-rule: **probe, then state.**

### Class 7 — Probe too small to observe the answer

**Signature:** a probe reports a working model as dead, or a healthy lane as broken, because the probe expired before the model produced the thing being measured.

**Worked example (illustrative).** A model was probed with a small token budget. The call returned HTTP 200, used the entire budget, and returned an empty answer. Read naively: "the model answers nothing." Re-probed with a larger budget, the same call returned a real answer — because the model emits a thinking block first (in one observed case, ~150 tokens) before producing output. The model was never broken: the probe's budget expired inside the reasoning.

**Same family as Class 6.** Class 6 is "the check cannot observe the fact"; Class 7 is "the check cannot reach the fact". Both end in a confident wrong verdict about a healthy system — the expensive direction.

**Fix pattern:**

- Size a probe for the task. A reasoning-capable model needs room to finish thinking before it can answer. If the probe returns `finish_reason: length` with no content, the probe was too small — that is a **probe verdict, not a model verdict**.
- Assert on content, not transport. HTTP 200 plus a token count is not evidence of an answer.
- Some runtimes expose the reasoning separately (`thinking` vs `response`). Know which field you are reading.
- Never report a model as dead from one probe. Report what the probe returned and what it could not observe.

**This rule binds the guide's own probe.** §7.2's probe timeout and token budget are properties of the question, not constants. A fixed timeout correct for a chat model is wrong for a reasoning model. See §7.2.

### Class 8 — Silent actor failure

**Signature:** a decision is made correctly, the component that would apply it fails, and nothing surfaces. The decision looks fine in the log; the action never happened.

**Worked example (illustrative).** A selector made correct routing decisions all evening and applied none of them. Every automatic switch died because the interpreter-discovery path found nothing on the box. The operator concluded "the switcher didn't rescue me"; the switcher had tried and could not act.

**Base-layer cause — a tool that cannot start produces the symptoms of a tool that ran and chose wrong.** A selector that never runs looks like a selector that parked on the wrong model. A verifier that never runs looks like a verifier that found no fault. The fixes differ: a wrong choice needs a new rule; a tool that cannot start needs a capability probe and a loud failure.

**Detection:** before diagnosing a component's output, read its last exit code and its first log line. A component that exited non-zero produced an error, not a decision. **Read the exit code, not the job state.**

**Why it is not Class 3.** Class 3 is an *observer* measuring the wrong quantity. Class 8 is an *actor* failing while the decision is correct.

**Fix pattern:**

1. **Probe capability, not path.** Before a script depends on an interpreter, binary, or module, prove it works in the environment the script will actually run in.
2. **Fail loud when the probe fails.** A decision that cannot be applied must log that fact to a verified destination.
3. **Test the actor from an environment that does not provide what it needs.** Run the real action from a temp home with none of the expected directories.

**Relation to Classes 6 and 7:** all three are "the check could not observe or reach the fact." Class 8 adds a fourth: the actor could not act on the fact.

---

## §0.6 — Claim discipline

Every statement about the system falls into one of five states. Do not blur them.

| Label | Meaning | Evidence required |
|---|---|---|
| **OBSERVED** | Directly checked on a specific box, at a specific time, with a specific command. | Command output, log line, or file hash. |
| **HYPOTHESIS** | Candidate explanation, not reproduced. | State what would verify or falsify it. |
| **REPORTED** | Came from a session or agent, not independently verified. | Name the source. Mark as unverified. |
| **PROPOSED** | Design intent. Not running. | State what would implement it. |
| **BLOCKED** | The only available fixes would clobber another writer's state, undo a decision someone else made, or pick a policy the agent is not authorized to pick. | The evidence on both sides, the options, the owner's question. |

Two further qualifiers:

- **SOURCE-VERIFIED** — the code path exists. Not the same as having run it.
- **LIVE-RUN-VERIFIED** — the command has been executed and the outcome observed.

If you cannot fill in the evidence column, the claim is HYPOTHESIS or REPORTED, not OBSERVED.

**Status words used in this guide map onto the five states:**

- APPLIED = OBSERVED (the change is in place and verified).
- SKIPPED = OBSERVED (already correct; not a change).
- PENDING = PROPOSED (planned, not done).
- DEFERRED = BLOCKED with a named reason (waiting on a dependency).
- N/A = applicability `not-applicable` (below). **It is not a check result.**

**Applicability and check results are separate axes.** Each rule first resolves its **applicability** from the box's capabilities and declared policy:

- **applicable** — every condition the rule depends on holds.
- **not-applicable** — a capability the rule depends on is detected as absent, or the policy explicitly excludes it. **Never inferred because a check could not run.**
- **unknown** — a capability or policy the rule depends on has not been determined. Reported, with the question that would resolve it; never skipped silently.

Only applicable rules are checked. A **check** returns one of three results:

- **PASS** (exit 0) — the check observed the fact and the fact was correct.
- **FAIL** (exit 1) — the check observed the fact and the fact was incorrect. A resource the policy requires but that is unavailable is FAIL, not not-applicable.
- **CANNOT-OBSERVE** (exit 2) — the check could not reach the fact. A read error, a missing input, or a missing tool is CANNOT-OBSERVE, never PASS.

An aggregate report exits 1 if any applicable rule failed, otherwise 2 if any rule is CANNOT-OBSERVE or has unknown applicability, otherwise 0. The capability questions are in `docs/capability-questionnaire.md`; the full model is in `docs/two-axis-reporting.md`.

**Half-implemented is not PROPOSED.** Before labelling something PROPOSED, check whether the mechanism it depends on already exists. A feature can be half-built: the runtime tracks a value but nothing surfaces it. The correct label is "partially implemented — surface proposed."

**Do not infer a successful write from the absence of an error in your own output.** A shared store at or over its cap refuses every writer; the refusal is a capacity error, not a permission error, and it is easy to miss. Read current usage against the cap before assuming a write landed. *An over-budget shared store fails closed for every writer, silently.*

**"Loud" is a defined term, and it is not the same as "fail loud."** The guide uses one term, **loud**, with this definition:

> **Loud** — delivered to a destination outside the box that a human watches, where a test message to that same destination succeeded end-to-end within the last `{{loud_verification_window}}`, and the event repeats or escalates until acknowledged.

Writing to a log file is **recorded**, not loud. If the destination has not been verified within the window, every fail-loud rule is unmet and the check reports FAIL, not PASS.

**A rule that says "fail loud" is met only when delivery is loud per the definition above.** The phrase "fail loud" in this guide always means "log *and* deliver loudly"; a deployment with no verified destination has no rule that can be met, and the check's result is FAIL, not PASS.

---

## §1 — Environment assumptions

**What "Hermes" means in this guide.** The agent runtime, its gateway, its dashboard, and its TUI clients, and the config file they read. Rules in this guide bind to the *policy* of model routing; rules that bind to a specific build are tagged "version-specific."

### 1.1 Processes

A Hermes deployment typically runs several long-lived processes:

- A **gateway** or main runtime.
- A **dashboard** serving an HTTP API on a local port.
- One or more **TUI sessions** or windowed clients, each its own process.

Each TUI session binds its model at creation. A running session keeps its in-memory model until a scoped `/model` command is issued in that window or the process is restarted. The dashboard offers a scope-limited external switch (§2.2); a bare `/model` command inside a session is session-scoped on current builds (§2.6). A config write reaches new sessions only.

**Consequence:** a script that changes the config for new sessions does not reach a session that has already bound its model. See §3.5.

### 1.2 Supervision

Hermes is usually supervised by one of:

- A user systemd unit (e.g., `{{service_name}}.service`).
- A system scope or transient unit.
- A container.

Restart semantics vary. **Verify the supervisor before assuming a restart command works.** No `ExecReload` is defined by default; a reload signal is typically equivalent to a restart.

### 1.3 File layout

```
{{hermes_home}}/
  config.yaml                 # {{model_default}}, {{model_provider}}, providers, fallback_providers
  model-override              # read at startup only; verify on your build
  free_model_prefs.json       # preferred free models, fallback paid model, scoring
  model_tiers.json            # tier definitions (if used)
  .env                        # provider keys; check for duplicate entries
  auth.json                   # credential pool; may be empty when env is used
  state.db                    # runtime state (sqlite; may not be readable)
  cron/jobs.json              # scheduled jobs
  logs/
    agent.log                 # primary signal source
    errors.log                # provider errors
    «other logs»              # e.g., verify-*.log, failover.log
  scripts/                    # selector and helper scripts
  profiles/                   # per-profile dirs; absence can cause phantom assignees
  state/                      # mode 700; heartbeat and ledger files
```

**A box may mount `{{hermes_home}}` under more than one path.** Verify by reading `{{hermes_home}}` from the runtime environment, not from the shell's `$HOME`. A harness that resolves the shell's `$HOME` may read a directory with no config.

### 1.4 Model resolution

At process start, the runtime resolves the model from (in typical priority):

1. `temp-override.json` — **build-specific.** If the running build supports it, describe the file in this section; otherwise it is absent. Confirm on your build before relying on it. See §16 Q25.
2. `model-override` — read at startup only; verify on your build.
3. `{{config_path}}` → `{{model_default}}` + `{{model_provider}}`.
4. Fallback providers declared in config.

At runtime, a sanctioned switch path typically exists in-process. Its scope depends on the command form (§2.6, §2.7). **It does not reach other running sessions.** See §2.

**Version tag:** the resolution order above is typical for the current lineage. A different build may reorder or omit entries; verify with a live probe (§10.19).

---

## §2 — Sanctioned switch mechanisms

### 2.1 In-process API

Most builds expose a `switch_model()` function reachable:

- Via a CLI slash command inside a running session (`/model ...`).
- Via a dashboard HTTP endpoint (e.g., `POST /api/model/set`).
- Via a helper script that imports the same function and calls it.

**Prefer the sanctioned path over editing the config file directly.** The sanctioned path applies validation, updates provider clients, and persists consistently. A script that writes `{{config_path}}` directly bypasses validation and provider-client updates; it should do so only when a helper is not available, and the limitation should be stated in the deployment's §12 record.

### 2.2 Dashboard endpoint pattern

```
POST http://127.0.0.1:{{dashboard_port}}/api/model/set
Content-Type: application/json
Cookie: <session cookie from the auth endpoint>

{
  "scope": "main",
  "provider": "{{provider}}",
  "model": "{{model_id}}",
  "confirm_expensive_model": <bool>
}
```

Send `confirm_expensive_model: false` unless the target tier is explicitly authorized. Setting it `true` unconditionally disables an important guard.

**Version-specific:** the endpoint path and `confirm_expensive_model` field exist on the current build; a different build may name them differently. Verify against the running dashboard's API documentation.

### 2.3 Auth

The dashboard typically requires a session cookie obtained via a login endpoint. Read the password from a mode-600 file:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
umask 077
set -a; . "{{hermes_home}}/secrets/dashboard.env"; set +a
```

Never pass a password on the command line. Never hardcode it in a script.

### 2.4 Hardened example

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
umask 077
set -a; . "{{hermes_home}}/secrets/dashboard.env"; set +a

COOKIE_JAR=$(mktemp); LOGIN_BODY=$(mktemp); SWITCH_BODY=$(mktemp)
cleanup() { rm -f "$COOKIE_JAR" "$LOGIN_BODY" "$SWITCH_BODY"; }
trap cleanup EXIT

# The password is read from the environment inside jq's program, not passed
# as an argument. `jq --arg p "$DASH_PASS"` would put the secret in argv,
# visible to any local user via /proc during the run.
jq -n '{username: env.DASH_USER, password: env.DASH_PASS, provider:"basic"}' > "$LOGIN_BODY"

if ! curl -sf --connect-timeout 5 --max-time 15 \
     -c "$COOKIE_JAR" -X POST "${DASH_URL}/auth/password-login" \
     -H "Content-Type: application/json" -d @"$LOGIN_BODY"; then
  echo "dashboard login failed" >&2; exit 3
fi

if ! jq -n --arg p "$PROVIDER" --arg m "$MODEL" --argjson c "${CONFIRM:-false}" \
        '{scope:"main", provider:$p, model:$m, confirm_expensive_model:$c}' > "$SWITCH_BODY"; then
  echo "jq failed to build switch body" >&2; exit 4
fi

curl -sf --connect-timeout 5 --max-time 15 \
  -b "$COOKIE_JAR" -X POST "${DASH_URL}/api/model/set" \
  -H "Content-Type: application/json" -d @"$SWITCH_BODY"
```

Notes:

- `mktemp` not predictable names.
- `umask 077` before any file with credentials.
- `jq -n` builds JSON; no shell interpolation into JSON.
- **No secret is ever a command-line argument.**
- Every step checks its exit code before the next runs. A failed login does not send the switch; a failed JSON build does not post.
- Connection and overall timeouts on every call.

### 2.5 Helper script pattern

If the deployment provides a helper (a Python script that imports the switch function and persists the result), prefer it to direct API calls. It avoids dashboard auth handling and is the path the sanctioned writers use.

**The helper's wrapper does the interpreter discovery.** The `.py` file itself does not discover its interpreter; the shell wrapper that invokes it does. The wrapper probes the capability the helper needs, using the same flags the helper will run under:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Discover an interpreter that can import the switch function. The check
# must test the capability the helper needs, not merely `import yaml`.
PY=""
for cand in "{{hermes_home}}"/installs/*/environments/*/venv/bin/python3 \
            "{{hermes_home}}"/tools/python-*/bin/python3 \
            "$(command -v python3)" /usr/bin/python3; do
  [ -x "$cand" ] || continue
  # Probe the capability the helper depends on. Substitute the module the
  # helper actually imports for the placeholder below.
  if "$cand" -I -c 'import {{helper_required_module}}' 2>/dev/null; then
    PY="$cand"; break
  fi
done
[ -n "$PY" ] || { echo "no python with {{helper_required_module}}" >&2; exit 2; }

"$PY" -I "{{scripts_dir}}/_model_switch.py" "{{model_id}}" "{{provider}}"
```

**Discover interpreters and binaries by capability, not by path.** A path that exists does not imply a capability. Test the module the helper actually needs, with the same interpreter flags the helper will run under (`-I` removes the caller's path and user site-packages from the import search).

**Four live instances of the same trap (illustrative):**

1. A launcher exists but cannot import the helper's module.
2. A runtime interpreter exists but cannot import the module the script needs.
3. A harness assumes the shell's home is the runtime's home when the runtime home is elsewhere. (On one deployment, the cron ticker ran with one `HOME`, shells ran with another, and a path alias pointed both at the same store. A harness resolving the shell's home was passing and failing against a directory with no config.)
4. A dependency is assumed present because the source tree lists it. (A Python package was absent after a rebuild on one box; a script exited non-zero on every run while the job list showed it as active.)

All four pass "the location exists" and fail the actual work. **The probe must run the thing, in the environment the thing will run in, resolving the paths the runtime resolves — not the paths the author's shell resolves.**

A helper that hardcodes a home is a portability bug. The helper should read `{{hermes_home}}` (with a sane default), not a literal path; a clone that bind-mounts the home under a different name works, a clone that moves it does not.

**Companion mechanism note:** some actions cannot be applied from inside a session. A config write may require the CLI with `{{hermes_home}}` set; values snapshotted at agent build never hot-reload, so a new session or window is required. **A config write that silently does not land is Class 8's cousin** — probe capability, fail loud.

### 2.6 What runtime switching does and does not do

**Scoped `/model` commands.** The current build defaults to **session-scoped** for the plain form. Earlier builds wrote `{{config_path}}` on plain `/model`. Anyone relying on the old behavior is wrong on this build.

**This is the canonical scope table; other sections cite it.**

| Command | Scope | Writes `{{config_path}}`? |
|---|---|---|
| `/model {{model_id}}` | session-scoped (current default) | no — unless the fresh-install case below |
| `/model {{model_id}} --once` | next turn only | no |
| `/model {{model_id}} --session` | this session only | no |
| `/model {{model_id}} --global` | persists for new sessions | yes |

**`--session` vs the plain form:** the two coincide once a `{{model_default}}` is configured — both return `False` from the persistence resolver. They are separate flags with separate semantics. On a **fresh install** (no `{{model_default}}` and no `{{model_provider}}` set yet), the plain form may persist the first switch; `--session` never does. Use `--session` when you want to guarantee no persistence, regardless of install state.

**Verified constraints (on the current build):**

- `--once` requires a live session. It is a hard error outside one.
- `--once` and `--global` together is a hard error.
- A config key (`{{persist_switch_by_default_key}}`) restores the old behavior. Do not set it unless you want plain `/model` to write config.

**Does:** switch the caller's in-memory model at the chosen scope; `--global` writes `{{config_path}}` for new sessions; on a fresh install, the plain form may too.

**Does not:** reach another running session; force a running session to keep a switched model past its scope; prevent another writer from overwriting `{{config_path}}`.

**On "persist":** only `--global` persists for new sessions. Everything else is scoped to the current turn or session. The `--session` form is the one a TUI user types in their own window; it is not reachable from a scheduled selector (§3.5). A rule that needs a session-scoped switch from the selector must state how the selector reaches it.

**Version-specific:** the scope behavior is build-dependent. Confirm the running build's default with the live probe in §10.19 before relying on the table above.

### 2.7 Per-session override

A user who needs a specific model for a specific scope uses a scoped `/model` command. The scopes are the table in §2.6; they are not repeated here.

**Rules:**

- A scoped override does not modify `{{model_default}}`. The ladder applies to new sessions; an overridden session keeps its override until the scope ends.
- The switcher's reports do not claim to have changed an overridden session. Reports name the sessions the switcher can reach (new sessions) and list the sessions it cannot reach (§3.5).
- If a switcher or scheduled job later writes `{{config_path}}` with `--global`, running sessions with an active override are unaffected. The override is in-memory; the config write is for new sessions.
- A `--once` override restores after one turn. Do not combine `--once` with a long-running task or the restore will fire mid-task. Use `--session` instead.
- The runtime's guards (`--once` requires a live session; `--once` + `--global` is a hard error) are enforced. Do not work around them.

**Detection:** the current session's model is visible in the status bar or via the runtime's status command. If it differs from `{{config_path}}`'s `{{model_default}}`, a scoped override is active.

**Reachability from the selector.** On current builds, a scheduled selector **cannot** issue a `--session` switch into a running session. The `--session` scope is typed inside the session's own window. A rule that needs a per-session switch from the selector (e.g., §5.8) must either name the mechanism the selector uses (a runtime-provided session-scoped API), or state that the rule is advisory when no such mechanism exists.

---

## §3 — Trap doors

Every entry: what it looks like, what it actually is, the fix.

### 3.1 Editing the override file at runtime

**Looks like:** change the file, done.
**Reality:** startup-only on most builds; may be inert entirely.
**Fix:** use the sanctioned switch path.

### 3.2 No streaming stale timeout, or too long

**Looks like:** a hung stream will eventually error out.
**Reality:** without an explicit timeout, a stalled stream may sit for the client's default — often several minutes.
**Fix:** set the streaming stale timeout (`{{stream_stale_timeout}}`) to a value you would tolerate as a user. Choose from the working range; a value below the minimum is a defect, and so is absence. **The key on most builds is the local-stream variant** (`{{stream_stale_timeout_key}}`); verify the exact key on your build and record it in the deployment's §12 record (§10.13).

### 3.3 Reload without restart

**Looks like:** a reload command re-reads config.
**Reality:** no `ExecReload` on most deployments. A reload signal is often treated as a restart.
**Fix:** do not rely on reload. Use the API or accept the restart.

### 3.4 Wrapping the runtime in a per-session loop

**Looks like:** `while true; do hermes; done`.
**Reality:** the runtime is a daemon. The loop never iterates.
**Fix:** external watcher process if you need per-failure handling.

### 3.5 A switch does not reach a running session

**Looks like:** "We changed the default, so the stuck session is fixed."
**Reality:** the switch reaches the caller and new sessions. A running session keeps its in-memory model.
**Fix:** every automated switch report lists affected sessions and the `/model` command for each, plus a restart alternative if the session is unresponsive.

**A scheduled selector cannot issue a session-scoped `/model` into a running session.** The scope is typed inside that session's own window. Rules that assume a per-session lever from the selector (§5.8) must name the mechanism, or state that the rule is advisory.

### 3.6 Config file is last-writer-wins

**Looks like:** the config is a coordination point.
**Reality:** every writer rewrites it. No lock, no ownership.
**Fix:** treat it as advisory. Never assume a write holds beyond the next writer's turn.

### 3.7 A scheduled job whose policy moves the default

**Looks like:** the job is maintaining state.
**Reality:** it may set a default that no human chose.
**Fix:** classify jobs by effect. Disable CLOBBER jobs unless their policy is intended.

**Exactly one component owns `{{model_default}}`.** Every other writer is paused or refuses to write (§4.14). Every switch report names the owner. Invariant 21.

**Owner field.** The owner is recorded in `{{owner_field}}` with the active writer's name or the active writer's job id. **An empty owner field is a defect and raises an alert** — a box with an empty `{{owner_field}}` has multiple writers by default and is running unaligned. Filling the field is an operator ruling, not an agent choice.

A box that runs two selectors with opposite policies (one free-first, one paid-first) will present different behavior depending on which one an agent reads. An agent reading the paused component concludes the wrong thing about the box. **Read the scheduler status before reading the policy.**

### 3.8 Free-tier quota exhaustion looks like a stall

**Looks like:** a provider stall. The session sits, retries silently.
**Reality:** the quota is exhausted; the client swallows the 429.
**Fix:** check the quota endpoint before assuming a stall. Switch off the free tier immediately when exhausted.

### 3.9 Response metadata can mislead

**Looks like:** a log line reports a duration.
**Reality:** the value may be the threshold at the moment of a kill, not an independent dwell time.
**Fix:** for dwell, use request-start-to-kill timestamps from a separate source.

### 3.10 Probe consumes the budget it protects

**Looks like:** a liveness probe every `{{probe_interval}}`.
**Reality:** on a small daily budget, the probe exhausts the budget by midday. The measurement destroys the thing it measures.
**Fix:** prefer passive signals (parse logs). Active probes only when idle, with a strict per-hour cap (`{{probe_per_hour_cap}}`). Where the runtime exposes a zero-cost read (a key-endpoint counter at 0 tokens), use it on every tick; probe only when the counter is unavailable or reads zero.

### 3.11 Probe without a hard timeout hangs

**Looks like:** a probe that waits for a response that never arrives.
**Reality:** the probe's default client timeout may be minutes.
**Fix:** wrap the probe in a hard ceiling, sized to the model class (§7.2). Read the HTTP status explicitly when the probe needs to distinguish outcomes:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# -w '%{http_code}' prints the status on stdout; no -f, so 4xx/5xx
# are distinguishable from a timeout (curl exit 28).
# timeout gets probe_budget + 5 s; curl --max-time gets probe_budget.
status=$(timeout "$(( {{probe_budget}} + 5 ))" curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time "{{probe_budget}}" "{{probe_url}}")
rc=$?
case "$rc" in
  0)   case "$status" in
         200) outcome=ok ;;
         429) outcome=http_429 ;;
         *)   outcome=http_error ;;
       esac ;;
  28)  outcome=timeout ;;
  124) outcome=timeout ;;
  *)   outcome=cannot-observe ;;
esac
echo "probe outcome=$outcome http=$status"
```

`curl -f` collapses every 4xx/5xx into one exit code, which makes a 429, a 403, and a generic 5xx indistinguishable. Read the status explicitly.

### 3.12 Latency-based health classifies fast failures as healthy

**Looks like:** a fast response is a healthy response.
**Reality:** a 429 or a 5xx comes back quickly and is dead. Latency alone misses it.
**Fix:** health signal is status first, chunk-arrived second, latency third. See §7.3.

**Same shape, one level up — the wrong observer.** A monitor can be perfectly accurate and still classify a failure as success, because it measures a different quantity than the one in trouble. Worked example: a session pinned to a slow local card is recorded by spend tooling as a saving, and it is a stall to the human waiting on it. Both readings are true; only one is the fact that matters.

**A failure can be classified as success by the wrong observer.** The fix is not to make the cost tool alert — it is to write a detector that asks the session question, because no existing observer asks it. Before hunting for the alert that should have fired, check whether any monitor is measuring the thing that broke (Class 3; §20.14).

### 3.13 Probe fires on a single outlier

**Looks like:** one slow sample triggers a switch.
**Reality:** shared infrastructure jitters. A single outlier is noise.
**Fix:** percentile thresholds and sustained evidence (multiple consecutive outliers in a window).

### 3.14 A switch does not fix a client-side stall

**Looks like:** session appears stuck, probe returns fast.
**Reality:** the model is responsive; the session is stuck on something else.
**Fix:** classify "probe fast, session stuck" as client-side. Do not switch.

### 3.15 Switch chaining without cooldown

**Looks like:** A slow → B slow → C slow.
**Reality:** provider-wide degradation is not fixed by changing model ids.
**Fix:** cooldown between switches (`{{state_min_dwell}}`); rate limit (`{{config_writes_per_hour}}`); skip recently failed models for a TTL (`{{recent_failure_ttl}}`). These are the same mechanisms as §4.13's hysteresis; see the note there about avoiding duplicate implementations.

### 3.16 Local detection by name is fragile

**Looks like:** a name list.
**Reality:** a custom provider with a local endpoint bypasses any name list.
**Fix:** classify by endpoint. Include private address ranges, common local ports, and any tailnet address space in use. **If the box has no local tier, the rule is `not-applicable` and is reported as such — never as a silent PASS.**

### 3.17 Local providers as the main model

**Looks like:** "resilience — fall back to local if the API is down."
**Reality:** local is typically slower; a silent fallback converts seconds into minutes.
**Fix:** local providers serve non-blocking auxiliary work and the offline tail. Main sessions should fail loud if all API tiers are unreachable, not degrade silently. See §6.3.

### 3.18 Fallback providers route to local

**Looks like:** the main default is API-only, so the path is safe.
**Reality:** the runtime may consult a fallback list at API failure time. Local entries in that list can route the main session to local.
**Fix:** audit the fallback list. The head after the primary must be an API model. Local entries belong only at the tail, and only for non-blocking auxiliary work. See §6.3a.

### 3.19 Validator tested against its own assumptions

**Looks like:** a validator passes on a synthetic config.
**Reality:** the synthetic config may match the validator's assumed schema, not the real one.
**Fix:** test the validator against a sanitized copy of the real config, plus negative tests that prove local entries are caught.

### 3.20 Alert path resolves to nothing

**Looks like:** every job has a delivery target.
**Reality:** the target may resolve to no registered channel. All output discarded.
**Fix:** test the delivery layer end-to-end (§10.12). Do not build escalation on an unverified channel. See invariant 15 and §0.6's definition of loud.

### 3.21 CLI flags assumed to exist

**Looks like:** a command that worked in one context.
**Reality:** the flag may not be accepted on this version.
**Fix:** check the command's help output before writing it into a runbook.

But `--help` only answers for CLI flags. A slash-command flag, a config value, and a runtime behavior each have their own surface (§0.5 Class 6). Verify from the surface that can actually observe the fact.

### 3.22 Source-verified is not run-verified

**Looks like:** a function exists in source, so the command works.
**Reality:** the code path is real; the command has not been executed.
**Fix:** mark source-verified and live-verified separately.

### 3.23 Duplicate keys in the env file

**Looks like:** the key is present.
**Reality:** two entries. Which one wins is parser-dependent. A shell that sources the file with `set -a` typically takes the last match; many `dotenv`-style parsers take the first. A placeholder in the losing position either never applies (harmless) or 401s every provider call (fatal).
**Fix:** determine the winner on the box, never assume. Sourcing test — **print a hash, never the key or a prefix:**

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Source the env file and hash the key's value; the hash identifies which
# entry won without printing any key material. Replace {{provider_key_var}}
# with the variable name from the deployment's registry, not a literal.
bash -c 'set -a; . "{{hermes_home}}/.env"; set +a;
         printf "%s" "${!1:-}" | sha256sum | cut -c1-12' _ "{{provider_key_var}}"
```

Compare the hash against the hash of the known-good key and the hash of the placeholder. A matching hash identifies the winner without printing any key material. A key prefix is still key material and must not appear in a transcript, a log, or a screen.

Same trap in `{{config_path}}`: an inline provider credential can shadow the `.env` value. Grep for the placeholder string.

**The variable name itself is also a redaction concern.** The deployment's §12 record and any published version of this guide should replace `{{provider_key_var}}` with a generic placeholder, per §22.

### 3.24 Phantom assignees

**Looks like:** tasks sit "ready" for hours.
**Reality:** the assignee profile does not exist; no worker picks them up.
**Fix:** check that every assignee referenced by the task system exists on disk.

### 3.25 The agent asked to fix its own failure

**Looks like:** prompt the stuck session to design failover for the failure it is stuck on.
**Reality:** it consumes more requests and produces nothing.
**Fix:** every fix originates outside the failure domain. §19.

### 3.26 Cross-box drift

**Looks like:** two boxes with "the same" config.
**Reality:** they drift. A fix applied on one may not be on the other.
**Fix:** a periodic drift check (§8). Fix drift before it becomes the next incident.

A clone inherits config, not packages. A tool the source box has may be absent on the clone; scripts that hard-depend on it fail loud (good) but nothing notices if the alert path is mute.

**Cross-box dependencies.** If a chain entry on this box is hosted on another box (a local model served over the tailnet by a peer), that is a **recorded cross-box dependency**. The consuming box's state file lists it; the host box's state file lists it. The dependency is probed from the consuming box, never assumed healthy because the host's own checks pass. See §6.4a.

### 3.27 Park-a-new-session-on-the-last-request

**Looks like:** spend every free request; they're free.
**Reality:** one turn costs one request per tool round. A turn with five tool calls costs five requests. Parking a new session on the last request or two guarantees a mid-turn 429 — the failure appears mid-conversation, not at session start.
**Fix:** hold the default on the preferred free id while `remaining > {{reserve}}`, else move to the paid tier. Setting the reserve to 0 spends every request and accepts the mid-turn failure.

### 3.28 Config rewrite on every tick

**Looks like:** the selector keeps the config fresh.
**Reality:** rewriting the config when nothing material changed creates churn, hides real changes in a stream of identical writes, and races with other writers.
**Fix:** gate writes on a material change. §4.14.

### 3.29 Chat filter rejects valid free ids

**Looks like:** a modality filter that requires `"text"`.
**Reality:** the field is `output_modalities` (a list). A filter on a different field (or on the input modality) may reject ids that are valid chat models, including ones the operator personally ranked.
**Fix:** filter on `architecture.output_modalities == ["text"]` exactly for the default text ladder. Test with the operator's preferred ids before trusting the filter. §4.4.

### 3.30 Ranking by the wrong key

**Looks like:** alphabetical ordering produces a stable choice.
**Reality:** alphabetical order ignores the operator's preference rank. The "best" model may be an unranked one.
**Fix:** rank by preference index, then by context length as a tie-break.

### 3.31 Suffix-only free detection

**Looks like:** free ids end in `:free`.
**Reality:** some free ids (0/0 pricing) have no suffix. A suffix-only check misses them or, worse, treats them as paid and skips the free tier entirely.
**Fix:** include both suffix and live free-set membership. Price-based detection is the safer union.

### 3.32 Two selectors with opposite policies

**Looks like:** one box, one policy.
**Reality:** a box may run two selectors with contradictory behavior. One might be paused. Both have a policy file on disk. Reading the wrong one produces the opposite conclusion about the box's current behavior.

**Fix:** before reasoning about what the box does, check:

- The scheduler's list — which selector is active?
- Its policy file — what does the active one do?
- The paused selectors' policies are historical, not current.

Every switch report names the active owner. Every report from a non-owner is prefixed `[paused]` or `[inactive]`. The rule from §3.7 applies.

### 3.33 Recovery instant left blank

**Looks like:** the run logs "no action" on every tick.
**Reality:** the operator cannot tell when the budget returns, so the "why is it stuck" question is unanswerable for hours.
**Fix:** every exhausted run and every status command names the recovery instant. §4.13, §5.7.

### 3.34 A wildcard bind is not proof of exposure

**Looks like:** `0.0.0.0:{{port}}` in the bind output; rotate the password.
**Reality:** `0.0.0.0` means "listen on all IPv4 interfaces." Whether an untrusted client can reach it depends on the host firewall, the network topology, and whether the port is forwarded. Rotation should be tied to actual exposure or actual compromise, not to the bind string alone.

**Fix:** check both the bind and reachability before reacting:

- Bind: on the server host, list listening ports.
- Reachability: attempt a connection from a host that is not the server, on a network you consider untrusted. If it fails, the wildcard bind is bounded by the network.

Rotate the password if there is evidence of exposure or compromise. Otherwise, note the bind as a hardening item, not an emergency.

**Local inference ports are a separate case.** Ollama-style inference ports and dashboards have no authentication by default. A tailnet is not a trust boundary: any device on it can use the cards. Give inference ports explicit access control:

- Bind to loopback or the tailnet interface only.
- Add a tailnet ACL that allows only named devices on those ports.
- Turn authentication on for web UIs; turn signup off.
- For an inference server with no built-in authentication, the ACL is its only boundary; record that as a deliberate choice, or put a token-requiring reverse proxy in front.

**Check:** connect from a tailnet device that isn't allowed and expect a refusal. If no such test device exists, the result is CANNOT-OBSERVE, not PASS. See §26.10 for the local-tier security rule.

### 3.35 Scoped-override guards

**Looks like:** any `/model` command writes the config.
**Reality:** on the current build, only `--global` writes config. The plain form is session-scoped. Guards exist: `--once` requires a live session; `--once` + `--global` is a hard error.

**Consequences of getting this wrong:**

- A user who expects `/model X` to persist for future sessions gets a session-scoped switch and is surprised when new sessions use the old default. Fix: use `--global` explicitly.
- A user who expects `/model X` to affect only their session but has `{{persist_switch_by_default_key}}` set gets a global write. Fix: unset that key, or use `--session` explicitly.
- A script that assumes a plain `/model` writes config will now fail silently (no config change) or throw if combined with `--once` outside a live session.

**Fix:** always name the scope explicitly in scripts. Do not rely on the default.

**The `--global`-writes rule is the normal case, not the only case.** On a **fresh install** (no `{{model_default}}` and no `{{model_provider}}` set yet), the plain form may persist the first switch (§2.6). A user who relies on "only `--global` writes config" is wrong on a fresh install.

### 3.36 Heuristic classifier misfires

**Looks like:** a selector infers the task type from the prompt.
**Reality:** the signals available in the catalog are weak. There is no `capabilities` field, no `code` flag, no `task`/`purpose`/`skill`/`category` key. A design-arena-specific benchmark field exists but is sparse and not a general assertion.

The usable signals are name substring (`code`/`coder`/`codex` in the id) and description prose. Both are heuristics. **In one observed catalog, this class of signal produced one real misroute** — a content-safety guardrail model winning the free-text ladder — plus reporting artifacts that never affected routing. Only the misroute was an actual bad selection.

That distinction matters: the guide's claims are calibrated. One misroute is enough to justify caution. Three would overstate what was observed.

**Fix:** a heuristic classifier is advisory only. It logs a hint (`TASK-CLASS-HINT: image task? matched 'screenshot'`), routes nothing, and requires the user to act explicitly (`/model {{image_model_id}} --once`). If you want a classifier active, gate it behind an opt-in config key (`classifier.enabled: true`), never as a default.

**The `reasoning` field is different.** It is a real structural field. Routing a reasoning task by the field is legitimate. See §4.16 for the correct filter.



### 3.37 Config rewrite destroys comments

**Looks like:** load the YAML, change two keys, dump it back.
**Reality:** a naive load/dump (PyYAML and most YAML libraries) drops every comment, reorders keys, and may change quoting. An operator's hand-annotated config is mangled on the first tick.
**Fix:** use the runtime's sanctioned switch path (§2.1) or a round-trip-preserving YAML writer, and verify on a copy that only the intended keys changed before writing the live file (§4.14 step 4). A box where neither is available has no safe direct writer; state the limitation and do not write.

### 3.38 Fighting a manual change

**Looks like:** the saved default differs from the selector's choice, so the selector writes its choice back.
**Reality:** a human (dashboard, `/model --global`) or another tool changed it on purpose. The selector reverts it, the human changes it again, and the write cap eventually pins a tier nobody chose.
**Fix:** compare the saved value with the selector's **last write**, not only with its choice. A value that matches neither is a foreign write: enter the manual-override pause (§4.14a). Invariant 41.

### 3.39 Remembered limits

**Looks like:** the provider's free tier allows N requests a day; put N in the script.
**Reality:** providers change limit numbers, tiers, and window shapes. A limit depending on account state (for example, whether credits were ever bought) changes when the account does. A remembered number is right until it silently isn't.
**Fix:** read limits and their structure from the provider each tick (§4.9a-bis). Numbers quoted anywhere in this guide are dated examples, not values. Invariant 42.

---

## §4 — Model selection design

### 4.1 Main ladder

A tier ladder that does not depend on specific model ids. Actual ids populate from the live catalog.

```
1. free-small        :free models with context below a threshold
2. free-large        :free models with context above a threshold
3. paid-cheapest     cheapest chat-capable model in the chosen paid family
4. paid-reasoning    same family, reasoning-flavored; used sparingly
5. paid-manual       manual only; never auto-selected
```

No local tier in the ladder. If all entries fail, fail loud.

**Local is not in the ladder.** It may appear as the offline tail of the fallback chain, after an API head, and only for non-blocking auxiliary work (see §6.3a). A stricter policy excludes local from the switcher entirely. Both are valid; **state which your deployment uses** in the deployment's §12 record.

**Unknown-tier defaults are asymmetric:**

- **Free → `mid`.** Keep options; a mid-tier free model is usable.
- **Paid → `small`.** Do not spend money on an unjudged model; the smallest safe tier is the conservative choice.

### 4.2 Configurable paid family

The paid family (the vendor prefix for tier 3+) is config, not a constant. If no model matches, exit non-zero. Do not widen silently.

### 4.3 Catalog fetch

Query configured catalogs. Merge results, tag by source.

- Fetch failure = exit non-zero.
- Optional catalog failure = WARN, continue.
- Cache for one run. Do not persist a "last known good" as a fallback.

**Deliberate narrowing some deployments use:** when the box is on the paid plateau and no decision depends on the free list, a free-catalog fetch failure is a WARN, not fatal. State this in your own §12 record so the next reader does not read it as a regression.

### 4.4 Chat-capability filter

For the default text ladder, only models whose `architecture.output_modalities` is exactly `["text"]`. Missing or ambiguous = reject.

Do **not** filter on a different modality field, on the model's name, or on the input-modality string. `input_modalities` may include image or audio for a model that produces text; the output modality is what matters for chat selection.

**Trap:** a filter that requires the model's modality to be exactly `"text"` on the wrong field will reject ids whose modality includes the input side. **In one catalog snapshot, this rejected 8 of 17 preferred free ids.** The observation is catalog-specific and dated; the rule travels, the count does not. Test with the operator's preferred ids before trusting the filter. See §3.29.

**Non-text work types** (§4.16) loosen this filter to include the relevant modality. The default remains text-only.

### 4.5 Suffix filter

Model ids carry meaningful suffixes:

| Suffix | Free tier | Paid tier |
|---|---|---|
| `:free` | Allow | Reject |
| `:batch` | Reject | Reject |
| `:promo` | Allow if 0/0 | Reject |
| `:preview` | Allow if 0/0 | Reject |
| `:extended`, `:thinking`, `:o1` etc. | Treat as distinct | Treat as distinct |

### 4.6 Free-set membership

Free means "priced 0/0 in the live catalog." Suffix is one signal; live membership is another. Do not rely on suffix alone.

- Suffix `:free` is a good signal but not exhaustive.
- Live membership in the catalog's free set (0/0 pricing) catches ids without the suffix.
- When in doubt, prefer live membership. **Price-based detection is the safer union** — it catches suffix-less free ids and does not depend on a naming convention.

**Trap:** some free ids have no `:free` suffix. A suffix-only check either skips them or routes them as paid, thrashing the free tier. See §3.31.

### 4.7 Pricing

Prices are strings, not floats. Missing, empty, or unparseable → reject the model. Do not default to 0. **Negative values are sentinels, not prices** — a provider may send `-1` to mean "unknown"; reject, do not rank.

### 4.8 Blended cost

If input and output prices differ, define a blend. A common default is input-heavy (e.g., 3:1 input:output). The ratio is not cosmetic — it decides the winner between two models with different price profiles. Document the ratio in the script. **The ratio is a per-box value; the rule that it must be computed and documented is portable.**

### 4.9 Free-tier budget — and what to do when the read fails

Some free tiers have per-account daily request limits. The budget is shared across every window on the account. Check before persisting a free default.

- `remaining > {{reserve}}` → free default is safe.
- `remaining ≤ {{reserve}}` → cheapest paid.

Do not persist a free default when the budget is spent. See §4.13 for the reserve.

**When the quota read itself fails, route by failure class — not by direction.** The rule is not "fail closed to paid." Paid shares some failures with free and not others, so a paid tick that fixes nothing is worse than holding.

| Failure | Free affected? | Paid affected? | Action |
|---|---|---|---|
| Auth (401; a 403 only when the provider identifies it as an authorization failure) | yes | yes | **Do not switch.** A 401 cannot be fixed by changing models. Record, alert, hold current tier. A 403 that reports a spent budget or guardrail is the credit/spend-limit class below, not auth; when the adapter cannot tell which, the class is unknown and the box holds. |
| Provider unreachable (DNS, connect, TLS, provider-wide 5xx) | yes | yes | **Do not switch.** See the note on independent routes below. If no independent route exists, hold current tier, record, alert. |
| Quota counter unreadable (malformed body, parse error) | unknown | no | Fail closed to paid. Log the parse failure. Re-read next tick. |
| Free-model-only fault (429 on a `:free` model, 404 on a specific free id) | yes | no | Fail closed to paid. Log the specific model and reason. |
| Paid credit or spend limit reached (e.g. a key limit or insufficient credits) | no | yes | **Paid is not eligible.** Use free only if it is otherwise eligible (`remaining > {{reserve}}`); otherwise hold, alert, and name the limit and its reset. Do not alternate between tiers. |
| Account balance negative (errors on every model, free included) | yes | yes | **Do not switch.** The fix is a payment, not a route. Hold, alert. |

**The rule in one sentence:** *route to a tier that does not share the failed dependency; if none exists, log, hold, and alert.*

**"Fail closed to paid" means paid only when paid is eligible** — configured, permitted by policy, and not itself at a credit or spend limit. The provider adapter classifies provider-specific status codes and error metadata into these classes; the rules bind to the class, not the code.

**"Independent route" means an independent API route.** A second provider or a second key is an independent route. **A local entry is not an escalation target for the main session.** Local stays aux-only (§6.3, invariant 9). Where a box has no independent API route:

- **Hold the current tier.** Do not switch. Do not fall through to local for the main session.
- **Rely on the provider-side spend cap** (invariant 36) to bound the cost of the current tier.
- **Record and alert.** The failure mode is now "auth or endpoint problem"; it is not a routing problem, and the fix is outside the switcher.

**Log the class, not just "failed."** The four cases have different remedies. `quota-read failure: auth (401)` calls for a credential fix; `quota-read failure: endpoint unreachable` calls for a network check. A single "quota read failed" line hides which.

**Escalation when the failure persists.** Fail-closed to paid on one tick is fine. Fail-closed on every tick for hours is a different problem — the box can pay indefinitely while the actual fault goes unfixed.

- Track *why* the box is on paid. Only "failed closed" reasons count toward escalation; a paid choice by policy or by the operator does not.
- After `{{fail_closed_N}}` consecutive ticks, or `{{fail_closed_T}}` minutes, on paid because of failure: alert through a **verified** destination (per §0.6's definition of loud). If no verified destination exists, the alert is recorded and the box holds the last known state; see invariant 34.
- After `{{fail_closed_M}}`: **hold current tier and repeat the alert until acknowledged.** Do not switch to local (§6.3, invariant 9). The escalation target, where one exists, is an independent API route; where none exists, hold and alert.

**Spend guard, two layers.** A local daily-spend ledger checked before any switch to paid, plus a **provider-side credit limit** on the key itself. The second is the only guard that still works when the tick is dead. A dead tick needs a watchdog outside the tick — a separate job checking the heartbeat file's age, or a peer box checking.

**No verified destination? The provider-side cap is mandatory.** If the box cannot deliver a loud alert, the local ledger is the only thing that might not run, and the provider-side cap is the only backstop. A box with no verified destination and no provider-side cap is unprotected; state this in the deployment's §12 record.

### 4.9a — Refresh the free set on every run, paid or not

**The free set is refreshed on every run, not only when free is about to be used.** A selector that fetches the free catalog only when routing to free carries a stale picture while the box sits on paid: the ranking, the membership, and the "what is free now" question all decay. Refresh unconditionally; apply the material-change gate (§4.14) to the *write*, not the *fetch*.

**Consequence:** when the budget resets, the ranking the selector uses is current, not as-of-last-time-the-free-tier-was-reached.

### 4.9a-bis — Read limits and their structure live

Every limit the selector depends on is read from the provider on each tick, at zero cost where the provider allows it:

- **The counter** — used, cap, and remaining for each limit that applies (free daily requests, per-minute rate, credit balance, spend budgets).
- **The window** — fixed calendar window (and its timezone), rolling window, or lifetime.
- **The reset** — prefer an explicit reset instant from the API, then a confirmed rate-limit header (§4.13a), then the documented window boundary, labelled as computed.
- **The scope** — per key, per account, or per model. When the scope cannot be determined, treat a free limit as **account-level**: the cost of that assumption is an avoidable paid tick; the cost of the opposite is a fallback that fails the same way.

The provider adapter returns this structure; the decision engine never sees provider field names. When the structure changes between ticks (a cap rises because the account bought credits, a window changes type), log the change. Invariant 42.

### 4.10 Free selection

Fetch, merge, filter to free and chat-capable, apply suffix/set filter, rank by preference index, tie-break by context length. Winner is the top.

**Trap:** ranking alphabetically or by context length alone ignores the operator's preference order. Use the preference list as the primary key. See §3.30.

### 4.10a — Preference-list maintenance

- **New free models are appended at the bottom.** The operator's ordering keeps priority; the selector does not insert.
- **Models that drop out of the free set are reported, not deleted.** One bad catalog download must not silently erase the operator's taste.
- **Back up before write; keep the last N.**
- **Write only on material change.** A refresh that changes nothing writes nothing (§4.14).
- **A second run is a no-op.**

**Worked example (illustrative).** A listed model with `:free` in the id was no longer 0/0 in the live catalog. The refresh logged it as "not in today's free set" and left the entry in place. Suffix-only detection would have kept routing to it — §3.31's exact trap.

### 4.11 Paid selection

Fetch, filter to family, apply chat filter and suffix filter, parse pricing, require positive price, rank by blended cost, log the full ranked list.

Do not write the default unconditionally — only on escalation or when the free budget is spent.

### 4.12 Ordering

Free → paid-cheapest → paid-reasoning. No local tier.

Local providers may appear in the fallback chain only as entries after an API head, and only for non-blocking auxiliary work. The head is where a session lands when the primary 429s (§6.4). See §6.3a.

### 4.13 Cliff reserve

The free budget is spent one request per tool round. A turn with five tool calls costs five requests. Parking a new session on the last request or two guarantees a mid-turn 429 — the failure appears mid-conversation, not at session start.

**Rule:** hold the default on the operator's preferred free id while `remaining > {{reserve}}`, else switch to the paid tier. Setting the reserve to 0 spends every request and accepts the mid-turn failure.

**Size the reserve against the largest observed single-session draw, not the average turn.** The unit is the **session**, not the turn. A fixed reserve correct for an average turn is meaningless against one session that can consume the entire daily budget in a single run. Track per-session draw; set the reserve at or above the p95 of that draw.

**Use the largest observed draw once the sample is large enough.** With at least **{{reserve_sample_floor}} sessions** (recommended **59**), set the reserve to the **largest observed per-session draw**. **Why 59:** the largest of n samples is at or above the true p95 unless every sample fell below it, which happens with probability 0.95ⁿ; for n = 59 that is under 5% (`ln(0.05) / ln(0.95) ≈ 58.4`). So the sample maximum is a 95%-confidence upper bound on the p95. Do **not** compute a p95 from a few dozen points — it is noise with a decimal point. Until the sample reaches the floor, use a conservative fixed reserve and **label it provisional** in the log and in the deployment's §12 record. When the sample reaches the floor, the measured value replaces the provisional one and the label is dropped. Re-derive on a schedule; a workload change makes old samples misleading.

**The reserve value is per-box; the rule travels.** A box with a 50-request daily budget and one session that can spend all 50 in a single tool loop needs a reserve sized above its p95 draw; a box whose heaviest session is 5 requests can hold a reserve of 2. The rule — *size above the p95 single-session draw* — is invariant; the number is not. **Do not write a specific number into this guide; the number lives in the registry.**

**Paid-tick cost near the reserve carries a shadow price.** One paid tick taken near the reserve is more expensive in practice than one taken at the start of the day, because it draws down the buffer that protects the main session. When the paid cost `c` enters the §4.18 inequality, `c` should reflect this — a shadow price, not just the unit cost.

**A shared budget cannot be protected by a per-session reserve.** When multiple sessions draw from one account-level quota, and a session's model binding cannot be changed after creation (§3.5, §2.6), no reserve on any *other* session can stop the one that is already drawing. The cost is paid by everyone; the decision is made by one session that cannot be reached.

**Detection:** if the budget is shared and any session can hold a binding past its scope, the fact that matters is *how many sessions are bound to the shared resource right now*, not how much is left.

**Fix — one of two, chosen by the operator:**

1. **Do not park the main lane on the shared resource.** If the paid resource is cheap enough, paying is smaller than the cost of occasionally 429-ing every window at once.
2. **Enforce a per-session cap that fails the session, not the budget.**

**Do not add a bigger reserve.** The reserve does not reach the session that is already drawing, and it cannot stop a second session from starting while the first is still bound.

**One line:** *a per-session reserve cannot protect a shared budget when a session's binding outlives the policy that set it.*

**Hysteresis: leave free quickly, return slowly.** This is the canonical home of the hysteresis rule. §7.5's cooldown and rate-limit entries refer to this section; they do not define a second mechanism.

- **Leave free** on one confirmed failure. The safe direction does not need hysteresis.
- **Return to free** requires `{{free_return_K}}` healthy reads in a row, covering at least `{{free_return_D}}` minutes. A CANNOT-OBSERVE result does not count as healthy and resets the return counter.
- **Every state** has a minimum stay — a switch away requires the state to have been held for at least `{{state_min_dwell}}`.
- **Write cap:** no more than `{{config_writes_per_hour}}` config writes in a rolling hour. Hitting the cap means the system is flapping: pin the safe tier, stop switching, alert.

**Why the cap matters.** A flaky quota endpoint flips free/paid every tick. Each flip counts as a material change, so the config-write log churns exactly the way §3.28 warns about.

**A note on §7.5 and §3.15.** Those sections list `{{state_min_dwell}}` and `{{config_writes_per_hour}}` — the minimum interval between switches and the maximum number of switches per hour. Those are **the same mechanism** as the hysteresis rule above, expressed in different units. Configure them once, in the registry, and reference them from both sections. Do not implement two separate cooldowns.

**Logging:** every exhausted run and every status command names the recovery instant. Do not leave the reason blank.

```
«timestamp» no action: remaining=0 used=«n»/«cap» current=«paid» | free side spent (remaining=0 <= reserve={{reserve}}); resets «ISO-8601-UTC»
```

**Reading the reset instant.** One rule, one source:

- **Preferred:** parse the rate-limit reset header from the most recent 429 and convert to ISO-8601, after confirming which limit the header describes (§4.13a).
- **Fallback only when the header is unavailable or unconfirmed:** compute next UTC midnight. This is correct for providers that reset at 00:00 UTC and wrong otherwise. Record the fallback use in the deployment's §12 record.
- **The fallback is a display value, not a decision input.** The decision re-reads the budget on every tick, so a wrong ETA is cosmetic. A deployment that gates on the ETA is using the fallback as a decision input and is in error.

**Do not mix the two.** A run should either read the header or use the fallback; it should not print a header-derived instant in one line and a computed one in the next. If the header is unconfirmed, the fallback is used and labeled as such.

**Read the reset instant from the header, not from a computation.** A quota counter read from the provider, or cached from a prior tick, can be stale across the reset instant. The failure is silent: the selector takes `remaining=0` at face value, concludes "still spent," and prints a reset time computed from the stale value — which can be wrong by a day or more.

**Detection:** if the reset header's value is in the past and `remaining` still reads exhausted, the counter is stale — re-probe the quota endpoint. Do **not** compute the reset instant when the counter is suspect; a computed value inherits the staleness.

**Token discipline on quota reads:** where the runtime exposes a zero-cost counter read (a key endpoint that returns remaining at 0 tokens), use it on every tick. Probe for the header only when the counter is unavailable or reads zero. **Never spend budget to read what you already have.** Normal ticks should cost 0 tokens.

**The reset instant in a log line must come from the most recent header reading, or be labeled as the computed fallback.** A wrong reset date in the log is worse than no date, because the operator trusts it.

### 4.13a — The reset header is a HYPOTHESIS until confirmed

A rate-limit reset header on a 429 may describe whichever limit tripped, not the daily budget. Before treating it as the recovery time:

- Confirm the header describes the daily limit — from provider docs, or from observed pairs of headers and limits.
- Sanity-check its value: a reset under ~60 s away usually means a per-minute limit; one landing on the expected daily boundary usually means the daily limit.
- Cross-check with the counter: if the key endpoint shows daily `remaining` above the reserve, the 429 wasn't the daily limit and the reset header should not be treated as the recovery time.
- Handle units (seconds or milliseconds since epoch) and clock skew.

If any of these is uncertain, treat the 429 as short-term: back off, retry, re-check the counter. Do not hold paid until the daily reset on an ambiguous header. **This stays a HYPOTHESIS until a recorded 429 confirms which limit the header reports.**

### 4.13b — Schedule vs. reset: what actually matters

**The rule is a maximum delay after reset, not a divisibility test.** Restated:

> For every reset instant `R`, the first selector run that reads the counter at or after `R + {{skew_margin}}` must happen by `R + {{max_post_reset_delay}}`.

`R` comes from the confirmed daily reset (per §4.13a). `{{max_post_reset_delay}}` is an operator choice — the maximum acceptable idle time before the free tier is re-tried.

**Why the divisibility rule was wrong.** Any `*/N` cron with N dividing 1440 satisfies "period divides reset," including a `*/5` job that misses the window by 40 minutes. What actually matters is how soon after the reset the first tick runs.

**Timezones.** The check must name the timezone the cron schedule runs in, compared with the UTC reset. A `*/5` job that misses the window is often a timezone offset, not a period problem. The restated rule covers timezone, clock skew, and cached counters.

**If the provider uses a rolling window instead of a fixed daily reset,** the invariant does not apply. State which model the provider uses in the deployment's §12 record, and if the model is rolling, replace the invariant with "the first tick after any 429 re-reads the counter."

### 4.14 Material-change gate and atomic writes

A selector that rewrites the config on every tick creates churn, hides real changes in a stream of identical writes, and races with other writers.

**Rule:** compute whether the chosen model differs from what is saved. Only write the config when the answer is yes.

**Compare against the selector's last write, too.** The selector records every value it writes. If the saved value differs from both the last write and the current choice, another writer changed it: that is not a material change to correct, it is a foreign write. Enter the manual-override pause (§4.14a) and write nothing (§3.38).

- **Material change** (chosen model differs): write the config default and the full prefs file.
- **No material change** (chosen model is the same): skip the config write entirely. Optionally refresh the paid-fallback field if the paid ranking shifted — verify this refresh exists on your build before relying on it.

**Prefer the sanctioned switch path.** §2.1 says to use the sanctioned path over editing the config file directly. The atomic-pair procedure below is what to do when the sanctioned path is unavailable or cannot produce the write the deployment needs. A deployment whose only writer is a CLI that writes in place must state the limitation in its §12 record.

**Write both keys atomically.** `{{model_default}}` and `{{model_provider}}` are one logical value split across two keys. A crash between them leaves the config inconsistent. **Two sequential per-key renames are not atomic, in either order.**

**The write procedure, complete:**

1. **Acquire a lock on a dedicated lock file**, not on `{{config_path}}`. Locking the config itself is wrong: the rename replaces that file, and the next writer locks a different one.
2. **Read the current config** into memory.
3. **Resolve the target path.** If `{{config_path}}` is a symlink or an alias to a mount point (a home directory mounted twice), rename semantics differ: `os.replace` on the symlink replaces the link, not the target, and cross-filesystem renames fail. Write the temp file **in the same directory as the resolved target**, and `os.replace` the resolved target.
4. **Write the new config to a temp file in the same directory** (a predictable `/tmp` path is wrong for this — it may be on a different filesystem, and rename across filesystems is not atomic). **Serialize with a round-trip-preserving writer** so comments, key order, and quoting survive; then diff the temp file against the original and abort unless only the intended keys changed (§3.37).
5. **fsync the temp file.**
6. **Preserve mode and owner.** Copy the existing file's mode and owner to the temp file before the rename. A rename replaces permissions and ownership with the temp file's; if the config carries inline credentials or is read by a runtime running as another user, changed mode or owner can lock the runtime out or expose the file.
7. **`os.replace`** the temp file over the resolved target. One rename: atomic.
8. **fsync the directory** after the rename. Without it, a crash can lose the rename, even though the file's contents were fsynced.
9. **Release the lock.**

**Where the writer cannot do an atomic replace** — a config CLI that writes in place, a dashboard endpoint that mutates its own file — **state the limitation**. That writer is not protected against a crash between its internal writes. Do not claim atomicity the writer cannot deliver.

**Lock the write** so concurrent writers cannot corrupt the file. A lock prevents corruption; it does not prevent a logical race between two writers that both believe they own the default. That is §3.6 and §3.7's problem, solved by the single-owner rule.

**Consequence:** the config log shows only real changes. Operators can trust the log.

### 4.14a — Manual-override pause

A foreign write (§4.14) means someone chose a model on purpose. The selector respects it for a bounded time.

- **Enter the pause** on detecting a foreign write. Record: when it was detected, the observed model, the selector's last write, and when the pause expires.
- **While paused, write nothing** and never revert the change. Every status output and every tick's log shows the pause and its expiry.
- **Default window:** `{{manual_override_hours}}` hours — **4 by default; 4–6 recommended.** Long enough to finish a block of work on the chosen model, short enough that a forgotten change does not disable the selector for days.
- **Hold:** when the operator asks for it (`switcher hold`, or the equivalent the deployment provides), the pause has no expiry and ends only on an explicit resume.
- **Resume:** an explicit `switcher resume` ends the pause immediately. On expiry, the selector logs the resume, announces it through the alert path if one is verified, and re-plans. It writes only if the current policy still selects a different model; it does not restore its old choice by reflex.
- **A new foreign write during the pause** restarts the window.

Invariant 41; check §10.34.

### 4.15 Auxiliary work split

Not all auxiliary work is equally harmless if it fails.

**Blocking auxiliary** runs inside the user's turn. Examples: context compression, tool-call parsing, result extraction. Failure stalls or corrupts the main session.

- Primary route: an API provider.
- Secondary: a local provider with a tight timeout and a documented API fallback.
- If both fail: visible warning, degraded mode, not silent continuation.

**Non-blocking auxiliary** runs off the critical path. Examples: background jobs, embeddings for later retrieval, scheduled maintenance.

- Primary: a local provider (the intended use of local hardware), or an API provider if no local is available.
- Failure logged; main session unaffected.

Subagents are not automatically non-blocking. Classify by whether the main turn waits on them.

**Unknown blocking status → API head.** A chain whose blocking status cannot be determined from source or from a live trace heads at an API entry. The reason is asymmetric risk: an unknown blocking chain headed local delays a user turn; an unknown non-blocking chain headed API costs a paid tick on work that could have been free. The second error is bounded, logged, and recoverable next tick. The first is not.

**Measuring θ, if you want to move a chain off the API head.** For a chain known non-blocking at runtime, local wins if `θ < θ*` (see §4.18). Measure θ as an overlap bound, not a point estimate: compare each call's invocation timestamp with the wall-clock window of the user turn it belongs to. In-window fraction is an upper bound. A tighter experiment injects a fixed delay into one chain's endpoint and measures whether turn latency rises. Exact θ = 0 cannot be proven from outside the runtime; a per-chain upper bound can be made tight enough to decide. See §4.18.

### 4.16 Work-type routing

Different tasks suit different models. The ladder in §4.1 is the default. Work-type routing changes which subset of the catalog a given session draws from.

| Work type | Ladder | Filter |
|---|---|---|
| text (default) | the tier ladder of §4.1 | `output_modalities == ["text"]` |
| image | free-if-available / cheapest-capable | `output_modalities` includes `"image"` |
| video | cheapest-capable | `output_modalities` includes `"video"` |
| audio | cheapest-capable | `output_modalities` includes `"audio"` |
| reasoning | text ladder, with a structural preference | `output_modalities == ["text"]` AND `reasoning` field present AND desired effort level in `supported_efforts` |
| code | text ladder, with a bias toward the `family_purpose` map | `output_modalities == ["text"]` |

**The code case.** There is no code-capability field in the catalog. There is no `capabilities` field, no `code` flag, no `task`/`purpose`/`skill`/`category` key. The only ways to identify a code-tuned model are a hand-maintained `family_purpose` map (authoritative) or a name substring (advisory). Use the map when you need reliability; use the heuristic as a hint only, and log it.

**The reasoning case is different.** `reasoning` is a real structural field with a shape like:

```
reasoning:
  mandatory: <bool>            # if true, the model cannot be used WITHOUT reasoning
  supported_efforts: [<...>]   # e.g., max, xhigh, high, medium, low, minimal
  default_effort: <string>
```

**Filtering toward `mandatory: true` is wrong.** Mandatory means reasoning is *forced*, not that the model is *meant for* reasoning-heavy work. Filtering toward mandatory selects the models with the *least* flexibility.

**The correct filter:** `reasoning` field present, AND the effort level you want is in `supported_efforts`. Prefer models whose `default_effort` matches your typical usage. Absence of the field means the model cannot be effort-routed — fall back to the text ladder without the reasoning bias.

**The image, video, and audio cases** draw from a different subset of the catalog. `output_modalities` is a real list field. Free entries for these modalities are rare in most catalogs. The ladder collapses to "cheapest capable." The reserve (§4.13) is for free text turns; do not apply it to non-text work.

**Default is text.** If the work type is not explicit, use text. Heuristics do not change the default; they log a hint only.

### 4.17 Explicit work-type commands

Work-type routing is opt-in. A user requests a non-text work type by one of:

- **Explicit model override:** `/model {{image_model_id}} --once` or `--session` (§2.7). The user names the model; no classification needed.
- **Explicit work-type flag (if the runtime supports it):** a `/image`, `/video`, `/code`, `/reasoning` flag, or an equivalent config value. Consult the runtime's help output. Do not invent flags.
- **Explicit config:** a session-scoped config value the switcher reads when starting a new session.

**Heuristics are advisory.** A prompt mentioning "screenshot" or "video summary" may cause the classifier to log `TASK-CLASS-HINT: image task?`. The classifier does not act on the hint. The user acts.

### 4.18 Aux-chain head: the inequality

Let `L` = local latency with CDF `F_L`, `A` = API latency with mean `E[A]`, `τ` = timeout, `p = P(L > τ)`, `θ ∈ [0, 1]` = the fraction of the chain's calls on the user-turn critical path, `c` = paid-tick cost (with the shadow price near reserve, §4.13), `d` = user-turn-delay cost per unit time.

- Local-head expected delay: `E[D_local] = E[L; L ≤ τ] + p·(τ + E[A])`
- Local-head expected paid cost per call: `c·p`
- API-head expected cost per call: `c`, with expected delay `E[A]`

**The local head wins if and only if:**

    c·(1 − p(τ)) > d·θ·(E[D_local] − E[A])

Equivalently, when `E[D_local] > E[A]`: local wins when `θ < θ* = c·(1 − p(τ)) / (d·(E[D_local] − E[A]))`. When `E[D_local] ≤ E[A]` — local is no slower than the API on average — local wins for every θ, provided `c·(1 − p(τ)) > 0`.

**Consequences:**

1. **If θ = 0** — the chain is truly non-blocking — the right side vanishes and **local always wins as long as c > 0 and p(τ) < 1** (a local head that always times out only adds delay). No reserve conditional.
2. **If the runtime does not fall through on timeout** — the turn waits for the full `L`, `p` loses its meaning, and the inequality must be rewritten with `E[L]` unbounded. The API head can then win for any θ above zero.

**The decisive unknown is θ.** Measure it as an overlap bound (§4.15). Where it is unknown, use the conservative default (API head).

**Falls-through-on-timeout is a fact about the runtime, not a rule.** Verify on the running build (§10.28) before assuming. Where the runtime falls through, the inequality applies as written. Where it does not, the API head is the correct default for any chain with non-zero θ.

---

## §5 — Struggle detection

### 5.1 Signals

Two separate signal sets. Do not mix them.

**Failure signals** feed the struggle score (§5.2) and the escalation rules in §6:

- Tool errors (weight low, common).
- Stale interrupts (weight moderate).
- Batch aborts (weight moderate).
- Context overflow (weight high).
- Repeated tool calls with the same arguments (weight high).
- Latency spikes above a percentile (weight moderate).
- Empty or malformed responses (weight moderate).

**"Too weak" signals** feed the capability-escalation offer (defined in this section and in §5.8) and never feed the struggle score:

- **S1 — user re-prompts** within a short window with the same goal.
- **S2 — plan gap:** the assistant claims completion while an enumerable plan has unfinished items.
- **S3 — verifier failure after "done":** a test, lint, or schema check fails on the model's own completed output.
- **S4 — no-tool stop:** a turn whose work type needs a tool ends with zero tool calls.
- **S5 — explicit request:** the user says "use a stronger model," or runs the manual lever if the runtime supports one.

**Not signals:** the model's self-assessment (§19 puts it inside its own failure domain); answer length alone.

**What the "too weak" signals do.** Two or more of S1–S5 in one session produces an **offer** of a one-tier escalation. The offer is advisory. Whether it can be acted on depends on whether the runtime exposes a session-scoped lever the selector can reach — see §5.8.

### 5.2 Scoring

```
score >= threshold_low   → escalate +1 tier
score >= threshold_mid   → escalate +2 tiers
score >= threshold_high  → escalate to paid-cheapest
score == 0 for N minutes → de-escalate -1 tier
```

Set thresholds and windows to your workload. The above is a starting point, not a law.

**These escalations act only through a lever the selector can reach.** Where the runtime exposes a session-scoped switch the selector can call, the escalation applies to the struggling session alone. Where it does not — the common case (§2.7) — the score is **advisory**: log it and surface it; change the global default only on the many-session evidence of §5.8.

### 5.3 Not a struggle signal

Single tool error, isolated 429, legitimate long-running task, one "I don't know," a retry that succeeds.

### 5.4 Quota-exhaustion signals

Weight quota exhaustion highly. Free-models-per-day (or the provider's equivalent) is terminal for the free tier until the budget resets.

### 5.5 De-escalation respects budget

Before de-escalating to a free tier, check remaining budget. If spent, hold at the current tier. Record free-tier failures with an expiry:

- Reset time from a fresh rate-limit header, if available.
- A conservative default (`{{quota_expiry_default}}`) if not.

### 5.6 Config violations are alerts, not struggle signals

Config violations (local on the main path, unconfigured provider, unsafe timeout) have their own alert channel. They do not contribute to the struggle score.

### 5.7 Recovery-instant logging

Every log line about a quota-exhausted state includes the recovery instant, obtained as described in §4.13. An empty reason on every tick for twenty hours is an operator blind spot; the operator needs to know *when* the budget returns.

**Format example:**

```
«timestamp» no action: remaining=0 used=«n»/«cap» current=«model» (provider)
| free side spent (remaining=0 <= reserve={{reserve}}); resets «ISO-8601-UTC»
```

### 5.8 The signal-scope rule — one session's signal acts on that session, or not at all

**A struggle signal from one session must not change the global default.** The global default affects new sessions only. A session already in trouble cannot be helped by changing what a future session uses; making the change anyway moves everyone else's next session to a more expensive tier and does not help the session that triggered the signal.

**Rule:**

- **If the runtime exposes a session-scoped switch that the selector can reach** — that is, a runtime-provided mechanism by which a scheduled selector can issue a `--session`-equivalent switch into a running session — then a struggle score can act on that session only. Note that on current builds, a selector **cannot** issue a `--session` slash command; the reachability depends on whether the runtime exposes an API the selector can call (§2.7). Where the mechanism does not exist, the rule below applies.
- **Where no such mechanism exists** (the common case on current builds), the struggle score is **advisory only**: log it, surface it, never act on it globally. Changing `{{model_default}}` requires evidence from **many sessions**: struggle in at least `{{global_signal_k}}` distinct sessions within `{{global_signal_window}}`, OR a struggle rate above `{{global_signal_baseline}}`.
- **Where the evidence threshold is met**, the selector may change `{{model_default}}` for new sessions. This does not help the struggling sessions themselves; it changes the tier for the next batch of sessions, on the theory that the struggle is not session-specific.

**Operator choices:** the k, the window, the baseline rate.

**Why this rule exists.** The alternative — escalate the global default on one struggling session — is a global change from a local symptom. It produces churn, moves cost, and does not fix the session that triggered it.

**The reachability condition is load-bearing.** Without it, this rule assumes a session-scoped lever the selector does not have. On current builds, the lever does not exist; the rule reduces to "the struggle score is advisory, or it triggers a global change on many-session evidence."

---

## §6 — Escalation and de-escalation

### 6.1 Rules

- Default at the top of the free tier when budget allows, else cheapest paid.
- Reasoning tier requires reasoning-flavored signals, not just latency or a 429.
- Manual tier requires explicit user action. Never auto-selected.
- De-escalate one tier after a clean window. Never skip the free tier coming down (unless budget is spent).
- **Do not route the main session to a local provider** unless the local-as-main conditions of §6.3 are met. Never as escalation under an API failure. The escalation target, when one exists, is an independent API route; where none exists, the box holds and alerts (§4.9).

### 6.2 Failover must not run on the model it protects

The escalation mechanism must not itself be subject to the tier's limits. Shell script, cron, systemd timer. Never an LLM call.

### 6.3 Local is not a main model by default

**Rule (default):** the main default and the fallback head do not resolve to a local endpoint. **Under an API outage or a persistent failure this holds without exception.**

**Conditional exception.** A local model may serve the main default or the fallback head only when all of these hold and are recorded in the §12 record: the operator's policy allows it; its measured p95 time to first answer chunk is within the operator's declared tolerance and recently measured; a stream-stale timeout is set; and either the runtime falls through on timeout (§10.28) or the user can see the session is on a local model. An unmeasured latency counts as not met. The full card is `docs/rule-cards/local-as-main.md`. The exception exists because the default was learned on hardware too slow for interactive use; it does not describe every box. The escalation path does not route the main session to local (§4.9).

**Enforcement:**

1. Pre-write candidate validation — possible only for writers that support a target path. State the limitation otherwise.
2. Post-write audit — a scheduled check that alerts on violations. Does not roll back.

**Fail-loud behavior:**

| Situation | Wrong | Correct |
|---|---|---|
| Free budget spent | Switch to local | Switch to cheapest paid |
| All API tiers unreachable | Switch to local | Log, hold, alert |
| Network down | Switch to local | Log, hold, alert |
| Auth failure | Switch to local | Log, hold, alert |
| Persistent fail-closed | Switch to local | Hold, alert, rely on the provider-side cap |
| Paid credit or spend limit reached | Switch to local | Use free if otherwise eligible; else hold, alert |

**Local as offline tail:** local entries are permitted after an API fallback in the chain, and only for non-blocking auxiliary work. The head of the chain is where a session lands when the primary 429s; if it 429s there too, the session must land on an API model, not a slow local one. Local entries at the tail provide offline coverage for auxiliary work only; a main session with every API tier unreachable logs, holds, and alerts. See §6.3a.

**Stricter policy (some deployments):** exclude local from the switcher entirely. Valid; state which policy you use. The rule that travels is *local is never the main default.*

### 6.3a — The tail rule

A tail entry is defined as an entry in `fallback_providers` that appears **after** the API head. Tail entries serve **non-blocking auxiliary work only**:

- Background jobs and background reviews.
- Curator, judge, triage, decomposer, and similar autonomous work.
- Any chain the main turn does not wait on.

A tail entry does **not** serve:

- Main sessions during an API outage (log, hold, alert — see §6.3).
- Blocking auxiliary work (compression, tool parsing, result extraction).

**Enforcement check:** whether the runtime walks one `fallback_providers` list for both main and auxiliary traffic, or separate lists per role. If one list serves both, add a guard so a main session does not fall through to a tail entry; or split the chain per role. Confirm the runtime's behavior on your build before relying on the tail rule. See §16 Q21.

### 6.4 Mid-session escape

A running session whose primary 429s does not fail — the runtime arms a cooldown and swaps to the fallback chain, one-shot. The fallback chain's head is where the session lives for the rest of the day. If the head is a local model, the session grinds on a slow local card and appears to hang.

**Rule:** the fallback chain's first entry after the primary must be an API model that **does not share the primary's failed dependency**. A fallback may use the same tier only if it does not share that dependency. If the failed dependency is an account-level free allowance, another free model on the same account is not an eligible fallback; use paid if it is eligible, otherwise hold and alert. When the allowance's scope is unknown, treat it as account-level (§4.9a-bis). Local entries go after, and only for non-blocking auxiliary work (or under the §6.3 exception).

### 6.4a — Cross-box local dependencies

A chain entry on this box may be hosted on another box — a local model served over the tailnet by a peer. This is a **cross-box dependency** and it changes what "local" means for this box.

**Rules:**

- **Record the dependency.** The consuming box's state file lists the entry and its host. The host box's state file lists the consuming box. A change on the host (card maintenance, model swaps, VRAM use) shows the consumer is affected.
- **Probe from the consumer.** A local entry hosted on another box is never assumed healthy because the host's own checks pass. The consuming box probes it.
- **Provide a fallback not hosted on the same box.** If the peer is down, the consumer needs an independent route. The fallback for a peer-hosted local entry is not another entry on the same peer.
- **Report the independence.** In the θ/independence check (§4.18 and §6.3a), a peer-hosted local entry is independent of the box's own provider but **not** independent of the peer. A failure that takes the peer offline takes the entry with it.
- **State the dependency in the deployment's §12 record.** A reader who does not know that one box's cards serve another cannot reason about the second box's availability.
- **A peer-hosted local entry is not an independent API route.** For the purposes of §4.9's escalation target, an independent route means a route that does not share the failed dependency. A peer-hosted local entry shares its host; if the host is the failed dependency, the entry is not independent. The escalation target remains an independent API route, or the box holds and alerts.

### 6.5 Ladder ordering with a reserve

The reserve does not change the tier ladder; it changes the trigger for the paid switch.

- `remaining > {{reserve}}` → free tier preferred.
- `remaining ≤ {{reserve}}` → paid tier, until the reset.
- After the reset → free tier again, once the return conditions of §4.13 (hysteresis) are met.

**When the reserve is meaningless:** if a single session can consume the entire budget, the reserve cannot protect it (§4.13). The fix is not a bigger reserve — it is not parking the main lane on the shared resource, or a per-session cap.

**The unit is the session, not the turn.** The reserve protects against a session that cannot be reached once it is bound. A per-turn reserve computes against the wrong quantity.

---

## §7 — Health and liveness

### 7.1 Passive first

Parse existing logs for real latencies. Real traffic is the primary signal. Zero cost, no quota spent.

### 7.2 Active probes only to fill gaps — with a budget sized to the model class

An active probe fires only when:

- No real request in the last `{{probe_idle_window}}`.
- No active session.
- Below a per-hour cap (`{{probe_per_hour_cap}}`).

**A probe's timeout and token budget are properties of the model being probed, not constants of the probe.** This is Class 7's binding on the guide's own sensor. A fixed timeout correct for a chat model is wrong for a reasoning model: a reasoning model emits a thinking block before it emits an answer (in one observed case, ~150 tokens of thinking before the answer field populated), so a probe that expires inside the thinking returns a truncated or empty answer. Read naively, that is "the model is hung." The model is fine; the probe is too small.

**The rule:**

- **Derive the timeout and max-tokens from the model's class.**
  - **Chat model** (no `reasoning` field, or `reasoning` present but not the routing target): a short timeout (on the order of 15 s) with a small max-tokens budget. A chat model that has not answered within that window is genuinely slow.
  - **Reasoning model** (`reasoning` field present, or the model is being probed as a reasoning target): the timeout must exceed the model's expected thinking time, and max-tokens must exceed its expected thinking length. On the order of 60–120 s and 250+ tokens. The exact figure is a per-model value — measure it once, record it, use it thereafter.
- **Record the required budget per model.** A model whose first successful probe needed a larger budget carries that budget in the probe's configuration. Do not rediscover it on every run.
- **If a probe times out with no output, that is a probe verdict, not a model verdict.** Raise the budget and re-run before drawing any conclusion. A probe that returns `finish_reason: length` with an empty answer is likewise a probe verdict.
- **Assert on the answer content, not on the transport.** HTTP 200 plus a token count is not evidence of a healthy model. Check that the answer field is non-empty. A runtime that exposes the reasoning separately will show a non-empty `thinking` with an empty `response` when the model is still thinking — "in progress," not "broken."
- **Timeout is necessary but not sufficient.** A hard timeout bounds *silence*, not *total wall time*. A card that answers inside the budget may still take 9 s or more; a card that never answers hits the timeout and falls through. See §4.18 and §6.4a for how the fall-through interacts with the head choice.

**The trap this rule replaces:** a fixed timeout applied uniformly. In a deployment where reasoning is the primary workload, a fixed timeout maps `timeout → hung → BREACH → default switch`. A healthy reasoning model drives a fallback that its own probe caused. See Class 7 for the worked instance.

**Probe design:**

- Send a minimal request that returns quickly **for the model class**.
- Hard timeout, sized per the rule above.
- Measure time-to-first-byte, not total duration.
- Record the outcome as `ok`, `slow`, `timeout`, `http_429`, `http_error`, or `cannot-observe`. Record alongside it the budget that produced the outcome and the number of attempts.

**When a probe returns empty, check the probe before the model.** Raise the max-tokens above the model's expected reasoning length; re-run; if the answer arrives, the model is healthy and the probe was too small — record the required budget for that model.

**Per-model budget table.** Maintain a small table (`{{probe_budget_file}}`) with per-model entries: class, timeout that succeeds on a cold start, max-tokens that returned a non-empty answer on the first pass. Measured, not asserted; updated when a model's behavior changes.

### 7.3 Health signal order

1. Did we get a valid status? A 429 or 5xx is unhealthy regardless of latency.
2. Did a **first answer chunk** arrive within a threshold? See below.
3. If 1 and 2 pass, is the time-to-first-byte within the model's rolling band? Warning only.

Latency alone is never the pass/fail signal.

**"First chunk" means first answer chunk, not first byte.** A reasoning model that emits a thinking stream sends its first byte immediately, so a model stuck in reasoning passes the naive check. Require the first byte of the **answer** field. Where the runtime does not distinguish thinking from answer in the transport, the probe (§7.2) asserts on the answer content, not on the first chunk.

### 7.4 Baseline

Keep a rolling window per model:

- p50 and p95 of time-to-first-byte.
- Absolute floor (a hard ceiling, no matter what the baseline says). The floor is **per-model**: a chat model's floor is on the order of tens of seconds; a reasoning model's floor is on the order of a couple of minutes.

| Condition | Interpretation |
|---|---|
| < p95 | Normal |
| p95 to 2×p95 | Degraded |
| > 2×p95, sustained | Degraded; consider switching |
| > absolute floor | Hung |
| Timeout | Unreachable — see §7.2 for what a timeout actually means |
| 429 | Budget spent |

### 7.5 Cooldown and hysteresis

The canonical home of the switch-cooldown and switch-rate-limit rules is **§4.13**. This section names the parameters and points at §4.13 for the mechanism; it does not define a second one.

- Minimum interval between switches: `{{state_min_dwell}}` (§4.13, "minimum stay" and "write cap").
- Maximum switches per hour: `{{config_writes_per_hour}}` (§4.13, "write cap").
- Recently failed models are skipped for a TTL: `{{recent_failure_ttl}}` (§3.15, "leave free quickly" for the free-return side; §7.4's "Hung" and "Unreachable" for the model-failure side).

**One implementation, two names.** A deployment that implements these as two separate mechanisms — one for free-return hysteresis, one for switch churn — has the duplicate-rule defect this guide warns about (§24). Configure them once, in the registry, and reference them from both sections.

### 7.6 Client-side stall

If the probe is fast and the session appears stuck, the model is responsive. The session is stuck elsewhere (tool call, retry loop, UI). Do not switch. Report "not the model."

### 7.7 Post-hop verification

The switcher's own log is not evidence that the hop works. A separate verification step asserts, after the switch:

- The budget is restored (or in the expected state).
- The default is a free id again (when the budget allows).
- The id actually answers **with content** — a non-empty answer field, not merely HTTP 200 (§7.2).

Run the verification once after a scheduled recovery, not on every tick. Its own log is the source of truth, not the alert path.

**Cost:** the verification spends one real request against the daily budget. **Skip the verification when `remaining ≤ {{reserve}} + 1`.** The reserve is held back for user turns; the verification must not spend it.

**Trap:** trusting the switcher's own "I switched" line. It records intent. The verification records outcome.

**A checker enforces: act, then re-read.** It never judges a state the actor has not had a chance to fix. A verifier that runs before the switcher's first post-recovery tick reports about its own timing, not the switcher.

### 7.8 Probe attribution

**A probe may need to identify as the harness.** A model can gate on attribution headers: it answers the runtime that identifies itself and rejects a bare probe. In one observed case, a bare request returned 403 with a "harness-only" message; the same request with `HTTP-Referer`, `X-Title`, and a `User-Agent` returned 200 in ~0.5 s. A tools array alone still returned 403 — the gate reads the attribution headers. *(This observation is provider-specific; it is REPORTED, not OBSERVED across providers. Name the provider and date in the deployment's §12 record if confirmed.)*

**Fix pattern:**

1. The probe sends the same attribution the runtime sends.
2. The selftest asserts the header is *present*, not that the request succeeds. Asserting success makes the test depend on the model; asserting the header makes it depend on the probe.
3. A 403 or 401 from a probe is a fact about the *probe* until a real runtime request disproves it.

**One line:** *an un-attributed probe reports a working model as broken, and if the probe drives a fallback, it causes the reversal it was meant to prevent.*

---

## §8 — Keeping boxes aligned

Two boxes with "the same" config drift. The default state is drift, not parity.

**Single-box deployments.** If the deployment has one box, the pair-alignment rules in §8.1–§8.3 are not applicable. Replace the drift check with a **hash manifest of scripts and config** taken at a known-good state and compared on each run. The alignment rules do not apply; the manifest does. See §8.4.

### 8.1 What to align

- **Scripts.** Same file, same content hash.
- **Config schema.** Same keys at the top level. Values may differ per box.
- **Scheduled jobs.** Same jobs, same scripts, same classification (CLOBBER / SAFETY / NEUTRAL).
- **Provider keys.** Same providers configured, in the same shape.
- **Alert delivery.** Both boxes can deliver to the same channel, or neither can. A mismatch means one box silently discards.
- **Tools the scripts shell out to.** A package present on one box and absent on the other turns a working selector into a loud-but-unheard failure. Compare the dependencies, not just the scripts.
- **Cross-box dependencies.** A chain entry on one box hosted by another is a recorded dependency (§6.4a). Both boxes' state files list it; both boxes probe it from their own side.

### 8.2 A drift check

Run periodically. It exits with one of **three** codes: **0 = match**, **1 = drift**, **2 = cannot-observe**. It **does not** report "no drift" from a failed read, and it **does not** treat a comparison that failed on both sides as a match.

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
#!/usr/bin/env bash
# compare-boxes.sh — run from one box, compares against another.
# Exit codes: 0 match, 1 drift, 2 cannot-observe.
set -uo pipefail

REMOTE="$1"
HERMES_HOME="${HERMES_HOME:-$(python3 -c 'import os; print(os.path.join(os.path.expanduser("~"), ".hermes"))')}"
ACCEPTED="${ACCEPTED:-$HERMES_HOME/state/accepted-diffs.txt}"
FAIL=0
UNOBS=0

fail() { echo "DRIFT: $1"; FAIL=$((FAIL + 1)); }
unobs() { echo "CANNOT-OBSERVE: $1"; UNOBS=$((UNOBS + 1)); }

# Skip any comparison named in the accepted-differences file.
skip_accepted() {
  local comparison="$1"
  [ -f "$ACCEPTED" ] && grep -q "^${comparison}$" "$ACCEPTED"
}

# Resolve the remote home. A failed ssh is CANNOT-OBSERVE, not drift.
if ! REMOTE_HOME_RAW=$(ssh "$REMOTE" 'python3 -c "import os; print(os.path.expanduser(\"~\"))"'); then
  unobs "cannot read remote home"
  REMOTE_HOME=""
else
  REMOTE_HOME="$REMOTE_HOME_RAW/.hermes"
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
chmod 700 "$TMP"

echo "== script hashes =="
if [ -n "$REMOTE_HOME" ]; then
  # Stage remote output to a file. A failed ssh must not appear as empty
  # output for the diff; check the exit code explicitly.
  if ! ssh "$REMOTE" "cd '$REMOTE_HOME/scripts' 2>/dev/null && \
        find . -type f -not -path './.git/*' -exec sha256sum {} \; | sort" \
      > "$TMP/remote_hashes.txt" 2>/dev/null; then
    unobs "remote script hash read failed"
  else
      (cd "$HERMES_HOME/scripts" && find . -type f -not -path './.git/*' -exec sha256sum {} \; | sort) \
        > "$TMP/local_hashes.txt" 2>/dev/null
      if [ ! -s "$TMP/local_hashes.txt" ]; then
        unobs "local script hash read failed"
      else
        if ! skip_accepted "scripts"; then
          if ! diff "$TMP/remote_hashes.txt" "$TMP/local_hashes.txt"; then
            fail "scripts differ"
          fi
        fi
      fi
    fi
  fi

  echo "== top-level config keys =="
  if python3 -c "
  import yaml, sys, os
  try:
      print(sorted(yaml.safe_load(open(os.path.join('$HERMES_HOME','config.yaml'))).keys()))
  except Exception as e:
      sys.exit(2)
  " > "$TMP/local_keys.txt" 2>/dev/null; then
    if [ -n "$REMOTE_HOME" ]; then
      if ssh "$REMOTE" "python3 -c \\\"
  import yaml, sys, os
  try:
      print(sorted(yaml.safe_load(open(os.path.join('$REMOTE_HOME','config.yaml'))).keys()))
  except Exception as e:
      sys.exit(2)
  \\\"" > "$TMP/remote_keys.txt" 2>/dev/null; then
        if ! skip_accepted "config_keys"; then
          if ! diff "$TMP/remote_keys.txt" "$TMP/local_keys.txt"; then
            fail "config keys differ"
          fi
        fi
      else
        unobs "remote config read failed"
      fi
    fi
  else
    unobs "local config read failed"
  fi

  echo "== scheduled jobs (names only; ids differ by design) =="
  if [ -n "$REMOTE_HOME" ]; then
    if ! ssh "$REMOTE" 'hermes cron list' > "$TMP/remote_jobs.txt" 2>/dev/null; then
      unobs "remote cron list failed"
    else
      if ! hermes cron list > "$TMP/local_jobs.txt" 2>/dev/null; then
        unobs "local cron list failed"
      else
        # Extract the job *name* column; ids differ, names shouldn't.
              awk '/^[a-f0-9]+[[:space:]]/{print $2}' "$TMP/remote_jobs.txt" | sort -u > "$TMP/rj.txt"
              awk '/^[a-f0-9]+[[:space:]]/{print $2}' "$TMP/local_jobs.txt"  | sort -u > "$TMP/lj.txt"
        if ! skip_accepted "job_names"; then
          if ! diff "$TMP/rj.txt" "$TMP/lj.txt"; then
            fail "job names differ"
          fi
        fi
      fi
    fi
  fi

  echo "== alert delivery capability =="
  if ! hermes send -l > "$TMP/local_send.txt" 2>&1; then
    unobs "local send -l failed"
  else
    if [ -n "$REMOTE_HOME" ]; then
      if ! ssh "$REMOTE" 'hermes send -l' > "$TMP/remote_send.txt" 2>&1; then
        unobs "remote send -l failed"
      else
        # Compare the *set of channel kinds*, not full output; the two boxes
        # may show different channels by design.
        # Parse channel kinds from a stable section format: "kind: details"
        awk '/^[A-Za-z]+:/{print $1}' "$TMP/remote_send.txt" | sed 's/:$//' | sort -u > "$TMP/rkinds.txt" || true
        awk '/^[A-Za-z]+:/{print $1}' "$TMP/local_send.txt"  | sed 's/:$//' | sort -u > "$TMP/lkinds.txt" || true
        if ! skip_accepted "alert_delivery"; then
          if ! diff "$TMP/rkinds.txt" "$TMP/lkinds.txt"; then
            fail "alert-delivery kinds differ"
          fi
        fi
      fi
    fi
  fi

echo
if [ "$UNOBS" -gt 0 ]; then
  echo "CANNOT-OBSERVE: $UNOBS comparison(s) could not be completed"
  [ "$FAIL" -gt 0 ] && echo "DRIFT: $FAIL comparison(s) failed"
  exit 2
fi
if [ "$FAIL" -gt 0 ]; then
  echo "DRIFT: $FAIL comparison(s) failed"
  exit 1
fi
echo "no drift: all comparisons matched"
exit 0
```

**Four properties the script depends on:**

1. **Path expansion.** A literal `~` in a Python `open()` is not a path. Use `os.path.expanduser()` or `Path.home()`.
2. **Exit status.** The check accumulates failures and distinguishes "match" from "could not read." A read error fails the check. Two failed reads are not a match.
3. **Process substitution is not covered by `pipefail`.** A failed `ssh` inside `<(…)` reads as empty output, which would then be compared and reported as DRIFT. The script above stages remote output to a file and checks the `ssh` exit code explicitly.
4. **`.git` exclusion.** A versioned scripts directory contains `.git/` files that differ per box. Exclude `./.git/*`.

**A check that always fails gets ignored, which is as bad as one that always passes.** So the drift check allows for accepted differences (§8.3): cron ids differ by design, alert-delivery mechanism may differ, one box may have local hardware the other doesn't. Compare what should match; allow the rest to differ, and record why in §8.3.

### 8.3 Accepting intentional differences

Some differences are intentional. Record them in the deployment's §12 record:

- A box with local hardware; a box without.
- A box with a delivery channel; a box without.
- A box that handles messaging; a box that is a build node.
- A box whose local tier is served by another box over the tailnet (a cross-box dependency, §6.4a).

Recorded differences are contracts, not oversights. Unrecorded differences are future incidents.

**Cross-box dependencies belong here, in both directions.** A consumer records the dependency and the fact that its local tier is not independent of the host. A host records that it serves the consumer.

### 8.4 Single-box hash manifest

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
#!/usr/bin/env bash
# manifest.sh — record a known-good state; compare on each run.
# Exit codes: 0 match, 1 drift, 2 cannot-observe.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$(python3 -c 'import os; print(os.path.join(os.path.expanduser("~"), ".hermes"))')}"
# Defaults to $HOME/.hermes if HERMES_HOME is not set.
export HERMES_HOME
MANIFEST="${MANIFEST:-$HERMES_HOME/state/known-good.manifest}"
MODE="${1:-check}"   # "record" or "check"

# Compute the current state; a read error must be a distinct sentinel, not
# the same text as another error.
compute() {
  if ! (cd "$HERMES_HOME/scripts" && find . -type f -not -path './.git/*' \
         -exec sha256sum {} \; | sort); then
    echo "CANNOT-OBSERVE: scripts unreadable"; return 2
  fi
  if ! sha256sum "$HERMES_HOME/scripts/_model_switch.py" 2>/dev/null; then
      echo "CANNOT-OBSERVE: specific script missing"; return 2
    fi
  # Hash only the *key set* of the config, not the file bytes: a legitimate
  # model switch changes the file and must not appear as drift.
  python3 -c "
import yaml, os, sys, hashlib, json
p = os.path.join(os.environ.get('HERMES_HOME',''), 'config.yaml')
try:
    cfg = yaml.safe_load(open(p))
except Exception:
    sys.exit(2)
keys = sorted((cfg or {}).keys())
print(hashlib.sha256(json.dumps(keys).encode()).hexdigest(), 'config-keys')
" || { echo "CANNOT-OBSERVE: config unreadable"; return 2; }
}

record() {
  if ! compute > "$MANIFEST.tmp"; then
    rm -f "$MANIFEST.tmp"; echo "record failed: state unreadable" >&2; exit 2
  fi
  mv "$MANIFEST.tmp" "$MANIFEST"
  echo "recorded: $MANIFEST"
}

check() {
  [ -r "$MANIFEST" ] || { echo "CANNOT-OBSERVE: no manifest"; exit 2; }
  TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
  if ! compute > "$TMP"; then
    echo "CANNOT-OBSERVE: current state unreadable"; exit 2
  fi
  if ! diff "$MANIFEST" "$TMP"; then
    echo "DRIFT from recorded state"; exit 1
  fi
  echo "matches recorded state"; exit 0
}

case "$MODE" in
  record) record ;;
  check)  check ;;
  *)      echo "usage: $0 {record|check}" >&2; exit 2 ;;
esac
```

**Three properties this script gets right that the naive version does not:**

1. **An unreadable config is not written into the manifest as text.** If the read fails, `compute` returns non-zero and the manifest is not updated. Two failed reads do not match; they both fail.
2. **The config's hash is over its top-level key set, not its bytes.** A legitimate model switch changes the bytes of `config.yaml`; hashing the bytes would report drift on every switch. The key set is what should match across runs; the values legitimately differ.
3. **Defaults come from `HERMES_HOME` resolved as a path**, not from a literal `{{hermes_home}}` default.

---

## §9 — Config invariants

Set by hand unless noted. Verify on both boxes. **This is the canonical invariant list.** The §10 checks and §11 failure modes cite invariant numbers; they do not restate them.

**Pair-relative invariants** (invariants 2, 21 in their pair form) are not applicable on a single-box deployment; see §8.

**R-n** tags are a starting set for publish form (option (b) — snapshot to fork).

1. (R-1) `{{model_default}}` — API endpoint only.
2. (R-2) Fallback list — first entry is API; local entries only at the tail, and only for non-blocking auxiliary work (§6.3a).
3. (R-3) Auxiliary chains — no blocking chain heads at a local entry. Unknown status → API head (§4.15).
4. (R-4) `{{toolsets_key}}` — entry for every serving surface.
5. (R-5) Auxiliary providers health-checkable.
6. (R-6) No free default while budget is spent, or while `remaining ≤ {{reserve}}`.
7. (R-7) Errors log monitored, not just the main agent log.
8. (R-8) A state directory exists, mode 700.
9. (R-9) Main default and fallback head do not resolve to a local endpoint, **unless** the local-as-main conditions of §6.3 are met and recorded. Not applicable if the box has no local tier.
10. (R-10) All API tiers unreachable → log, hold, alert. Do not route the main session to local, and do not escalate the main session to a local entry (§4.9).
11. (R-11) Auxiliary failures never mutate the main default.
12. (R-12) Streaming stale timeout (`{{stream_stale_timeout}}`) is set explicitly and within the working range. **Absence and out-of-range both fail the check.**
13. (R-13) Every write by our scripts goes through lock + atomic pair (staged, single rename) + candidate validation (where the writer supports it). Where a writer cannot do an atomic replace, the limitation is stated in the deployment's §12 record.
14. (R-14) Every switch report lists stuck sessions.
15. (R-15) Detection assumes a working alert channel. "Working" means verified-loud per §0.6.
16. (R-16) Candidate validation requires a candidate file. Writers that cannot produce one are not protected.
17. (R-17) Free-tier reserve (`{{reserve}}`) is set at or above the p95 single-session draw. With at least `{{reserve_sample_floor}}` sessions (**recommended 59**), the reserve is the largest observed per-session draw. Below the floor, a conservative fixed reserve is used and labelled provisional.
18. (R-18) Selector writes only on material change, and writes both keys as one atomic pair (stage, then rename) (except a stated-limitation writer, inv. 13).
19. (R-19) Chat filter uses the output modality field exactly, for the default text ladder.
20. (R-20) Recovery-instant logging is present on exhausted runs, read from the confirmed daily reset (per §4.13a), or from the computed fallback labeled as such.
21. (R-21) **Exactly one component owns `{{model_default}}`.** Every other writer is paused or refuses to write (§4.14). **An empty owner field is a defect and raises an alert.**
22. (R-22) A scoped `/model` override does not modify `{{model_default}}`. The switcher's ladder applies to new sessions; an overridden session keeps its override until the scope ends.
23. (R-23) The default work type is text. Non-text work types require explicit classification or an explicit model override. Heuristics are advisory only.
24. (R-24) Code-capability routing uses a hand-maintained `family_purpose` map where reliability matters, and a name heuristic only as a hint. The catalog has no code flag.
25. (R-25) Every tool a scheduled selector shells out to is present on the box, and its absence is loud (a missing dependency produces a non-zero exit and a log line, never a silent skip).
26. (R-26) Scripts under `{{scripts_dir}}` are under version control, so a bad edit has a diff and a revert point.
27. (R-27) The tier table is checked against the live catalog on every run; drift is logged and a review is triggered.
28. (R-28) **Schedule vs. reset** — the first selector run that reads the counter at or after `R + {{skew_margin}}` happens by `R + {{max_post_reset_delay}}`, where `R` is the confirmed daily reset. (Not a divisibility test; see §4.13b.)
29. (R-29) **Probe budget** — timeout and max-tokens are sized per model class, not fixed. A probe that times out with no output is a probe verdict until a larger budget disproves it.
30. (R-30) **Quota-read failure policy** — route by failure class (§4.9): auth/provider-unreachable/negative balance → do not switch (log, hold, alert); quota-unreadable/free-only fault → fail closed to paid **only if paid is eligible**; paid credit or spend limit reached → paid is not eligible (use free if it is otherwise eligible, else hold and alert). Log the class, not just "failed."
31. (R-31) **Secrets hygiene** — secrets never appear on a command line and never appear in a transcript, a log, or a screen, not even a prefix. Tests print a hash or a length.
32. (R-32) **Verification surface** — a verification step is checked against the surface that can observe the fact it claims to test. A check that cannot read the fact is a ritual.
33. (R-33) **Two-axis results** — every rule reports applicability (`applicable` / `not-applicable` / `unknown`) and, when applicable, a check result: PASS (0), FAIL (1), or CANNOT-OBSERVE (2). A read error or a missing input is CANNOT-OBSERVE, never PASS. `not-applicable` comes only from an absent capability or an explicit policy exclusion; `unknown` applicability is reported, never skipped (§0.6).
34. (R-34) **"Loud" is verified delivery** — a rule that says "fail loud" is met only if delivery to a verified external destination succeeded within `{{loud_verification_window}}`. Otherwise the rule is unmet; the check reports FAIL, not PASS.
35. (R-35) **Signal scope** — a struggle signal from one session cannot change the global default. Global change requires evidence from many sessions, or it is advisory (§5.8).
36. (R-36) **Fail-closed escalation and spend guard** — The fail-closed escalation rule is in §4.9; this invariant names it, it does not restate it.
37. (R-37) **Hysteresis** — return to free requires `{{free_return_K}}` healthy reads over `{{free_return_D}}` minutes. Every state has a minimum stay. Config writes are capped at `{{config_writes_per_hour}}` per rolling hour; hitting the cap pins the safe tier and alerts (§4.13). This is the same mechanism as §7.5's cooldown and rate-limit entries; configure them once.
38. (R-38) **Cross-box dependency** — a chain entry hosted on another box is recorded, probed from the consumer, backed by an independent fallback, and listed on both boxes' state records (§6.4a). A peer-hosted local entry is not an independent API route for §4.9.
39. (R-39) **Owner field is populated** — every artifact that has a single-writer rule has a named owner. **The artifacts with a single-writer rule are:** `{{model_default}}` (invariant 21), the local-inventory state file (§26.1), the alert-heartbeat file (§29.1), the run ledger (§29.1), the decision record (per deployment §12), the write lock (§4.14), and the config-write path (§4.14). Each names its owner. (The empty-owner rule lives in invariant 21; it is not restated here.)
40. (R-40) **Local inference ports have explicit access control (§26.10)** — ports bind to loopback or the tailnet interface only, have a tailnet ACL allowing only named devices, and require authentication on web UIs. A check that cannot observe the refusal reports CANNOT-OBSERVE.
41. (R-41) **Foreign writes pause the selector** — if the saved default differs from both the selector's last write and its current choice, another writer changed it. The selector enters the manual-override pause (§4.14a), writes nothing, and never reverts the change. The pause ends after `{{manual_override_hours}}` hours (default 4), immediately on an explicit resume, or — when the operator asked for a hold — only on an explicit resume.
42. (R-42) **Limits are read, not remembered** — the free allowance, credit and spend limits, and their structure (counter, window type, reset instant) are read from the provider on every tick through the provider adapter. No script hardcodes a provider's limit numbers. A limit that cannot be read makes dependent checks CANNOT-OBSERVE.

---

## §10 — Verification checklist

Each check runs only for rules that are **applicable** on this box (§0.6). Rules that are not-applicable are reported as such and not checked; rules with unknown applicability are reported with the question that would resolve them. A check returns **PASS** (exit 0), **FAIL** (exit 1), or **CANNOT-OBSERVE** (exit 2). A read error, a missing input, or a missing tool is CANNOT-OBSERVE. **Reporting PASS when the check could not run is the failure mode the whole section exists to prevent.**

**Run these checks on a schedule, not on every edit.** They are the box's self-report.

### 10.1 The switch path works

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Run the WRAPPER, not the .py file directly. The wrapper (§2.5) does the
# interpreter capability probe. Running the .py directly skips that step
# and writes config outside the owner gate.
if ! "{{scripts_dir}}/_model_switch.sh" "{{model_id}}" "{{provider}}"; then
  echo "switch helper failed (exit $?)"; exit 1
fi
echo "switch helper OK"
```

A direct invocation of the `.py` file skips the interpreter check (§2.5), and it is a live config write by a component that may not be the owner (§3.7, invariant 21). Both are defects.

### 10.2 No hardcoded model ids in the selector

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
if grep -rn '{{specific_vendor}}/' "{{scripts_dir}}/{{selector_script}}"; then
  echo "hardcoded model id found"; exit 1
fi
echo "no hardcoded ids"
```

Zero hits. A literal in an assignment is a bug.

### 10.3 Log is human-readable

Last run logs per-million-dollar costs. A log showing `0.000000` for a real cost is unreadable.

### 10.4 What actually served the last requests

If the runtime state is readable, query it. Confirm the recorded model matches the intended default. If not, the gateway has not picked up the change, or the session predates the change.

### 10.5 Free tier preferred when budget available

Query the quota endpoint.

- If `remaining > {{reserve}}` and the current model is paid, the selector is wrong.
- If `remaining ≤ {{reserve}}` and the current model is free, the selector is wrong.
- If `remaining ≤ {{reserve}}` and the current model is paid, this is correct (§4.13, §6.5). Not an alarm.

The reserve is the boundary, not zero. (Invariant 17.)

### 10.6 Test the test

Source `.env` before any key test. A 401 from a test that did not source `.env` is a test bug.

### 10.7 Is the free tier exhausted?

The API key is not placed on the `curl` command line. Use a mode-600 config file, or stdin:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
set -a; . "{{hermes_home}}/.env"; set +a
# curl reads the auth from stdin; nothing touches disk.
curl -s --connect-timeout 5 --max-time 15 --config - \
  "{{quota_endpoint}}" <<EOF | jq '{
    is_free_tier: .data.is_free_tier,
    free_remaining: .data.free_model_daily_requests.remaining
  }'
header = "Authorization: Bearer ${{provider_key_var}}"
EOF
```

The key reaches `curl` without appearing in argv. `--config -` reads the config from standard input; nothing is written to disk and nothing is left behind if the process is killed. (Invariant 31.)

### 10.8 Did another writer clobber your write?

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
grep 'Model switched in-place' "{{hermes_home}}/logs/agent.log" | tail -20
grep -A2 '^model:' "{{config_path}}"
date -u +%Y-%m-%dT%H:%M:%SZ
```

Compare your write timestamp to the latest switch line.

### 10.9 Are task assignees real?

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
{{task_system}} assignees
ls "{{hermes_home}}/profiles/"
```

Any `ON DISK: no` is a phantom.

### 10.10 Does `.env` have duplicates?

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
grep -c "^$( printf '%s' '{{provider_key_var}}' )=" "{{hermes_home}}/.env"
```

Count > 1 is a bug. Also check `{{config_path}}` for an inline placeholder credential that shadows the file (§3.23).

### 10.11 Validator tested against real schema

Run the validator against a sanitized copy of the real config, plus at least one negative test that proves it catches a local fallback.

### 10.12 Alert path check

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
hermes send -l
cat "{{hermes_home}}/channel_directory.json" 2>/dev/null
cat "{{hermes_home}}/gateway_state.json" 2>/dev/null | jq '.platforms'
```

**Check for the half-wired contradiction.** If `gateway_state.json` claims a channel is connected while `channel_directory.json` shows an empty list and the last job's delivery failed, the state file is stale. That is a finding, not a config error. Fix the state source, not just the channel.

**Last successful delivery.** Query the cron ledger for the most recent delivery that succeeded, not just the last attempt. Record the timestamp in the deployment's §12 record. If there is no successful delivery in the retained window, the box is **not loud** (invariant 34), and every fail-loud rule is unmet.

### 10.13 Timeout sanity — fails on absence and on out-of-range

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
python3 - <<'PY'
import os, yaml, sys
h = os.environ.get("HERMES_HOME") or (os.path.expanduser("~") + "/.hermes")
try:
    cfg = yaml.safe_load(open(os.path.join(h, "config.yaml")))
except Exception as e:
    print(f"CANNOT-OBSERVE: config unreadable: {e}", file=sys.stderr)
    sys.exit(2)
# The key the runtime reads. On most builds this is the local-stream variant.
# The placeholder resolves from the registry; substitute the actual key
# before deployment.
key = "{{stream_stale_timeout_key}}"
agent = cfg.get("agent") or {}
v = agent.get(key)
if v is None:
    print(f"{key} is not set (a missing value is a defect)")
    sys.exit(1)
if not isinstance(v, (int, float)) or v <= 0:
    print(f"{key} is not a positive number: {v!r}")
    sys.exit(1)
mn = {{stream_stale_min}}
mx = {{stream_stale_max}}
if v < mn:
    print(f"{key} below working minimum: {v} < {mn}")
    sys.exit(1)
if v > mx:
    print(f"{key} above working maximum: {v} > {mx}")
    sys.exit(1)
print(f"{key} = {v} (in range)")
PY
```

**Absence fails.** A zero or negative value fails. A value below the working minimum fails. A **read error** exits 2 (CANNOT-OBSERVE), not 1.

The key is a registry placeholder, not a hardcoded literal. A check that hardcodes the key while the rest of the guide uses a placeholder is the same class of defect as a rule stated twice.

### 10.14 Verify a CLI flag exists before using it

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
{{command}} --help 2>&1 | grep -i {{flag}} || echo "no {{flag}} on this version"
```

This answers for CLI flags only — see §10.19 for slash-command flags.

### 10.15 Drift check between boxes

See §8.2. Exit codes 0 / 1 / 2. Compare the output; do not report "no drift" when the check could not read a file.

### 10.16 Reserved vs spent

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
remaining=$({{read_remaining}})
reserve=${FREE_RESERVE:-{{reserve}}}
cur=$({{read_current_tier}})
if [ -z "$remaining" ]; then
  echo "CANNOT-OBSERVE: remaining is empty (quota read failed)"
  exit 2
fi
if [ "$remaining" -le "$reserve" ] && [ "$cur" != "paid" ]; then
  echo "POLICY MISMATCH: spent-below-reserve but current is not paid"
  exit 1
fi
exit 0
```

An empty `remaining` is CANNOT-OBSERVE (exit 2), not PASS.

### 10.17 Post-hop verification is present and runs

Confirm a `verify-*.sh` exists and a one-shot schedule invokes it after the expected reset. Its log file is the source of truth for the hop.

### 10.18 Owner confirmed

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
{{scheduler}} list | grep -iE 'selector|failover|autoswitch'
jq -r '.{{owner_field}}' "{{prefs_path}}"
```

Exactly one entry is active. Every other writer is paused or refuses to write. **The owner field is populated.** An empty value is a defect (invariant 21, §3.7) and the check reports FAIL, not PASS.

**Every artifact with a single-writer rule has a named owner** (invariant 39). Run the owner check against each: `{{model_default}}`, the local-inventory state file, the alert-heartbeat file, the run ledger, the decision record, the write lock, the config-write path.

### 10.19 Scoped `/model` semantics on this build

The scopes are `/model` sub-command flags, not top-level CLI flags, so `--help` cannot list them. The scope table is in §2.6. Verify from the source and then from live behavior:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Source check — the parser owns the flags:
grep -rn 'is_once\|is_session\|is_global' "{{runtime_dir}}/hermes_cli/model_switch.py" | head
# Live probe — confirm the behavior on this build:
#   run /model {{same_id}} in a session, then check whether config.yaml changed
#     changed   -> the plain form persisted (the fresh-install case, §2.6)
#     unchanged -> the plain form is session-scoped (the normal case)
#   then run /model {{same_id}} --global and confirm config.yaml changed.
```

Record the result in the deployment's §12 record under "Scoped `/model` default."

**Generalization (belongs with §10.14):** a CLI flag is exposed by `--help`; a slash-command flag is exposed by source or live probing; a config value is exposed by reading the config; a runtime behavior is exposed by observing the runtime. A check that cannot observe the fact is not a check.

### 10.20 Every shelled-out tool exists

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
missing=0
for t in {{selector_tools}}; do
  if ! command -v "$t" >/dev/null; then
    echo "MISSING: $t"; missing=$((missing + 1))
  fi
done
[ "$missing" -eq 0 ] || exit 1
```

A missing tool must fail the last run loudly (invariant 25). If the run log says "silent," the dependency check and the alert path are both broken.

### 10.21 Selector scripts are versioned

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
git -C "{{scripts_dir}}" rev-parse --is-inside-work-tree 2>/dev/null || {
  echo "NOT VERSIONED — no diff, no history, no revert"; exit 1
}
```

### 10.22 A flag name is not a specification

The scope flags exist on exactly one surface. In one observed case, `hermes model --help` listed a flag with a name (`--scope`) that meant an OAuth scope for the login flow, not a persistence scope; the subcommand took no model id and rejected the scoped form. The persistence scopes `--once` / `--session` / `--global` live only in the `/model` slash-command parser. *(This is an OBSERVED fact about one build; verify on your build.)*

An operator who reads `--scope` in the CLI help and concludes the CLI supports scoped switching is wrong twice: the flag means something else, and the surface cannot express a target model.

**Rule:** verify a flag's meaning on the surface you are using, not from its name.

### 10.23 Confirm the component ran before diagnosing its output

Read the last exit code and the first log line of any component whose output you are about to interpret. A job that cannot import its dependency is dead, not paused. A component that exited non-zero produced an error, not a decision. Class 8.

### 10.24 Confirm the tier table matches the live catalog

Compare the tier table's families against the live catalog. Log families that are missing from either side. Trigger a human review when the drift persists or the review-by date passes.

### 10.25 Confirm the probe budget matches the model class

For each model in the health probe's configuration, confirm the timeout and max-tokens are sized to that model's class. A reasoning model with a fixed chat-class timeout is a defect.

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
grep -n -i 'timeout\|max_tokens\|num_predict' "{{scripts_dir}}/{{health_script}}" 2>/dev/null
```

Any fixed value applied across models of different classes is the defect.

### 10.26 Confirm the quota-read failure path

Trigger the failure cases in a test environment and confirm the selector routes by failure class:

- Endpoint unreachable — must **not** switch; log, hold, alert.
- Key rejected (401/403) — must **not** switch; log, alert on the credential.
- Malformed response — must fail closed to paid, log the parse failure.
- Free-model-only fault (429 on `:free`) — must fail closed to paid.

Each case logs its class, not just "failed." See §4.9, invariant 30.

### 10.27 Confirm no secret is on a command line

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Static scan of the scripts for the shapes that leak secrets.
# The dynamic `ps` snapshot almost never catches a curl call (it lasts <1s),
# so the static scan is the real check.
hits=$(grep -rnE '(-H|--header)[[:space:]]+["'"'"']Authorization|--arg[[:space:]]+[a-z]+[[:space:]]+"\$[A-Z_]*KEY|Bearer[[:space:]]+\$' \
  "{{scripts_dir}}/" 2>/dev/null | wc -l)
case "$hits" in
  0) exit 0 ;;
  *) exit 1 ;;
esac
```

Zero hits. A key on `curl`'s argv is visible to any local user via `/proc`. The static scan is what catches it before the next edit re-introduces the pattern; see §20.16.

### 10.28 Confirm the runtime falls through on timeout

Two checks, both required:

> **Illustrative — not a tested script.** Do not copy into a live box. Known defects in the embedded scripts are listed in the review handoff; tested versions will live as files in the repository.

```bash
# Source check: look for a timeout-named fallback reason.
grep -rn '_is_timeout_error\|request timed out\|fallback.*timeout' \
  "{{runtime_dir}}/agent/" 2>/dev/null | head

# Black-box check: route a low-risk chain's head at an endpoint that accepts
# but never answers, with a short timeout, and observe whether the chain
# advances to the API entry.
```

A runtime that advances on timeout makes the §4.18 inequality apply as written. A runtime that does not makes the API head the correct default for any chain with non-zero θ. Report the result in the deployment's §12 record.

### 10.29 Confirm the owner gate accepts both name and id

Test with a scratch home:

- A selector whose `{{owner_field}}` holds its own name proceeds.
- A selector whose `{{owner_field}}` holds another producer's name or id stands down (exit 0 with `[inactive]`).
- A selector whose `{{owner_field}}` is empty **fails closed and raises an alert** (invariant 21, 39).

Report each case PASS / FAIL / CANNOT-OBSERVE.

### 10.30 Confirm the local inference ports have access control

See §3.34 and §26.10. Test:

- Bind: the inference port is not listening on all interfaces.
- Reachability: a connection from a tailnet device that is not allowed is refused.
- Auth: web UIs require auth; signup is off.

If no disallowed test device exists, the result is CANNOT-OBSERVE, not PASS.

### 10.31 Confirm the local-inventory state file is fresh and well-formed

See §26. Read the file, check the version field, the heartbeat, and the schema. A malformed file fails; a stale heartbeat reports CANNOT-OBSERVE for the state it describes, not PASS.

### 10.32 Confirm the run ledger is being written

See §29. The ledger exists, has one line per tick, and the last line's timestamp is within `{{ledger_staleness_multiplier}}`× the tick period.

### 10.33 Confirm the hot-path discipline holds

See §27. The prompt path makes no network calls, no probe calls, and no config writes. Where the box owns its own prompt path, run the blocked-network test (§27.3) and the import-boundary lint (§27.3). Where the prompt path is runtime code the box does not own, run the black-box test (§27.6): block the quota endpoint and stop the selector; confirm prompts still succeed within normal latency.

### 10.34 Confirm the selector stands down on a foreign write

In a scratch home: let the selector write a default; change the default by hand to a different model; run the selector.

- PASS: it reports the manual-override pause with an expiry, writes nothing, and on a second run still writes nothing.
- FAIL: it writes its own choice back, or reports no pause.
- With a hold requested: PASS only if the pause has no expiry.
- If the selector does not record its last write, the check is CANNOT-OBSERVE.

### 10.35 Confirm limits are read live

- Static: no script hardcodes a provider's limit number (a daily request cap, a per-minute rate). Any literal is FAIL.
- Dynamic: the last run's log shows the counter, the window type, and the reset source read from the provider on that tick. Missing → CANNOT-OBSERVE.

---

## §11 — Failure modes and expected behavior

The failure table is no longer duplicated here. It is the trap-door entries in **§3** and the invariants in **§9**, cross-referenced. Additions:

| Symptom | Expected | Where |
|---|---|---|
| Quota-read failure of any class | Route by class | §4.9, invariant 30 |
| Auth failure (401/403) | Do not switch; log, alert | §4.9 |
| Provider unreachable | Do not switch; try independent API route; else hold | §4.9 |
| Persistent fail-closed | Hold current tier; alert; rely on provider-side cap | §4.9, invariant 36 |
| Free-return flap | Hysteresis + write cap | §4.13, invariant 37 |
| Check read error | Report CANNOT-OBSERVE, not PASS | §10, invariant 33 |
| "Fail loud" with no verified channel | Report FAIL, not PASS | §0.6, invariant 34 |
| One session struggles | Act on that session (if the lever exists) or advisory | §5.8, invariant 35 |
| Schedule "divides" reset but misses the window | Use the max-delay rule | §4.13b, invariant 28 |
| Cross-box local entry down | Consumer's fallback is not on the same host | §6.4a, invariant 38 |
| Empty owner field | Alert; do not treat as aligned | §3.7, invariants 21, 39 |
| Timeout on a probe | Probe verdict until a larger budget disproves | §7.2, invariant 29 |
| Timeout on a runtime call | Confirm the runtime falls through; if not, API head | §10.28, §4.18 |
| Local head on a blocking chain | Move head to API | §4.15, invariant 3 |
| Config write with no material change | Skip the write | §4.14, invariant 18 |
| Write without a lock | Lock file + atomic pair | §4.14, invariant 13 |
| Inference port open to the tailnet | Add ACL, bind loopback/tailnet only | §3.34, §26.10 |
| Empty alert channel and no provider-side cap | State unprotected in §12 | §4.9, invariant 36 |
| Hot-path I/O creep | Run the blocked-network test and the lint | §27.3, §27.7 |
| Rule's capability absent | Report not-applicable; do not run the check | §0.6, invariant 33 |
| Rule's capability unknown | Report unknown with the question that resolves it | §0.6, invariant 33 |
| Paid credit or spend limit reached | Paid ineligible; free if eligible, else hold and alert | §4.9, invariant 30 |
| Default changed by someone else | Manual-override pause; write nothing | §4.14a, invariant 41 |
| Provider changed its limits | Read live; log the structure change | §4.9a-bis, invariant 42 |
| Config rewrite would drop comments | Round-trip writer or sanctioned path; else do not write | §3.37, §4.14 |

---

## §12 — Verification state (per-box record)

Maintain this as a table per deployment. **Generated from the §10 checks where possible; the check's result is the value.** Values are per-box; the *shape* is portable.

Each row that records a rule's state records its **applicability** (§0.6) alongside the value. A not-applicable row names the absent capability or the policy that excludes it.

| Item | Source (§10 check) | Value |
|---|---|---|
| `{{hermes_home}}` resolved path | — | «path» |
| Scripts directory resolved path | — | «path» |
| Streaming stale timeout | §10.13 | «value» + PASS/FAIL/CANNOT |
| Main default / provider | — | «model» / «provider» |
| Fallback list | §3 / §6.4 | «summary» — API head? locals tail? |
| Free reserve | — | «value» (provisional? sample count?) |
| Reserve sample count | — | «n» — above floor 59? |
| Material-change gate | §10.8 | present / absent |
| Write rule | §4.14 | atomic pair / sequential (state limitation if not atomic) |
| Write lock path | §4.14 | «path» (a dedicated lock file, not the config) |
| Owner — `{{model_default}}` | §10.18 | name/id/empty (empty is a defect) |
| Owner — local-inventory file | §10.18 | name/id/empty |
| Owner — alert-heartbeat file | §10.18 | name/id/empty |
| Owner — run ledger | §10.18 | name/id/empty |
| Owner — decision record | §10.18 | name/id/empty |
| Owner — write lock | §10.18 | name/id/empty |
| Owner — config-write path | §10.18 | name/id/empty |
| Auxiliary routing | §4.15 | blocking chains → API; non-blocking chains → «head» |
| Unknown-status chains | §4.15 | count and heads |
| Validator | §10.11 | PASS/FAIL/CANNOT |
| Selector schedule | — | «cron / timer / manual» |
| Post-hop verification | §10.17 | present / absent |
| Probe attribution | §7.8 | headers sent? asserted present? |
| Probe budget per model | §10.25 | per-class / fixed (fixed is the defect) |
| Quota-read failure policy | §10.26 | classes handled? which? |
| Secrets on argv | §10.27 | none / leaked |
| Alert delivery | §10.12 | configured / mute / half-wired |
| Last successful alert delivery | §10.12 | timestamp, or "never" |
| Alert channel is verified-loud | §0.6, §10.12 | yes / no |
| Env file duplicates | §10.10 | count |
| Inline config placeholder | §10.10 | present / absent |
| Reserve honored | §10.5 | yes / no |
| Recovery-instant source | §4.13 | header / computed / absent |
| Reset header confirmed | §4.13a | yes / no / HYPOTHESIS |
| Schedule vs. reset | §4.13b | max delay after reset (minutes) |
| Scoped `/model` default | §10.19 | session / global |
| Override semantics | §10.19 | once / session / global supported? |
| Work-type routing | §4.16 | present / absent |
| Code capability source | §4.16 | map / heuristic / none |
| `reasoning` field used | §4.16 | yes / no |
| Shelled-out tool deps | §10.20 | present / missing |
| Live read isolated on dry-run | §10 | yes / no |
| Staleness-line delivery | §10.12 | verified / advisory |
| Running selector under VCS | §10.21 | yes / no |
| Tier-table drift check | §10.24 | present / absent |
| Falls through on timeout | §10.28 | yes / no / source-verified |
| Local tier exists (capability) | §3.16 | present / absent / unknown |
| Local tier is host-local or peer-hosted | §6.4a | host-local / peer-hosted (host: «name») |
| Cross-box dependencies | §6.4a | list |
| Tailnet inference-port access control | §10.30 | ACL on? bind loopback/tailnet only? auth on UIs? |
| `{{probe_budget_file}}` present | §7.2 | yes / no |
| Local-inventory file fresh | §10.31 | yes / no / CANNOT |
| Run ledger being written | §10.32 | yes / no / CANNOT |
| Hot-path discipline holds | §10.33 | yes / no / CANNOT |
| Fail-closed escalation exists | §4.9 | yes / no |
| Provider-side spend cap | §4.9 | yes / no |
| Hysteresis values in use | §4.13 | K, D, config_writes_per_hour |
| Signal-scope lever reachable | §5.8 | yes / no / advisory |
| Manual-override state | §10.34 | none / paused until «ts» / held until resume |
| Manual-override window | §4.14a | «hours» (default 4) |
| Limits source | §10.35 | read live from «endpoint» / not observable |
| Limit structure | §4.9a-bis | counter + window («daily UTC» / rolling / …) + reset source |

**Generated where possible.** Where a §10 check exists for a row, the check's output is the value. Where no check exists, the operator fills the row by hand. A row left as `«…»` after a run is a check that did not run — report it as CANNOT-OBSERVE, not omit it.


---

## §13 — Priorities when onboarding a box

This is a **priority order**, not a restatement of rules. Each item names the rule it satisfies; the rule is in the section cited.

1. **Rotate any leaked credentials.** If a password or key appeared in a transcript, rotate. Secrets hygiene is invariant 31; the three leak shapes (§2.4, §10.7, §3.23).
2. **Audit the env file for duplicates**, and for an inline config placeholder shadowing them. Use the hash test in §3.23, never a key prefix.
3. **Verify the alert delivery path.** If mute or half-wired, fix before building anything alert-dependent. **"Verified" means loud per §0.6** — delivered to an external destination a human watches, verified within `{{loud_verification_window}}`. If `gateway_state.json` claims a connection the jobs do not have, fix the state source, not just the channel. Invariants 15, 34; §10.12.
4. **Check the free-tier quota and the current default.**
5. **Audit the fallback provider list.** Head must be API; local entries belong at the tail, and only for non-blocking auxiliary work. Invariants 2, 9; §6.3a.
6. **Classify scheduled jobs.** CLOBBER / SAFETY / NEUTRAL. §3.7.
7. **Verify the streaming stale timeout.** Absence and out-of-range both fail. §10.13; invariant 12.
8. **Set the free-tier reserve** (sized above the p95 single-session draw) and confirm the selector honors it. If the sample is below `{{reserve_sample_floor}}` (recommended 59), use a conservative fixed value and label it provisional. Invariant 17; §4.13.
9. **Confirm the selector writes only on material change, and writes both keys as one atomic pair.** Sequential writes are the defect. Invariant 18; §4.14.
10. **Do not ask any model to fix the failure it is experiencing.** §19.
11. **Run the drift check between boxes, or the hash manifest on a single box.** Fix or record differences. Confirm the check can read both sides before trusting a match. §8.2, §8.4; invariant 33.
12. **Do not build new escalation paths until the alert channel is verified-loud.** Invariant 34; §0.6.
13. **Confirm the owner.** Verify exactly one selector is active. Every other writer is paused or refuses to write. Populate the owner field for every artifact with a single-writer rule. Invariants 21, 39; §3.7.
14. **Confirm the `/model` default on each box.** Plain `/model X` is session-scoped; a script that assumed the old behavior must name the scope explicitly. §2.6, §10.19.
15. **Verify every tool the selector shells out to is installed.** A clone inherits config, not packages. Invariant 25; §10.20.
16. **Put the selector scripts under version control** before the next edit. Invariant 26; §10.21.
17. **Confirm the tier table against the live catalog.** Log stale tiers, missing tiers, overdue reviews. Invariant 27; §10.24.
18. **Confirm the schedule against the reset.** The rule is a maximum delay after reset, not a divisibility test. Name the cron timezone versus the UTC reset. Invariant 28; §4.13b.
19. **Confirm the reset instant is read from the header**, that the header is confirmed to describe the daily limit, and that the read is cheap (0 tokens where the runtime allows). Invariants 20, 30; §4.13a.
20. **Confirm the probe sends the runtime's attribution headers.** §7.8.
21. **Confirm the probe budget is sized per model class.** A fixed timeout on a reasoning model maps timeout to a default switch. Invariant 29; §7.2.
22. **Confirm the quota-read failure path routes by failure class.** Auth and provider-unreachable do not switch; quota-unreadable and free-model-only faults fail closed to paid. Log the class. Invariant 30; §4.9.
23. **Confirm no secret appears on a command line.** Run the static scan in §10.27. Invariant 31.
24. **Confirm the runtime falls through on timeout**, or apply the conservative default for any chain with non-zero θ. §10.28; §4.18.
25. **Confirm the local inference ports have explicit access control.** The tailnet is not a trust boundary. §3.34; §10.30; §26.10.
26. **Record cross-box dependencies** in both boxes' state records. §6.4a; invariant 38.
27. **Confirm the fail-closed escalation and spend guard exist**, or state their absence in the deployment's §12 record. Invariant 36; §4.9.
28. **Confirm the signal-scope rule is implemented**, or the struggle score is advisory only. Invariant 35; §5.8.
29. **Confirm hysteresis and the config-write cap.** Invariant 37; §4.13.
30. **Confirm the local-inventory state file** is fresh and well-formed. §26; §10.31.
31. **Confirm the run ledger is being written.** §29; §10.32.
32. **Confirm the hot-path discipline holds.** §27; §10.33.
33. **Answer the capability questions** so each rule's applicability is known, not guessed. `docs/capability-questionnaire.md`; §0.6.
34. **Confirm the selector stands down on a manual change** and that its pause window is set. Invariant 41; §10.34.
35. **Confirm limits are read live**, with no hardcoded provider numbers. Invariant 42; §10.35.

---

## §14 — Things not to do

Most of this list is generated from invariants. The rest names a failure mode no invariant covers.

**Generated from invariants** (the invariant number is in parentheses; do not restate the invariant here):

- Do not write `{{model_default}}` from more than one writer (21, 39).
- Do not write the config without a material change (18).
- Do not write the two config keys sequentially (18).
- Do not claim atomicity a writer cannot deliver (13).
- Do not route the main session to a local endpoint outside the §6.3 exception, and never under an API failure (9, 10).
- Do not head a blocking auxiliary chain at a local entry (3).
- Do not head an unknown-status chain at a local entry (3).
- Do not persist a free default while `remaining ≤ {{reserve}}` (6).
- Do not use a fixed probe budget across model classes (29).
- Do not fail open to free on a quota-read failure (30).
- Do not switch on an auth failure (30).
- Do not escalate the main session to local under failure (9, 10, 36).
- Do not place a secret on a command line or print a key prefix (31).
- Do not pass a verification step that could not observe the fact (32).
- Do not report PASS when the result is CANNOT-OBSERVE (33).
- Do not claim "loud" from a log file (34).
- Do not change the global default from one session's signal (35).
- Do not leave an empty owner field and call the box aligned (21, 39).
- Do not treat a chain entry hosted on another box as an independent API route (38, §4.9).
- Do not assume a peer-hosted local entry is healthy because the host's checks pass (38).
- Do not implement hysteresis as two separate mechanisms (37, §7.5).

**Not generated from an invariant** — a short list of rules that stand alone:

- Do not treat an agent's report as an observation.
- Do not treat a proposed policy as a running mechanism.
- Do not run a command that may write to live config without isolation.
- Do not infer runtime behavior from config facts.
- Do not use a command in an example unless its flags are confirmed to exist.
- Do not claim candidate validation exists for a writer that cannot produce a candidate file.
- Do not use the log's duration values as independent dwell time without confirming the emitter.
- Do not read a reset field from the quota endpoint unless the endpoint documents it. Read the reset from the rate-limit header (§4.13a).
- Do not assume a scheduled job's delivery target resolves. Test.
- Do not test a validator only against the schema it assumes.
- Do not escalate on a probe-generated 429.
- Do not retry a timed-out request unless idempotent.
- Do not turn missing telemetry into a diagnosis.
- Do not assert a CLI verb has been run when it has only been read.
- Do not present a runbook step as verified when the underlying command is not.
- Do not conflate "cron writer check" with "no writer check."
- Do not invent a CLI flag.
- Do not park a new session on the last requests of the daily budget.
- Do not rank free models alphabetically.
- Do not detect free by suffix alone.
- Do not leave the recovery instant out of an exhausted run's log line.
- Do not rotate a credential because of a wildcard bind without checking reachability.
- Do not assume `/model X` persists without checking the build's default.
- Do not filter reasoning models by `mandatory: true`.
- Do not route code tasks by a catalog field that does not exist.
- Do not act on a heuristic classifier's hint without an explicit command.
- Do not verify a fact from a surface that cannot expose it (Class 6).
- Do not rely on a switch command's default scope. Name the scope explicitly.
- Do not label something PROPOSED without checking whether the mechanism it depends on already exists.
- Do not assume a clone has the tools the source box has.
- Do not judge a model by a probe too small to let it answer.
- Do not read a flag's meaning from its name.
- Do not let a preference list go stale while a tier is unavailable.
- Do not auto-delete entries from a preference list.
- Do not delete another writer's entries to free space.
- Do not resolve a blocker by clobbering another writer to close your own loop.
- Do not diagnose a component's output before confirming the component ran.
- Do not gate a diagnostic by the policy it exists to bypass.
- Do not express a locality rule as an order rule.
- Do not route a router. Exclude `router` / `/auto` / `fusion` patterns from the interactive ladders.
- Do not treat a zero-price non-text model as free.
- Do not apply a fixed timeout to a probe whose model class may reason.
- Do not let a verification step pass on an absent value.
- Do not let a drift check report "match" from a failed read.
- Do not size a reserve against an average turn.
- Do not leave the local inference ports open to the tailnet.
- Do not leave an artifact with a single-writer rule without a named owner.
- Do not mark a rule not-applicable because its check could not run.
- Do not revert a manual model change; pause instead (41).
- Do not hardcode a provider's limit numbers (42).
- Do not rewrite a hand-edited config with a writer that drops comments.
- Do not fall back to a model that shares the failed dependency.

---

## §15 — Quick reference

**The checks are §10.** This section is a pointer and a small set of shell pitfalls. It does not restate any check; if a command you need is not in §10, add it there, not here.

**Where to look for what:**

- A verification check → §10.
- A rule → §9 (invariants), §3 (trap doors), §4–§6 (selection, escalation).
- A parameter and its value → the registry (`{{registry_file}}`).
- A definition → §18 (glossary).
- The record of what happened → Part III (Record).
- The local-inventory design → §26.
- The hot-path discipline → §27.
- The parameter structure → §28.
- The weekly review ledger → §29.

**Shell and tool pitfalls (each cost an hour in practice):**

- **`jq` treats `0` as truthy.** A boolean check on a numeric field can invert. Test explicitly (`if .x > 0`).
- **`${!VAR}` with an empty name is an error.** Indirect expansion needs a non-empty name.
- **`awk` model-id extraction must stop at a delimiter.** A pattern that reads to end-of-line eats suffixes and trailing fields.
- **Stub servers must be threaded.** A single-threaded stub handles one request and hangs on the second.
- **`stat -c` is GNU; macOS uses `stat -f`.** Scripts that check inode or mtime for write-detection need the right flag per platform.
- **`set -e` does not catch a non-zero exit inside a condition.** A drift check that expects a `diff` to exit 1 on difference must handle it explicitly.
- **`set -e` does not cover process substitution.** A failed `ssh` inside `<(…)` reads as empty output. Stage remote output to a file and check the exit code explicitly (§8.2).
- **`curl -f` collapses every 4xx/5xx into one exit code.** A 429, a 403, and a generic 5xx become indistinguishable. Read the status with `-w '%{http_code}'` when the caller needs to distinguish them; drop `-f` (§3.11).
- **`open("{{hermes_home}}/config.yaml")` in Python resolves the path from the environment or runtime home; using a literal `~` does not expand.** Use `os.path.expanduser()` or `Path.home()` with the resolved `HERMES_HOME`.
- **A `find . -type f` walk inside a versioned directory includes `.git/`.** Exclude `./.git/*` in hash manifests.
- **`mktemp` not fixed `/tmp/name`.** Two concurrent runs overwrite each other; predictable names are a hijack target.

---

## §16 — Open questions

Fill in per deployment. Each is a fact or a choice a deployment must supply.

**Provider and credential facts**

1. Do free and paid use the same key on this box? (If yes, an auth failure takes out both.)
2. Does a second provider or a second key exist? (An independent API route is the escalation target under §4.9.)
3. Is there a paid cap on this box? Where? (A local ledger, or a provider-side credit limit.)
4. Env file duplicates? Which entry wins on this box's loader?
5. Fallback list contains local endpoints? Where in the chain?

**Scheduling and quota**

6. Free-tier reset time (from a confirmed header)?
7. Which limit does the rate-limit reset header describe — daily, or per-minute? (§4.13a.)
8. Is the provider's quota model a fixed daily reset or a rolling window? (§4.13b.)
9. Does the selector's schedule meet the maximum-delay-after-reset rule? Name the cron timezone.
10. Does the selector's schedule prevent overlapping invocations of the same job? What is the current tick duration? (§27.8.)

**Selector and policy**

11. Which scheduled jobs are CLOBBER / SAFETY / NEUTRAL?
12. Which selector owns `{{model_default}}`? Are all others paused?
13. What is the current free-tier reserve, and is the selector honoring it?
14. Does the selector log show only material changes, or churn?
15. Does the active selector read the rate-limit header for the recovery instant, or compute a fallback?
16. Does the active selector refresh the paid-fallback field, or only the main default?
17. What are the hysteresis values in use — free-return healthy-reads, dwell, writes-per-hour cap? (§4.13.)

**Auxiliary chains**

18. Blocking/non-blocking auxiliary work enumerated?
19. Does every tool the selector shells out to exist on this box (and on any box it is cloned to)?
20. Does any auxiliary chain head at a local entry, and is it blocking or non-blocking? (§4.15.)
21. Does the runtime walk one `fallback_providers` list for both main and auxiliary traffic, or separate lists per role? (§6.3a.)

**Runtime facts**

22. Does the runtime support `--once`, `--session`, `--global` on this build? What is the plain form's default? (§2.6, §10.19.)
23. Does the runtime support explicit work-type flags? Check the parser, not `--help`. (§4.17.)
24. Does the runtime fall through on timeout, or does the turn wait for the full local latency? (§10.28.)
25. Does `temp-override.json` exist in `{{hermes_home}}` on this box, and does the running build read it at startup? (§1.4.)
26. Does the runtime expose a session-scoped lever the selector can reach? (§5.8.)
27. Does the runtime expose plan or todo state to the selector? (§5.1's S2 signal depends on it.)
28. Does the runtime expose per-turn tool-call counts to the selector? (§5.1's S4 signal depends on it.)

**Alert and observability**

29. Alert delivery target — does it resolve? Was the last delivery a **success**, not just an attempt?
30. If `gateway_state.json` claims a connection, does the channel list confirm it? (§10.12.)
31. Do staleness or review-by lines have a delivery target, or are they advisory log lines?
32. What does the streaming-stale log line actually record? (§3.9.)

**Local tier**

33. Does this box have a local tier? If so, is it host-local or peer-hosted? (§6.4a.)
34. Do the local inference ports bind to loopback or the tailnet interface only? Is there an ACL? Is auth on for web UIs? (§3.34, §26.10.)
35. Which chain entries on this box are hosted on another box? (§6.4a.)
36. Does the local-inventory state file exist, and is it fresh? (§26, §10.31.)

**Versioned artifacts and setup**

37. Is the running selector under version control anywhere?
38. Does the tier table get checked against the live catalog, and does drift trigger a review?
39. Is the running config's key set identical to the guide's registry keys? (§8.2.)
40. Does the box have a hand-maintained `family_purpose` map? Where? (§4.16.)

**Design parameters**

41. What are the fail-closed escalation thresholds — N ticks, T minutes, M ticks? (§4.9.)
42. What are the global-signal thresholds — k distinct sessions, window, baseline rate? (§5.8.)
43. What is the maximum acceptable delay after reset? (§4.13b.)
44. What is the "loud" verification window? (§0.6.)
45. What are the probe per-hour cap and idle window? (§7.2.)
46. What are the alert and ledger staleness multipliers? (§29.5.)
47. How long should a manual override pause the selector — the default 4 hours, or another value in the 4–6 hour range? (§4.14a.)
48. Which limits does the provider expose, and what is their structure — counter, window type, reset source, scope? (§4.9a-bis.)

**Checking these answers.** Each question maps to a §10 check or a §12 record row. A question with no answer after a §10 run is a CANNOT-OBSERVE for that row — not an omission.

---

## §17 — Failure patterns this guide addresses

The list below names the **patterns** the rules exist to prevent. The incident history — deployments, dates, evidence — is in Part III (Record).

**Configuration and identity**

- A hardcoded paid default.
- Stale free-model preferences.
- A shared config file with no coordination.
- Two writers racing on one config.
- A writer that set the default before the provider, one crash away from a mismatch.

**Detection and observation**

- A muted alert path that runs detection and discards verdicts.
- A validator whose tests validated its own assumptions.
- A metric that could never match by construction.
- A source reading treated as proof of behavior.
- An observer that measured a different quantity than the one failing.
- A state file that claimed a connection the jobs did not have.
- A check that could not observe the fact it claimed to test.
- A check that read nothing and reported "no drift."
- A check that returned PASS on an absent value.
- A probe too small to reach the answer.

**Action and application**

- A decision made correctly that never applied.
- A selector that made correct decisions and could not act on any of them.
- A capability the runtime did not expose, assumed present.
- A tool that could not start, producing the symptoms of a tool that ran and chose wrong.

**Scheduling and cadence**

- A free-tier daily quota that silently hung sessions.
- A session parked on the last requests of the daily budget.
- A schedule that "divided" the reset but missed the window.
- A quota counter read at a reset boundary, stale, printing a wrong reset date.

**Failure-domain violations**

- Agents asked to fix the failures they were themselves experiencing.
- A stuck session prompted to unstick itself.
- A probe that drove a fallback it was meant to prevent.
- An escalation to local under failure, defeating the "local is never the main default" rule.

**Portability and consistency**

- A clone that lacked a tool the source box installed.
- Cross-box drift mistaken for parity.
- A rule applied on one box and not the other.
- A cross-box dependency unrecorded, so a peer's outage took a box's local tier with no warning.

**Documentation and process**

- A runbook step that used a CLI flag the box did not accept.
- A runbook step that used a CLI verb without checking it existed.
- A validator labeled "built" when it had never existed.
- A writer check narrowed to cron only, mislabeled as general.
- A changelog entry for rules that did not exist.
- Chat residue and part boundaries left in an operator's document.
- A rule stated twice with different wording.

**Design principles (intent, not enforcement)**

- Fail loud — and loud means delivered, not logged.
- Verify the test as well as the thing being tested.
- Verify the command exists before writing it into a runbook — and from the surface that can observe it.
- Never hardcode what can be discovered.
- Never route a decision through the failure domain.
- Measure without consuming the budget you protect.
- Match tooling to hardware: local is auxiliary.
- An automatic switch fixes the next session, not the stuck one.
- Validate the candidate, not the current file.
- Test isolation is not optional when the test could write to production.
- Verify the alert path before building anything that depends on it.
- A validator tested against its own assumptions validates nothing.
- Source-verified is not live-run-verified.
- Drift is the default between "identical" boxes.
- Spend the daily budget with a reserve; the last request is not free.
- Rewrite the config only when the choice changes.
- Rank by preference, filter by output modality, detect free by price and live membership.
- Write the recovery instant from the confirmed header.
- Exactly one writer owns each artifact.
- A wildcard bind is not proof of exposure.
- Name the scope of a `/model` command explicitly.
- A capability the catalog does not expose is a heuristic, and heuristics are advisory.
- Probe, then state.
- Size the probe to the question.
- A flag's meaning belongs to its surface, not its spelling.
- A refresh that disagrees with a curated list appends and reports; it never deletes.
- Line the schedule up with the reset, and verify the reset instant first.
- Do not call an artifact durable until you have named what prunes it.
- A shared budget cannot be protected by a per-session reserve.
- Blocked is a decision, not unfinished work.
- A tool that cannot start produces the symptoms of a tool that ran and chose wrong.
- Size a probe to the model class.
- A secret on a command line is public.
- A check that passes on an absent value reports health it did not measure.
- A check that cannot read its inputs reports a match it never made.
- Fail closed only to a tier that doesn't share the failed dependency.
- "Loud" is delivered-and-verified, not logged.
- One session's signal acts on that session, or it is advisory.
- A peer-hosted local entry is not an independent API route.

---

## §18 — Glossary

| Term | Meaning |
|---|---|
| **Box** | One Hermes deployment. |
| **Selector** | The component that reads the model catalog and writes the model choice. |
| **Tick** | One scheduled run of the selector. |
| **Owner** | The single component authorized to write a given artifact (invariants 21, 39). |
| **Ladder** | The ordered list of models the selector considers. |
| **Hot path** | The code executed inside a user prompt; does no I/O (box-owned code; §27.2). |
| **Tick path** | The code executed on the selector's schedule; does the network work. |
| **Event path** | The code executed on a material change; writes config. |
| **Observed** | Checked directly. Scope and evidence recorded. |
| **Hypothesis** | Candidate explanation, not reproduced. |
| **Reported** | From an agent session. Not verified. |
| **Proposed** | Design intent. Not running. |
| **Blocked** | A decision, not unfinished work. File with both sides and the options. |
| **Unverified** | Asserted without a check. |
| **Source-verified** | Code path confirmed by reading source. Not run. |
| **Live-run-verified** | Command has been executed and the outcome observed. |
| **CANNOT-OBSERVE** | A check result: the check ran but could not reach the fact. Distinct from PASS and FAIL. |
| **Applicability** | Whether a rule binds on this box: `applicable`, `not-applicable` (capability absent or policy excludes it), or `unknown`. Separate from the check result (§0.6). |
| **Capability** | A fact about the box a rule depends on (free tier, paid tier, local models, alert destination, …): `present`, `absent`, or `unknown`. |
| **N/A** | Shorthand for applicability `not-applicable`. Not a check result. |
| **Candidate validation** | Checking the file a writer intends to save. Requires writer support. |
| **TTFB** | Time to first byte. |
| **p50 / p95** | Percentiles of a rolling window. |
| **Sustained** | Multiple consecutive outliers in a window. |
| **Cooldown** | Minimum interval between switches. |
| **Recent failures** | Models that failed within a TTL. |
| **Passive probe** | Sample from real logs. Zero quota. |
| **Active probe** | Synthetic request. Consumes quota. |
| **Probe budget** | The timeout and max-tokens for a given model class. Per-model, not fixed. |
| **Probe verdict** | The outcome when a probe expires before the model answers. A fact about the probe, not the model. |
| **Client stuck** | Probe fast, session hangs. Not the model. |
| **Main ladder** | API-only tier list. |
| **Blocking auxiliary** | Auxiliary running inside the user turn. |
| **Non-blocking auxiliary** | Background; failure contained. |
| **Local provider** | Self-hosted. Auxiliary-only, or excluded. |
| **Tail entry** | A `fallback_providers` entry after the API head. Non-blocking aux only (§6.3a). |
| **Cross-box dependency** | A chain entry on one box hosted on another. Recorded on both sides (§6.4a). |
| **Independent API route** | A second provider or a second key — a route that does not share the failed dependency. Local is not an independent API route (§4.9). |
| **Loud** | Delivered to an external destination a human watches, verified within `{{loud_verification_window}}`, repeating until acknowledged. Logging is "recorded," not "loud." |
| **Mute alert path** | Delivery target resolving to nothing. |
| **Half-wired alert path** | A state file claims a connection the jobs do not have. |
| **Stuck session** | A running session whose in-memory model is bad. Needs a scoped `/model` or restart. |
| **Cron writer** | A scheduled job that writes the config file. |
| **CLOBBER job** | A job that moves the default toward paid or a specific tier. |
| **SAFETY job** | A job that moves the default toward free or cheap. |
| **Reserve** | Free requests held back from the daily budget to avoid a mid-turn 429. Sized per-session, not per-turn. |
| **Provisional reserve** | A reserve computed from fewer than the minimum sample of sessions. |
| **Sample floor** | The minimum number of sessions before the reserve is measured rather than provisional. Recommended **59**: at that size the largest observed draw is at or above the true p95 with 95% confidence (0.95⁵⁹ < 0.05). Not the rule of three, which is a different bound. |
| **Shadow price** | The extra cost of a paid tick taken near the reserve, when it draws down the buffer that protects the main session (§4.13). |
| **Material change** | The chosen model differs from what is saved. Gate for config write. |
| **Atomic pair** | Writing two config keys as one staged file, renamed once, under the lock. |
| **Recovery instant** | The timestamp when the daily budget resets, from the confirmed daily-limit header (§4.13a). |
| **Mid-session escape** | Runtime behavior: a running session whose primary 429s swaps to the fallback chain's head. |
| **Post-hop verification** | A separate check that confirms the switcher's intent matched reality. |
| **Reserve band** | The range `remaining ≤ {{reserve}}`. Default belongs on the paid tier inside this band. |
| **Scoped override** | A `/model` command with `--once`, `--session`, or `--global`. Controls how far the switch reaches. |
| **Work type** | text (default) / image / video / audio / reasoning / code. |
| **`family_purpose` map** | A hand-maintained mapping from model family to intended purpose. |
| **`reasoning` field** | A structural catalog field indicating reasoning capability and supported effort levels. Filter by presence + desired effort, not by `mandatory`. |
| **Heuristic classifier** | An advisory hint. Logs a suggestion; routes nothing unless explicitly enabled. |
| **Ritual check** | A verification step that cannot observe the fact it claims to test (Class 6). |
| **Read error masked as no-drift** | A drift check whose failed read produces the same output as a matching comparison. |
| **Dependency drift** | A clone that inherits config but not packages. |
| **Tier-table drift** | The tier table and the live catalog diverge. |
| **Token discipline** | Reading a value at zero cost when the runtime allows, probing only when necessary. |
| **Silent actor** | A correct decision that never applied because the component could not act (Class 8). |
| **Secrets hygiene** | A credential reaches its consumer through the environment or a mode-600 file, never argv; tests print a hash or a length. |
| **θ** | The fraction of a chain's calls on the user-turn critical path (§4.18). |
| **Rule of three** | With n sampled turns and no observed blocking, the 95% upper bound on θ is ≈ 3/n. |
| **Signal scope** | One session's struggle signal cannot change the global default (§5.8). |
| **Fail-closed escalation** | After N ticks on paid because of failure, alert; after M, hold and repeat the alert (never switch to local) (§4.9). |
| **Watchdog** | A monitor outside the tick that checks the tick's heartbeat. |
| **Local inventory** | The dynamic state file that records which local cards are reachable, read by the ladder (§26). |
| **Reconciler** | The process that probes the local cards and writes the local inventory (§26). |
| **Allowlist** | The operator-owned list of card node ids the reconciler is permitted to probe (§26.7). |
| **Hot-path discipline** | The invariant that the prompt path performs no I/O, no network calls, no config parsing, and no rule evaluation (§27). |
| **Blocked-network test** | A test that runs the prompt path with network, tailnet, probe, and file-write modules disabled (§27.3). |
| **Import-boundary lint** | A build-time check that fails if a hot-path module imports a probe, discovery, budget-writer, or alert module (§27.4). |
| **Rule tier** | One of Cheap / Medium / Expensive, classifying when a rule may consult (§28.3). |
| **Run ledger** | An append-only JSONL file with one record per selector run, for the weekly review (§29). |
| **Heartbeat** | The current-state file, overwritten each run (`alerts.json`) (§29.1). |
| **Foreign write** | A change to the saved default that matches neither the selector's last write nor its current choice (§4.14). |
| **Manual-override pause** | The state the selector enters after a foreign write: no writes until the window expires, an explicit resume, or — for a hold — only an explicit resume (§4.14a). |

---

## §19 — Failure Domain Isolation

The principle: **an agent may never be asked to fix the failure mode it is currently experiencing.**

Corollaries:

- Failover must live outside the failure domain.
- Liveness probes must live outside the failure domain.
- Measurement must not consume the resource it measures.
- A slow tier cannot diagnose why it is slow.
- A stuck session needs a scoped `/model` or a restart.
- A test that can write to live config must run in isolation.
- Verify delivery, not just delivery config.
- A runbook step that uses an unverified command is inside the failure domain.
- A source reading proves the code path, not the behavior.
- The switcher's own log records intent. Only the post-hop verification records outcome.
- A classifier that is advisory only cannot misroute. A classifier allowed to act is inside the failure domain.
- A check that cannot observe the fact is a ritual, and a ritual is inside the failure domain.
- A detector that pages through the channel it watches has nowhere to report when that channel is down. A watchdog delivers to a different target.
- A probe whose budget expires before the model can answer is inside the failure domain of the model it is probing.
- A check that passes on an absent value is inside the failure domain of the fact it checks.
- A drift check that cannot read its inputs is inside the failure domain of the drift it watches.
- A tool that cannot start is inside the failure domain of the work it was meant to do.
- A "loud" rule that writes to a log file is inside the failure domain of the alert path it claims to use.
- A quota-read failure path that fails closed to paid is inside the failure domain of the failure it is responding to, unless the target tier does not share the failure.
- A signal that changes the global default from one session is inside the failure domain of that session, because the change does not reach it.
- A check that reports PASS when it should report CANNOT-OBSERVE is inside the failure domain of the check itself.
- An escalation that routes the main session to local under failure is inside the failure domain of the outage, because local is exactly what the failure domain contains.
- A drift check that treats a failed read as a match is inside the failure domain of the drift it is meant to detect.
- A local-inventory reconciler that reads the tailnet on the hot path puts the network inside the prompt's failure domain.

---

## §26 — Local inventory (dynamic)

The local cards are on a tailnet. Peers come and go, names change (a card renamed at the DNS level keeps its address), models change, and the tailnet drops. Static config names peers by name; when a peer renames, the name goes stale and the chains silently fail — a Class 8 shape. The local inventory keeps the ladder current without a human editing config on every reboot.

### 26.1 The design

**A separate state file, read by the ladder. No network in the routing path.**

- **The reconciler** — the single owner of the state file — runs each tick. It reads the tailnet backend state, probes each allowlisted peer, reads each peer's model list, and writes `{{local_inventory_file}}` through stage-and-rename (§4.14).
- **The state file** carries a version field, a heartbeat, the resolved set, and observed attributes (hostname, IP, model list). The ladder reads only that file; it makes no network calls.
- **The reconciler owns the state file.** If it runs inline in the selector, the same process owns both the state file and `{{model_default}}`. If it runs as its own job, the owner rule is per artifact — one owner per file, not one owner per box.

### 26.2 Card identity

Stable node id (the tailnet's node id, if the installed version exposes it) is the identity key. Survives reboot, rename, DHCP change. Hostname and IP are observed attributes only, never keys. The role label (`{{card-1}}`, `{{card-2}}`, `{{card-3}}`) is the only local name in `{{config_path}}`.

**Fact to confirm:** does the installed tailnet client expose a stable node id? If not, the allowlist becomes role → observed-attributes-with-history and the operator's edit is on any change, not just hardware swap.

### 26.3 Three failure modes

- **Tailnet down** — every peer fails at once; the local tailnet backend reports itself not running or not connected. Check the backend first. Drop all locals from this tick; leave `{{config_path}}` untouched.
- **Specific peer offline** — backend healthy; the peer is listed but unreachable while others succeed. Remove from this tick's resolved set; keep the entry in inventory; retry on cooldown.
- **Peer renamed or moved** — stable node id present; hostname or IP differs. Update observed attributes in the state file; log a rename; change nothing in config (the ladder resolves by role). If the node id is absent and only the name matches, treat as unknown — do not bind a new machine to an old role.

### 26.4 Discovery failure

**Fail closed on locals. Keep the main session untouched.** Discovery fails (tailnet unreachable, probe timeout, tool missing) → drop locals for the tick; write nothing to `{{config_path}}`. **Do not use last-known-good for routing** — a card that renamed or went offline since the last good read would cause silent misroutes. Last-known-good stays in the state file with a timestamp, for display only. Raise an alert after a set number of consecutive failures.

### 26.5 Stability guards

Four guards, stacked:

- **Cooldown** — minimum time between applied inventory changes.
- **Hysteresis** — N consecutive probes to enter the resolved set; M consecutive failures to leave.
- **Sample count** — how many probes the hysteresis window needs.
- **Minimum dwell** — a newly admitted peer stays out of batch work until it has been up for a set period.

Rewrite the state file every tick (stage-and-rename) so its heartbeat stays fresh; change the **resolved set** only on a material change that has passed the stability guards. The material-change gate (invariant 18) governs the resolved set and the config, not the heartbeat. Specific numbers are per-box values (`{{local_inventory_cooldown}}`, `{{local_inventory_hysteresis_up}}`, `{{local_inventory_hysteresis_down}}`, `{{local_inventory_dwell}}`).

### 26.6 State-file schema

The file is the contract between reconciler and ladder. It carries a version field, a heartbeat timestamp, the resolved set, observed attributes, and a schema check at read time that fails loud if the version or a required key is missing. The ladder does not proceed with a malformed file. A stale heartbeat means the reconciler is not running: the ladder treats the resolved set as unknown and uses no local entries. Same shape as the alerts heartbeat (§29.5).

### 26.7 Operator curation

Resolve against a hand-maintained allowlist of stable node ids. Auto-discovery reports unknown peers; it does not add them. Full self-population is less safe: any node matching a name or tag pattern would receive aux prompts — which can contain user content — from an unapproved device. The allowlist costs one edit on hardware swap; it costs nothing on reboot or rename. Model lists on an allowlisted peer can be discovered automatically.

### 26.8 Stated limitation

The allowlist is itself a hand-maintained map. A replaced card gets a new node id, so the operator must edit config on every hardware swap. **The design removes the reboot-and-rename edits; it does not remove the hardware-swap edit.** Runbook step: *when you replace a card, update the allowlist with the new node id.*

### 26.10 Inference-port access control

**Local inference ports bind to loopback or the tailnet interface only, have a tailnet ACL allowing only named devices, and require authentication on web UIs; a check that cannot observe the refusal reports CANNOT-OBSERVE.**

Ollama-style inference ports and dashboards have no authentication by default. A tailnet is not a trust boundary: any device on it can use the cards. Give inference ports explicit access control:

- Bind to loopback or the tailnet interface only.
- Add a tailnet ACL that allows only named devices on those ports.
- Turn authentication on for web UIs; turn signup off.
- For an inference server with no built-in authentication, the ACL is its only boundary; record that as a deliberate choice, or put a token-requiring reverse proxy in front.

**Check:** connect from a tailnet device that isn't allowed and expect a refusal. If no such test device exists, the result is CANNOT-OBSERVE, not PASS.

---

## §27 — Hot-path discipline

The rule that keeps the design from bloating as rules are added.

### 27.1 The invariant

**The prompt path performs no I/O, no network calls, no config parsing, and no rule evaluation.** It reads one precomputed decision record that the tick or an event has already written.

### 27.2 Scope

**This rule applies to box-owned code.** The prompt path in the runtime itself is not box-owned; the box cannot edit it. For the runtime, the hot-path invariant becomes a black-box test and a re-check on upgrade (§27.5).

### 27.3 Enforcement, for box-owned code

Two required tests:

1. **Blocked-network prompt test.** Run the prompt path with network, tailnet, probe, and file-write modules disabled. It must produce a routing decision from the state file alone.
2. **Import-boundary lint.** Fails if any hot-path module imports a probe, discovery, budget-writer, or alert module. A new hot-path rule requires editing the lint allowlist — a visible review event.

### 27.4 Proportional response

Frame: cost tracks the cost of a wrong decision AND how long the error would stay hidden.

| Tier | Cadence | Reversible? | May consult | Requires |
|---|---|---|---|---|
| **Cheap** | per-prompt | reversible | state file + in-memory config snapshot | nothing |
| **Medium** | per-tick | recoverable next tick | tailnet state, probes within budget, quota ledgers, allowlist | nothing beyond the tick budget |
| **Expensive** | event-driven | hard to undo | everything | log-before-act AND (user confirmation OR cooldown) |

"Expensive" covers config writes, paid-budget spend, session escalation to paid, pausing another job. Every rule declares its tier.

### 27.5 Rule placement

| Rule | Tier | Why |
|---|---|---|
| Ladder selection | **Cheap** | lookup in a precomputed ordered list |
| Capability floor check | **Medium** | static map; filtering applied when ladder is written |
| Frustration signal detection | **Expensive** | analyzes a completed turn; runs after, never delays |
| Quota check | **Medium** | tick writes a cached flag; hot path reads it; stale → hold current tier, alert |
| Probe budget selection | **Medium** | depends on probe history and reserve state |
| Local inventory resolution | **Medium** | depends on tailnet probes and stability guards |
| Alert heartbeat write | **Medium** | written each run as a fixed heartbeat |
| Override handling | **event for application, hot for lookup** | user command writes once; prompt reads |

### 27.6 Enforcement, for runtime code the box does not own

- **Black-box test.** Block the quota endpoint and stop the selector; confirm prompts still succeed within normal latency. Re-run on every runtime upgrade; record the result as "observed at runtime version X."
- **Limit to config-level controls.** Anything that needs a runtime edit goes on an upstream request list, not into an invariant.
- **No claim of enforcement the box cannot make.** If the runtime's prompt path does I/O, the box cannot change that; it can only observe it and report.

### 27.7 The two failure modes

- **Hot path — I/O creep.** One more file read or endpoint call per prompt; looks harmless in one test; shows as latency under load. Guard: blocked-network test + per-prompt counter of file reads and network calls (fails above zero).
- **Tick path — overrun and overlap.** Tick exceeds its schedule period, or two ticks run at once and one reads a half-written state file. Guards: lockfile with a timeout; tick duration budget below the schedule period; atomic stage-and-rename for every state write; heartbeat staleness rule catching a stopped tick.

### 27.8 Facts to gather per box

1. Does the box's cron runner prevent overlapping invocations of the same job?
2. What is the current tick duration? The tick budget must be below the schedule period.

---

## §28 — Parameter structure

Which knobs are optimization problems, which are judgments, what to measure.

### 28.1 The category sort

Every tunable parameter falls into one of three categories:

**(a) Optimization problem** — well-posed given measurable inputs:
- Free-tier reserve, conditional on a chosen risk level ε.
- Stability guards (cooldown, hysteresis, sample count, dwell).

**(b) Judgment call** — math structures but cannot resolve:
- Aux-chain head choice (the §4.18 inequality structures it; the human sets θ).
- Free-tier reserve's tolerated shortfall probability ε.
- Capability floor class boundaries.
- The Pareto point on the stability-guard front.
- The Pareto point on the aux-chain cost/latency front.

**(c) Convention** — no mathematical content:
- Class labels (S, M, L), rule names, field names, `/stronger` as slash command vs box script.

Category (c) items are resolved by choice, not by math. Pick one, apply to both boxes, move on.

### 28.2 Objective functions and required inputs

**Free-tier reserve.** Objective: minimize P(main-session starvation) + λ·E(aux paid spend), or equivalently keep P(remaining < main-session demand over the recovery window) ≤ ε. Inputs: main-session draw distribution, aux draw rate, quota reset schedule. Measure: per-session draws (not per-turn; §4.13), reset timing. λ and ε are judgment inputs.

**Stability guards.** Objective: minimize flap rate + λ·time-to-detect a real change over N, M, sample count, cooldown, dwell. Inputs: each peer's probe success/failure process, its autocorrelation, the probe interval. Measure: probe history per peer. The Pareto front runs between flap rate and detection delay.

**Capability floor.** Procedure: label a small held-out task set per work type; measure success rate per class; set each floor where misclassification cost (weighted by the asymmetry between a too-weak answer and a wasted paid call) is lowest. Evidence: the per-class success table. Not automatically optimized.

### 28.3 What to measure to move a parameter from (b) to (a)

| Parameter | Move to (a) by measuring |
|---|---|
| Aux-chain head | θ per chain (§4.15); or confirm blocking status by live trace |
| Reserve floor | main-session draw distribution, aux draw rate, reset timing |
| Stability guards | per-peer probe success/failure process and autocorrelation |
| Capability floor | per-class success table on a labeled held-out set |
| Paid-tick cost c | include shadow price near reserve (§4.13) |

Until measured, these are judgment inputs, not optimized values.

---

## §29 — Weekly review ledger

The lightest artifact for a 1–2 week review. Written by the selector on every run, read on demand at review time. No new service, no dashboard.

### 29.1 The shape

Two files, not one:

- **Heartbeat** (`{{alert_file}}`) — current-state snapshot, overwritten every run. Shows the design is running now.
- **Run ledger** (`{{ledger_file}}`) — append-only JSONL, one small fixed record per run. The trend record. Survives a corrupted heartbeat because it is separate.

Both written in the same run, with the same stage-and-rename or append discipline. The return review is a read-only summary over the two, run on demand.

**Single-writer rule.** The heartbeat and the ledger each have a single owner (invariant 39). The selector that runs the tick is the owner; where a separate job writes them, that job is the owner.

### 29.2 Minimum signal set

- **Heartbeat freshness** — age of `last_run_ts` against the schedule period. Shows whether the selector runs at all.
- **Exit-code distribution** — counts per day. Shows whether runs succeed, fail, or refuse (Class 8).
- **Active alerts with first-seen time** — each alert's code and how long it has persisted. Long-lived alerts show drift a snapshot hides.
- **Main-session model versus intended default** — a mismatch means a switch or override did not revert. *(Depends on the runtime exposing the active model per session; if not, the field is not populated.)*
- **Minimum free-budget headroom over the window** — the lowest `remaining − reserve`. Shows whether the reserve is holding.
- **Paid aux ticks per day** — count of paid calls from non-blocking chains. *(Depends on the cron ledger or state DB recording per-call provider and tier; if not, the field is not populated.)*
- **Tick duration and overlap count** — time per run, any run starting while another was active.
- **Local resolved count against allowlist size** — how many allowlisted cards resolved. A falling count shows a tailnet or peer problem before any user sees it. **When the box has no local tier, the field reads `not-applicable`, not `0/0`.**
- **Last successful alert delivery timestamp** — most direct check on whether alerts reach the operator.

### 29.3 Cadence

Write the ledger line on every run. Roll up daily only at review time, not as a separate job. A per-run cadence misses nothing the selector sees but cannot show anything between runs (a peer that flapped between two ticks). File growth handled by weekly rotation.

### 29.4 What "good" looks like at 1–2 weeks

- **Clean:** `heartbeat_age=4m period=10m exit=0 main_model=match alerts=0 headroom_min=+38 paid_aux_per_day=0 tick_p95=52s delivery_last=ok[ts]`
- **Drifting:** `heartbeat_age=4m exit=0 main_model=mismatch(3 days) alerts=1 (reserve_low, first_seen=9d) headroom_min=+2 paid_aux_per_day=140 tick_p95=410s overlaps=6`
- **Broken:** `heartbeat_age=3h (period=10m) exit=timeout last_ok_run=9d ago alerts=STALE delivery_last=none local_resolved=0/4 paid_aux_per_day=unknown`

### 29.5 Staleness rule

The staleness threshold is a multiple of the producer's schedule period (`{{ledger_staleness_multiplier}}` for the ledger; `{{alert_staleness_multiplier}}` for the heartbeat). If the heartbeat is older than the threshold, the display shows `STALE: producer silent since «ts»` and treats earlier alerts as unknown, never as cleared. A stale file never shows "all clear." A missing or unparsable file prints "unreadable" — never silence.




---

## PART II — RUNBOOK

The checks are in §10. This part adds the scripts §10 references. Run each against a test config before trusting it on a live box.

### R.1 Drift check

Full script in §8.2. Exit codes: 0 match, 1 drift, 2 cannot-observe. Run on a schedule from one box, comparing to the other. On a single-box deployment, use R.2.

### R.2 Single-box hash manifest

Full script in §8.4. Exit codes: 0 match, 1 drift, 2 cannot-observe. Records a known-good state; compares on each run. Hashes the config's top-level key set, not its bytes, so a legitimate model switch does not show as drift.

### R.3 Health probe with per-model budgets

Sketched in §7.2. Key properties:

- Reads `{{probe_budget_file}}`.
- Class resolution structural first (the runtime's `reasoning` field), then per-id, then a conservative default.
- Asserts on the answer field, not on HTTP status.
- Records the budget that succeeded.
- Re-runs at a larger budget on `finish_reason: length` with an empty answer.

### R.4 Write helper

The atomic-pair procedure from §4.14 as an ordered list of operations. Every step checked; a failure at any step exits non-zero and leaves the config untouched. Prefer the sanctioned switch path (§2.1) where it exists; the atomic-pair procedure is what to do when the sanctioned path is unavailable or cannot produce the write the deployment needs.

### R.5 Local-inventory reconciler

Runs on the tick. Reads the tailnet backend state, probes each allowlisted peer, writes `{{local_inventory_file}}` via stage-and-rename. Fails closed on discovery failure. Reads the allowlist from `{{allowlist_file}}`. See §26.

### R.6 Weekly review reader

Reads the heartbeat and the run ledger (§29) and prints the clean/drifting/broken summary from §29.4. Read-only; no network, no selector run.

### R.7 Alert writer and reader

The selector's alert writer and the login-MOTD / TUI reader (Record 3 #10, which names the design). Same shape as the heartbeat file: `last_run_ts`, `producer_id`, `exit_code`, active alerts with `first_seen` and `last_seen`. Staleness rule at `{{alert_staleness_multiplier}}`× the producer's schedule period.

### R.8 Hot-path checker

Box-owned prompt path: run the blocked-network test and the import-boundary lint (§27.3). Runtime-owned prompt path: run the black-box test (§27.6). No claim of enforcement the box cannot make.

---

## PART III — RECORD

History. Changes rarely. Records what happened, why the rules exist, and what the reference deployments observed. A forker reads Part I and edits the registry; Part III is context.

### Record 1 — Reference-deployment findings

Observed on a reference deployment by the agent that produced the original guide. Each finding names its evidence.

| ID | Finding | Evidence | Status |
|---|---|---|---|
| F1 | The selector was dead and only the log knew: repeated `FATAL: <interpreter> not installed`, a missing dependency the source box had. | Job log; source manifest vs installed packages. | Fixed: dependency vendored with a SHA-256 check; scripts set their own PATH. |
| F2 | The alert path was mute: every scheduled job delivered to an unconfigured target. Detectors ran; verdicts discarded. | Delivery config; job ledger. | Path restored on the reference box; the state file may still assert a connection the jobs do not have on some deployments. |
| F3 | The `.env` first entry was a shipped placeholder; a first-wins loader would 401 every call. | `.env` read. | Placeholder commented out; inline config placeholder flagged. |
| F4 | The scoped-`/model` verification could never pass — it tested a surface that cannot expose the flags. | Source read; live probe. | Promoted to Class 6; the TUI round-trip is named as outstanding. |
| F5 | Capabilities the guide names did not exist in the code on that deployment: work-type routing, heuristic classifier, `family_purpose` map, reasoning-field filter. | Source read. | Listed as PROPOSED where the code lacks them. |
| F6 | The selector scripts were not under version control. | `git rev-parse` returned false. | Fixed: a local git repo was initialized. |
| F7 | Dry-run isolation was partial: the catalog read could be pinned to a fixture; the quota read always hit the live endpoint. | Source read. | Recorded as a limitation; a dry-run is not full isolation. |
| F8 | A concurrent writer changed four scripts mid-review. | Version-control status. | Changes preserved, not clobbered. |
| F9 | The operator's policy statement and the changes made to honor it. A correction followed: a working alert path would not have surfaced a card-bound session, because no scheduled job asks the session question. | Policy statement; job ledger; session audit. | Promoted as the "wrong observer" cause of Class 3 and §3.12. |
| F10 | The alert path brought up: self-hosted, tailnet-bound, read-only anonymous, token to publish, verified end-to-end, with a watchdog delivering to a different target on purpose. | Delivery verification. | Reference-box only; not evidence for any other box. |

**Every F-row is an observation from the reference box at the date recorded. None is evidence for any other box.** Each deployment runs its own checks (§10) before treating any F-row's condition as present.

### Record 2 — Lineage notes

The rule set in Part I was reached by two independently-built switchers. The rules were reached by different paths and were tested against different deployments.

**Rules reached independently** are treated as stronger evidence: two separate paths arrived at the same rule. Where the two paths diverged and both positions were valid, Part I states the invariant (the rule that must hold on every box) and treats the divergence as a per-box value.

**Rules added in this version** (not in earlier lineages): the failure-class sort for quota-read failures (§4.9); the "loud" definition (§0.6); the signal-scope rule (§5.8); the maximum-delay-after-reset form of the schedule rule (§4.13b); the cross-box dependency rule (§6.4a); the tail-is-non-blocking-aux-only rule (§6.3a); the fail-closed escalation and spend guard (§4.9); the hysteresis and write-cap rule (§4.13); the three-result check convention (§10, invariant 33); the dynamic local inventory (§26); the hot-path discipline (§27); the parameter structure (§4.18, §28); the weekly-review ledger (§29).

**Rules removed or narrowed in this version:** the "provider before default" ordering (replaced by the atomic pair, §4.14); the general stream-stale timeout key (the runtime reads the local variant, §3.2, §10.13); "one fallback list" as a rule (a fact to confirm per deployment, §6.3a, §16 Q21); "typically 2" as the reserve number (the number is per-box, §4.13).

### Record 3 — Decisions made during the merge

Each decision is recorded with its reason.

1. **Write ordering.** Sequential writes in either order are the defect. The rule is the atomic pair: stage both keys, rename once under a lock. Where the writer cannot do an atomic replace, the limitation is stated, not assumed away.
2. **`config set` semantics.** `config set`'s write behavior is unverified; see §16 Q40. §4.14 says the CLI writes in place.
3. **Reserve unit.** Session, not turn. Sized above the p95 single-session draw, with a sample floor of 59 before the p95 is trusted.
4. **Free detection.** Price and live membership (the union). Suffix-only detection misses suffix-less free ids.
5. **Probe timeout.** Per-model class. A fixed timeout is the defect Class 7 names.
6. **Fail-closed route.** By failure class, not by direction. Auth and provider-unreachable do not switch; quota-unreadable and free-model-only faults fail closed to paid. Where no independent API route exists, hold and alert; the provider-side cap is mandatory.
7. **Signal scope.** One session's struggle acts on that session if the runtime exposes a lever the selector can reach; otherwise it is advisory. Global change requires evidence from many sessions.
8. **"Loud."** Delivered to an external destination verified in the recent window, repeating until acknowledged. Logging is "recorded," not "loud."
9. **Local head rule.** Local wins unconditionally for a truly non-blocking chain (θ = 0). Where θ is unknown, the API head is the conservative default.
10. **Alert path.** Deferred as a rule; specified as a design (dead-man switch + MOTD/TUI surfacing). Implementation is per-deployment.
11. **Single-owner enforcement.** Enforced at the writer, not the scheduler. Each selector checks the owner field; a non-owner writes nothing. No script pauses another job.
12. **Router exclusion.** The ladder must not route a router or a guardrail id. The pattern list is per-box.
13. **Parity boundary.** Invariant core (rules that protect the main session and prevent wrong verdicts); capability-gated rules (applied when the hardware or chain is present); per-box values (reserve, model ids, endpoints, cadences).
14. **Dynamic local inventory.** A separate state file, read by the ladder. No network in the routing path. Stable node ids as the identity key.
15. **Hot path discipline.** The prompt path performs no I/O, no network calls, no config parsing, and no rule evaluation. Applies to box-owned code; runtime-owned prompt path is verified by a black-box test.
16. **Parameter structure.** Every parameter is (a) an optimization given measured inputs, (b) a judgment call, or (c) a convention.
17. **Publish form.** Single document with three internal parts, plus a registry.
18. **Escalation target under failure.** An independent API route (a second provider or key). Local is never the escalation target for the main session. Where no independent API route exists, hold current tier, alert, rely on the provider-side cap.

### Record 4 — Earlier versions and what they changed

| Version | Base | Change |
|---|---|---|
| v2.2 | original guide | First reference-deployment record; classes 1–4 and 6–7; the trap-door list; priorities and pitfalls. |
| v2.2.1 | v2.2 | Added Class 8 (silent actor failure); the capability-probe rule with its four instances; the durability rules; the pre-destructive procedure. |
| v3.0 | v2.2.1 + second lineage | Merged the two lineages; added the second lineage's rules (token discipline, atomic-pair write, router/batch/zero-price exclusions, tier-drift detection, write lock, asymmetric unknown-tier defaults). Composed from chat parts and carried known defects. |
| v3.1 | v3.0 | Applied the v3.0 review's 17-item defect list: probe-budget fix, atomic pair, secrets off argv, drift-check fix, timeout check, reserve unit and sample floor, quota-read policy, document cleanups. |
| v3.2 | v3.1 | Applied the v3.1 review's defects, the portability stress test, the publication-readiness list, the parameter structure, the hot-path discipline, the dynamic local inventory, the reconciliation fixes. Sanitized for publication. Introduced a local-escalation contradiction and cited sections (§26–§29) that were not written. |
| v3.2a | v3.2 | Fixed the local-escalation contradiction (escalate to an independent API route, not local); wrote §26–§29; restored the scoping of the hot-path rule and the reachability qualifier of the signal-scope rule; named the authoritative file and hash in the header; restored the box findings, blocked items, and chain disputes to the record; corrected the sample floor to 59; named the owner for every artifact with a single-writer rule; deduplicated the hysteresis rule; converted every §10 check to the three-result convention. |

### Record 5 — Anomalies and open items

Anomalies observed but whose cause was not determined, recorded so a future reader does not treat them as resolved:

- **Missing response files.** At one point during the project, the directory that had held a deployment's earlier response files no longer contained them. No scheduled job touched the path; no session logs an operation there. A reconciliation copy was written as insurance. If it recurs, it is a real problem.
- **Runtime source location.** An earlier search for the runtime source returned "not found" because the search scope was under the home's `installs/` directory; the actual source was outside that path. Future searches should check the runtime's own install path.

**Open items at publication:**

- The TUI round-trip for scoped `/model` — a human types `/model «id» --session` in a live window and confirms the status bar changes while the config does not. Source-verified; not live-run-verified.
- The runtime's fall-through-on-timeout behavior — source-verified on the reference box; confirm on each deployment (§10.28).
- The alert path — deferred. The design is in §29; the implementation is per-deployment.
- The per-chain θ — measured as an overlap bound where the box can; otherwise the conservative default applies (§4.18).
- The `temp-override.json` question — verify on each deployment (§16 question 25).

### Record 6 — Deployment findings from the review rounds

Observed during the review of the running deployments. Names are anonymized to `«box-a»` and `«box-b»`. A prior private deployment record contained findings that informed these rules; it is not part of this repository.

**Dormant chains.** Over a multi-day window on one deployment, several auxiliary chains configured on the box never fired. Only one fired, at a low per-session rate. The aux-head question for the dormant chains is not urgent; the chains that carry traffic are the ones that matter.

**Model-too-slow-to-answer finding.** A probe of local inference cards returned empty answers at a modest token budget. The cards were answering — the probe expired inside the model's thinking block. This is the Class 7 exemplar. A later probe with a correct budget confirmed the model answers, but the total time was longer than the runtime's per-chain timeout. The model, not the head, is the constraint on those chains.

**Alert path half-wired on both deployments.** One deployment's state file claimed a connection the jobs did not have; the other's alert-channel state files were absent entirely. Both are mute at delivery time. This is the finding the invariant-34 rule (loud is verified delivery) exists to catch.

**Alert path status (2026-10-13):** Both reference deployments report half-wired or mute alert paths. Fix tracked per deployment in §12 records.

**Owner field empty on one deployment.** The owner gate was implemented in every writer and inert, because the owner field's value was empty. Three enabled writers were writing the default. The empty value is a defect (invariant 21) and the alert is part of the fix.

**Field-name reconciliation.** The two deployments used different field names for the same concepts — one used `policy.owner`, the other `producer_id`; one used `categories`, the other `preferred_free_models_tags`; both read the local-stream timeout key. The reconciliation is recorded in the deployment's §12. The rule (one field name per concept) is invariant; the specific name is a convention and is recorded as resolved.

### Record 7 — Blocked items

Items that could not be applied at the time of the merge, with the reason.

- **Probe budget — the health sensor did not exist.**
- **Manual /stronger lever — the runtime did not expose a slash-command extension point.**
- **Alert MOTD/TUI wiring — per-box task, not done unasked.**

### Record 8 — Chain disputes

During the merge, the two deployments classified the same set of auxiliary chains differently. One called several of the chains blocking (moved to API heads); the other left them non-blocking (kept local heads). Neither deployment traced the runtime to observe whether a user turn waits on the chain. The conservative default (§4.15) applies: unknown status → API head. Where a deployment has measured θ for a chain (§4.18), it may move that chain off the API head on the measured bound. The dispute is not a defect; it is the honest state of two deployments with different heuristics and no live trace.

---

## §20 — Further work [proposed]

Design directions, not running systems.

### 20.1 Responsiveness probe

Passive-first. Active probes only to fill gaps, with a per-class timeout and a per-hour cap. Status-based signals fire immediately for request-level fallback; config changes require repeated evidence. A probe-generated 429 does not count toward escalation. The per-model budget table (§7.2) is part of this.

### 20.2 Locked writes

If multiple scripts write the config, serialize them through a single lock-guarded wrapper. The lock coordinates only the writers that use it. The lock prevents corruption; it does not prevent a logical race — that is the single-owner rule's job.

### 20.3 Candidate validation

Where the writer supports a target path, stage the proposed config, validate it, then atomic-replace. Writers that cannot produce a candidate file are not protected; state the limitation.

### 20.4 Auxiliary router

Split blocking from non-blocking auxiliary work. Blocking gets API-first with a tight local fallback; non-blocking gets local-first or API-only depending on what the box has. Failure behavior differs by class.

### 20.5 Reserve auto-tuning

Read the observed per-session request count over the last N days. Set the reserve to the largest observed count (§4.13). The sample floor applies; below it, use a conservative fixed reserve and label it provisional. Opt-in. Log the choice and the sample count.

### 20.6 Recovery-instant propagation

When a quota-exhausted run logs the recovery instant, push it to a status file that the next log line can reference. Avoid re-reading a header if it has not changed.

### 20.7 Override lifecycle

Track scoped overrides per session and surface them in status output. A session with an active `--once` or `--session` override should show that fact; a session whose override expires should log the restore.

### 20.8 Classifier accuracy logging

If a classifier is enabled, log both the hint and whether the user acted on it. The hit/miss ratio tells you whether the heuristic is worth keeping.

### 20.9 Work-type routing by explicit flag

If the runtime gains explicit work-type flags, plumb them through to the selector's catalog filter. Until then, work-type routing is by explicit model override or by config.

### 20.10 `family_purpose` map maintenance

The map is authoritative and hand-maintained. Treat it like a guardrail map: small, reviewed, versioned. Log when a code task routes to a model that is not in the map.

### 20.11 Dependency preflight in the selector

Before the first shelled-out call, assert every tool the selector needs exists and exit non-zero with a named cause.

### 20.12 Scripts under version control

Put the scripts directory in a local git repo, with the pre-write backup directory covering config rollback.

### 20.13 Tier-table drift detector

Compare the tier table's families against the live catalog on every run. Log families missing from either side. Trigger a human review on calendar age or on a catalog-fingerprint change.

### 20.14 Session-model watchdog

A scheduled, read-only check that flags any active session bound to a model the policy no longer intends. It is the first observer to ask the session question, and without it no existing monitor will.

### 20.15 Per-class probe-budget table

Maintain a small per-model-class table with the timeout and max-tokens that succeed on a cold start. Built once, updated when a model's behavior changes.

### 20.16 Secrets hygiene linter

A static scan that flags key-shaped strings on command lines, in `--arg` and `-d` arguments, and in output that prints substrings of keys. §10.27 is one form; a linter catches the pattern before the next edit re-introduces it.

### 20.17 Drift-check readability self-test

Before running the drift check against a remote box, verify the check itself can read a file both locally and remotely. If the sentinel read fails on either side, the check exits with CANNOT-OBSERVE, not PASS.

### 20.18 Quota-read failure drill

A scheduled off-hours test that exercises the four failure classes of §4.9 against a stub endpoint and confirms the selector routes each correctly.

### 20.19 Deployment self-report

A `doctor` command that outputs the deployment's actual config, chains, owners, cron jobs, and cross-box dependencies as a machine-readable record. The document says what should be true; the deployment reports what is true. The deployment's §12 record is generated from this.

---

## §21 — Document version

**Version:** 3.3
**Last updated:** 2026-10-15

**Companion artifacts:**

- `{{registry_file}}` — the literal values referenced by `{{...}}` in this guide.
- The runbook scripts (R.1–R.8), each a candidate for the checks directory.
- The deployment's §12 record — per-box state.
- The per-model probe-budget table (`{{probe_budget_file}}`).
- A `family_purpose` map, if code routing matters.

**Not covered by this document:**

- Live verification of your specific CLI verbs. Check the parser and then the behavior.
- Delivery channel configuration. Per-deployment.
- Decisions about which jobs to run. Per-deployment.
- The byte-authoritative text of any specific deployment. Where a deployment's file and this guide disagree, read the deployment's file.

**Golden rule:** Do not trust any handoff, including this guide, without running §10. Before asking any agent to fix anything, check whether the agent is inside the failure it's being asked to fix. Before probing anything, check whether the probe is subject to the failure it's probing for, and whether its budget is sized to the model it is probing. Before setting a default, check both the main default and the fallback list. Before building escalation, verify the alert path delivers. Before writing a command into a runbook, verify the command exists, from a surface that can observe it. Before reasoning about a box's policy, confirm which selector owns the default. Before assuming a capability the catalog does not expose, treat it as a heuristic. Before trusting a check that returned "OK," ask whether it could have returned anything else.

---

## §22 — Redaction checklist

Before publishing a deployment-specific version of this guide, remove or generalize:

- Machine names, hostnames, usernames.
- Scheduled job ids and job names.
- Account-specific quota figures and reset times.
- Credential file line numbers and character counts.
- Process ids.
- Service unit names.
- Bind addresses and ports, or generalize to "loopback-only."
- Internal box names, provider nicknames, hostnames.
- Internal file paths beyond `{{hermes_home}}`.
- Specific model ids that reveal the account's catalog.
- Any specific hash from a script verification.
- The active selector's name and job id.
- The reserve value in use.
- The `family_purpose` map's contents.
- API key variable names and their values.
- The SHA-256 of a key printed by a test — treat it as account-specific.
- The measured probe budget per model.
- The reserve sample count.
- The quota-read failure-mode mix observed on the deployment.
- The drift-check sentinel path or contents.
- Tailnet peer names and MagicDNS names.
- Local-inference card model tags and endpoints.

Replace with generic terms: `«box»`, `«peer»`, `«tailnet-ip»`, `«card-1»`, "a local provider", "a scheduled job", "a chat model", "a reasoning model".

---

## §23 — Reference-deployment record

The F1–F10 findings and their status are in Part III, Record 1. Part I does not repeat them. Where a rule cites an F-row, the citation is a pointer to the origin of the rule, not a claim that the condition exists on your box.

**Every F-row is an observation from the reference box at the date recorded. None is evidence for any other box.** Each deployment runs its own checks (§10) before treating any F-row's condition as present.

---

## §24 — Rule provenance

The rule set is the merge of two independently-built implementations, plus rules that were reached by the reference deployment and by the reviewers. Where two independent paths reached the same rule, that is stronger evidence the rule is correct. Where the paths diverged and both positions were valid, Part I states the invariant and treats the divergence as a per-box value. Where Part I cites §10 for a check, §15 for a pointer, or §18 for a definition, the citation is to the canonical home; the citing section does not restate the rule.

---

## §25 — Closing

The purpose of the rule set is one sentence: **make the switcher's behavior observable, and make every decision reviewable against evidence.**

The failure modes in §0.5 are all variations on a single shape: a decision whose evidence was unavailable to the person who needed it. Class 3's wrong observer, Class 6's ritual check, Class 7's undersized probe, Class 8's silent actor — each is a case where a fact existed but could not be observed by the party making the call. Every rule in Part I is downstream of that.

The counter-rules:

- **Probe, then state.**
- **Read the exit code, not the job state.**
- **Source-verified is not live-run-verified.**
- **Half-implemented is not PROPOSED.**
- **Report what the probe returned and what it could not observe.**
- **A check that cannot observe the fact is a ritual, not a check.**

If a deployment keeps these, the rule set stays honest. If it drops them, it produces a document that looks right and isn't — which is the failure the whole effort exists to prevent.

---

**End of the guide, v3.3.**

---

## Registry — `HERMES-MODEL-SWITCHER.registry.yaml`

Every `{{...}}` in the guide resolves here. Each entry names its purpose and, where it is an operator choice, states the question the operator answers. Fill before deployment.

```yaml
# Hermes Model Switcher registry.
# Every {{...}} in the guide resolves to a key below.
# Where a value is an operator choice, the description names the question.

paths:
  hermes_home:                 # the runtime home directory. Discover from the runtime, not from $HOME.
  scripts_dir:                 # where the selector and helper scripts live
  config_path:                 # the config.yaml the runtime reads
  prefs_path:                  # the preference file
  runtime_dir:                 # the runtime source path (may be outside hermes_home)
  registry_file:               # this file's path
  probe_budget_file:           # per-model probe budget table
  local_inventory_file:        # dynamic local-inventory state
  allowlist_file:              # operator-owned allowlist of card node ids
  state_dir:                   # mode-700 state directory
  alert_file:                  # alerts.json
  ledger_file:                 # append-only run ledger

config_keys:
  model_default:               # e.g. "model.default"
  model_provider:              # e.g. "model.provider"
  stream_stale_timeout:        # logical name for the timeout value
  stream_stale_timeout_key:    # the exact key the runtime reads; usually the local-stream variant
  persist_switch_by_default_key:
  toolsets_key:
  owner_field:                 # the field the owner gate reads; usually "policy.owner"

numbers:
  reserve:
    description: "free requests held back from the daily budget"
    question: "size above the p95 single-session draw; per-box"
  reserve_sample_floor:
    description: "minimum sessions before a p95 is trusted"
    question: "recommended 59: with at least 59 sessions, the largest observed draw is a 95%-confidence upper bound on the p95"
  stream_stale_min:
    description: "lower bound of the working range for the stream-stale timeout"
    question: "typical 120 seconds"
  stream_stale_max:
    description: "upper bound of the working range"
    question: "typical 300 seconds"
  probe_interval:
    description: "how often an active probe fires when idle"
  probe_per_hour_cap:
    description: "maximum active probes per hour"
  probe_idle_window:
    description: "idle time before an active probe fires"
  probe_budget:
    description: "hard timeout for a single probe call, sized to the model class"
  recent_failure_ttl:
    description: "how long a failed model is skipped"
  quota_expiry_default:
    description: "fallback expiry for a free-tier failure when no header is available"
  loud_verification_window:
    description: "how recently a delivery destination must have been verified for 'loud' to hold"
  alert_staleness_multiplier:
    description: "multiplier of the producer's schedule period before the heartbeat is stale"
  ledger_staleness_multiplier:
    description: "multiplier of the tick period before the ledger is stale"
  skew_margin:
    description: "allowance for clock skew when checking the post-reset delay"
  max_post_reset_delay:
    description: "maximum acceptable idle time after reset before the free tier is re-tried"
  fail_closed_N:
    description: "consecutive ticks on paid because of failure before the alert fires"
  fail_closed_T:
    description: "or minutes on paid because of failure before the alert fires"
  fail_closed_M:
    description: "consecutive ticks before holding current tier and repeating the alert"
  free_return_K:
    description: "healthy reads in a row required to return to free"
  free_return_D:
    description: "minimum minutes the healthy reads must cover"
  state_min_dwell:
    description: "minimum time a tier must be held before a switch away"
  config_writes_per_hour:
    description: "cap on config writes per rolling hour before the system is considered flapping"
  manual_override_hours:
    description: "how long a manual change pauses the selector before it re-plans"
    question: "default 4; 4–6 recommended. A hold (no expiry) is requested explicitly, not configured here"
  global_signal_k:
    description: "distinct sessions with struggle required before a global change"
  global_signal_window:
    description: "window for the distinct sessions"
  global_signal_baseline:
    description: "struggle rate above which a global change is allowed"
  local_inventory_cooldown:
    description: "minimum time between applied inventory changes"
  local_inventory_hysteresis_up:
    description: "consecutive probes to enter the resolved set"
  local_inventory_hysteresis_down:
    description: "consecutive failures to leave the resolved set"
  local_inventory_dwell:
    description: "minimum uptime before a newly admitted peer serves batch work"

lists:
  selector_tools:
    description: "every shelled-out tool the selector needs"
  aux_chains_blocking:
    description: "auxiliary chains a user turn waits on; API head required"
  aux_chains_non_blocking:
    description: "auxiliary chains the turn does not wait on; local head permitted"
  aux_chains_unknown:
    description: "chains whose blocking status is unknown; API head required by default"
  cross_box_dependencies:
    description: "chain entries on this box hosted by another box"

placeholders:
  box:                         "the deployment identifier"
  peer:                        "the other deployment in a pair"
  tailnet-ip:                  "the tailnet address of a card or box"
  card-1:                      "first local inference host (role order)"
  card-2:                      "second local inference host (role order)"
  card-3:                      "third local inference host (role order)"
  model_id:                    "a model id from the deployment's catalog"
  image_model_id:              "an image-capable model id from the catalog"
  provider:                    "a provider name from the deployment's config"
  provider_key_var:            "the environment variable name holding a provider key"
  helper_required_module:      "the module the switch helper imports"
  dashboard_port:              "the dashboard's listening port"
  quota_endpoint:              "the provider's quota-read endpoint"
  probe_url:                   "the URL the health probe calls"
  scheduler:                   "the scheduler command (cron, systemd, ...)"
  task_system:                 "the task-system command"
  specific_vendor:             "the paid-family vendor prefix"
  selector_script:             "the active selector's script name"
  health_script:               "the health-probe script name"
  command:                     "a CLI command to verify"
  flag:                        "a CLI flag to verify"
  service_name:                "the supervisor's unit name"
  port:                        "a listening port"
  read_remaining:              "the command that reads remaining quota"
  read_current_tier:           "the command that reads the current tier"
  same_id:                     "a model id to test scope persistence without changing the default"
  ```

