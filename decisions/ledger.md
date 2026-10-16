# Decision ledger

| Idea | Status | Why | Evidence | Date | Revisit when |
|---|---|---|---|---|---|
| "A running session keeps the model it started with" | **reversed** | One report, taken as settled | The operator's observation of one continuous session moving across 4 models; the runtime documents a session-scoped model command, and most observed switches were error fallbacks | 2026-10-16 | Live test of the session-scoped command confirms or refines it |
| "The switcher is in dry-run" | **reversed** | Inferred from a static log line | The scheduled command had no dry-run flag; the switcher had been writing live | 2026-10-15 | — |
| "The free-quota cap is hard-coded" | **reversed** | Misread counter | A provider counter that hadn't rolled over (pre-reset), not a constant | 2026-10-15 | — |
| "A GPU lane is offline" | **reversed** | Probed stale addresses from memory | The lane answered at its current name | 2026-10-15 | — |
| Local GPU lanes as main or background tiers | **set-aside** | Judged too slow | That judgment was made while one GPU host ran CPU-only (a hidden device-mapping fault) and another lane had no GPU access | 2026-10-15 | Both faults are now fixed. **Retest** per work class with the pilot's checks |
| Some auxiliary model slots on a local lane | **set-aside** | The lane's stability was unclear | A per-slot recommendation exists (non-blocking slots local; blocking slots on API) | 2026-10-16 | The lane is stable for 7 days |
| Embeddings on a second local lane instead of CPU | **set-aside** | The CPU fix was simpler | The CPU path costs about 2.4 s per cold embedding | 2026-10-16 | Embedding latency matters to a work class |
| Partial expert offload and a smaller KV cache for a large MoE | **set-aside** | Never tested | Proposed only | 2026-10-15 | Any MoE becomes a candidate tier |
| Smaller context window and parallel=1 on a busy local lane | **set-aside** | No shell access at the time | Measured co-residency headroom | 2026-10-16 | Shell access is available |
| `MAX_LOADED_MODELS=1` to stop MoE eviction | **rejected-measured** | Eviction was memory pressure, not the loader count | A second model evicted the MoE under either value | 2026-10-16 | The runtime's memory model changes |
| A per-tick 1-token probe for the per-minute rate limit | **rejected-measured** | Cost every tick for a signal 429 handling already provides | The provider's key endpoint doesn't report the per-minute limit; the 429 path detects it for free | 2026-10-16 | 429 handling proves insufficient |
