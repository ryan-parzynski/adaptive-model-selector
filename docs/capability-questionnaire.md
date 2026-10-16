# Capability questionnaire

**Status:** PROPOSED.

The specification is written for many different setups: a free-only hobbyist, a single paid key, paid models plus local GPUs, several independent boxes. This questionnaire is how a box finds out **which rules apply to it**. Answers feed the applicability axis described in `docs/two-axis-reporting.md`.

Two kinds of question:

- **Capability** — a fact about the box. `doctor` should detect it where possible; the operator answers where it cannot. Values: `present` · `absent` · `unknown`.
- **Policy** — a choice the operator makes. There is no detection, only a declaration. An undeclared policy is `unknown`, and `doctor` asks for it.

An answer of `unknown` is legitimate. It makes the dependent rules `unknown`, and `doctor` keeps listing the question until it is answered. It never quietly turns rules off.

---

## Providers and budgets

| ID | Question | Kind | Detection | Rules it gates |
|---|---|---|---|---|
| C1 | Does the main session use a model with a **bounded free allowance** (a daily or rolling request cap)? | capability | Provider adapter: classify configured models; read the allowance | Reserve; recovery-instant logging; schedule-vs-reset; free-return hysteresis |
| C1a | Is that allowance **per-model** or **account-level**? | capability | Provider adapter, from provider docs or observed 429s. Unknown → treated as account-level (see note) | Fallback eligibility (T1) |
| C1b | Is the allowance a **fixed daily reset** or a **rolling window**? | capability | Provider adapter / docs | Schedule-vs-reset (§4.13b) |
| C2 | Is a **paid tier** configured and permitted by policy? | capability + policy | Config inspection; operator declaration | Fail-closed-to-paid; spend guards; 402 handling |
| C2a | Is there a **provider-side spending cap** on the paid key? | capability | Operator declaration (most providers expose it only in their dashboard) | Spend guard; "unprotected" statement in the box record |
| C3 | Can the remaining allowance be **read without spending it**? | capability | Provider adapter: zero-cost quota endpoint present and parseable | Token discipline; all quota-dependent checks (`cannot-observe` if not) |
| C4 | Is there a **second provider or second key** — an independent API route? | capability | Config inspection | Escalation target under auth/unreachable failures (§4.9) |

**Note on C1a.** When the scope of a free limit is unknown, treat it as **account-level**. The cost of that assumption is a paid tick that might have been avoidable; the cost of the opposite assumption is a fallback that 429s the same way the primary did, mid-session.

## Local models

| ID | Question | Kind | Detection | Rules it gates |
|---|---|---|---|---|
| C5 | Does the box have **local or self-hosted models** reachable from Hermes? | capability | Classify configured endpoints by address (private ranges, loopback, tailnet), not by name (§3.16) | Local-as-main; tail rule; inference-port access control; local inventory |
| C5a | Has the **latency profile** of each local model been measured (time to first answer chunk, p95, by model class)? | capability | Probe history / probe-budget table | Local-as-main (whether local may serve the main session) |
| C5b | Are any local models **hosted by another box**? | capability | Operator declaration; endpoint inspection | Cross-box dependency recording |
| C5c | Is there a current **capability profile** for this box (GPU, memory, RAM, admitted models with measured resource use)? | capability | Read `capability_profile_file` (§31.7); see `docs/examples/capability-profile.example.yaml` | Admission (invariant 46); local tiers |
| C5d | Which **local tiers** does the box have: fast, capacity, specialized? | capability | From the capability profile | Tier escalation and resource guards (§31) |

## Alerting

| ID | Question | Kind | Detection | Rules it gates |
|---|---|---|---|---|
| C6 | Is there an **alert destination outside the box** that a human watches? | capability | Hermes delivery config | Every "fail loud" rule |
| C6a | Has a test message to it **succeeded end-to-end** within the verification window? | capability | Last successful delivery timestamp | Whether "loud" holds (invariant 34) |
| C6b | **Alert state:** `absent`, `configured-failing` (configured or claimed connected, but the last delivery failed, was suppressed, or resolved no target), or `verified`? | capability | Delivery config plus the job ledger's last *successful* delivery | Configured-failing is a FAIL that cannot be acknowledged and blocks enabling automated writers (§0.6) |
| C14 | Is there a **writer registry**, and does every writer of routing state have a kind other than `unknown`? | capability | `checks/writer-registry.py` | Implementation readiness (invariant 47) |
| P6 | If there is no alert destination: does the operator **acknowledge running unalerted**? | policy | Declaration | Turns dozens of "not loud" failures into one recorded limitation (handoff E11) |

## Boxes

| ID | Question | Kind | Detection | Rules it gates |
|---|---|---|---|---|
| C7 | Does the operator run **more than one box**? | capability | Declaration | Cross-box reporting (optional) |
| C7a | Do any boxes **share a provider account or quota**? | capability | Declaration | Shared-budget accounting. For independent boxes this is `absent` and the rules are not applicable. |
| P7 | Which properties are **declared shared** across boxes (e.g. spec version, policy version)? | policy | Declaration | Cross-box comparison — only these are compared; all other differences are informational |

## Hermes runtime

| ID | Question | Kind | Detection | Rules it gates |
|---|---|---|---|---|
| C8 | Which **switch mechanisms** exist on this build: sanctioned helper, dashboard endpoint, scoped `/model` flags (`--once` / `--session` / `--global`), persist-by-default key? | capability | Hermes adapter: source inspection, then a live probe in a scratch home | Which writer the selector may use; scope rules |
| C8a | Can the selector reach a **running session** to switch it? | capability | Hermes adapter | Signal-scope rule (§5.8): per-session action vs advisory |
| C9 | Does the runtime **fall through to the next fallback on timeout**? | capability | Source check plus a black-box test (§10.28) | Aux-chain head choice (§4.18); local-as-main |
| C10 | Which **stream-stale timeout key** does the runtime read, and where in the config? | capability | Hermes adapter | Timeout check |
| C11 | Is one `fallback_providers` list used for **both main and auxiliary** traffic? | capability | Source inspection / trace | Tail rule (§6.3a) |
| C12 | Can `config.yaml` be **rewritten without destroying comments and key order**? | capability | Hermes adapter: round-trip a copy and diff | Whether a direct writer is allowed (handoff E1) |
| C13 | Does the scheduler **prevent overlapping runs** of the selector? | capability | Inspect schedule; `flock` presence | Tick-overlap guard |

## Operator policy

| ID | Question | Kind | Values | Rules it gates |
|---|---|---|---|---|
| P1 | **Manual-override window** — when someone changes the default model by hand, how long should the selector pause before re-planning? | policy | hours; **default 4**, 4–6 recommended (`manual_override_hours`) | Foreign-write handling (§4.14a, invariant 41) |
| P1a | A **hold** — a pause with no expiry — is requested per override (`switcher hold`), not configured. | — | — | Same |
| P2 | Is **local** allowed for the main session at all? | policy | `never` · `when-measured-fast-enough` | Local-as-main rule card |
| P3 | Which **work types** are routed (text only, or also image / code / reasoning)? | policy | list | Work-type routing (§4.16) |
| P8 | Which **capacity-tier triggers** are enabled (explicit request, deep work type, hard failure, background work)? | policy | subset of the four; default all four | §31.3 |
| P9 | **Capability floors and escalation envelope:** a starting floor per work type, the maximum escalation steps, and the daily paid envelope for escalated runs | policy | `capability_floors`, `escalation_max_steps`, `escalation_daily_budget` | §4.19, invariant 48 |
| P10 | **Long-job safeguards:** pre-approval threshold, soft-limit percentage, progress-breaker settings, heartbeat interval; and which work types may let their track record change model selection | policy | `job_preapproval_usd`, `job_soft_limit_pct`, `breaker_repeat_n`, `breaker_no_progress_minutes`, `heartbeat_minutes`, `capability_sample_floor`, `exploration_share` | §4.20, §4.21, invariants 50–51 |
| P11 | **Alert destination:** a push channel (ntfy, a runtime chat channel such as Discord or Telegram), in-app notices, both, or **undecided** for now | policy | — | §0.6 |
| P12 | **Shared lanes:** which local lanes are shared, which switcher leads each, the guest timeout, and the sampler interval | policy | `shared_lane_leads`, `guest_first_token_timeout_s`, `lane_sample_minutes` | §6.4b, §30.9, invariants 52–53 |
| P13 | **Spending layers:** box daily cap (or leave unset for the adaptive cap, with an optional ceiling), chat window cap and length, interactive reserve, the time zone for daily resets; which provider limits exist and whether one account is shared by several boxes | policy | `box_daily_cap_usd`, `session_window_cap_usd`, `session_window_hours`, `interactive_reserve_pct`, `auto_cap_multiple`, `auto_cap_start_usd`, `auto_cap_max_usd`, `budget_day_tz` | §4.22, invariant 54 |

**Note on P1.** A manual change is respected, not reverted. The selector writes nothing for the window, then logs the resume, announces it through the alert path if one is verified, and re-plans; it writes only if the current policy still picks a different model. A hold keeps the pause until `switcher resume`. (§4.14a.)

**Note on C1–C3.** Limits and their structure are read from the provider every tick (§4.9a-bis, invariant 42). Never answer these from remembered numbers.

---

## How `doctor` uses this

1. Detect every capability it can; mark the rest `unknown`.
2. Read declared policies; mark undeclared ones `unknown`.
3. Resolve each rule's applicability from its `applies_when`.
4. Run checks for applicable rules only.
5. Print the unresolved questions first, because they decide what the rest of the report means.

See `docs/doctor-design.md`.
