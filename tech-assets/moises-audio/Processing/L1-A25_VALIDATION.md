# L1-A25｜AI Stem Generation End-to-End Processing Facade / Crash-Recovery Composition

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation`  
PARITY claim: `NONE`

## Purpose

A21-A24 deliberately separated entitlement/credit, runtime execution, mix compatibility/variant activation, and retention/delete/refund behavior. That separation made each layer testable, but it also left a product-integration hazard: a caller could invoke the layers out of order or resume after a crash at the wrong boundary.

A25 introduces a durable generation-processing facade that constrains the legal operation order and returns only the next safe recovery directive. It does not select or certify a real generation runtime and does not claim Moises equivalence.

## Composition order

The facade preserves this order:

1. validate/hash-bind generation identity and private source WAV format;
2. durably persist A25 intent;
3. A21 reserve/credit lifecycle through A22 runtime start;
4. reconcile ambiguous start instead of blindly issuing another generation;
5. observe bound runtime until terminal runtime state;
6. re-check A22 project-controlled artifact identity;
7. require A23 mix-ready/normalization provenance;
8. atomically activate the generated variant through A23;
9. register the active variant with A24 retention;
10. expose `READY` only after the above chain is durable.

A caller cannot use the A25 `READY` state as a shortcut around A21 credit authority, A22 binding, A23 mix compatibility, or A24 retention registration.

## Start / crash semantics

A25 stores `START_CALL_IN_FLIGHT` before entering the A22 start operation.

If a process disappears around this boundary:

- if the intact A21 ledger already contains the generation record, A25 does **not** issue another start; it routes to A22 reconciliation/observation;
- if the A21 ledger explicitly returns `GEN_RECORD_NOT_FOUND`, A22 ordering proves that A21 reserve/authorize did not complete and therefore the external runtime start could not yet have been issued. Only this narrow case permits a safe start retry;
- corrupt/unknown A21 state is not converted into a retry permission.

This preserves A21/A22 duplicate-execution and duplicate-credit protections.

## Runtime / publication separation

An A22 `READY` result is only `RUNTIME_READY` in A25. The deterministic project-controlled A22 WAV must still exist and match the A21 recorded SHA before A23 is allowed to run.

A23 then decides whether the artifact is directly mix-compatible or needs explicitly authorized normalization. `NORMALIZATION_REQUIRED` is durable and does not register retention or publish the variant.

After A23 returns an active variant, A25 stores `VARIANT_ACTIVE` before calling A24. If the process fails after A23 activation but before A24 registration, relaunch returns `REGISTER_RETENTION`; generation and runtime observation are not repeated. A24 registration remains idempotent.

## Cancellation

A25 persists cancellation intent before the external cancel attempt and makes the A21 logical cancellation durable first.

If the external cancel call is interrupted, the A25 record remains in an in-flight/pending cancel condition and repeated user cancellation does not blindly resend the upstream cancel. Recovery uses A22 observation. A cancelled generation is forbidden from A23 mix promotion even if the runtime later reaches `READY`.

This preserves the A08/A21 distinction between logical cancellation, upstream stop confirmation, and output discard.

## Delete / relaunch

The base facade delegates destructive generated-variant deletion to A24 only after a generated variant exists.

`ai_stem_generation_delete_resume.py` adds a private durable delete-intent journal so relaunch can remember the exact destructive reason without asking a caller to reconstruct it. A changed reason is rejected. A crash after delete intent resumes the same A24 operation and never restarts generation.

The public result emits only a domain-separated delete-reason hash and `delete_reason_emitted=false`; the raw delete reason remains private operational state.

A24 remains authoritative for association deletion, content-addressed reference checks, remote runtime erasure, refund state, and orphan cleanup. A25 does not treat association deletion as proof of remote erasure or credit refund.

## Durable identity

The A25 private journal binds:

- A21 request fingerprint;
- project/source hashes;
- source sample rate/channels/audio format/bit depth/frame count;
- target role and variant index;
- A21-compatible generation reference hash;
- exact A22 runtime descriptor SHA;
- exact A23 mix policy SHA;
- exact A24 retention policy SHA.

Changing these on relaunch is an idempotency conflict rather than a silent reinterpretation.

## Privacy-safe evidence

Public A25 facade evidence includes only hashes, source format metadata, role/variant, durable phase, recovery directive and safe booleans.

It excludes:

- raw logical generation ID;
- source/runtime output paths;
- raw prompt;
- raw execution ID;
- credential values;
- raw audio.

The evidence is marked `NON_PARITY_EVIDENCE_ONLY` and `parity_claim=NONE`.

## Validation

Local focused validation performed while implementing A25:

- base facade regression: `23/23 PASS`;
- delete-resume regression: `4/4 PASS`;
- facade evidence representative JSON Schema validation: `2/2 PASS`;
- A25 Python implementation/test syntax compilation: `PASS`.

Covered cases include idempotent begin, safe pre-A21 crash restart, ambiguous start, transport ambiguity, reconcile, running/ready observation, runtime output mutation, normalization-required state, variant-to-retention crash recovery, cancellation interruption/no blind resend, delete ordering, delete interruption/same-reason replay, identity mismatch, source SHA mismatch, journal corruption, missing layer surface and privacy redaction.

All audio/runtime behavior used in A25 tests is synthetic/control evidence. It is not a real generated-audio or current-iPhone comparison.

## NON-PARITY boundary

A25 materially reduces the chance that Late Integration can accidentally bypass P025 safety layers, but it does not satisfy the P025 PARITY gate.

Still required:

- commercially approved real generation runtime and exact runtime descriptor;
- rights-cleared real sources;
- exact current-iPhone generation role/mode/preset/credit/entitlement/delete behavior;
- real quality, latency, credit, failure/recovery and retention evidence;
- current-iPhone blind A/B;
- integrated iPhone Playback/DSP mix validation;
- HQ PARITY judgment.

Therefore `MOI-P025` remains canonical `MISSING` and `parity_claim` remains `NONE`.

## Files

- `Separation/Server/ai_stem_generation_processing_facade.py`
- `Separation/Server/ai_stem_generation_delete_resume.py`
- `Separation/Tests/test_ai_stem_generation_processing_facade.py`
- `Separation/Tests/test_ai_stem_generation_delete_resume.py`
- `Separation/Evaluation/schemas/ai-stem-generation-facade-evidence.schema.json`
- `Processing/Tests/L1-A25_GENERATION_FACADE_MATRIX.json`

## Next lane-local target

A05-A25 now contain many independently hardened layers. The next highest-value non-external Lane 1 task is a complete cross-module dependency/regression closure audit: import all Lane 1 Python modules, run the full checked-in Lane 1 test set, validate all owned JSON schemas/examples, detect duplicate/conflicting stable-code or protocol assumptions, and produce one integration handoff manifest without claiming PARITY.
