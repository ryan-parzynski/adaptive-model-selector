# Changelog

Version history of `HERMES-MODEL-SWITCHER.md`. The current version is in `VERSION`. Each version's detailed notes are at the top of the specification; Record 4 in Part III carries the same history in table form.

**For adopters.** Every entry ends with **Adopters: action required**: the work a box that adopted an earlier version must do to reach this one. When updating, read every entry between your adopted version (in `state/switcher-adoption.yaml`) and the current one, and treat those lists as your work queue (`AGENT-GUIDE.md` §5). Invariant numbers never change, so references in earlier reports stay valid.

**For maintainers.** Every new entry must include an *Adopters: action required* list, even if it says "none". An entry without one is incomplete.

---

## v3.10 — 2026-10-15 — layered spending limits with a built-in catch; on by default

- §4.22: provider limits read live; box daily cap, chat window cap, job budget and interactive reserve, each named by scope. Without an operator cap, the switcher sets a catch: the smaller of a multiple of its median daily spend and the pace of any provider period limit. Edge cases are listed (mid-turn, midnight, retries and delegated work, unreadable or conflicting spend, temporary raises, shared accounts). Invariant 54.
- §4.23: test mode ends when verification passes or after `test_mode_max_hours`; on is the default; off only by a recorded override; reports judge the mode from the running command. Invariant 55.

**Adopters: action required**
- Set the box daily cap, or confirm the built-in catch is active and reported (questionnaire P13). Read provider key limits live where available.
- Check what actually decides your switcher's mode; a log line saying "dry-run" is not evidence.

## v3.9 — 2026-10-15 — shared lanes, lightweight lane sampling

- §6.4b: one lead per shared GPU lane; guests use loaded models only, with short timeouts, and fall back immediately; a person using the card makes the lane busy and is never evicted; relays run on inference nodes, not hypervisor hosts. Invariant 52.
- §30.9: lane sampler on every box hosting or consuming a local lane, default every 15 minutes, no model calls, no content, one schema everywhere so rollups can be pulled together for tuning. Metric cards `lane_sample` and `lane_probe`. Invariant 53.

**Adopters: action required**
- If any local lane is used by more than one consumer, name its lead in `shared_lane_leads` and set guests' `guest_first_token_timeout_s` (questionnaire P12).
- Install the lane sampler on each box that hosts or consumes a local lane; check its own cost stays under a second per run.
- If a lane is relayed through a hypervisor host, plan to move the relay to an inference node.

## v3.8 — 2026-10-15 — capability-first model choice, long-job safeguards, in-app notices

- §4.20: the switcher filters models by hard requirements, estimates capability from this box's own track record (once enough runs are checked), operator overrides, then conservative priors, and picks the lowest **effective** cost (including the free allowance's shadow price) among models that meet the floor. Unrated models are tried only on low-stakes work, on free or local lanes. Any trigger that needs a stronger model just raises the floor. Invariant 50.
- §4.21: heavy and long jobs get a per-job budget (soft limit: downshift to the cheapest capable lane and notify; hard limit: pause at a checkpoint and ask), a **progress breaker** that pauses a job repeating itself or making no progress regardless of budget, and **heartbeats**. Invariant 51.
- §0.6: in-app notices (session banners, task-end notices) are recorded-and-surfaced, not loud; runtime chat channels count once tested; an undecided destination reports like absent.

**Adopters: action required**
- Before running long or heavy background jobs: set the job pre-approval threshold, soft-limit percentage, breaker settings and heartbeat interval (questionnaire P10). Make sure jobs checkpoint, or state that they can't.
- Start recording per-model evidence-check results per work type; track records count only after `capability_sample_floor` runs and only where enabled.
- Record the alert destination decision (questionnaire P11), "undecided" allowed.

## v3.7 — 2026-10-15 — capability floors, quality-gated escalation, agent memory

- §4.19: escalation raises a task's **capability floor**, never a provider. The switcher's normal logic picks the lane (free while available and above the reserve, then paid-cheapest), so a spent free allowance is handled like any other session. Escalation is bounded by a step limit and a per-work-type daily paid envelope; when the envelope is spent, output is delivered marked "unverified" instead of retried. The trigger is an evidence check on the output (placeholder hashes, VERIFIED without a command, summary/body contradictions, key fragments, unchecked "offline" claims), not the model's opinion of itself. Invariant 48.
- §0.7: agent memory. Recalled memory is context, never a task; current-state memories are REPORTED until re-observed; memories carry provenance. Invariant 49.

**Adopters: action required**
- Before enabling escalation: set `capability_floors`, `escalation_max_steps` and `escalation_daily_budget` (questionnaire P9). Make sure no escalation logic names a provider or forces paid; it must only raise the floor.
- If your agents keep memory: audit current-state memories (addresses, loaded models, limits, chain order) and adopt provenance on new ones (§0.7).

## v3.6.1 — 2026-10-15 — recurring status report

- `docs/switcher-status-report.md`: a read-only "switcher in action" report for any box running a switcher, adopted or not. It puts the provider's limits next to the switcher's beliefs (flagging impossible readings like used > limit and reset instants that never advance), reconciles spend sources, breaks costs down by model and task type including reasoning-token share, shows each local lane from this box's view (online, on GPU, address vs. node id, last call, latency), and ends with a sanitized JSON summary for comparing boxes.

**Adopters: action required**
- None required. Recommended: run the status report once now and then periodically; keep the JSON summaries.

## v3.6 — 2026-10-15 — principles, writer registry, alert gate, scratch home

- §0 principles restated around *discover safely, decide explicitly, implement narrowly, verify independently, preserve a working fallback*. "Keep boxes aligned by contract" is replaced by "deployment-driven, not replicated".
- §3.7a writer registry with phased retirement; invariant 47.
- Alert delivery is `absent`, `configured-failing`, or `verified`. Configured-failing is a routing defect: FAIL, not acknowledgeable, and it blocks enabling automated writers, escalation, or self-tuning.
- §4.13: the reserve is a static per-box value (provisional until measured); limits are read live.
- §6.4a: a model served by another box is self-hosted, peer-hosted — admitted and measured from the consuming box, identified by node id.
- §8.0: per-box state vs. fleet-shared material.
- §10.36: scratch-home isolation and the minimal safe check set when routing changes are forbidden.
- New checks `writer-registry.py`, `scratch-preflight.sh`; fixture suite now 75 cases.
- Agent guide: phase table; CANNOT-OBSERVE is a distinct item state; merge path writes a writer registry.

**Adopters: action required**
- Write `writers.yaml` (`writer_registry_file`) listing every component that can write routing state; run `checks/writer-registry.py`. Any `unknown` writer blocks implementation work.
- Retire any legacy writer through the phases in §3.7a rather than deleting it.
- Re-check the alert state. If it is `configured-failing`, do not enable automated writers, escalation, or self-tuning until a test alert succeeds.
- If a reserve value was set by hand, label it provisional until the per-session draw ledger supports it.
- If a routed model is served by another box: re-admit it from this box and record the host by node id.
- Before any write-test, run `checks/scratch-preflight.sh` against the scratch home.
- Reports: use CANNOT-OBSERVE for items that ran but could not reach their fact (previously folded into FAILED).

## v3.5 — 2026-10-15 — local capability tiers and resource guards

- §31: local models are tiered (fast / capacity / specialized). Start on the fast tier; escalate only on an explicit request, an explicitly deep work type, a hard failure of the fast tier, or background work. A model's judgment of its own answer is recorded, not acted on.
- Invariant 45 (resource guards): check GPU memory, RAM, loaded models and context before a capacity-tier load; never enable swap, unload or delete a working model, download a model, or change quantization without authorization.
- Invariant 46 (admission): a model is routed only after it loads, answers with content, and has its resource use recorded in this box's capability profile.
- New: rule card `local-capacity-tiers.md`, `docs/examples/capability-profile.example.yaml`, questionnaire C5c/C5d/P8, ledger metrics `tier_escalation` and `local_resource_snapshot`, registry key `capability_profile_file`.

**Adopters: action required**
- Boxes **with local models:** write the capability profile (§31.7), measured on the box. Admit every local model currently in a routing path (§31.6); defer any that fail, with the reason.
- Confirm the default for local work is a fast-tier model, not the largest one.
- Search the selector and scripts for commands that enable swap, unload, pull, delete or re-quantize models outside an operator-invoked path (invariant 45).
- Set policy P8 (which capacity-tier triggers are enabled).
- Boxes **without local models:** invariants 45 and 46 are not applicable. No action.

## v3.4.2 — 2026-10-15 — definition of done for agents

- `AGENT-GUIDE.md` §9: every run ends COMPLETE or INCOMPLETE, decided by a final verification pass that re-checks each acceptance item from current state, never from earlier notes. Missing items are listed with the exact command that would obtain them.
- A failing rule on the box is a finding; an unverified rule makes the run incomplete.
- High-stakes changes (ownership transfer, enabling or disabling a writer or job, fallback-list changes, self-tuning) require verification by the operator or a separate agent.
- The guide checks that a run left live routing unchanged (config and job-listing hashes, start vs end), and that the report contains no key material.

**Adopters: action required**
- Reports written under v3.4.1 or earlier have no Status or Verification log. On your next run, produce a full report under guide §9 rather than updating the old one.
- Add `second_party_verified` to `state/switcher-adoption.yaml`. For any high-stakes change already applied, record who verified it, or verify it now.
- No rule changes.

## v3.4.1 — 2026-10-15 — agent guide and update path

- `AGENT-GUIDE.md`: one guide for a Hermes agent adopting the specification on a new box, merging it with an existing switching setup, or updating from an earlier version. Includes a paste-in prompt and a report format.
- `VERSION` file. A per-box adoption record (`state/switcher-adoption.yaml`) is defined.
- Invariant numbers are declared stable (§9).

**Adopters: action required**
- Write `state/switcher-adoption.yaml` recording the version and commit you have adopted (`AGENT-GUIDE.md` §7.1). Without it, future updates cannot tell where to start.
- No rule changes.

## v3.4 — 2026-10-15 — tested checks, edge cases, ledgers

- `checks/`: nine tested checks plus `checks/tests/run.sh` (55 fixture cases). They replace the defective inline scripts in the spec.
- Drift check compares only declared-shared properties; manifest now catches an edited fallback list.
- Edge cases: DST/UTC scheduling, kernel-released lock, decimal prices and every price field, empty catalog, delisted default, reset-header formats, single "unalerted" finding, provider-defined answer field, owner-change privilege.
- §30 observation and decision ledgers; invariants 43 (no conversation content) and 44 (descriptive before self-tuning); `docs/ledger-metrics.md`.

**Adopters: action required**
- Replace any copy of an inline script from §3.11, §8.2, §8.4, §10.1, §10.2, §10.10, §10.13, §10.16 or §10.27 with the tested file in `checks/`. Run `checks/tests/run.sh` first.
- If you compare boxes: create `state/shared-properties.txt` listing what is declared shared. Without it the drift check reports cannot-observe.
- Re-record the single-box manifest (`checks/manifest.sh record`). The fingerprint format changed.
- New registry keys: `catalog_min_fraction`, `ledger_raw_retention_days`, `observation_ledger_file`, `decision_ledger_file`.
- New invariants 43 and 44. Check that no existing log or ledger contains conversation content.
- Re-check: §4.3 (empty catalog, delisted default), §4.7 (decimal prices, every price field), §4.13a (reset formats), §4.13b (DST), §4.14 step 6 (owner change).

## v3.3.1 — 2026-10-15 — cleanup

- Cross-references corrected; §26.10 renumbered §26.9.
- Placeholders renamed to underscores (`tailnet_ip`, `card_1`..`card_3`).
- Router/guardrail exclusion (§4.4a) and "zero-price is free only for its work type" (§4.6) moved into the selection rules.
- Embedded registry declared a copy; the `.yaml` file is canonical.

**Adopters: action required**
- Rename registry keys `tailnet-ip`, `card-1`, `card-2`, `card-3` to `tailnet_ip`, `card_1`, `card_2`, `card_3`.
- New registry key `router_exclusion_patterns`. Confirm the selector excludes routers and guardrail models (§4.4a).
- Confirm non-text zero-price models are not in the free text ladder (§4.6).

## v3.3 — 2026-10-15 — rule pass

- **Two-axis reporting:** applicability (`applicable` / `not-applicable` / `unknown`) is separate from the check result (`pass` / `fail` / `cannot-observe`).
- **Manual override:** a model change the selector didn't make pauses it, 4 hours by default, or until resume when a hold is requested. The selector never reverts it (invariant 41).
- **Limits are read, not remembered:** provider limits and their structure are read live every tick; no hardcoded numbers (invariant 42).
- Fallback heads must not share the failed dependency.
- New failure classes: paid credit or spend limit reached, negative balance; a 403 is no longer assumed to be auth.
- Config writes must preserve comments and key order.
- Local-as-main: a default rule with a measured, conditional exception.
- Corrections: sample floor (largest observed draw once ≥59 sessions), per-session measurement, local-inventory heartbeat, struggle-score scope, return-to-free hysteresis, aux-head inequality edge cases.

**Adopters: action required**
- Re-report every rule on the two axes. Anything previously reported "PASS (N/A)" becomes `not-applicable`.
- Add foreign-write detection and the manual-override pause; set `manual_override_hours` (invariant 41, §4.14a, check §10.34).
- Remove every hardcoded limit number; read limits live (invariant 42, check §10.35).
- Re-check the fallback head against §6.4: after an account-level free limit, another free model is not an eligible fallback.
- Add the credit/spend-limit and negative-balance classes to quota-failure handling (§4.9). Don't treat every 403 as auth.
- Confirm config writes preserve comments, or use the sanctioned switch path (§3.37).
- Re-derive the reserve as the largest observed per-session draw once you have 59 sessions.

## v3.2c — 2026-10-15 — housekeeping

- LF line endings and `.gitattributes`.
- Embedded scripts marked illustrative and untested.
- Private deployment record filename removed.
- Whole-repository GPL-3.0 stated.

**Adopters: action required**
- If you copied any script out of the specification before this version, check it for CRLF line endings; they break bash.

## v3.2b — 2026-10-13 — patch pass

See the v3.2b notes at the top of the specification.

**Adopters: action required** — not recorded for this and earlier versions. Treat an adoption older than v3.2c as a fresh adoption (`AGENT-GUIDE.md` §3) rather than an update.

## Earlier

v2.2 through v3.2a are described in Record 4 of the specification. The reference implementation that preceded v3.2 is preserved in the repository's commit history.
