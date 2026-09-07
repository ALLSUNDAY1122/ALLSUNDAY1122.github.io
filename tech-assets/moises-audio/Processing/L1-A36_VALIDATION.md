# L1-A36｜Dependency Audit Safety-Surface Closure

State: `COMPLETE_NON_PARITY`

PARITY claim: `NONE`

## Why this wave exists

`L1-A26` is the Lane 1 full regression / dependency-closure audit. Its existing explicit dependency inventory was created before A27-A35 and still required only the A21-A26 generation/retention surfaces.

That created a false-green path: a later safety module and its related regression files could be deleted together, shrinking unittest discovery while leaving the old A26 explicit dependency checks satisfied. The owned-source snapshot would truthfully describe the smaller tree, but it did not by itself declare that the missing post-A26 surface was required.

A36 closes that gap inside the existing A26 `dependency_contracts` result. It does not close A26 itself because exact Worker-checkout execution is still unavailable.

## Implementation

`Separation/Evaluation/lane1_dependency_audit.py` now explicitly requires the following post-A26 safety modules:

- `Separation/Server/mutation_topology.py` — A27/A35 deployment topology safety;
- `Separation/Server/privacy_retention.py` — A28 same-host privacy registry durability/serialization;
- `Separation/Server/provider_delete_reconciliation.py` — A29-A34 observation-only deletion reconciliation.

Missing modules fail with:

- `L1A36_REQUIRED_SAFETY_FILE_MISSING`

The audit also explicitly requires the critical regressions that protect these surfaces:

- `test_mutation_topology.py`;
- `test_privacy_retention.py`;
- `test_privacy_retention_concurrency.py`;
- `test_provider_delete_reconciliation.py`;
- `test_provider_delete_reconciliation_resume.py`;
- `test_provider_delete_reconciliation_ordering.py`;
- `test_provider_delete_reconciliation_crash_atomicity.py`;
- `test_provider_delete_reconciliation_temporal_causality.py`;
- `test_provider_delete_reconciliation_documented_expiry.py`.

Missing required regressions fail with:

- `L1A36_REQUIRED_REGRESSION_MISSING`

The original A21-A26 required-file checks, stale A24 schema rejection, A24 coordinator/reference-graph checks, A24/A25 gateway surface check and A25 retention-expectation checks are preserved.

The report schema remains v2 and `TOOL_VERSION` remains `L1-A26-v2`; A36 strengthens `dependency_contracts` without changing the machine-readable report shape.

## Regression

New repository regression:

`Separation/Tests/test_lane1_dependency_audit_safety_surfaces.py`

It covers eight cases:

1. complete safety-surface inventory passes;
2. missing topology module fails closed;
3. missing privacy module fails closed;
4. missing reconciliation module fails closed;
5. missing reconciliation regression fails closed;
6. missing topology regression fails closed;
7. legacy A24 surface validation remains active;
8. stale A24 schema validation remains active.

Focused validation against an interface-compatible implementation of the final `_dependency_checks` logic plus the repository regression body:

- `py_compile`: PASS
- unittest: 8/8 PASS
- failures: 0
- errors: 0

Remote readback after write:

- `lane1_dependency_audit.py`: `6210a1f3d2bfb2f8de1fe9055f89e1fd27a5992a`
- `test_lane1_dependency_audit_safety_surfaces.py`: `dd4de00e38385abbf242653b985bd75af3b47c67`

Exact current Worker-branch unittest discovery remains `NOT_OBSERVED` because the full checkout/CI execution gate is unavailable.

## A26 remains open

At the start of this wave the exact checkout retry again failed with:

`Could not resolve host: github.com`

Therefore A26 remains:

`HEAD_TREE_BOUND_EXACT_CHECKOUT_AUDIT_PENDING`

When an executable exact checkout or CI runner becomes available, run:

`Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact final Worker branch tip>`

A26 may close only when the resulting report has:

- `overall_state=PASS`;
- `git_head_binding.state=PASS`;
- `owned_source_snapshot.state=PASS`;
- `dependency_contracts.state=PASS`;
- `unittest_discovery.state=PASS`.

Because A36 changes owned source bytes and adds a regression, the audit must use the then-current final Worker tip, never an older A26-A35 commit.

## PARITY boundary

A36 is audit-integrity engineering evidence only. It does not promote P003, P004, P005, P020, P021, P024 or P025. Real current-iPhone, real-audio, live-provider and HQ integrated evidence remain required.
