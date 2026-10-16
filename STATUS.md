# Status: what is proven and what isn't

**Specification freeze:** from v3.15 (2026-10-16), changes to the specification for about a week are limited to fixes found on real boxes. New ideas go to `proposed/` (see its three-question rule).

The specification grew quickly. Most recent sections are **experimental**: designed, reviewed, and partly implemented on test boxes, but not yet validated across adopters. This file says which is which.

| Area | Status | Evidence so far |
|---|---|---|
| Live limit reads, free-quota reserve, single owner of the default model, writer registry | **Proven on a box** | Implemented and self-tested on a reference box; registry check passes |
| Box daily paid cap (§4.22) | **Pilot** | Enforced on one box with fixtures; a second box in progress |
| Lane sampling (§30.9) | **Pilot** | Running on several lanes; two sampler bugs found and fixed (containers see the host's GPUs; load average isn't per container) |
| Shared lanes: one lead, guests yield (§6.4b); relays on inference nodes | **Pilot** | A relay moved off a hypervisor host onto an inference node and verified |
| Local last-resort fallback marked degraded | **Pilot** | Works, but surfaced a model loading CPU-only. Fallback eligibility must check GPU residency |
| Check-by-headroom cadence, switch damping, live limit changes (§4.24) | **Pilot** | Implemented with fixtures on one box |
| Capability-first selection (§4.20), quality-gated escalation (§4.19) | **Experimental** | Depends on whether the runtime supports per-task model overrides (being tested) |
| Long-job budget, breaker, heartbeat (§4.21) | **Experimental** | Not yet exercised |
| Anonymous contributions (`contrib/`), sharing off by default (§30.10) | **Pilot** | Validator tested; the first real contributions are being reviewed |
| Everything in `proposed/` | **Proposed** | None |

**Known open questions:**

- Can the runtime switch models for a single task, or only per session?
- Is per-request usage (tokens and cost) recorded, so cost can be tied to a task?
- Do separate API keys get separate rate limits and daily allowances, or only separate credentials? (Verify per provider.)

Updated as boxes report back.
