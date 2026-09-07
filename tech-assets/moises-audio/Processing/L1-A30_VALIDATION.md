# L1-A30｜Provider Delete Reconciliation Durable Resume

Status: `COMPLETE_NON_PARITY`

PARITY claim: `NONE`

## Why this Wave existed

L1-A29 introduced a safe observation-only provider deletion reconciliation path. It intentionally persisted an authoritative observation before mutating the privacy registry. That ordering was crash-safe for evidence preservation, but it left a practical restart gap: if the process stopped after ledger append and before registry application, the durable `observed_not_applied` event could only be completed by supplying the original observation again.

L1-A30 closes that Lane-local recovery gap without replaying the provider DELETE side effect.

## Implemented behavior

`ProviderDeletionReconciler.resume_pending(logical_job_id)` now:

1. Reads only durable `observed_not_applied` events already present in the reconciliation ledger.
2. Reconstructs the hash-bound `ProviderDeletionObservation` from ledger fields.
3. Reuses the A29 local registry-application path; it does not contact the provider or reissue DELETE.
4. Marks a receipt `applied` only after the registry mutation succeeds.
5. Leaves failed observations pending and returns `INCOMPLETE` with stable error codes rather than pretending recovery succeeded.
6. Recomputes the remaining pending count after the recovery attempt.

The reconciliation snapshot now exposes `pending_observation_count` and `reconciliation_required` so an operator/HQ integration layer can distinguish a clean ledger from unresolved external-side-effect evidence.

## Ledger integrity hardening

A30 also tightened the durable ledger itself:

- `application_state` must be exactly `observed_not_applied` or `applied`.
- Every loaded event is reconstructed and revalidated against the controlled observation contract.
- The event content must hash back to its receipt key; semantic tampering therefore fails closed with `SEP_PRIVACY_RECONCILE_LEDGER_RECEIPT_MISMATCH`.
- Directory `fsync` failure after atomic replace is treated as `SEP_PRIVACY_RECONCILE_LEDGER_WRITE_FAILED` instead of being silently accepted as durable success.

## Focused validation observed in this session

A local interface-compatible focused harness covering the authored A30 logic ran `8/8 PASS`, including restart resume, two-object resume, hash mismatch, pending snapshot truthfulness, semantic ledger corruption, receipt tamper, already-applied idempotency, and terminal downgrade handling.

`provider_delete_reconciliation.py` and the focused harness compile with Python `py_compile`: `PASS`.

The repository test `Separation/Tests/test_provider_delete_reconciliation_resume.py` was committed with the same recovery assertions. A qualifying exact Worker-branch checkout is not executable in this session, so the exact full repository unittest discovery is deliberately recorded as `NOT_OBSERVED`, not PASS.

## A26 relationship

A30 does **not** complete L1-A26. The exact-checkout audit was retried at the start of this Wave and container git access again failed with `Could not resolve host: github.com`.

Because A30 adds owned bytes, the eventual A26 command must use the then-current final Worker branch tip:

`Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact final Worker branch tip>`

A26 may be marked complete only after the v2 report proves all of:

- `overall_state=PASS`
- `git_head_binding.state=PASS`
- `owned_source_snapshot.state=PASS`

## Safety / PARITY boundary

A30 is recovery/correctness engineering evidence only.

It does not:

- create an authoritative provider deletion observation,
- contact a provider delete-status endpoint,
- replay an ambiguous provider DELETE,
- make the A09/A16/A23/A24/A29/A30 file-backed stores multi-host safe,
- provide integrated project/account deletion evidence on iPhone,
- promote `MOI-P024` or any other PARITY row.

Production provider observation remains external/private input. Raw provider IDs, credentials and private authority records must remain outside durable public evidence; only hash references are durable here.
