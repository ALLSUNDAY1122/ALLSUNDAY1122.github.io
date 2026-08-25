# L4-W39 Validation｜Physical capture artifact materialization + staging recovery

Status: **COMPLETE as Worker-4 NON_PARITY engineering wave**  
PARITY impact: **none**. MOI-P009/P011/P013/P016/P021 remain MISSING.

## Latest-state audit at wave start

Re-fetched Notion/GitHub canonical state before implementation.

- Operating model remains v4 / Four Autonomous Independent Lanes / Late Integration.
- Worker 4 current bundle was W39.
- Frozen base remained `be1c84314db182d6eee5097de34e017af1a4a7de`.
- Worker branch was ahead 387 / behind 0 from frozen base at W39 start.
- Integration PR had moved, but Lane 4 was still canonical only through W36; W37+ remained post-Epoch24 continuation.
- PARITY_MATRIX still had zero promoted current-iPhone rows.
- No rebase or cross-lane edit was performed.

## Problem closed by W39

W37 produced a structurally validated capture result in memory and W38 defined the W35-W37 archive-chain roles, but HQ would still have needed to manually encode/copy individual files and construct archive entries. That creates avoidable evidence risks:

- manual path/role mismatch;
- stale or re-encoded bytes;
- run/execution rebinding;
- W27 and W38 projections referring to different bytes;
- partial filesystem publication after interruption;
- silent overwrite of an existing evidence run;
- uncertain ownership of a leftover hidden staging directory.

W39 makes that seam deterministic and fail-closed.

## Implementation

Added:

- `AnalysisPhysicalCaptureArtifactMaterialization.swift`
- `AnalysisPhysicalCaptureArtifactBundleValidation.swift`
- `AnalysisPhysicalCaptureArtifactStaging.swift`
- `AnalysisPhysicalCaptureArtifactPublicationGate.swift`
- `iOS/HostCore/AnalysisIOSPhysicalCaptureArtifactMaterializer.swift`
- Package registrations for all W39 production sources

### Exact materialization

A valid W37 capture is converted to exactly nine artifacts:

1. W23 performance evidence
2. W23 performance validation
3. W25 workload receipt
4. W25 workload validation
5. W35 algorithm evidence
6. W36 current-runtime archive evidence
7. W37 capture plan
8. W37 execution-integrity evidence
9. W37 execution-integrity report

The same bytes automatically generate four W27 per-run archive entries and five W38 per-run archive-chain entries.

### Validation replay bug found and fixed

During implementation, W39 initially replayed `AnalysisDevicePerformanceEvidenceValidator` with its default `Date()` evaluation time and then compared the entire report. Because the W23 report stores `generatedAt`, a correct historical report would have failed equality solely due to replay time.

W39 now passes the original `performanceValidation.generatedAt` as `evaluatedAt`, making semantic replay deterministic instead of weakening report comparison.

### Capture-chain binding

Materialization fails unless W23/W25/W35/W36/W37 bind to the same run and W25/W35/W36/W37 bind to the same W36 workload execution ID.

The current source contract must remain `.boundedPull` in W35, W36 and W37 evidence.

Complete and cancellation runs have separate terminal semantic checks.

### Bundle integrity

`AnalysisPhysicalCaptureArtifactBundleValidator` independently checks:

- filesystem-safe run ID and normalized execution ID;
- exact nine-role inventory;
- unique paths under `runs/<runID>/`;
- artifact bytes / length / SHA-256 consistency;
- exact W27 four-entry projection;
- exact W38 five-entry projection;
- deterministic bundle root.

A later audit found that exposing the low-level stager publicly could otherwise allow a hand-created bundle to bypass the high-level gate. The low-level stager and interrupted-stage checkpoint now also run the bundle validator themselves.

### Publication / recovery

Evidence is written beneath a deterministic hidden same-parent staging directory. Every artifact is read back and hash/length checked before READY. Publication is one directory move to `runs/<runID>` followed by another readback.

Recovery policy:

- existing final path: fail closed, no overwrite;
- leftover hidden stage with exact marker: delete the whole incomplete stage and restage from authoritative bytes;
- missing/corrupt/mismatched marker: stop as ambiguous and preserve the stage;
- post-publication verification failure: stop and leave the final directory for explicit HQ inspection; retry cannot overwrite it silently.

The final directory contains two W39 control manifests. They are transaction metadata, not W27/W38 evidence roles; W27/W38 consumers must use declared entry paths rather than blindly enumerate the directory.

## Durable XCTest source added

### `AnalysisPhysicalCaptureArtifactMaterializationTests.swift`

Covers:

- valid physical cancellation chain materializes exact 9/4/5 inventory;
- W23 replay report remains structurally complete using original `generatedAt`;
- W25 cancellation receipt validation binding;
- W37 execution-integrity validity;
- non-bounded W36 runtime rejection;
- cross-execution rebinding rejection;
- filesystem-unsafe run ID rejection.

### `AnalysisPhysicalCaptureArtifactStagingTests.swift`

Covers:

- exact prepared-bundle validation;
- successful publication and byte readback;
- existing final collision/no overwrite;
- matching-marker interrupted staging recovery;
- corrupt marker remains preserved and fails ambiguous;
- forged bundle root rejection;
- artifact change with stale W27/root projection rejection;
- missing W27 projection rejection;
- missing W38 projection rejection;
- path traversal rejection;
- deterministic repeated validation.

### `AnalysisIOSPhysicalCaptureArtifactMaterializerTests.swift`

Apple-conditional source verifies that a non-structurally-complete W37 result cannot enter materialization.

## Portable validation actually observed

Worker environment:

- Swift 6.2.1
- target `x86_64-unknown-linux-gnu`
- Python 3.13.5

### Swift source-shaped transaction mirror

Compiled with warnings treated as errors.

Observed PASS:

- 20,000 bundle/tamper validation iterations;
- 200 real temporary-filesystem publication transactions;
- alternating normal publication and exact-marker interruption recovery;
- all second publication attempts rejected as existing-target collisions;
- corrupt-marker case rejected as ambiguous and its stage remained on disk.

Observed execution:

- elapsed approximately 14.12 s;
- maximum RSS approximately 20,844 kB.

An earlier deliberately larger configuration (200,000 validations + 1,000 filesystem publications) compiled successfully but exceeded the 45-second execution limit. It is recorded as `TIMEOUT_NOT_COUNTED_AS_PASS`, not as a successful stress result.

### Python SHA-256 metadata/root mirror

Observed PASS for 200,000 cases:

- exact nine-role/path inventory;
- deterministic SHA-256 metadata root;
- artifact hash mutation rejection;
- workload-execution mutation changes root.

Observed execution:

- elapsed approximately 15.867 s;
- maximum RSS approximately 109,920 kB.

### Apple conditional parse

A source-shaped UIKit/Darwin conditional publication seam passed Swift frontend parse.

This is syntax-shape evidence only; it is not Apple SDK typecheck or device execution.

## Fresh canonical tests not observed

The Worker container could not resolve `github.com` during W39 validation. Therefore a fresh checkout and full current Worker-branch SwiftPM/XCTest run was not available and is **not claimed**.

Also not observed:

- selected Xcode / Apple ARM compile;
- actual APFS/iPhone publication semantics;
- physical W37 materialization from a real capture result;
- genuine Lane-2 bounded decoder runtime;
- real RSS / physical-footprint / thermal / battery / cancellation timing;
- W24 repeated worst-case acceptance;
- HQ W27/W38 root anchoring;
- current-iPhone Moises differential.

## Acceptance mapping

W39 goal | Result
--- | ---
No manual W23-W37 encoding/copy | Implemented
Exact W27/W38 entry derivation | Implemented from same bytes
Run/execution rebinding prevention | Implemented
Non-bounded source rejection | Implemented
Partial-write isolation | Hidden staging tree implemented
Interrupted-stage retry | Exact marker required; whole-stage cleanup/restage
Recovery ambiguity | Fail closed; preserve ambiguous stage
Existing final collision | Fail closed; no overwrite
Prepared bundle tamper validation | Independent root/bytes/projection validator
Durable negative/recovery tests | Added
NON_PARITY evidence/runbook | Added
Physical-iPhone/APFS evidence | NOT_OBSERVED

## Remaining P021 gate

W39 removes hand-assembled evidence risk but does not make P021 pass.

HQ must still:

1. integrate a genuine Lane-2 bounded decoder;
2. compile the selected Apple stack;
3. execute W37/W39 on physical iPhone hardware using HQ W24/W25 inputs;
4. collect real RSS, physical footprint, thermal, battery and cancellation evidence;
5. assemble multi-run W27/W38 archives;
6. perform repeated W24 worst-case acceptance;
7. independently anchor archive roots;
8. make the final PARITY decision.

`BOUNDED_PULL_CONTRACT` remains a declaration until a concrete decoder and physical process telemetry corroborate it.
