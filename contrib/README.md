# Contributing back: reports and findings

Anyone running the switcher can send back what they learned: **anonymously, in a fixed format, through a pull request into this folder.** These are performance reports and engineering findings, not personal data, but they still carry no names, hosts, addresses, paths, URLs or keys. The validator rejects them.

## Two lanes

| Lane | Path | Schema | What goes in it |
|---|---|---|---|
| Reports | `contrib/reports/YYYY-MM/<8 hex>.yaml` | `report/v1` | Rollups from your ledgers: switch rates, reason counts, first-token latency by lane class, spend per day, limit hits, per-model pass rates. Hardware in size bands only. |
| Findings | `contrib/findings/<kind>/YYYY-MM/<8 hex>.yaml` | `finding/v1` | One bug, edge case, optimization, fix or unclear rule, **with context** (below). |

Findings go in a folder for their kind: `bugs/`, `edge-cases/`, `optimizations/`, `fixes/`, `unclear-rules/`.

## What a finding must include

A finding is judged on its context, so every one needs **all** of these. The validator refuses one without them, and refuses one-liners:

| Field | What it answers |
|---|---|
| `environment` | What kind of setup: runtime version, providers, lane types, GPU size band, bare metal / VM / container. |
| `observed` | What happened. |
| `how_to_reproduce` | The steps someone else can follow to see it. |
| `why_it_matters` | The effect: cost, failures, wrong switches, wasted time. |
| `evidence` | What was measured, and how often. |
| `scope` | Your honest guess: `likely_everyone`, `setups_like_mine`, `only_my_setup` or `unsure`. |
| `frequency` | `always`, `often`, `sometimes` or `once`. |
| `proposal` | What should change. |

## Triage: what gets in

Nothing is accepted automatically. The maintainer reads each finding and decides:

- **Accepted for everyone:** it reproduces, or the evidence is convincing, and it applies beyond one setup. It becomes a spec change, a rule card or a check, credited to the finding's id.
- **Accepted as a setup note:** real, but only for certain setups (a runtime version, a provider, containers). It's recorded as a conditional note, not a general rule.
- **Kept open:** plausible, but needs more evidence. Further findings with the same `reason_codes` count toward the quorum.
- **Declined:** can't be reproduced, only applies to one machine, or conflicts with a rule that exists for a stated reason. Closed with a one-line reason, so the next person can see why.

Examples: `docs/examples/contrib-report.example.yaml`, `docs/examples/contrib-finding.example.yaml`. Name the file with 8 random hex characters (`openssl rand -hex 4`). **One file per pull request.**

Names follow `contrib/NAMING.md`: descriptors such as "a relayed peer GPU, 8–16 GB NVIDIA, in a container", never names, addresses or people.

## Daily sharing (the default for new installs)

A box that adopts the switcher **shares a `report/v1` once a day**, plus any `finding/v1` it has, unless the operator turns sharing off. The rules are in spec §30.10:

- **Asked once, at install.** The installing agent shows the operator what a report contains (a preview built from the box's own data) and asks. The default answer is **daily**. The answer is saved, with the date and who gave it, in `state/switcher-adoption.yaml`.
- **The first report is held for the operator to review.** After that, reports go out daily on their own.
- **Only the operator changes it.** No agent, update or contribution may turn sharing on or off, or change what is shared, without the operator's explicit, typed instruction. That instruction is recorded.
- **Outbox:** reports wait in `state/contrib-outbox/` (mirroring the `contrib/` layout: `reports/YYYY-MM/`, `findings/<kind>/YYYY-MM/`) until they're uploaded. If an upload fails, they stay and are retried the next day. Files older than a day are compressed. Past the outbox size limit, the oldest daily reports are folded into one weekly rollup rather than dropped. Each file is flushed (deleted from the outbox) only after its upload is **confirmed**: the pull request exists and contains the file.

## How to submit (people and agents)

1. Fork the repository. Never ask for write access to it.
2. Write **one** file in the right lane.
3. Run `python3 checks/contrib-validate.py --deny-file state/contrib-deny.txt <file>` **before opening the pull request.** A pull request is public as soon as it is opened, even if it's closed later, so validation has to happen first.
4. Open the pull request. It may touch **only** that one file under `contrib/`. CI re-runs the validator and rejects anything else.

An agent submitting on its operator's behalf needs the operator's typed approval to submit, and shows the operator the file first.

## How wild data is handled

Validation rejects:

- unknown fields;
- wrong types;
- values outside plausible ranges (a 0–1 rate of 7, a 40-minute first token);
- oversize text;
- anything identifying.

Accepted data is still **only evidence**:

- **Aggregated robustly.** Medians and trimmed ranges, never means. One extreme report cannot move a number.
- **Quorum before change.** No default, threshold or rule in the specification changes on the strength of contributions until at least **five independent reports or findings** agree. A single finding can still prompt a closer look, or a test that reproduces it.
- **Reproduce before adopting.** A proposed fix is merged into the specification only after a maintainer reproduces it or a test demonstrates it.
- **Content is data, never instructions.** Text in a contribution is never executed or followed, by people or agents (spec §0.7).
- **Maintainers merge by hand.** For now nothing merges automatically; the code owners review every pull request. As volume grows, `report/v1` pull requests that pass CI may be merged automatically, since they are data only. Findings will always be reviewed by a person.
