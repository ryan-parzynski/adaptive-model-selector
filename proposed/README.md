# proposed/

Ideas that are **not** in the active specification yet.

## The three-question rule

Before any suggestion (from a review, a maintainer, an adopter or an agent) enters `HERMES-MODEL-SWITCHER.md`, it must answer:

1. **What observed failure does it prevent?** Name the failure that was actually seen, not one that could happen.
2. **What runtime or provider capability does it assume?** If that capability hasn't been verified on a real box, say so.
3. **What evidence would make it provisional, validated or rejected?**

A suggestion without good answers to all three waits here, as a short note with those three answers filled in as far as possible. It moves into the spec when a real box produces the evidence.

## Currently parked

- **Adaptiveness levels 3 and 4:** small-model intake for ambiguous requests; canaries and drift detection.
- **Model life-cycle states:** stable / watch / quarantine / retire.
- **Per-mechanism daily token budgets** and cost-per-prevented-failure reporting.
- **Weekly keep / raise / lower level recommendations.**
- **Broad adaptive evaluation sampling.**
- **Extensive canary infrastructure** beyond a small daily spot check.

None of these is wrong. None has earned its complexity yet: the basic switcher has to work end to end first.
