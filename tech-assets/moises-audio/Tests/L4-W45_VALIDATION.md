# L4-W45 validation｜Anchored P021 physical-evidence adjudication

## Result

**Implementation: complete.**

**Current real P021 readiness: NOT READY.**

W45 intentionally does not manufacture a positive physical result. The gate can emit `READY_FOR_HQ_P021_JUDGMENT` only after the real externally anchored physical inputs exist.

## Canonical context at W45 start

Fresh project reads established:

- operating model remains v4 / Four Autonomous Independent Lanes / Late Integration;
- Worker 4 scope remains `Analysis/**`, `Package.swift`, `Tests/**`, `iOS/**` plus Worker-4 status;
- `PARITY_MATRIX.json` remains HQ-owned;
- MOI-P021 remains `MISSING`;
- HQ Epoch 30 canonicalized Lane 4 through W44;
- Epoch 30 semantic checkpoint: `f2b82b167ce2ddde1039666e29740d9ba52f9027`;
- HQ Run #221 / `32884713489`: SUCCESS 375/375 on Linux SwiftPM;
- W45+ remained post-Epoch30 at execution start.

Run #221 is not W45 evidence and is not physical-iPhone evidence.

## Production implementation

### `AnalysisP021PhysicalEvidenceAdjudication.swift`

W45 adds a fail-closed path that starts from the current W43/W44 anchor chain and the exact W41 transfer package.

Production `adjudicate(...)`:

1. verifies the W44 certificate against the current W43 ledger;
2. recomputes and validates the supplied W42 anchor receipt and latest-ledger binding;
3. verifies the entire W41 transfer package;
4. requires W41 identities/roots/run summaries to equal the W42 anchor;
5. reopens the published W40 payload;
6. decodes W24/W25/build/device singleton evidence;
7. decodes every run's W23/W25/W35/W36/W37 artifact chain;
8. recomputes W24 acceptance at the original evaluation timestamp;
9. checks archived W24 batch equality to the retained per-run W23 evidence;
10. revalidates W25 receipts, W35 current runtime, W36 bounded execution and W37 capture integrity;
11. requires exact W24 planned-run inventory and unique W36 execution IDs;
12. requires physical-iOS telemetry and complete memory/thermal/battery/cancellation observations;
13. binds everything to an independent HQ W45 runtime binding.

### Genuine-runtime requirement

The runtime binding must identify:

- `GENUINE_LANE2_BOUNDED_DECODER`;
- `iphoneos`;
- `arm64`;
- decoder implementation/revision;
- selected Xcode/Swift/source revision;
- exact app build identity;
- physical device/OS/capture session;
- exact W44/W42/W41 roots;
- exact unique W36 run/execution inventory.

Compatibility, synthetic, unknown, simulator or non-arm64 bindings can never produce READY.

### Persisted report validation

`AnalysisP021PhysicalEvidenceAdjudicationReportValidator` reopens W45 reports and rejects:

- malformed roots/IDs;
- duplicate run or execution IDs;
- run-count drift;
- READY with any issue;
- READY without all planned physical runs;
- READY without memory/physical-footprint/thermal/battery/bounded-pull facts;
- cancellation READY without cancellation latency;
- NOT_READY without an issue;
- report-root mismatch.

## Durable XCTest source

Added:

- `AnalysisP021PhysicalEvidenceAdjudicationTests.swift`
- `AnalysisP021PhysicalEvidenceAdjudicationReportValidatorTests.swift`

Negative-first scenarios include:

- missing physical evidence;
- compatibility adapter;
- synthetic fixture;
- mixed W44/W42/W41 roots;
- execution substitution;
- duplicate execution IDs;
- deterministic report root/codec;
- forged READY with recomputed root but no physical runs;
- tampered report root;
- inconsistent NOT_READY.

### Execution status

Fresh full Worker-branch SwiftPM/XCTest: **NOT_OBSERVED**.

Reason: local `git ls-remote`/fresh checkout could not resolve `github.com` during this Wave. No claim is made that W45 XCTest ran in the canonical package.

HQ Epoch 30 Run #221 covers canonical W44, not W45.

## Portable Swift runtime-binding mirror

Environment:

- Swift 6.2.1
- x86_64 Linux
- compile: `-warnings-as-errors`

Result:

- compile PASS;
- 160,000 runtime checks PASS;
- compile elapsed ~0.43 s;
- compile max RSS 148,852 kB;
- runtime elapsed ~6.29 s;
- runtime max RSS 18,848 kB.

Checks include genuine binding acceptance at the structural layer and rejection of compatibility, synthetic, simulator/x86, W44-root drift, W42-root drift, W41-root drift and duplicate execution IDs.

This mirror is NON_PARITY and is not a selected-device run.

## SHA-256 report-root mirror

Result:

- 30,000 report packages;
- 270,000 mutations;
- PASS;
- ~6.270 s;
- max RSS ~110,388 kB.

Mutated bindings include W44/W42/W41 roots, checkpoint sequence, runtime binding ID, report status, W36 execution ID, bounded-pull flag and issue code. Every mutation changed the deterministic report root.

## Current P021 conclusion

W45 implementation is ready for real evidence, but current real evidence is not.

MOI-P021 must remain `MISSING` because this Worker session did not observe:

- the exact HQ W24 planned run inventory on a selected physical iPhone;
- a genuine Lane-2 bounded decoder execution bound to that run set;
- selected `iphoneos/arm64` Xcode runtime metadata from that execution;
- the complete physical RSS / physical-footprint / thermal / battery / cancellation run set needed to satisfy W24;
- an externally retained/signed or trusted-timestamped W45 runtime binding.

## Safety boundary

`READY_FOR_HQ_P021_JUDGMENT` is deliberately weaker than PARITY. Even after READY, HQ remains responsible for inspecting the physical evidence and editing `PARITY_MATRIX.json` if and only if the P021 gate is actually satisfied.
