# Rule card: local-capacity-tiers

**Status:** Adopted in v3.5. Consolidates §31, invariants 45 and 46.

## Purpose

Pick the right *local* model for the work: fast enough for interactive use, capable enough for hard work, never so large that it stalls the user or starves the machine. Prevent three failures: the largest model becoming the default because it is there; a capacity model exhausting memory and taking down other work; and routing to a model nobody has verified runs on this box.

## Applies when

| Condition | Questionnaire |
|---|---|
| The box has local models Hermes can route to | C5 = `present` |

Tier-specific parts apply when the box has more than one local tier (C5d). On a box with only a fast tier, escalation and the capacity-tier guards are not applicable; admission (invariant 46) still applies.

Whether local serves the **main session** is a separate decision: see `local-as-main.md`.

## Evidence

- **REPORTED (owner's deployment, 2026-10-15):** an MoE model with a large total parameter count, running with partial GPU/RAM offload, was substantially slower than smaller models fully in GPU memory. Treating it as a default would have slowed routine work without benefit.
- **OBSERVED (Record 6, Class 7):** local models answered correctly but slower than the runtime's per-chain timeout. On constrained hardware the model, not the routing, is the constraint.
- **Limitation:** the tier boundaries depend entirely on the hardware. A model that is "capacity tier" on one box may be "fast tier" on a box with more GPU memory. That is why tiers are measured per box (§31.7).

## Measurement

| Value | Unit | How to collect |
|---|---|---|
| Free GPU memory, free RAM, loaded models | MB; model list | Read just before a capacity-tier load (`local_resource_snapshot`) |
| Per-model resource use and offload split | MB; GPU/RAM/CPU | At admission, from the serving runtime |
| Per-model time to first answer | seconds, p95 | At admission, then sampled (`time_to_first_answer`) |
| Known-working context size | tokens | At admission |

## Decision

| Situation | Action |
|---|---|
| Any local work, no escalation trigger | Fast tier |
| Explicit request, explicit deep work type, hard failure of the fast tier, or background work | Capacity tier, **if** admitted and resources allow |
| Capacity tier short of resources | Reduce context → admitted smaller quantization → fast tier |
| Capacity tier busy or too slow | Fast tier, with a visible note |
| Model not admitted on this box | Not routed; deferred with reason |
| Fast tier's answer judged "inadequate" by the model itself or a heuristic | **Record only** — not a trigger until validated (invariant 44) |

**Never without authorization:** enable swap, unload or delete a working model, download a model, change a model's quantization.

## Verification (read-only)

1. Read the capability profile. Missing on a box with local models → `fail`. Unreadable → `cannot-observe`.
2. For every local model in any routing path, check it appears in the profile as admitted, with resource use and latency. Any routed model not admitted → `fail`.
3. Check that the default for local work is a fast-tier model → otherwise `fail`.
4. Check the selector and scripts contain no commands that enable swap, unload, pull or delete models outside an operator-invoked path → any found → `fail`.
5. Otherwise → `pass`.

## Exceptions

- **Single-tier boxes:** escalation rules are not applicable.
- **Operator-pinned model:** a user who explicitly picks a model for their session has made that choice (§2.7); this card governs the selector, not users.
- **Experimental work:** an operator may route to a deferred model in a scratch session to test it. That is the admission process, not routing.

## Spec references

§31, §6.3, §6.4a, §7.2, §4.15, §4.17, §4.18, invariants 9, 44, 45, 46.
