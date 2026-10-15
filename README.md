# Adaptive Model Selector — Hermes Model Switcher specification

**AI-assisted creation.** This specification was developed with substantial
assistance from large language models. Human authorship directed the design,
reviewed the drafts, and made the editorial decisions. The specification's
content should be evaluated on its technical merits. Where a claim is wrong,
the provenance is not the reason.

**A portable specification for safe, auditable model routing on Hermes boxes.**

The specification names the failure modes that break model routing, states the
rules that prevent them, and gives runnable checks that report what is true
instead of what was assumed. It is written to be forked: the rules travel,
the values are per-box.

## What this is

- **A rule set.** Forty-two numbered invariants, seven failure classes (numbered 1–4 and 6–8), and the
  procedures that enforce them.
- **A specification, not an implementation.** The rules bind to model routing
  policy; where they bind to a specific runtime build, they say so.
- **A record.** Every rule traces to an observed incident or a named decision.
  The record is in Part III of the document and is meant to be read.

## What this is not

- Not a model catalog. Model ids are examples; the real ones come from your
  deployment's registry.
- Not a finished tool. The checks are starting points; run them against a test
  config before trusting them on a live box.
- Not bound to any single provider. The specification was developed against the
  Hermes agent stack; the rules generalise.

## Read this first

1. **`HERMES-MODEL-SWITCHER.md` — Part I (Rules).** The portable rule set.
   This is the part a fork adapts.
2. **`HERMES-MODEL-SWITCHER.registry.yaml`.** Fill it in. The document is
   incomplete without it — every `{{placeholder}}` resolves here.
3. **`HERMES-MODEL-SWITCHER.md` — §10 (Verification checklist).** Run the
   checks against your box. Every check returns PASS, FAIL, or CANNOT-OBSERVE;
   a read error is never PASS.

Part II of the document is the runbook (tested scripts will live in `checks/`; not yet written). Part III is
the record — incident history, decisions, and the reference deployment findings.
Read it or don't; the rules stand alone.

## Repository layout

    HERMES-MODEL-SWITCHER.md              the specification
    HERMES-MODEL-SWITCHER.registry.yaml   values the spec references
    HERMES-MODEL-SWITCHER.sha256          integrity sidecar
    docs/rule-cards/                      one rule per card: why, when, how to verify
    docs/two-axis-reporting.md            applicability vs. check result
    docs/capability-questionnaire.md      which rules apply to your setup
    docs/doctor-design.md                 read-only discovery tool (design)
    docs/adapters/                        provider notes (dated; limits are read live)
    CHANGELOG.md                          version history

A `checks/` directory of tested scripts is planned; it does not exist yet.

## Status

- **Version:** 3.3.1
- **Verified:** source-verified against the running stack. The checks embedded
  in §10 are **illustrative, not tested scripts**; several have known defects.
  Do not copy them onto a live box. Tested checks will ship as files.
- **Open items:** named in the document's §16 (open questions) and Record 5
  (open items at publication). The specification is honest about what is not
  yet live-run-verified.

## Contributing

Discussion in **GitHub Discussions**; concrete bugs and proposals in **GitHub
Issues**. If a rule here is wrong for your environment, open a Discussion and
say so. Rules that fail against a real deployment are the most valuable input
this specification can receive.

## License

GPL-3.0 for the **whole repository**: the specification, rule cards, examples,
scripts, reference implementation and documentation. See `LICENSE`.

## Relationship to earlier work

This repository previously held an earlier reference implementation (`core/`,
`scripts/`, `tests/`, `docs/`) of a cost-aware model selector. That
implementation's rules were absorbed into the specification; the code was
removed in the v3.2 rewrite. The earlier history is preserved in the
repository's commit graph.