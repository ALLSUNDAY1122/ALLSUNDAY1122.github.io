# Analysis Physical Evidence Archive Chain Runbook｜L4-W38

## Purpose

W38 extends the W27 tamper-evident physical-evidence archive after W35-W37 without rewriting or invalidating the historical W27 schema.

This runbook is **NON_PARITY preparation**. A root-consistent archive does not prove physical-iPhone performance, decoder bounded memory, current-Moises quality, or HQ acceptance.

## Canonical validation entrypoint

Use `AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict(...)` for W38 acceptance.

Do not operationally substitute the lower-level `validate(...)` call. `validateStrict` first:

1. rejects duplicate or non-exact W24 planned run inventories before lookup construction;
2. recomputes the legacy W27 manifest root locally;
3. requires the W27 declared root, validation-report root, archive inventory, policy binding and W38 parent root to agree exactly;
4. only then evaluates the W35-W37 extension chain.

## Parent W27 archive

Before W38 assembly, HQ must already possess the exact W27 archive inputs and validate them with the W27 validator. Preserve the W27 manifest/policy bytes and independently record its deterministic root.

W38 policy must include:

- W27 policy ID;
- W27 archive ID;
- exact W27 deterministic root SHA-256;
- the unchanged W27 archive binding;
- exact unique W24 predeclared run IDs;
- `authority = HQ_LATE_INTEGRATION`.

W38 never silently migrates a W27 archive to a new interpretation.

## Required W35-W37 roles per W24 run

Every predeclared run requires exactly one of each:

1. `W35_RUNTIME_ALGORITHM_EVIDENCE`
2. `W36_CURRENT_RUNTIME_EVIDENCE`
3. `W37_CAPTURE_PLAN`
4. `W37_EXECUTION_INTEGRITY_EVIDENCE`
5. `W37_EXECUTION_INTEGRITY_REPORT`

Missing, duplicate, unexpected-run, duplicate-path, unsafe-path, hash, length or unmanifested-byte conditions fail closed.

## W36 current-runtime evidence

Build `AnalysisCurrentDeviceWorkloadArchiveEvidence` from the actual `AnalysisCurrentDeviceWorkloadExecution` returned by W36.

It must preserve:

- run/performance IDs;
- run kind;
- W36 execution ID;
- `BOUNDED_PULL_CONTRACT` source contract;
- W36 bounded-source acceptance;
- observed source chunk/sample counts;
- workload outcome;
- snapshot SHA when finalized;
- W35 algorithm run and W36 execution binding.

Do not construct this from the historical W25 materialized runner. The W36 archive summary exists specifically to distinguish current W30-W34 product-path execution from the old regression-only runner.

## Exact capture-chain binding

For each run, W38 requires one chain:

`W24 planned run -> W37 capture plan -> W23/W25/W35/W36 run identity -> W36 execution ID -> W37 integrity evidence/report`

The validator requires:

- same run ID and run kind across W35/W36/W37;
- W35 and W37 algorithm execution IDs equal the W36 execution ID;
- W35 source/identity/manifest equal the HQ W37 capture plan;
- W35/W36/W37 all declare bounded-pull input;
- W36 observed source work is non-zero;
- W36 and W37 observed-source sample count/outcome agree;
- W37 sampling interval equals the capture plan;
- archived W37 integrity report equals a freshly recomputed report;
- the same W36 execution ID is not reused by another run.

### Complete run

Require W36 `COMPLETED`, a snapshot SHA, W35 `FINALIZED_RUNTIME_IDENTITY`, current W35 algorithm schema, and no cancellation timestamps.

### Cancellation probe

Require observed source work, W36 `CANCELLED`, no final snapshot, W35 `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION`, and ordered W37 cancellation-request/observed timestamps.

## Telemetry metadata

W37 integrity evidence carries periodic-sampling metadata that W38 archives with the exact run:

- requested sample interval;
- sampling attempts;
- periodic samples captured;
- sample-cap state;
- sampler termination;
- cancellation-task termination;
- performance limitations;
- cancellation requested/observed timing.

W37 validation remains authoritative for lifecycle semantics. A telemetry sample cap, missing periodic telemetry on a long-enough capture, or unjoined helper task invalidates the archived W37 report and therefore invalidates W38.

## Root construction

W38 computes a deterministic schema-v2 extension root from:

- W38 archive/policy IDs;
- parent W27 archive ID/root;
- unchanged physical-evidence binding;
- all sorted W35-W37 entries including role, run ID, path, SHA-256 and length.

Changing the parent W27 root, run ownership, execution binding, artifact bytes, or entry inventory changes or invalidates the W38 root.

HQ should independently anchor **both** the W27 root and W38 extension root. Neither root is a digital signature or Apple/hardware attestation.

## Physical execution procedure

For actual P021 evidence, HQ must still:

1. use a genuine Lane-2 bounded decoder, not `AnalysisWholeSignalChunkedCompatibilityAdapter`;
2. compile the selected integrated build with Xcode/Apple ARM;
3. execute W37 on the selected physical iPhone using HQ-supplied W24/W25 thresholds, run IDs and cancellation timing;
4. preserve raw W23 RSS/physical-footprint/thermal/battery/cancellation telemetry;
5. preserve W25 receipts, W35 companions, W36 current-runtime summaries and W37 plan/integrity artifacts;
6. assemble the W27 parent and W38 extension;
7. call `validateStrict`;
8. perform repeated W24 worst-case acceptance;
9. let HQ alone decide PARITY.

`BOUNDED_PULL_CONTRACT` is a software contract and does not prove the decoder has no hidden buffers. Physical process telemetry remains authoritative.

## Worker validation boundary

Worker-side portable/XCTest/mirror evidence may verify serialization, role inventory, root determinism, malformed-policy handling, tamper detection and execution reuse rejection. It must be labelled NON_PARITY.

Physical-iPhone runtime, Apple ARM compilation, real decoder memory behavior and W24 approved-threshold acceptance remain HQ Late Integration gates.
