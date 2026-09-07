# L1-A34｜Provider Delete Reconciliation Documented Expiry Authority

State: `COMPLETE_NON_PARITY`

PARITY claim: `NONE`

## Purpose

A29-A33 made ambiguous provider-delete reconciliation durable, resumable, monotonic, crash-safe and temporally causal. One authority gap remained: `documented_expiry` could previously mark an asset `expired` without proving that the registered vendor asset TTL had actually elapsed.

That is unsafe for privacy evidence. A documented retention policy is not itself proof that an object has already expired before its stated expiry time.

## A34 behavior

`provider_delete_reconciliation.py` is now `L1-A34-v1`.

Before a documented-expiry observation can become an `applying`/`applied` ordering watermark:

1. Existing provider-object hash binding must pass.
2. Existing A33 post-delete and future-clock checks must pass.
3. `documented_expiry` may represent only `asset + expired`.
4. The privacy registry must contain a positive integer `vendor_asset_expires_at_epoch`.
5. `observed_at_epoch` must be at or after that registered expiry epoch.
6. The local validated runtime clock must also be at or after that expiry epoch.

Stable errors added:

- `SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_STATE_INVALID`
- `SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_EPOCH_INVALID`
- `SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_NOT_REACHED`
- `SEP_PRIVACY_RECONCILE_LOCAL_CLOCK_BEFORE_EXPIRY`

The prior `SEP_PRIVACY_RECONCILE_SOURCE_INSUFFICIENT` behavior for `confirmed/not_found` from `documented_expiry` is intentionally preserved. Task expiry remains invalid because the documented AudioShake asset TTL does not prove task deletion.

## Failure and recovery semantics

Premature or malformed documented-expiry evidence may remain durably visible as `observed_not_applied`, but it does not become an ordering watermark. A later valid provider API/console/support observation can therefore still apply and is not blocked by an invalid high/early policy event.

`resume_pending` continues to fail closed on invalid evidence rather than silently converting policy expectation into confirmed erasure.

## Focused verification

A locally reconstructed A34 candidate passed:

- `py_compile`: PASS
- focused documented-expiry authority harness: `9/9 PASS`
- failures: `0`
- errors: `0`

Focused cases include premature TTL, exact TTL boundary, local-clock-before-expiry, missing/boolean expiry metadata, invalid documented-expiry states, preserved confirmation error contract, task-expiry rejection and invalid-event ordering non-poisoning.

Remote source readback confirms the intended A34 branches in blob `139d0fcbe993baecbc2bcb1662ed3cad849205f5`.

The committed repository regression is:

`Separation/Tests/test_provider_delete_reconciliation_documented_expiry.py`

Exact current Worker-branch unittest discovery is **not observed** because the L1-A26 executable exact-checkout/CI gate remains unavailable. No full-suite PASS is claimed.

## Privacy boundary

A documented asset TTL may now establish only that asset expiry is eligible after its actual registered expiry time. It does not prove task deletion, account deletion, provider metadata deletion, billing reversal, or any current-iPhone product behavior.

Durable public reconciliation evidence continues to store provider object hashes and SHA-256 authority references rather than raw provider IDs or private authority material.

## Deployment topology

A34 does not change the A27 topology conclusion. Privacy registry, reconciliation ledger and application lock remain single-host file-backed authorities. POSIX flock, atomic rename, temporal validation and TTL gates are not distributed synchronization.

Multi-host operation still requires a real shared transactional backend with atomic CAS, durable commit, monotonic fencing and read-after-write consistency.

## Remaining gates

- `L1-A26` exact full Worker-branch audit remains `HEAD_TREE_BOUND_EXACT_CHECKOUT_AUDIT_PENDING`.
- Provider-specific authoritative deletion-status/clock contracts remain external/private evidence.
- HQ/App still needs to invoke `resume_pending` when `reconciliation_required` is true.
- E01-E10 remain `PENDING_EXTERNAL_INPUT`.
- `MOI-P003`, `P004`, `P005`, `P020`, `P021`, `P024`, `P025` remain `MISSING`.

A34 is correctness/privacy hardening only and must not promote any PARITY row.
