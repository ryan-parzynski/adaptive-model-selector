# Fleet Findings for Spec Update (2026-10-16)

**Box:** `<hermes-box>` (LXC container) · **Date:** 2026-10-17

## Blockers Fixed This Session

| Blocker | Severity | Fix | Verified |
|---------|----------|-----|----------|
| **GPU GPU CPU-only** | High | Device node mismatch corrected (earlier fix, mtime 2026-10-16 14:05). UVM node now at correct major/minor. | ✅ `nvidia-smi` shows GPU; `/api/ps` shows `100%GPU`, `3.38 GiB VRAM`; `inference compute=CUDA` |
| **Aux chains inverted** | High | Three auxiliary heads moved off paid provider to local lanes: `approval` → local-4b, `memory_query_rewrite` → local-4b, `compression` → local-9b. Only 3 aux blocks differ from backup. | ✅ **Live verified**: 5 real calls observed post-change. Config backup created with timestamp. |
| **Alert path dead** | Critical | **Rebuilt self-hosted ntfy v2.31.1** (checksum-verified). Regenerated `server.yml`, admin user, token. Restored both scripts from prior commit. Rotated alert token. Re-created watchdog cron. | ✅ **Real alert delivered** — watchdog job message read back from server topic. Verified end-to-end. |

## Lane Performance (Post-Fix)

| Lane | Role | Warm 4B T1 | GPU | Headroom |
|------|------|-----------|-----|----------|
| **<lane-1>** (16 GB) | capacity/deep | **64.8 tok/s** | 100% GPU | ~13 GiB free |
| **<lane-2>** (8 GB) | fast/interactive | **37.9 tok/s** (was 11.7 CPU-only) | **100% GPU now** | ~4.6 GiB free |
| **<lane-3>** (12 GB) | fallback | **61.7 tok/s** | partial | **~1.1 GiB — the constraint** |

**GPU lane before/after (same input, one-shot):**

| Metric | Before (CPU) | After (GPU) | Improvement |
|--------|--------------|-------------|-------------|
| Cold load | 234.47 s | 7.91 s | **29.6×** |
| Warm T1 | 37.36 s | 0.53 s | **70×** |
| Generation | 11.68 tok/s | 37.86 tok/s | **3.2×** |

## Findings That Remain Open

- **Fallback lane OOM-evicting** under high model concurrency (only 1.1 GiB headroom, two >5 GiB models)
- **Lane GPU status invisible to standard tools** — device mismatch hid CPU-only inference; only container-native Ollama `inference compute` line tells the truth
- **Fast lane eviction races** — model pairs cause switches, 4.5–7.2 GiB reload penalties
- **Fallback timeouts uniform, not per-lane** — single timeout per task but measured cold loads differ 30× across lanes
- **Stream stale timeout outside spec range** (currently 90; spec requires 120–300)
- **Delivery ledger writes nothing** — 0 rows despite verified delivery; ledger frozen since prior session
- **Credit watchdog false failures** — parser issue with response shape; actual balance is fine

## Spec Implications

1. **Alert path is a critical failure class** — failed silently in three layers (no platform block, self-referential server, deleted stack). Assert **delivered row in ledger within N minutes of a known event**, not just a configured channel.
2. **Lane GPU status must be probed live per-lane** — read container-native compute status and VRAM, never host-level tools alone. Device mismatches are invisible to host-level queries.
3. **Aux chain order driven by measurement, not configuration** — for four days the highest-frequency tasks were pinned to slowest lane while faster lanes idled.
4. **VRAM headroom, not model size, decides co-residency** — per-lane timeout windows should derive from measured load time, not global settings.
5. **Adaptive unload (from peer box) belongs here after residency is deterministic** — otherwise will fight the OOM evictor.

## Files Created/Modified

- Alert platform files — rebuilt server, state, scripts
- Dotenv file — rotated alert token
- Main config — added alert platform config block
- Findings doc (this file)
- Session summary — documented all changes

All changes backed up; no secrets in this document.
