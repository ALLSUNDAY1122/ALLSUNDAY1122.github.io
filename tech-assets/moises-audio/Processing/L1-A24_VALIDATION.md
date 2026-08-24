# L1-A24｜Generated Stem Retention / Delete / Refund / Orphan Recovery

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation` with supporting `MOI-P024｜privacy` semantics  
PARITY claim: `NONE`

## Purpose

A21 protects generation execution and credits, A22 binds the real runtime boundary, A23 makes generated output mix-compatible and atomically activates variants, and A09 established the ordinary-separation privacy principle that delete intent must be durable and provider acceptance is not erasure confirmation.

A24 closes the generated-stem-specific lifecycle gap between those systems. It prevents regeneration, cancellation, deletion or crash cleanup from silently deleting a still-referenced generated stem, fabricating a credit refund, or falsely claiming remote erasure.

## Implementation

`Separation/Server/generated_stem_retention.py`

### Retention registry and policy binding

The retention registry is atomic (`flock`, temporary file, `fsync`, replace) and stores only hashed generation/project/artifact identities. Its policy is itself hash-bound:

- orphan grace period;
- superseded-variant grace period.

`retention_policy_sha256` is persisted with the registry. Reopening existing state with different grace values fails closed with `GEN_RET_POLICY_MISMATCH`; policy changes cannot silently reinterpret old retention state.

### Variant registration / supersession

A24 registers exact A23 manifests by generation hash + variant index and binds the manifest SHA. When a newly active variant for the same project/role is registered, the previous registered variant becomes superseded but is not immediately destroyed.

The active variant is never eligible for `SUPERSEDED_RETENTION` or `ORPHAN_ABANDONED` deletion.

### Delete intent before destruction

For user/project/cancel/superseded/abandoned deletion, the delete reason and timestamp are saved before local destructive work. A crash or local integrity failure therefore cannot erase the fact that deletion was requested.

Project deletion first inventories all generated manifests for the project. If any project-owned generated manifest is not registered, project deletion fails closed before deleting the registered subset. This avoids a false "project generated content deleted" result while an untracked variant remains.

### Content-addressed shared artifact safety

A23 stores audio by content SHA, so two generation records may legitimately reference identical bytes. A24 computes physical references from both:

- all remaining immutable manifests; and
- all current active pointers.

The active-pointer reference is checked even if its manifest is missing. A physical WAV is removed only when neither source references it and its bytes still hash to the expected SHA. Otherwise it is retained as `retained_shared_reference`.

Association deletion and physical artifact erasure are separate facts.

### Runtime erasure truthfulness

Raw execution IDs are obtained only from the A22 private binding store and verified against the A21/A22 execution hash domain.

Before calling an external runtime delete operation, A24 durably changes the runtime delete state from `not_requested` to `requesting`. This closes the concurrent/relaunch window in which two workers could both send the same destructive request.

Consequences:

- `requesting` after a crash is ambiguous and is not blindly re-sent;
- `accepted` is not treated as erased;
- provider/runtime errors remain unknown;
- missing binding remains `identifier_unavailable`, not inferred `not_applicable`;
- `confirmed` or `not_found` counts as erasure only after a separate authority evidence SHA is recorded;
- a genuinely local/project-owned runtime may be marked `not_applicable` only with physical authority evidence describing why no external runtime storage exists.

### Credit/refund separation

A24 never changes A21 credits itself. It reads the A21 durable credit state and reports:

- `released_no_charge` only when A21 says `released`;
- `reserved_unsettled` while A21 remains `reserved`;
- `eligible_not_requested` for a cancelled committed generation whose refund has not been requested;
- `pending_authority` while A21 is `refund_pending`;
- `confirmed` only when A21 is `refunded` and carries refund authority evidence;
- `not_eligible` for an ordinary committed non-cancelled generation.

Deleting local audio therefore never fabricates a credit return.

### Orphan recovery

A23 crash windows may leave content-addressed objects or inactive manifests that never became active.

Objects with no manifest or active-pointer reference are not immediately erased. They require:

1. first observation;
2. a second observation after the policy-bound grace interval;
3. durable `delete_intent_at_epoch` written and fsynced;
4. exact object SHA verification;
5. unlink + directory fsync.

Inactive unregistered manifests are only reported. They may be adopted as abandoned and deleted only with an explicit abandonment evidence SHA; an active manifest cannot be abandoned.

### Privacy completion

`privacy_erasure_complete` requires all of the following:

1. generated variant association deletion confirmed;
2. local physical artifact state is `confirmed_erased` or `missing_before_delete`;
3. runtime erasure is authority-confirmed (`confirmed`, `not_found`, or evidence-backed `not_applicable`).

A shared physical artifact retained for another valid variant therefore cannot produce a full-erasure claim.

## Public evidence

The public snapshot contains retention policy hash, project/generation/artifact hashes, role, variant index, mix-ready receipt hash, deletion state, runtime erasure state and refund state.

It does not emit raw logical generation IDs, raw runtime execution IDs, paths or audio. `parity_claim` is fixed to `NONE`.

Schemas:

- `Separation/Evaluation/schemas/generated-stem-retention-policy.schema.json`
- `Separation/Evaluation/schemas/generated-stem-retention-evidence.schema.json`

## Validation

Final local validation against the exact core/test bytes written to GitHub:

- focused regression: `38/38 PASS`;
- JSON Schema checks: `3/3 PASS` (policy sample, ordinary evidence sample, durable `requesting` evidence sample; negative false-erasure evidence rejected);
- `py_compile` for implementation/test: `PASS`;
- GitHub core blob SHA equals the tested local bytes;
- GitHub test blob SHA equals the tested local bytes.

Regression coverage includes durable delete intent, project-delete completeness, shared content-addressed references, active-pointer-only references, manifest/object mutation, superseded cleanup, orphan grace and intent, abandonment evidence, A21 refund states, A22 binding identity, runtime accepted/confirmed/error/not-applicable handling, duplicate runtime-delete suppression, crash-window `requesting` recovery, retention-policy mismatch and public evidence redaction.

Machine ledger: `Processing/Tests/L1-A24_GENERATED_STEM_RETENTION_MATRIX.json`.

## NON-PARITY boundary

A24 is engineering/safety evidence only. It does not establish:

- the selected production generation runtime's contractual deletion/retention behavior;
- real remote deletion on a production account;
- current-iPhone Moises delete/cancel/refund semantics;
- rights-cleared real generation quality/latency;
- integrated iPhone project/account deletion across other Lane-owned storage;
- P024 or P025 PARITY.

`MOI-P025` remains canonical `MISSING` and `parity_claim` remains `NONE` until real runtime/current-iPhone/device/HQ evidence exists.

## Next lane-local gap

A21-A24 now form separate but compatible generation lifecycle layers. The remaining meaningful non-external gap is composition: one durable processing facade must enforce the ordering across credit reservation, runtime execution/recovery, A23 mix-ready activation and A24 retention registration so a relaunch cannot skip a layer or publish an unregistered generated variant. This is the next candidate `L1-A25｜AI Stem Generation End-to-End Processing Facade / Crash-Recovery Composition`.
