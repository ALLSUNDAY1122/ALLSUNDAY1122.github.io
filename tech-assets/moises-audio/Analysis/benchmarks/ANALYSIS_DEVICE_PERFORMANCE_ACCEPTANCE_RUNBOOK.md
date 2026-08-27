# W24 Physical-iPhone Analysis Performance Acceptance Runbook

Purpose: prevent a single favorable W23 physical-iPhone run, a favorable mean, a cherry-picked fixture subset, or a different runtime algorithm from becoming MOI-P021 evidence.

W24 does not execute the device benchmark, choose production thresholds, or declare PARITY. HQ Late Integration owns physical-iPhone execution, threshold approval, archive and final PARITY judgment.

## 0. Pass W22 and W26 before approving W24

Freeze the exact rights-cleared manifest, pass W22 corpus coverage, then pass W26 physical corpus selection against the same manifest/policy. W24 `requiredFixtureIDs` and `expectedFixtureDurationsSeconds` must exactly equal the W26 selected inventory. If W22/W26 changes, issue a new W24 profile/batch.

## 1. Approve the profile before running

Start from `ANALYSIS_DEVICE_PERFORMANCE_ACCEPTANCE_PROFILE_TEMPLATE.json`. HQ must fill exact batch/profile, device/iOS/app/build, manifest, W26 fixture inventory, at least two complete and two cancellation runs per fixture, exact predeclared run IDs, and every approved wall/memory/thermal/battery/cancellation limit.

The exact run IDs are frozen before execution so unfavorable attempts cannot be dropped after capture.

## 2. Capture W23 and W25 on the current product runtime

Every submitted run must satisfy W23 structural validation. W23 rejects simulator/portable execution, unavailable required telemetry, corrupt timing/samples, mixed provenance and inconsistent completion state.

W25 must prove real canonical workload execution. After W35, however, the historical `AnalysisDeviceWorkloadRunner` / `AnalysisCanonicalProductPipeline` is not sufficient for new P021 evidence because it predates the W29-W34 single-pass runtime and W34 backend guard.

New physical acceptance must execute the current W30-W34 product-equivalent runtime and produce W35 companion algorithm evidence from the same execution.

## 3. Pass W35 runtime-algorithm identity before W24

Use `AnalysisDeviceCorpusAlgorithmPerformanceGate` as the canonical post-W35 entry point. The order is:

1. W22 corpus coverage;
2. W26 physical fixture selection;
3. W23 telemetry + W25 workload capture on the current runtime;
4. W35 exact runtime-algorithm companion evidence;
5. W25 receipt validation;
6. W24 performance acceptance.

W35 requires exact W23/W25/W24 run inventory and binds run ID, W25 execution ID, snapshot SHA, source, analyzer/config/build, device/iOS/app/build, manifest, W31 retention modes, W32 Tempo mode and W34 Chord backend state.

Repeated complete runs for the same fixture must have the same W35 runtime identity SHA. `vectorizedVerified`, `scalarFallback`, `verifying`, different W31 strides or different W32 modes must not be pooled as one comparable performance condition.

Cancellation probes may end before runtime identity finalization; they bind the exact run/execution without inventing final diagnostics.

If W35 fails, W25/W24 are not evaluated.

The older `AnalysisDeviceCorpusBoundPerformanceGate` is historical pre-W35 compatibility only and MUST NOT be used for new MOI-P021 acceptance.

## 4. Submit the exact W23/W24 batch

The W23 run-ID set, W25 receipt set and W35 companion set must each exactly equal W24 `plannedRuns`. No planned run may be absent and no post-hoc replacement may be inserted unless HQ approves a new batch/profile before rerunning.

If build, device, iOS, W22/W26 selection, manifest, runtime algorithm identity, run plan or thresholds change, create a new evidence batch rather than combining epochs.

## 5. Worst-case acceptance semantics

W24 never averages away bad runs. For every required fixture it records the worst run for:

1. complete-analysis wall seconds;
2. peak resident bytes;
3. peak physical-footprint bytes;
4. worst thermal-state rank;
5. battery drain fraction;
6. memory-pressure event count;
7. cancellation latency seconds.

A fixture passes only when every required worst metric is present and within the HQ-approved limit. A good mean cannot offset one approved-limit breach.

## 6. Status meanings

`INVALID_PROFILE`: profile/approval is incomplete or inconsistent.

`INCOMPLETE_PHYSICAL_DEVICE_EVIDENCE`: exact run set, W23/W25/W35 binding, telemetry or preconditions are incomplete/invalid. This is invalid evidence, not a performance failure.

`OUTSIDE_HQ_APPROVED_LIMITS`: exact valid physical run set exists, but at least one worst-case metric exceeds an HQ-approved limit.

`WITHIN_HQ_APPROVED_LIMITS_PENDING_HQ`: all exact repeated physical runs and runtime identities are valid and every worst metric is inside approved limits. This still is not PARITY.

## 7. Required archive

Archive together:

- W22 coverage policy/report;
- W26 selection policy/report;
- W24 profile and exact W23 evidence batch;
- every W23 raw record/report;
- W25 workload policy/receipts/reports;
- every W35 algorithm-execution companion record and canonical runtime-identity SHA;
- W24 acceptance report;
- manifest bytes/SHA;
- integrated app build corroboration;
- device/iOS corroboration;
- operator notes for interrupted/replaced attempts.

W27 predates W35. Until HQ extends the W27 archive role inventory, preserve W35 bytes/SHA separately and do not claim W27 currently requires them.

## 8. MOI-P021 boundary

W22/W26/W23/W25/W35/W24 together harden corpus selection, workload authenticity, runtime-algorithm comparability and repeated worst-case measurement. They still do not themselves supply a real iPhone run, a genuine bounded Lane-2 decoder, production thresholds, current-Moises differential evidence, hardware attestation, or final MOI-P021 PARITY. Those remain HQ Late Integration responsibilities.
