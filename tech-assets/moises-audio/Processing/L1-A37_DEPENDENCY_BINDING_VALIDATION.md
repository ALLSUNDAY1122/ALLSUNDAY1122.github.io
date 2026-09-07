# L1-A37 Dependency Binding Validation

## Why this follow-up is part of A37

A37 introduced a new safety-critical module and a new regression file after the A36 dependency-safety audit was authored. Without updating the audit, a future change could remove both the A37 implementation and its test while the dependency inventory still reported green. That is a paired-deletion false-green risk, so A37 is not considered internally complete until the new surface is bound into the existing A26 audit.

## Change

`Separation/Evaluation/lane1_dependency_audit.py` is upgraded from `L1-A26-v2` to `L1-A26-v3`.

The dependency contract now requires both:

- `Separation/Server/provider_delete_conflict_resolution.py`
- `Separation/Tests/test_provider_delete_reconciliation_conflict_resolution.py`

The complete synthetic dependency inventory therefore increases from 23 to 25 checks.

## Focused regression

`Separation/Tests/test_lane1_dependency_audit_safety_surfaces.py` now covers 11 focused cases, including:

- complete inventory passes with 25 checks;
- missing A37 module fails closed;
- missing A37 regression fails closed;
- simultaneous removal of the A37 module and regression fails with both missing-surface findings;
- prior topology/privacy/reconciliation guards remain present;
- legacy A24 surface and stale-schema checks remain present.

An isolated contract-compatible execution of this focused test suite passed **11/11**, with 0 failures and 0 errors.

## Non-claim

This closes a dependency-audit blind spot only. It does not close A26's exact-final-tip execution gate. The final one-command audit still needs an executable full Worker checkout or CI runner so git-head binding, owned-source snapshot, dependency contracts and full unittest discovery can all be observed on the same exact branch tip.

No PARITY row is promoted by this work.
