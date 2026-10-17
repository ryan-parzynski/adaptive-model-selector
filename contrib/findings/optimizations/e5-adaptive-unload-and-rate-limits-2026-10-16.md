# E5 Findings for Spec Update (2026-10-16)

## Model Switching: What's Proven

| Feature | Status | Evidence |
|---------|--------|----------|
| Per-message model override | ✅ Verified | Prior session confirmed; session constraint prevented re-test |
| Session-scoped model selection | ✅ Verified | Prior session confirmed; session constraint prevented re-test |
| Global default not overwritten | ✅ Verified | Config read confirms default unchanged |
| Manual override preserved | ⚠️ Partial | Code inspection shows task overrides; session model preservation untested |
| Fallback chain on timeout | ✅ Partial | Logs show auto-recovery cycles on timeout (5 attempts) |
| Cap enforcement live | ✅ Verified | Dry-run confirms cap enforcement, paid lanes available |
| Rate limit handling | ❌ Missing | **Critical gap: selector keeps choosing rate-limited models (HTTP 429 errors)** |

## Adaptive Unload: Integration Decision

- **Integrated:** YES
- **Reason:** Timeout patterns observed in logs, VRAM contention evident on test hardware
- **Integration point:** Agent-level retry logic; scripts created for timeout history and adaptive retry
- **Test result:** Dry-run successful; pattern analysis recommends intelligent unload strategy

## End-to-End Task Flow

**Task:** Explain a complex concept in simple terms

**Initial model:** Free tier (OpenRouter)

**Fallback activations:** 0 (selector doesn't switch on rate limits)

**Final model:** Test incomplete due to rate limiting

**Cost:** $0

**Verdict:** Task would fail; no fallback triggered

**Key finding:** Selector checks quota (`remaining > reserve`) but not provider rate limits (HTTP 429). Free models frequently rate-limited upstream.

## Spec Implications

1. **Rate limit handling is critical missing feature** — selector should detect 429 and switch to alternative
2. **Adaptive unload ready** — timeout history functional, can integrate once routing stabilizes
3. **Model switching proven** — per-message and session-scoped overrides confirmed in prior session
4. **Session model preservation unclear** — needs dedicated test
5. **Ready for v3.16+** — core logic works; rate limit detection is the gate

## Findings That Remain Open

- Rate limit detection and fallback in selector (blocks full validation)
- Session model preservation vs. selector overrides (separate test needed)
- Long-term stability of adaptive unload (requires days of timeout data)
- Fallback chain cooldown per-lane tuning (varies 4× across lanes)
- API quota prediction under variable load

## Files Created/Modified

- Timeout history module (new)
- Adaptive retry logic (new)
- Timeout event ledger (new)
- Scripts backup (created before modifications)
