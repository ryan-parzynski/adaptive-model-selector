# Rule cards

**Status:** PROPOSED format.

A rule card keeps three things together that the long-form specification spreads across sections: **why a rule exists, when it applies, and how to verify it.** The goal is that an operator whose setup differs from ours can judge whether the rule fits, instead of inheriting our conclusion.

The exact layout matters less than keeping these sections together.

| Section | Contains |
|---|---|
| **Purpose** | The failure the rule prevents, in one or two sentences. |
| **Applies when** | Conditions, each tied to a question in `docs/capability-questionnaire.md`. Drives the applicability axis (`docs/two-axis-reporting.md`). |
| **Evidence** | The incident or reasoning behind the rule, the environment it was observed in, and its limits. Labelled with the claim states from §0.6 (OBSERVED, HYPOTHESIS, REPORTED, PROPOSED). |
| **Measurement** | Values the operator must measure rather than copy: unit, how to collect, uncertainty. |
| **Decision** | Condition → action, and what to do when no eligible alternative exists. |
| **Verification** | A read-only check, its expected result, and what makes it `cannot-observe`. |
| **Exceptions** | Situations where the rule should not be applied as written, and why. |
| **Spec references** | Sections and invariants this card consolidates. |

Cards so far:

- `quota-reserve.md` — hold back part of a bounded free allowance.
- `local-as-main.md` — when a local model may serve the main session.
