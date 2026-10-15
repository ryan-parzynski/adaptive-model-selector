# OpenRouter adapter notes

**Observed:** 2026-10-15, from OpenRouter's limits documentation (https://openrouter.ai/docs/api-reference/limits).
**Subject to change.** These notes say *where to read* limits, not what the limits are. The adapter reads every value live on each tick (invariant 42). The numbers below are examples to recognize, never values to code against. Re-verify against the documentation when the adapter is built and whenever a field goes missing.

## Where the adapter reads limits

`GET https://openrouter.ai/api/v1/key` with the provider key in the `Authorization` header. The adapter sends the key through stdin or a mode-600 config, never on a command line (invariant 31). Reading this endpoint costs no model requests.

| What the adapter needs | Field (under `data`) as documented | Notes |
|---|---|---|
| Free allowance counter | `free_model_daily_requests.used`, `.limit`, `.remaining` | Daily, in UTC. The cap changes with account state (below); read `limit` every tick, not just `remaining`. |
| Whether the account has ever bought credits | `is_free_tier` | Informational. The documentation says the free cap depends on credits purchased, **not** on this flag. |
| Key credit limit | `limit`, `limit_remaining`, `limit_reset` | `null` means unlimited / never resets. |
| Spend budgets | `budgets[]` (with `limit_usd`, `spend_usd`, `remaining_usd`, `reset_interval`, `resets_at`), `effective_budget` | `resets_at` is an explicit reset instant: prefer it over a computed boundary (§4.9a-bis). |
| Spend so far | `usage`, `usage_daily`, `usage_weekly`, `usage_monthly` | UTC day; week starts Monday. |
| — | `rate_limit` | Documented as deprecated; do not use. |

## Structure as documented on 2026-10-15

- **Free models** (`:free` variants): a per-minute rate limit and a daily request limit. The daily cap was documented as higher for accounts that have purchased credits above a threshold. *Example only: 20 requests/minute; 50/day below the threshold, 1,000/day above it.*
- **Window:** free and spend windows reset at 00:00 UTC; weekly on Monday, monthly on the 1st.
- **Scope:** extra keys or accounts do not raise limits, so the free limit is not per key. The documentation does not say whether the daily counter is per account or per model. **The adapter reports scope `unknown`, which §4.9a-bis treats as account-level.**

## Error classes the adapter must map

The rules bind to failure classes (§4.9), not to codes. Documented mappings on 2026-10-15:

| Documented response | Class for §4.9 |
|---|---|
| 429 on a `:free` model | Free-model-only fault, or free allowance exhausted — confirm against `free_model_daily_requests.remaining` |
| 402, `limit_source: openrouter_key_limit` | Paid credit or spend limit reached (key limit) |
| 402, `limit_source: openrouter_credits` | Paid credit limit reached (insufficient balance) |
| 402 on free models too, with a negative balance | Account balance negative — do not switch |
| 402, `reason: in_flight_budget_exhausted` | Transient; honor `Retry-After`, do not change tiers |
| 403 from a guardrail, workspace, or key budget | Spend limit reached (budget), not an auth failure — check the error body before classifying a 403 as auth |
| 401 | Auth |

The 403 row matters: §4.9 treats 401/403 as auth failures (do not switch). On OpenRouter a 403 can also mean a spent budget. The adapter must read the error body to tell them apart. If it cannot, the class is unknown and the box holds.

## To verify when building the adapter

1. Every field above still exists with the documented meaning, on the running account.
2. Whether the free daily counter is per account or per model. If it can be observed — for example, by two free models drawing from one counter — record the scope; otherwise leave it `unknown`.
3. The exact error bodies for 402 and 403 cases, captured as test fixtures.
