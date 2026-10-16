# Agent guide — adopting, merging, and updating the Hermes Model Switcher

*Section references written "guide §n" point within this file; a bare "§n" points to `HERMES-MODEL-SWITCHER.md`.*

This file is written **to a Hermes agent** running on a box whose operator wants better model switching. It works whether you are:

- **New** — this box has no model-switching automation of its own;
- **Merging** — this box already has its own selector, failover scripts, cron jobs, or preference files;
- **Updating** — this box already adopted an earlier version of this specification and a newer one has been released.

Everything else in this repository is reference material. This guide tells you what to do with it, in what order, and what never to do.

---

## The pattern

**Discover safely, decide explicitly, implement narrowly, verify independently, and preserve a working fallback.**

| Phase | Who | What happens | What may change on the box |
|---|---|---|---|
| **Discover** | Agent | Classify state, run read-only checks, inventory writers, build the capability profile | Nothing. Only report and state files, if the operator allows them |
| **Decide** | Operator | Answer the open questions; approve or reject each proposal; record the decisions in the adoption record | The adoption record |
| **Implement narrowly** | Operator, or the agent on an explicit, scoped task | One approved change at a time, smallest first, each with a rollback | Only what that task names |
| **Verify independently** | Operator or a separate agent | Fresh evidence that the change did what it claimed (guide §9) | Nothing |
| **Preserve a fallback** | Everyone | A working route exists at every step; nothing is retired before its replacement is verified | — |

This guide covers **Discover** in full and sets up **Decide**. An implementation pass is a separate, operator-approved task.

The specification's principles are listed in `HERMES-MODEL-SWITCHER.md` §0.

---

## Paste-in prompt

An operator can give this to a Hermes agent as-is:

> You are helping me adopt the Hermes Model Switcher specification on this box. Clone or update `https://github.com/ryan-parzynski/adaptive-model-selector` and follow `AGENT-GUIDE.md`. Work out which path applies — new, merging an existing setup, or updating from an earlier version of this spec — and follow it. **Do not change model routing on this box:** no edits to `config.yaml`, no `/model --global`, no enabling or disabling scheduled jobs. Discover, check and report; propose changes for me to approve. Report in the format the guide specifies, and finish only by its Definition of done (guide §9): end with COMPLETE or INCOMPLETE, verified from fresh evidence.

---

## 1. Ground rules

### 1.1 You report; the operator changes routing

**Do not change your own model routing from inside a session.** That means editing `config.yaml`, running `/model --global`, installing or enabling a selector that writes config, pausing or deleting scheduled jobs, or editing preference files. The specification calls this *fixing the failure domain from inside it* (§0.5 Class 4, §19). An agent cannot safely reconfigure the thing it is running on, and a mistake can strand the session.

You may:

- read anything under the Hermes home, the runtime source, logs, and scheduler listings;
- run the read-only checks in `checks/`;
- create a **scratch copy** of the Hermes home and run write-tests against the copy only;
- write your report and proposals to files the operator will read.

The one check that writes config, `checks/switch-path.sh`, refuses to run unless `SWITCH_CHECK_SCRATCH=1` marks a scratch home. Never set that flag on the live home. Before **any** write-test, run `checks/scratch-preflight.sh` and proceed only if it exits 0 (spec §10.36). It proves the scratch home has its own files, no links into the live home, no scheduled job pointing at it, no shared ports, and no real provider endpoints.

### 1.2 Label every claim

The specification's claim discipline (§0.6) applies to your report:

| Label | Use when | Evidence you must include |
|---|---|---|
| **OBSERVED** | You checked it on this box | The command and its output, or the file and line |
| **HYPOTHESIS** | A likely explanation you did not confirm | What would confirm or refute it |
| **REPORTED** | Someone else told you | Who; marked unverified |
| **PROPOSED** | A change you recommend | What it would take to implement |
| **BLOCKED** | A decision that belongs to the operator | Both sides and the options |

Two qualifiers matter for runtime facts: **source-verified** (you read the code path) is not **live-run-verified** (you ran it and saw the result). Say which.

### 1.3 Report applicability separately from results

For each rule, report **applicability** — `applicable`, `not-applicable`, or `unknown` — and, only when applicable, a **check result**: `pass`, `fail`, or `cannot-observe` (§0.6, `docs/two-axis-reporting.md`).

- `not-applicable` only when a capability is absent or the operator's policy excludes it. Never because a check was hard to run.
- A read error, missing input, or missing tool is `cannot-observe`. Never `pass`.
- `unknown` comes with the question that would resolve it.

### 1.3a Memory

If you keep memory across sessions, follow spec §0.7: recalled memory is context, never your task; remembered current-state facts (addresses, loaded models, limits) are REPORTED until you re-observe them; new memories carry date, source, box and claim label.

### 1.4 Privacy

Nothing you write — report, ledger, proposal — contains conversation content, prompts, responses, tool arguments, file contents, URLs, or key material. Not even a key prefix (invariants 31, 43). To identify which of two keys is in use, hash it (§3.23).

---

## 2. Which path are you on?

Check in this order:

1. **Updating** — the box has an adoption record at `$HERMES_HOME/state/switcher-adoption.yaml` (guide §7.1). Go to **guide §5**.
2. **Merging** — no adoption record, but the box has *any* of: a scheduled job that changes the model; a selector, failover, or autoswitch script; a preference file of preferred models; or a non-empty owner field in a prefs file. Go to **guide §4**, after guide §3.
3. **New** — none of the above. Go to **guide §3** and stop at its end.

If you find an adoption record *and* switching automation that the record doesn't mention, you are both updating and merging: do guide §5, then guide §4 for the unrecorded parts.

---

## 3. Discovery (every path)

### 3.1 Get the repository

```bash
git clone https://github.com/ryan-parzynski/adaptive-model-selector   # or: git -C <dir> pull --ff-only
cat VERSION
checks/tests/run.sh      # fixture tests; never touches the real Hermes home
```

If the fixture tests fail, report the failures and stop running checks. A broken check is worse than no check (§0.5 Class 6).

### 3.2 Read, in this order

1. `README.md` — layout and status.
2. `HERMES-MODEL-SWITCHER.md` §0, §0.5, §0.6 — summary, failure classes, claim discipline.
3. `docs/capability-questionnaire.md` — the questions that decide which rules apply.
4. `docs/rule-cards/` — how a rule carries its purpose, applicability, evidence and verification.
5. §4 (selection), §6 (escalation), §9 (invariants).
6. §13 — the onboarding priority order. Use it to order your proposals.
7. §30 and `docs/ledger-metrics.md` — what to record for future tuning.
8. §31 and `docs/rule-cards/local-capacity-tiers.md` — if the box has local models: tiers, resource guards, admission.

### 3.3 Resolve the Hermes home

Read `HERMES_HOME` from the **runtime's** environment, not from your shell's `$HOME` (§1.3). A box can mount the home under two paths; a check pointed at the wrong one reads a directory with no config. Export it for the checks.

### 3.4 Answer the capability questionnaire

Work through `docs/capability-questionnaire.md`. Detect what you can; for each answer, record how you know. Mark anything you cannot determine `unknown` with the question that would resolve it. Policy questions (P1–P7) are the operator's: list them as questions, don't answer them.

The ones that most change what applies:

- **C1–C3:** Is there a bounded free allowance? Can it be read without spending it? Read limits live from the provider. Never from memory or from numbers in any document, including this one (invariant 42).
- **C2:** Is a paid tier configured and allowed?
- **C5, C5a:** Are there local models, and has their latency been measured?
- **C5c, C5d:** Is there a capability profile for this box, and which local tiers (fast, capacity, specialized) does it have? If local models exist but no profile does, propose writing one (§31.7): measure GPU memory, RAM, and each model's actual resource use **on this box**. Never borrow another box's numbers.
- **C6, C6a:** Is there an alert destination outside the box, and did a test message succeed recently?
- **C8–C12:** Which switch mechanisms does this Hermes build have? Does it fall through on timeout? Can `config.yaml` be rewritten without losing comments?

### 3.5 Run the read-only checks that apply

See `checks/README.md` for each check's inputs, which map to registry keys. Run only checks whose rule is applicable. Record each result with its exit code.

**If the operator forbids routing changes** (the default for a discovery pass), the minimal safe set is: `no-hardcoded-ids.sh`, `env-duplicates.sh`, `no-secrets-on-argv.sh`, `writer-registry.py` (once a registry exists), `stream-timeout.py` (reads config only), and `reserve-vs-spent.sh` when the remaining count comes from a zero-cost endpoint. Plus source reads for the runtime facts in guide §3.6. Everything else is **SKIPPED with its reason** ("live write not permitted"), never silently left out.

### 3.6 Verify the runtime facts

These differ between Hermes builds, and the specification cannot know yours:

| Fact | Where | How |
|---|---|---|
| Plain `/model` scope; whether `--once` / `--session` / `--global` exist | §2.6, §10.19 | Source read, then a live probe **in a scratch home** |
| Whether the runtime falls through to the next fallback on timeout | §10.28 | Source read, then a black-box test against a non-answering endpoint |
| Whether one fallback list serves main and auxiliary traffic | §6.3a, §16 Q21 | Source read or trace |
| Exact key and location of the stream-stale timeout | §3.2, §10.13 | Source read |
| What `config set` writes, and whether atomically | §4.14, §16 Q49 | Source read |

Label each **source-verified** or **live-run-verified**.

**New path:** after this section, write the report (guide §6) and stop. Your proposals follow §13's priority order.

---

## 4. Merging an existing setup

The box already switches models somehow. Your job is to **map what exists onto the specification, find the gaps and conflicts, and propose a migration the operator approves**, without breaking what works today.

### 4.1 Inventory every writer

List everything that can change the model or the fallback list:

- scheduled jobs (the scheduler's job listing, `cron/jobs.json`): **read the exit code and the first log line of each** before trusting what it claims to do (§10.23);
- scripts in the scripts directory: selectors, failover, autoswitch, verify scripts;
- the dashboard's model endpoint and any TUI or `--global` habits the operator mentions;
- preference files, tier tables, owner fields.

Classify each scheduled writer by its effect on the default (§3.7): **CLOBBER** (moves toward paid or a fixed tier), **SAFETY** (moves toward free or cheap), or **NEUTRAL**. If two selectors exist with opposite policies, say which one the scheduler actually runs (§3.32). Reading a paused one tells you nothing about current behavior.

### 4.2 Map components to the specification

| Existing thing | Specification concept | What to check |
|---|---|---|
| Every writer found in guide §4.1 | **Writer registry** (§3.7a, inv. 47) | Write `writers.yaml` (see `docs/examples/writers.example.yaml`): path, fields written, kind, status, evidence. Any `unknown` blocks implementation |
| The active selector or autoswitch job | **Owner** of the default (§3.7, inv. 21) | Exactly one active writer? Owner field populated? (§10.18) |
| Other jobs that write the model | Non-owner writers | Should be paused or refuse to write; until then they are **foreign writes** to the owner (§4.14a) |
| Preferred-models list | Preference list (§4.10a) | The operator's ordering is authoritative: new models are appended, dropped ones reported, never deleted |
| Free/paid logic | Reserve (§4.13), quota-failure routing (§4.9) | Is there a reserve? Sized per session? What happens on 401, 402, 403, 429, malformed quota? |
| Hardcoded limit numbers | Live limits (inv. 42) | Every literal limit is a gap |
| Failover script | Fallback head rule (§6.4) | Does the fallback share the failed dependency? |
| Local model list or tiers | Capacity tiers and admission (§31, rule card) | Is the default local model the fast tier? Is every routed model admitted? Any scripts that unload models, pull models or enable swap? |
| Local model routing | Local-as-main (§6.3, rule card) | Is local reachable from the main path? Measured? |
| Logs of switches | Decision ledger (§30) | What's recorded; is any conversation content in it? |
| Alerting | "Loud" (§0.6, inv. 34) | Last *successful* delivery, not last attempt (§10.12). Report the state as `absent`, `configured-failing`, or `verified`. **Configured-failing is a routing defect**, not a cosmetic one, and it blocks enabling any automated writer |
| Scripts directory | Versioning (inv. 26) | Under version control? (§10.21) |

### 4.3 Merge rules

1. **Keep today's behavior until the operator approves a change.** A working box that switches imperfectly is better than a box with no switching.
2. **The operator's curated data wins.** Preference lists, tier tables, allowlists and accepted differences are merged by appending and reporting, never by overwriting or deleting (§4.10a).
3. **One owner at the end.** Propose which component becomes the owner of the default, and how every other writer is retired or made to refuse. Transferring ownership is an operator decision: list it as **BLOCKED** with the options.
4. **Conflicts are BLOCKED, not resolved.** Where the existing setup and the specification disagree on policy (for example, a fallback to local, or no reserve), present both sides and let the operator choose. The specification's rule cards explain *why* each rule exists, so the operator can decide whether the reason applies here.
5. **Never fight a human change.** If the operator changes the model while you are investigating, that is a foreign write, not drift.
6. **Fix nothing from inside the failure.** If you find the box is currently degraded, report it with the manual command to fix it (§3.5); do not apply it.

### 4.4 Merge output

Add to the report (guide §6) a **migration plan**: an ordered list of steps, each with the rule it satisfies, the risk, how to roll it back, and whether it needs an operator decision. Order by §13's priorities. Alert path and ownership come before tuning.

Retire writers **in phases**, never in one step (§3.7a): registered → quarantined (removed from schedules, file kept) → observed through a full allowance reset with no foreign writes from it → retired. Classify any writer that runs inside the request path first. If a preference file has a manual lock, propose mapping it onto the spec's hold (§4.14a), and verify from the owner's source that the owner honors it.

---

## 5. Updating to a newer version

### 5.1 Find what changed

1. Read the adoption record (guide §7.1) for the version and commit last adopted.
2. Pull the repository; read `VERSION`.
3. Read `CHANGELOG.md` from the adopted version up to the current one. Each entry has an **Adopters: action required** list. That list is your work queue.
4. For detail, diff the specification between the two commits: `git diff <adopted-commit>..HEAD -- HERMES-MODEL-SWITCHER.md HERMES-MODEL-SWITCHER.registry.yaml checks/`.

### 5.2 Apply the update

For each action-required item:

- **New invariant or rule:** resolve its applicability on this box (guide §1.3), run its check if one exists, record the result.
- **Changed rule:** re-check it. A rule that passed under the old wording may fail under the new one.
- **Retired rule:** note it; propose removing anything that existed only to satisfy it.
- **New or renamed registry key:** propose a value with your reasoning; the operator sets it.
- **Changed check script:** re-run it; compare with the last recorded result.
- **New capability question:** answer it (§3.4).

**Invariant numbers are stable.** They are never renumbered. A retired invariant keeps its number and is marked retired, so references in your earlier reports stay valid.

### 5.3 Update output

Add to the report (guide §6) an **update summary**: from-version, to-version, each action-required item with its outcome, and anything whose result changed since the last adoption record.

---

## 6. Report format

Write one Markdown file, for example `$HERMES_HOME/state/switcher-report-<date>.md`, with these sections:

1. **Status** — `COMPLETE` or `INCOMPLETE` (guide §9). If INCOMPLETE, the missing-items list comes first.
2. **Summary** — path taken (new / merge / update); spec version and commit; the three most important findings.
3. **Box** — resolved Hermes home; Hermes build or version; provider(s); single or multiple boxes; local models yes/no; if yes, the capability profile (or the gap where it should be).
4. **Capabilities** — each questionnaire item: `present` / `absent` / `unknown`, with how you know.
5. **Open questions for the operator** — every `unknown` and every policy question, each phrased so it can be answered in one line.
6. **Rules** — a table: rule or invariant, applicability, check result, evidence (command and exit code, or file and line).
7. **Runtime facts** — each fact from guide §3.6, with source-verified or live-run-verified.
8. **Inventory** (merge path) — every writer, its classification, and whether it ran successfully last time.
9. **Gaps and conflicts** — each labelled OBSERVED / HYPOTHESIS / BLOCKED.
10. **Proposals** — ordered by §13; each with the rule it satisfies, risk, rollback, and whether it needs an operator decision.
11. **Migration plan** (merge path) or **Update summary** (update path).
12. **Limits of this report** — what you could not observe and why.
13. **Verification log** — the final verification pass (guide §9.3): each acceptance item, its state, the command that verified it, and the timestamp.

No conversation content, no key material (guide §1.4).

---

## 6a. Recurring status report

After adoption — or before it, on any box already running a switcher — `docs/switcher-status-report.md` is the periodic, read-only "is the switcher working?" report: what each component did, the provider's limits vs. the switcher's beliefs, measured spend and unit economics, local-lane usage seen from this box, health, and anomalies. It ends with a small sanitized JSON summary that boxes can compare as lessons.

---

## 7. After the operator approves

### 7.1 Record the adoption

The operator, or you once explicitly permitted, writes `$HERMES_HOME/state/switcher-adoption.yaml`. Example:

```yaml
spec_version: "3.4.1"         # from VERSION
spec_commit: "<short hash>"   # git rev-parse --short HEAD
adopted_at: "2026-10-15"
path: new | merge | update
report: state/switcher-report-2026-10-15.md
operator_decisions:           # one line each, from the BLOCKED items
  - "owner of the default: <component>"
  - "manual_override_hours: 4"
second_party_verified:        # guide §9.5: change, who verified it, when
  - "owner transfer to <component>: verified by <operator|agent>, <date>"
deferred:                     # rules knowingly not adopted yet, with reason
  - "invariant 9 local-as-main exception: latency not yet measured"
```

This record is what the update path (guide §5) starts from. Keep it current; it is the box's answer to "which version are we on, and what did we decide?"

### 7.1a Ask about daily sharing (new installs)

Before finishing an install, ask the operator **once** about daily anonymous sharing (spec §30.10). It is **off** until they say yes.

1. Build a preview `report/v1` from this box's own data, following `contrib/NAMING.md`.
2. Show the preview, explain what sharing contributes, and recommend yes. Don't pre-select an answer.
3. Record the answer (`daily` or `off`), the date, and who answered in `state/switcher-adoption.yaml`.
4. **On yes:** generate a random `contributor_id`; create `state/contrib-deny.txt` (this box's own names, aliases, lanes, peers, addresses, users and home paths) and the outbox directory; hold the first report for review.
5. **On no:** schedule the reminders (30, 90, 180, 365 days, then yearly) through the box's alert path. Each one offers yes, not now, or don't ask again.

On an **update** or **merge**, keep the recorded answer and its schedule. Never change it without the operator's explicit instruction.

### 7.2 Start the ledgers early

Even before any selector exists, recording observations (§30) starts the evidence clock: per-session request draws, limit snapshots, overrides and fallbacks. Every measured value the specification asks for — the reserve, local latency, aux-chain overlap, the override window — needs history first. The ledgers are descriptive until the operator enables tuning for a specific rule (invariant 44).

### 7.3 Share lessons, not state

If the operator runs several boxes, or wants to contribute back, share a **sanitized lessons summary**: what failed, what the rule was, what changed. Never share raw ledgers or reports (§30.6, §22). Rules that turn out wrong for a real deployment are the most valuable input this project can receive; open a GitHub Discussion or Issue.

**Submitting back** (only with the operator's typed approval): write one `report/v1` or `finding/v1` file as `contrib/README.md` describes, run `checks/contrib-validate.py` on it, show it to the operator, then open a pull request from a fork that touches only that file. A pull request is public once opened, so validate first.

---

## 8. Never

- Change model routing on the live box from inside a session.
- Report `pass` for a check that could not read its input.
- Mark a rule `not-applicable` because checking it was inconvenient.
- Hardcode a provider's limit numbers, or trust numbers quoted in any document.
- Delete or reorder an operator's curated list.
- Revert a model change a human made.
- Load, unload, download or re-quantize a local model, or touch swap, to test something on the live box (invariant 45).
- Put conversation content or key material in a report, ledger, or log.
- Treat a source read as proof of runtime behavior.
- Copy an illustrative code block from the specification onto a live box. Tested checks are in `checks/`.
- Report COMPLETE from evidence gathered before the final verification pass, or from your own earlier summary.
- Treat your own re-check as independent verification of a high-stakes change (guide §9.5).

---

## 9. Definition of done

You are both the executor and the verifier of your own run. Do the work, then **re-verify every acceptance item against the current state of the box** with fresh commands, not your earlier notes or summary. Only then choose the final status.

### 9.1 Two different questions

- **Is the run complete?** Did you establish everything this guide asks for, with current evidence? That decides **COMPLETE** or **INCOMPLETE**.
- **Is the box healthy?** Do the rules pass? That is a **finding**, reported in the Rules section.

A rule that **fails** on the box does not make the run incomplete. A rule you **could not verify** does. A finished report that says "the alert path is mute (fail)" is COMPLETE. A report that never checked the alert path is INCOMPLETE.

### 9.2 Acceptance items

Every path:

| # | Item | Verified by |
|---|---|---|
| A1 | Repository at a recorded commit; `VERSION` read | `git rev-parse --short HEAD`; `cat VERSION` |
| A2 | Fixture tests run **in this run**; result recorded | `checks/tests/run.sh` exit code and summary line |
| A3 | Hermes home resolved from the runtime | The process environment or runtime source you read it from |
| A4 | Every capability question answered `present` / `absent` / `unknown` | Evidence per answer, or the question that resolves it |
| A5 | Every invariant (1–57) has an applicability; every applicable one has a check result or a documented manual review with evidence | The Rules table |
| A6 | Every applicable check in `checks/` run in this run | Command, exit code, timestamp |
| A7 | Each runtime fact in guide §3.6 is source-verified, live-run-verified, or `unknown` with the command that would settle it | The Runtime facts table |
| A8 | **Live routing unchanged by the run** | SHA-256 of `config.yaml` and of the scheduler's job listing, taken at the start and the end; they must match. (If the operator changed something meanwhile, say so; that is a foreign write, not yours.) |
| A9 | Report contains no key material or conversation content | For each provider key variable, with `.env` sourced: `grep -cF -f <(printf '%s\n' "${!VAR}") <report>` returns 0. `printf` is a shell builtin, so the value never appears on a command line; never print it |

Merge path, additionally:

| # | Item | Verified by |
|---|---|---|
| M1 | Every writer of routing state inventoried in a writer registry, with its last exit code and first log line; `writer-registry.py` run on it | Inventory table |
| M2 | Every scheduled writer classified CLOBBER / SAFETY / NEUTRAL | Inventory table |
| M3 | Every row of the mapping table (guide §4.2) filled for this box | Mapping table |
| M4 | Migration plan: every step has the rule it satisfies, risk, rollback, and decision flag | Migration plan |

Update path, additionally:

| # | Item | Verified by |
|---|---|---|
| U1 | Adoption record read; from-version and from-commit recorded | The record's contents |
| U2 | Every *Adopters: action required* item between the adopted and current version has an outcome | Update summary |
| U3 | Every result compared with the last recorded result; changes listed | Comparison table: rule, previous result, current result |

### 9.3 The final verification pass

After the report is drafted, before choosing a status:

1. **Re-run** A1, A2, A6, A8 and A9 now. Do not reuse output from earlier in the run.
2. **Re-check** every other item against current state: re-open the files, re-read the listings. Don't re-read your own notes.
3. **Record** each item in the Verification log: item, state, command, timestamp.
4. If anything differs from the draft, correct the report first, then re-verify the changed items.

Each item ends in one of these states:

| State | Meaning |
|---|---|
| **VERIFIED** | Established from evidence produced in this final pass |
| **FAILED** | Attempted; the step itself errored or its tooling broke, with the error |
| **CANNOT-OBSERVE** | Attempted; the step ran but could not reach the fact (endpoint unreachable, input missing, permission denied), with what blocked it |
| **SKIPPED** | Not attempted, with an allowed reason: the rule is `not-applicable` (capability absent or excluded by policy), or settling it needs an operator answer or a live write you are not permitted to make |
| **MISSING** | Not done, done with evidence from before this pass, shortened, or timed out without a retry |

A step that timed out is CANNOT-OBSERVE if retried and still timing out, MISSING if not retried. Either way, record the timeout and its limit. **No silent skips:** every acceptance item appears in the Verification log with one of these five states.

### 9.4 Choosing the status

- **COMPLETE** — every item is VERIFIED or SKIPPED with an allowed reason.
- **INCOMPLETE** — anything else. List each FAILED, CANNOT-OBSERVE or MISSING item first in the report, with:
  - **the exact missing item** (its number and name);
  - **why existing evidence is insufficient** (stale, from an earlier run, shortened, errored, ambiguous);
  - **the exact command or check that would obtain it.**

If one item cannot be completed, mark it and **continue with the rest**, unless continuing is unsafe (for example, the box is degraded and further probing would spend a scarce budget). Then stop, say why, and report INCOMPLETE.

### 9.5 Your own re-check is not independent

Re-verifying your own work catches stale evidence and skipped steps; it does not catch your own blind spots (§19). So any proposal that, once applied, would **transfer ownership of the default, enable or disable a writer or scheduled job, change the fallback list, or turn on a rule's self-tuning** is marked **requires second-party verification**. After the operator applies it, the operator or a **separate** agent, not the one that proposed it, verifies the outcome from current state. Record who verified it in the adoption record.

