# W37 Physical-iPhone Analysis Capture Orchestration Runbook

Status: NON_PARITY readiness. Worker 4 does not declare MOI-P021 PARITY.

## Purpose

Run W23 physical telemetry around the exact W36 current chunked product workload, while binding W25 workload receipt and W35 runtime-algorithm companion to one HQ-predeclared run. W37 owns orchestration integrity only; HQ owns production thresholds, cancellation timing values, corpus selection, final physical-device acceptance and PARITY.

## Required inputs

1. HQ W24 `AnalysisDevicePerformanceAcceptanceProfile` with one exact planned run ID / fixture / run kind.
2. HQ W25 `AnalysisDeviceWorkloadPolicy` with the same manifest, source binding and analyzer/build identity.
3. `AnalysisDeviceCapturePlan` with `authority = HQ_LATE_INTEGRATION` and the same run/fixture/manifest/identity.
4. A genuine Lane-2 decoder wired as `AnalysisPCMChunkPulling` / `AnalysisChunkedSignalLoading` and honestly declared `BOUNDED_PULL_CONTRACT`.
5. Physical iPhone selected by HQ. Do not use `AnalysisWholeSignalChunkedCompatibilityAdapter` for P021 evidence.

## Complete-analysis capture

- Start `AnalysisIOSPhysicalCaptureCoordinator.capture` with the HQ plan.
- W23 captures start telemetry immediately.
- The coordinator starts the W36 current product runtime and periodically samples RSS, physical footprint, thermal state and battery while W36 is alive.
- When W36 returns, W37 cancels and joins all helper tasks before finalization.
- The final result must include W23 performance evidence, W25 validation, W35 algorithm evidence, W36 execution, and W37 execution-integrity evidence.
- Any run/fixture/manifest/source/identity mismatch fails closed.

## Cancellation capture

Cancellation timing is supplied by HQ; Worker code must not invent a production delay.

Required order:

1. Observe the first non-empty real PCM chunk from W36 lifecycle instrumentation.
2. Apply the HQ-supplied delay.
3. Record W23 `cancellationRequested`.
4. Call `workloadTask.cancel()`.
5. Require W36 to return `CANCELLED` with observed source samples > 0.
6. Only then record W23 `cancellationObserved`.
7. Cancel/join periodic sampler and cancellation helper before `session.finish`.

Source-work timeout is cleanup only. It must not be recorded as an evidence cancellation request.

## Telemetry fail-closed rules

W37 rejects or marks invalid:

- non-bounded source contract;
- telemetry sampler not joined before finalization;
- cancellation helper not joined before finalization;
- `TELEMETRY_SAMPLE_CAP_REACHED`;
- a capture lasting at least one requested interval with no periodic sample beyond start/final snapshots;
- cancellation observed before requested;
- cancellation observed when W36 did not return `CANCELLED`;
- planned cancellation that completed normally or before source work;
- W23/W25/W35/W36 run identity mismatch;
- W35/W36 execution-ID mismatch;
- duplicate run IDs or one W36 execution ID reused across distinct W37 runs in a capture batch.

The W23 start/final forced snapshots remain bounded by the existing `maximumSampleCount + 1` evidence contract. Reaching the periodic sampling cap is never a silent success.

## Archive outputs

Archive at least:

- HQ capture plan;
- W23 performance evidence + validation;
- W25 workload receipt + validation;
- W35 algorithm companion;
- W36 current workload execution metadata;
- W37 execution-integrity evidence + validation;
- W24 repeated-run acceptance report after all planned runs are complete.

W27 archive roles predate W35-W37. Until W38 extends the archive schema, preserve these artifacts without claiming that the W27 final-role inventory is complete.

## Remaining HQ gates

W37 completion does not close MOI-P021. Remaining gates include genuine Lane-2 bounded decoding, selected Xcode/Apple ARM compile, physical iPhone execution, real RSS/physical footprint/thermal/battery/cancellation measurements, repeated worst-case W24 acceptance, approved HQ thresholds, archive integrity extension and HQ PARITY judgment.
