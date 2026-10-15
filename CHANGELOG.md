# Changelog

Version history of `HERMES-MODEL-SWITCHER.md`. Each version's detailed notes are at the top of the specification; Record 4 in Part III carries the same history in table form.

## v3.4 — 2026-10-15 — tested checks, edge cases, ledgers

- `checks/`: nine tested checks plus `checks/tests/run.sh` (55 fixture cases). They replace the defective inline scripts in the spec.
- Drift check compares only declared-shared properties; manifest now catches an edited fallback list.
- Edge cases: DST/UTC scheduling, kernel-released lock, decimal prices and every price field, empty catalog, delisted default, reset-header formats, single "unalerted" finding, provider-defined answer field, owner-change privilege.
- §30 observation and decision ledgers; invariants 43 (no conversation content) and 44 (descriptive before self-tuning); `docs/ledger-metrics.md`.

## v3.3.1 — 2026-10-15 — cleanup

- Cross-references corrected; §26.10 renumbered §26.9.
- Placeholders renamed to underscores (`tailnet_ip`, `card_1`..`card_3`).
- Router/guardrail exclusion (§4.4a) and "zero-price is free only for its work type" (§4.6) moved into the selection rules.
- Embedded registry declared a copy; the `.yaml` file is canonical.
- Record 4 and this changelog brought up to date.

## v3.3 — 2026-10-15 — rule pass

- **Two-axis reporting:** applicability (`applicable` / `not-applicable` / `unknown`) is separate from the check result (`pass` / `fail` / `cannot-observe`).
- **Manual override:** a model change the selector didn't make pauses it, 4 hours by default, or until resume when a hold is requested. The selector never reverts it (invariant 41).
- **Limits are read, not remembered:** provider limits and their structure are read live every tick; no hardcoded numbers (invariant 42).
- Fallback heads must not share the failed dependency.
- New failure classes: paid credit or spend limit reached, negative balance; a 403 is no longer assumed to be auth.
- Config writes must preserve comments and key order.
- Local-as-main: a default rule with a measured, conditional exception.
- Corrections: sample floor (largest observed draw once ≥59 sessions), per-session measurement, local-inventory heartbeat, struggle-score scope, return-to-free hysteresis, aux-head inequality edge cases.
- New docs: rule cards, capability questionnaire, two-axis reporting, `doctor` design, OpenRouter adapter notes.

## v3.2c — 2026-10-15 — housekeeping

- LF line endings and `.gitattributes`.
- Embedded scripts marked illustrative and untested.
- Private deployment record filename removed.
- Whole-repository GPL-3.0 stated.

## v3.2b — 2026-10-13 — patch pass

See the v3.2b notes at the top of the specification.

## Earlier

v2.2 through v3.2a are described in Record 4 of the specification. The reference implementation that preceded v3.2 is preserved in the repository's commit history.
