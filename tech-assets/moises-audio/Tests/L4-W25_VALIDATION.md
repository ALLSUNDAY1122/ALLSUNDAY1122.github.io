# L4-W25 Validation — Physical-iPhone Analysis workload integrity

## Result

Worker-side result: `FULL_WORKLOAD_INTEGRITY_STRUCTURALLY_COMPLETE_PENDING_HQ`.

This is NON_PARITY evidence. It closes the specific W23/W24 loophole where an arbitrary/no-op/partial workload could produce attractive telemetry and enter acceptance without a machine-checkable full-Analysis receipt. It does not establish physical-device performance or feature PARITY.

## Production changes

- Added the W25 production set: `AnalysisDeviceWorkloadReceipt.swift`, `AnalysisDeviceWorkloadValidation.swift`, `AnalysisDeviceWorkloadRunner.swift`, `AnalysisDevicePerformanceWorkloadGate.swift`, and `AnalysisDeviceWorkloadSHA256.swift`.
- Added exact W23 run/manifest/fixture/source/analyzer/config/build binding.
- Added canonical seven-stage workload trace and complete/cancellation semantics.
- Added deterministic canonical snapshot bytes, SHA-256 and output/cardinality binding.
- Added run-specific execution binding and cross-run reuse rejection.
- Added `AnalysisCanonicalProductPipeline` and fixed `AnalysisDeviceWorkloadRunner`; benchmark execution is no longer an arbitrary closure.
- Added W25-first wrapper around W24 acceptance: invalid/missing workload receipts prevent performance acceptance from running.
- Added fail-closed HQ policy template and operator runbook.

## Portable validation

Environment: Swift 6.2.1, x86_64 Linux. Production source-shaped Swift 6 typecheck: PASS. Durable XCTest source-shaped Swift 6 typecheck against an `-enable-testing` mock module: PASS.

Adversarial harness, five clean runs: `16/16 PASS` each.

Covered cases include valid full workload, missing tempo, missing section, impossible order, duplicate stage, source SHA swap, run-ID mismatch, manifest mismatch, snapshot SHA tamper, copied execution receipt, cancellation before work, cancellation after real work, complete/cancel semantic mismatch, deterministic codec, legitimate same-snapshot repeated runs and SHA-256 known vector.

Stress validation: 10,000 complete receipts per clean process × five = 50,000 validated receipts, all PASS.

| Run | Internal seconds | Process wall seconds | Max RSS kB |
| --- | ---: | ---: | ---: |
| 1 | 12.933978 | 12.96 | 27100 |
| 2 | 12.646778 | 12.69 | 27152 |
| 3 | 12.749567 | 12.78 | 27072 |
| 4 | 12.775439 | 12.80 | 27128 |
| 5 | 12.623320 | 12.65 | 27064 |

These timing/RSS values measure only the portable W25 validator stress harness. They are not an iPhone performance benchmark and must not be used as P021 acceptance evidence.

## Important design correction

A deterministic analyzer can legitimately emit exactly the same canonical snapshot for repeated runs of the same fixture. Therefore W25 intentionally does **not** reject repeated snapshot SHA values. Instead it binds each receipt to its own run ID, workload start, stage trace and execution ID, and rejects reuse of an execution ID/execution binding across different runs.

Source metadata comparison occurs against the original injected decoded signal before `AnalysisWorkingSetPolicy` resampling. Comparing the preprocessed 8 kHz working signal against a 44.1/48 kHz source binding would be incorrect and was avoided.

## Remaining HQ gates

- actual rights-cleared production corpus selection and source-file SHA provenance;
- actual current-iPhone Moises differential evidence;
- integrated Xcode/SwiftPM execution;
- actual physical-iPhone W23/W24/W25 runs;
- HQ-approved production performance thresholds;
- archive authenticity/device-run attestation;
- final PARITY_MATRIX decision.

Accordingly MOI-P009/P011/P013/P016/P021 remain `MISSING`.
