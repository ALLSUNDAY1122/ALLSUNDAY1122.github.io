# L1-A31 Validation — Provider Delete Reconciliation Observation Ordering

State: `COMPLETE_NON_PARITY`

Parity claim: `NONE`

## Why this wave existed

A29 introduced durable, hash-bound provider-delete observations and A30 made `observed_not_applied` evidence resumable after restart without replaying the provider DELETE. The remaining correctness gap was observation ordering: an older non-terminal observation could arrive after a newer applied observation and overwrite the newer registry state.

That is unacceptable for deletion/privacy recovery because network delay, provider-console lag, support responses, or delayed maintenance work can reorder evidence.

## Implementation

`Separation/Server/provider_delete_reconciliation.py` is advanced to `L1-A31-v1`.

The reconciler now serializes the complete single-host ordering decision plus privacy-registry mutation with a dedicated POSIX flock application lock.

For each `(logical_job_id, object_kind)`:

1. observations older than the newest already-applied observation are durably classified `superseded_stale` and never mutate the registry;
2. equal-timestamp evidence with the same object hash and observed state is accepted as equivalent evidence without changing registry state;
3. equal-timestamp evidence that conflicts on object hash or observed state fails closed with `SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT` and stays pending;
4. newer evidence still passes the existing delete-reservation, registered-object hash, and terminal-state checks before mutation;
5. terminal erasure states remain monotonic and cannot be downgraded to `present`/`unknown`;
6. repeated identical receipts remain idempotent;
7. `resume_pending` can resolve an old persisted pending event as `superseded_stale` after a newer observation has already been applied, without provider DELETE replay.

`snapshot()` now exposes `superseded_stale_count` in addition to pending reconciliation count.

## Tests / evidence

New repository regression:

- `Separation/Tests/test_provider_delete_reconciliation_ordering.py`

It covers:

- stale late observation rollback prevention;
- equivalent equal-time observations;
- conflicting equal-time observations;
- repeated receipt idempotency;
- terminal downgrade rejection;
- wrong-object hash rejection;
- restart/resume with an older pending observation;
- concurrent out-of-order single-host observation delivery.

A focused interface-compatible ordering model was executed during this wave: `8/8 PASS`, zero failures/errors.

Machine-readable evidence:

- `Processing/Tests/L1-A31_RECONCILIATION_ORDERING_MATRIX.json`

## Exact-checkout boundary

At wave start, A26 exact-checkout access was retried with `git ls-remote`. It again failed with:

`Could not resolve host: github.com`

Therefore the complete repository unittest discovery and `lane1_dependency_audit.py --expected-git-head <exact current tip>` were not executed on an exact Worker checkout. A26 remains current and incomplete. This document does not convert focused tests into a full-suite claim.

## Safety boundaries

A31 does **not** establish distributed/multi-host serialization. The reconciliation ledger and application lock are still single-host POSIX-flock mechanisms. A real shared transactional authority with fencing/CAS semantics is required before multiple hosts may mutate this state.

A31 does not invent or call provider deletion/status APIs. Real API/console/support observations remain external/private evidence. Raw provider IDs and private authority material remain excluded from durable public evidence.

## PARITY boundary

A31 is correctness/privacy hardening only. It does not prove current-iPhone deletion UX, production-provider deletion behavior, integrated account/project deletion, real audio/runtime behavior, or Moises differential equivalence.

`MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021`, `MOI-P024`, and `MOI-P025` therefore remain `MISSING` unless HQ changes them from real integration/device/runtime evidence.
