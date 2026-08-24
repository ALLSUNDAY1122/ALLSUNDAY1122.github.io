# L4-W35 Validation — Physical Runtime-Algorithm Evidence Binding

## Result

W35 is complete as Worker-4 evidence-integrity hardening. It does not establish MOI-P013 or MOI-P021 PARITY.

## Problem closed

W23/W24 physical telemetry originally bound device/build/manifest/run inventory, while W25 bound workload execution. After W31-W34, the same nominal Analysis build can execute different duration/resource modes and different Chord backend states. W35 prevents those states from being silently pooled.

During W35 review an additional correctness gap was found: the historical W25 `AnalysisDeviceWorkloadRunner` still uses `AnalysisCanonicalProductPipeline`, which materializes prepared PCM and invokes the pre-W28 separate analyzers. It does not execute the W29-W34 single-pass runtime or W34 guard. Therefore it is retained only for historical receipt/regression compatibility and is explicitly rejected as new current-runtime P021 evidence.

## Production changes

- `AnalysisDeviceAlgorithmExecutionEvidence.swift`
  - run-scoped companion evidence model;
  - canonical current algorithm schema ID;
  - W31/W32/W34 runtime identity;
  - canonical runtime-identity SHA-256;
  - separate finalized-complete and cancelled-before-finalization capture states.
- `AnalysisDeviceAlgorithmExecutionValidation.swift`
  - exact W24/W23/W25/W35 run inventory;
  - exact execution/source/analyzer/config/build/manifest/device binding;
  - complete snapshot SHA binding;
  - W34 state/counter invariants;
  - same-fixture repeated complete runtime-identity homogeneity;
  - legacy/non-single-pass current-runtime rejection.
- `AnalysisDevicePerformanceAlgorithmGate.swift`
  - suppresses W25/W24 downstream evaluation whenever W35 evidence is invalid.
- `AnalysisDeviceCorpusAlgorithmPerformanceGate.swift`
  - canonical post-W35 physical acceptance entry point: W26 selection -> W35 -> W25 -> W24.
- Package source registration, durable XCTest, fail-closed template and W24/W25 runbook corrections.

## Complete versus cancellation semantics

Complete runs must carry `FINALIZED_RUNTIME_IDENTITY`, W25 snapshot SHA, exact single-pass diagnostics and a canonical runtime-identity SHA.

Cancellation probes may terminate before final feature diagnostics exist. They therefore bind exact W23/W25 run/execution/source/build identity using `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION` and must not fabricate a final runtime identity or snapshot.

## Runtime identity fields

The complete runtime identity binds:

- `algorithmSchemaID=L4-W35-SINGLE_PASS-W34-GUARDED-V1`;
- exact single prepared traversal and prepared sample count;
- W32 Tempo mode (`REFERENCE_RESCAN` / `ROLLING_REUSE`);
- W31 compression flag, Tempo/Chord/Section strides and safety flags;
- W34 guard state, verification limit/count/matches, fallback state/index and publication counts.

Repeated complete runs for one fixture must have the same canonical runtime-identity SHA. Cross-fixture identity may legitimately differ because W31/W32 are duration dependent.

## Source-shaped Swift validation

Swift 6.2.1, `-strict-concurrency=complete`, `-warnings-as-errors`:

- W35 evidence model + validator + algorithm gate: PASS
- W35 corpus -> algorithm -> workload/performance gate: PASS

The execution environment could not DNS-resolve GitHub for a fresh repository clone, so a full canonical SwiftPM/Xcode checkout was not executed in this Worker wave. Canonical integrated SwiftPM/Xcode remains an HQ gate.

## Adversarial executable harness

`19/19 PASS`.

Covered:

1. exact 2 complete + 2 cancellation batch passes;
2. exact run inventory is reported;
3. missing W35 run fails;
4. missing W35 run suppresses W24 downstream evaluation;
5. mixed `vectorizedVerified` / `scalarFallback` complete identities in one fixture fail;
6. `exactSinglePreparedTraversal=false` fails as `NON_CURRENT_ANALYSIS_RUNTIME_PATH`;
7. W25 execution-ID substitution fails binding;
8. valid W35 gate permits downstream gate construction;
9. 3600-second source derives W32 rolling Tempo mode;
10. 120-second source derives reference-rescan Tempo mode.

## Inventory stress

10,000 predeclared runs per process: 5,000 complete + 5,000 cancellation. Five independent processes all passed.

Internal validator elapsed seconds:

- 0.122936
- 0.119360
- 0.128966
- 0.124917
- 0.127639

Process wall seconds: `0.21-0.22 s`.

Maximum RSS: `50,896 kB`.

These numbers measure W35 validator/inventory overhead only. They are not physical-iPhone Analysis performance results.

## Evidence boundary

W35 does not provide:

- real physical-iPhone execution;
- a genuine bounded Lane-2 decoder;
- HQ-approved production performance thresholds;
- current-iPhone Moises Analysis differential;
- current-Moises complex Chord vocabulary evidence;
- hardware/device attestation;
- final W27 archive inclusion for the new W35 artifact.

MOI-P009, P011, P013, P016 and P021 therefore remain MISSING. HQ Late Integration remains the sole PARITY authority.

## Durable artifacts

- `Analysis/AnalysisDeviceAlgorithmExecutionEvidence.swift`
- `Analysis/AnalysisDeviceAlgorithmExecutionValidation.swift`
- `Analysis/AnalysisDevicePerformanceAlgorithmGate.swift`
- `Analysis/AnalysisDeviceCorpusAlgorithmPerformanceGate.swift`
- `Tests/MoisesAudioCoreTests/AnalysisDeviceAlgorithmExecutionEvidenceTests.swift`
- `Analysis/benchmarks/ANALYSIS_DEVICE_ALGORITHM_EVIDENCE_TEMPLATE.json`
- `Analysis/benchmarks/ANALYSIS_DEVICE_ALGORITHM_EVIDENCE_RUNBOOK.md`
- `Analysis/benchmarks/L4-W35_RUNTIME_ALGORITHM_EVIDENCE_BINDING.json`
- updated W24/W25 runbooks
- `Package.swift`
