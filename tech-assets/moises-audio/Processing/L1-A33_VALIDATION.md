# L1-A33 Validation｜Provider Delete Reconciliation Temporal Causality

State: `COMPLETE_NON_PARITY`

Parity claim: `NONE`

## Why this wave existed

A29-A32 made ambiguous provider-delete recovery durable, resumable, monotonic and crash-safe on one host. A32 still trusted `ProviderDeletionObservation.observed_at_epoch` as an ordering input without establishing temporal causality relative to the durable delete request or the local runtime clock.

That left two correctness hazards:

1. a provider observation created **before** the delete request could be supplied later and incorrectly used as evidence about post-delete erasure; and
2. a valid-hash observation with an erroneous far-future timestamp could become an `applying`/`applied` ordering watermark and suppress legitimate later evidence for a long period.

## Implementation

`Separation/Server/provider_delete_reconciliation.py` is now `L1-A33-v1`.

Before a resumable observation may transition from `observed_not_applied` to the A32 `applying` watermark, the reconciler now requires:

- the provider object hash to match the durable privacy registry;
- `provider_delete_requested == true`;
- a valid positive `delete_requested_at_epoch`;
- `observed_at_epoch >= delete_requested_at_epoch`;
- `observed_at_epoch <= now_epoch + max_future_skew_seconds`;
- the existing A29-A32 terminal-erasure monotonicity rules.

The default future skew is 300 seconds and can be explicitly configured. Invalid skew configuration or an invalid runtime clock fails closed.

Temporal validation is intentionally performed **before** `mark_applying`. A temporally invalid observation can remain durable as `observed_not_applied` for diagnosis/operator correction, but it does not become an ordering authority. A later causally valid observation therefore remains eligible to apply.

The registry mutation repeats the delete-epoch causality check so a concurrent registry mutation cannot bypass the pre-watermark validation path.

## Stable errors added

- `SEP_PRIVACY_RECONCILE_DELETE_EPOCH_INVALID`
- `SEP_PRIVACY_RECONCILE_OBSERVATION_PRECEDES_DELETE`
- `SEP_PRIVACY_RECONCILE_OBSERVATION_FROM_FUTURE`
- `SEP_PRIVACY_RECONCILE_CLOCK_INVALID`
- `SEP_PRIVACY_RECONCILE_FUTURE_SKEW_INVALID`

## Tests / evidence

A focused interface-compatible temporal-causality model was executed locally:

- tests: **8**
- failures: **0**
- errors: **0**
- result: **PASS**

It covered pre-delete rejection, exact delete-epoch acceptance, beyond-skew future rejection, skew-boundary acceptance, invalid/missing delete epoch, invalid runtime clock and hash-validation ordering.

Repository regression committed:

`Separation/Tests/test_provider_delete_reconciliation_temporal_causality.py`

It contains 9 tests, including a durable invalid future observation followed by a valid lower-epoch observation, plus `resume_pending` stable-error behavior.

Machine-readable evidence:

`Processing/Tests/L1-A33_RECONCILIATION_TEMPORAL_CAUSALITY_MATRIX.json`

The implementation was read back remotely after commit as blob:

`07db9eceda29d6af190b18711e65c5959142a86d`

## Exact-checkout boundary

At the beginning of this wave, A26 exact checkout access was retried with `git ls-remote`. The container again failed with:

`Could not resolve host: github.com`

Therefore the exact current Worker-branch unittest discovery and `lane1_dependency_audit.py --expected-git-head <exact tip>` have **not** been observed. A26 is not complete and no unavailable CI/full-suite PASS is claimed.

## Safety / scope limits

A33 does **not** establish:

- multi-host/distributed synchronization;
- a provider-specific authoritative delete-status API;
- real provider deletion semantics;
- real current-iPhone deletion UX;
- real account/project deletion integration;
- `MOI-P024` PARITY;
- any other PARITY promotion.

`flock`, atomic rename, applying watermarks and temporal gates remain single-host controls. A real shared transactional backend with CAS/fencing is still required before independent multi-host writers are enabled.

## Integration requirement

HQ/App integration should preserve A28-A33 sequencing:

1. durable delete intent;
2. idempotent local delete;
3. provider side effect reserved once;
4. ambiguous external result remains non-confirmed;
5. separately observed hash-bound evidence only;
6. observation must be causally at/after the durable delete request and not implausibly future-dated;
7. durable `applying` watermark before registry mutation;
8. crash/relaunch uses `resume_pending` and never blind provider DELETE replay.
