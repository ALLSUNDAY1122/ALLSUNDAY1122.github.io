# L1-A37 Validation — Equal-Epoch Provider Deletion Conflict Adjudication

## Goal

Close the Lane 1 known gap where two authoritative-looking provider deletion observations can share the same observation epoch while disagreeing on state. The pre-A37 reconciler correctly failed closed and left the conflicting observation pending, but provided no durable, reviewable path to retire that ambiguity after an operator/HQ had authoritative external evidence.

A37 adds an explicit adjudication layer without weakening the pre-existing fail-closed behavior.

## Implemented surface

- `Separation/Server/provider_delete_conflict_resolution.py`
  - `EqualEpochConflictDecision`
  - immutable `AtomicEqualEpochConflictDecisionStore`
  - `ConflictResolvingProviderDeletionReconciler`
- `Separation/Tests/test_provider_delete_reconciliation_conflict_resolution.py`
- `Processing/Tests/L1-A37_EQUAL_EPOCH_CONFLICT_ADJUDICATION_MATRIX.json`

## Safety contract

1. No decision means no winner. The original `SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT` behavior remains active.
2. A decision cannot introduce a new provider state. It must name an observation receipt already present in the reconciliation ledger for the exact logical job, object kind and epoch.
3. Authority and rationale are durable only as SHA-256 references; raw ticket text, reviewer notes, provider IDs or credentials are not accepted into the public sidecar format.
4. A conflict key is `logical_job_id + object_kind + observed_at_epoch`. The first durable decision for that key is immutable. A later attempt to replace it fails closed.
5. Before accepting the decision, the chosen observation is revalidated through the existing registry binding, object hash, deletion timing and terminal-erasure protections.
6. A decision cannot downgrade a terminal erasure state (`confirmed`, `not_found`, `expired`) to a non-terminal state.
7. If a newer applying/applied observation already exists for the same object, an older conflict decision is rejected as stale.
8. The decision sidecar uses POSIX flock, fsync, atomic replace and parent-directory fsync. Corrupt or schema-invalid sidecar state fails closed.
9. Restart recovery is explicit: a durable decision is re-read and pending observations are resumed through the same validation path.
10. Later same-epoch observations that disagree with the chosen state are ignored; equivalent observations can be accepted idempotently after the chosen receipt is applied.

## Validation performed in this wave

- New implementation candidate: Python `py_compile` PASS.
- New repository regression candidate: Python `py_compile` PASS.
- Isolated interface-compatible execution harness: **14/14 PASS**, 0 failures, 0 errors.
- The focused harness covered:
  - no-decision fail closed;
  - choose pending conflict;
  - keep already-applied observation;
  - immutable decision;
  - unknown chosen receipt rejection;
  - equivalent rows are not treated as a conflict;
  - future decision rejection;
  - pre-observation decision rejection;
  - restart/resume from durable decision;
  - late loser ignored;
  - late equivalent observation accepted;
  - terminal downgrade rejected;
  - corrupt sidecar rejected;
  - raw authority/rationale text absent from durable sidecar.

The formal repository regression additionally covers newer-watermark staleness and independent asset/task conflict scoping.

## What is not claimed

A37 is **NON-PARITY engineering safety evidence**. It does not establish:

- actual provider deletion or provider-specific authoritative status semantics;
- task/account/metadata deletion or billing reversal;
- current-iPhone Moises behavior;
- multi-host correctness;
- any promotion of MOI-P024 or another PARITY row.

The reconciliation ledger and the A37 sidecar remain single-host file-backed state. A real multi-host deployment still requires a shared transactional authority with atomic CAS, durable commit, monotonic fencing and read-after-write consistency.

## Remaining execution gate

The repository-native A37 regression and full Worker-branch unittest discovery have not been observed on an executable exact checkout in this session. Container `git ls-remote` still cannot resolve `github.com`. Therefore A26 remains open and no exact-final-tip dependency/provenance PASS is claimed.

HQ should preserve A37 during late integration and explicitly wire the conflict-resolving reconciler only at an HQ/App-owned composition point where the operator decision authority is defined. The base no-decision path must remain fail closed.
