# L1-A24｜Generated Stem Retention / Delete / Refund / Orphan Recovery

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation`, supporting `MOI-P024｜privacy` semantics  
PARITY claim: `NONE`

## Purpose

A21 protects generation execution and credits, A22 binds the runtime boundary, A23 makes generated output mix-compatible and atomically activates variants, and A09 established the rule that durable delete intent and actual erasure confirmation are different facts.

A24 closes the generated-stem-specific lifecycle gap across delete, regeneration, cancellation, refund and crash/orphan cleanup. It does not claim live vendor deletion, refund behavior or current-iPhone parity.

## Final implementation

`Separation/Server/generated_stem_retention.py`

### Durable delete intent

A delete is bound to the exact A23 project/role/generation/variant plus the current manifest SHA and artifact SHA. The delete record is durably persisted before any active pointer, manifest or object is removed.

The same intent is idempotent. Conflicting identity/reason/evidence fails closed. A durable delete record also serves as a tombstone through `assert_generation_not_deleted`, so a deleted generation must not silently reappear at a later composition point.

### Local delete ordering

All local generated-variant mutation shares the same A23 store lock.

1. If the active pointer names the exact target variant, detach it durably.
2. If another variant is active for the same project/role, preserve it.
3. Re-check the target manifest against the SHA captured before deletion and remove it.
4. Recompute content references from **both all remaining manifests and all active pointers**.
5. Remove the content-addressed object only when no remaining reference uses it.
6. Mark `LOCAL_DELETED` durably.

The active-pointer scan is essential. A still-active artifact remains protected even if its corresponding manifest is missing. Any corrupt or symlink manifest/active pointer makes deletion/GC fail closed rather than guessing reachability.

### Refund is not deletion

Local deletion never releases or refunds credits.

- A24 records a refund request only when the authoritative A21 credit state is `refund_pending`.
- A refund can become `CONFIRMED` only when A21 is already `refunded` and an authority evidence SHA is supplied.
- `DENIED` / `UNKNOWN` remain visible results.
- Deleting local bytes without a confirmed A21 refund leaves `refund_confirmed=false`.

This prevents a cancelled/deleted generated stem from being represented as a returned credit when the runtime/account authority has not actually returned it.

### Runtime erasure is separate

A24 separately records runtime deletion/erasure state. Local deletion or a delete request does not prove remote erasure.

Authoritative completion is limited to:

- `CONFIRMED`;
- `NOT_FOUND`;
- `NOT_APPLICABLE` only when supported by physical authority evidence.

`PENDING`, `UNSUPPORTED` and `UNKNOWN` do not become an erasure claim. `overall_erasure_complete` requires both local deletion and authoritative runtime-erasure completion.

### Abandoned generation cleanup

An inactive A23 manifest can enter cancellation cleanup only when physical A21 lifecycle evidence states `cancelled` or `failed`. If that exact variant is active, cleanup is rejected. This prevents an active stem from being classified as an orphan simply because another lifecycle observer is stale.

### Orphan / temporary-file recovery

Content-addressed object GC:

- considers references from manifests **and** active pointers;
- accepts only 64-hex content-addressed WAV object names;
- requires an explicit minimum-age grace period;
- preserves any referenced object;
- stops on corrupt/symlink reference metadata.

Temporary-file cleanup also requires a full reference-integrity scan and an explicit age threshold before deleting `*.tmp` files.

These paths address object/manifest leftovers from crash windows without weakening A23 atomic active-variant semantics.

## Privacy-safe evidence

Public A24 evidence contains only hashed project/generation/artifact identities, role/variant, local delete state, reference-retention booleans, refund state and runtime-erasure state.

It does not contain paths, raw audio, raw runtime/execution IDs, raw billing/credit records, prompts, credentials or signed URLs.

## Validation

Final validation layers:

- broad pre-persistence fault/design suite: `40/40 PASS`;
- durable checked-in focused regression: `24/24 PASS`;
- final JSON Schema representative-document validation: `2/2 PASS`;
- implementation/test `py_compile`: `PASS`.

The focused suite covers durable intent, active/inactive deletion, shared object references through manifests and active pointers, reference corruption, manifest mutation, idempotency/tombstones, refund-state truth, runtime-erasure truth, orphan/grace cleanup, stale temporary files, abandonment guard and privacy-safe evidence.

The removed prototype retention-policy schema is intentionally not part of final A24. The final coordinator does not invent provider/current-iPhone retention durations; actual retention terms remain external/live evidence.

## NON-PARITY boundary

No production generation runtime, rights-cleared real generation campaign, actual account refund, current-iPhone delete/regenerate workflow or integrated project/account deletion was exercised here.

Therefore:

- `MOI-P025` remains canonical `MISSING`;
- P024 is not promoted by A24;
- `parity_claim = NONE`;
- all A24 synthetic/fault/schema results are `NON_PARITY_EVIDENCE_ONLY`.

## Files

- `Separation/Server/generated_stem_retention.py`
- `Separation/Tests/test_generated_stem_retention.py`
- `Separation/Evaluation/schemas/generated-stem-delete-request.schema.json`
- `Separation/Evaluation/schemas/generated-stem-retention-evidence.schema.json`
- `Processing/Tests/L1-A24_GENERATED_STEM_RETENTION_MATRIX.json`

## Next lane-local gap

A21-A24 now expose safe subsystems, but they can still be called independently. The next material Lane 1 gap is a lifecycle facade / cross-ledger composition layer that makes the safe order mandatory: generation contract -> runtime binding -> mix-ready activation -> retention tombstone/delete. Without that facade, an integration caller could bypass an A24 tombstone or activate/publish in the wrong order.
