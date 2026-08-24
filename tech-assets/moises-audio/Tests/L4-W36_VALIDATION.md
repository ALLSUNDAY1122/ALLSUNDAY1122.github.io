# L4-W36 Validation — Current Single-Pass Physical Workload Runner

## Result

W36 is complete as Worker-4 execution/evidence hardening. It does not establish MOI-P009, P011, P013, P016 or P021 PARITY.

## Problem closed

W35 identified that the historical W25 `AnalysisDeviceWorkloadRunner` executes the pre-W28 materialized Analysis path. W36 adds a new physical workload runner that executes the current W30-W34 chunked/single-pass runtime and emits W25 receipt + W35 algorithm evidence from one execution ID.

`ProjectOwnedMusicAnalyzer` chunked execution now uses the same `AnalysisCurrentChunkedProductRuntime` stage functions as the W36 runner.

## Production changes

- `AnalysisChunkedInput.swift`
  - adds `AnalysisChunkedSourceMemoryContract`;
  - `BOUNDED_PULL_CONTRACT` is required for new P021 evidence;
  - compatibility adapter identifies itself as whole-signal materialized.
- `AnalysisCurrentChunkedProductRuntime.swift`
  - central current W30-W34 runtime shared by product chunked path and W36 physical runner.
- `AnalysisSignal.swift`
  - routes `ProjectOwnedMusicAnalyzer` chunked execution through the shared current runtime.
- `AnalysisCurrentDeviceWorkloadRunner.swift`
  - current chunked physical workload execution;
  - exact W25 seven-stage receipt;
  - one execution ID for W25/W35;
  - complete/cancellation behavior;
  - observed source chunk/sample progress;
  - zero-work cancellation suppression.
- `AnalysisDeviceAlgorithmExecutionEvidence.swift`
  - optional historical-decode-safe `sourceInputContract` binding;
  - W36 builders can create W35 evidence before W23 batch join using the exact receipt run/execution identity.
- `AnalysisDevicePerformanceAlgorithmGate.swift`
  - new physical evidence cannot reach W25/W24 unless every planned algorithm record declares `BOUNDED_PULL_CONTRACT`.
- Package registration, durable XCTest and runbooks updated.

## Honest W25 stage timing

The stage names remain backward compatible, but W36 does not misattribute shared work:

- `SIGNAL_PREPARATION` includes source pull, W30 resampling, single-pass shared feature extraction, W31/W32 runtime modes, and W33/W34 Chord spectral preclassification.
- `CHORD` only finalizes timeline segments from those preclassified frames.

Therefore CHORD stage wall time alone is not the total Chord CPU cost.

## Complete execution invariants

A successful W36 complete execution requires:

- `BOUNDED_PULL_CONTRACT`;
- descriptor sample rate and duration matching the W25 source binding;
- exact seven-stage order;
- canonical final snapshot JSON/SHA/output summary;
- W35 companion with the same W25 execution ID and snapshot SHA;
- exact single prepared traversal diagnostics.

The same input samples run directly through `AnalysisCurrentChunkedProductRuntime` and through W36 are covered by durable XCTest snapshot equality.

## Cancellation invariants

- cancellation probe that actually observes source samples may emit W35 `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION` evidence;
- final snapshot/runtime identity is absent;
- cancellation before the first source sample receives no W35 companion;
- W25/W23 timing validation remains independently required.

This prevents a stage-start-only/no-op cancellation from satisfying the new canonical W35/W36 layer.

## Swift validation

Swift 6.2.1 with `-strict-concurrency=complete -warnings-as-errors`:

- W36 current-device runner core: PASS;
- W36 current chunked product runtime: PASS after fixing a real tuple-label compile defect (`diagnostics` -> `inputDiagnostics` relabel);
- W36 observed puller actor: PASS;
- optional W35/W36 JSON fields: old JSON decode compatibility PASS.

The Worker environment could not perform a fresh network clone of GitHub, so full canonical SwiftPM/Xcode remains an HQ integrated-checkout gate.

## Portable executable validation

Backward-compatibility codec checks:

- historical algorithm evidence without `sourceInputContract` decodes to nil;
- historical gate report without `currentRuntimeSourceContractValid` decodes to nil;
- new `BOUNDED_PULL_CONTRACT` decodes correctly;
- result: `3/3 PASS`.

Stage/inventory state stress, five independent processes:

- 500,000 records/process;
- every process: `500000/500000 PASS`;
- wall approximately `0.02 s/process`;
- maximum RSS `16,852 kB`.

Cancellation observation stress, five independent processes:

- 100 observed-work cancellation cases/process: `100/100 PASS` every process;
- 100 zero-work cancellation cases/process: `100/100 PASS` every process;
- wall range `0.42-0.46 s/process`;
- maximum RSS `17,632 kB`.

These are Linux portable integrity/coordination measurements, not Analysis throughput or iPhone thermal/battery evidence.

## Fail-closed boundaries

W36 rejects for new P021 evidence:

- `UNSPECIFIED` source contract;
- `WHOLE_SIGNAL_COMPATIBILITY_MATERIALIZED` source contract;
- descriptor/source metadata mismatch;
- planned cancellation that completes normally instead of cancelling;
- zero-source-sample cancellation for W35 companion purposes.

The public post-W35 acceptance gate additionally refuses downstream W25/W24 evaluation unless every planned W35 record is bounded-pull.

## Remaining limitations

W36 does not prove:

- a genuine Lane-2 decoder is actually bounded internally;
- no hidden AVFoundation/decoder cache exists;
- physical-iPhone RSS/physical-footprint/thermal/battery;
- Apple ARM runtime behavior;
- HQ-approved thresholds;
- current-iPhone Moises Analysis differential;
- archive coverage of the new W35/W36 artifacts.

`BOUNDED_PULL_CONTRACT` is only a software execution contract. W23/W24 physical telemetry remains authoritative for integrated memory/thermal/battery behavior.

## Durable artifacts

- `Analysis/AnalysisChunkedInput.swift`
- `Analysis/AnalysisCurrentChunkedProductRuntime.swift`
- `Analysis/AnalysisSignal.swift`
- `Analysis/AnalysisCurrentDeviceWorkloadRunner.swift`
- `Analysis/AnalysisDeviceAlgorithmExecutionEvidence.swift`
- `Analysis/AnalysisDevicePerformanceAlgorithmGate.swift`
- `Tests/MoisesAudioCoreTests/AnalysisCurrentDeviceWorkloadRunnerTests.swift`
- `Tests/MoisesAudioCoreTests/AnalysisCurrentDeviceWorkloadCancellationIntegrityTests.swift`
- `Analysis/benchmarks/ANALYSIS_CURRENT_DEVICE_WORKLOAD_RUNBOOK.md`
- `Analysis/benchmarks/L4-W36_CURRENT_PHYSICAL_WORKLOAD_RUNNER.json`
- updated `Analysis/benchmarks/ANALYSIS_DEVICE_WORKLOAD_RUNBOOK.md`
- `Package.swift`
