# W36 Current Physical Analysis Workload Runner Runbook

## Purpose

W36 replaces the historical W25 execution path for NEW MOI-P021 physical evidence. W25 receipt semantics remain unchanged, but new evidence must actually execute the W30-W34 chunked/single-pass Analysis runtime.

W36 is readiness/integrity infrastructure. It does not itself provide a physical iPhone, a genuine Lane-2 decoder, approved performance thresholds or PARITY.

## Required source contract

New physical evidence must construct `AnalysisChunkedSignal` with:

- exact source sample rate and sample count from the approved decoder/manifest path;
- a consumer-driven `AnalysisPCMChunkPulling` source;
- `sourceMemoryContract = BOUNDED_PULL_CONTRACT`.

`UNSPECIFIED` and `WHOLE_SIGNAL_COMPATIBILITY_MATERIALIZED` fail before Analysis work starts.

`AnalysisWholeSignalChunkedCompatibilityAdapter` is migration/test compatibility only and is forbidden as MOI-P021 bounded-input evidence.

The bounded-pull declaration is not hardware attestation. A concrete decoder may still hide large buffers. W23 process RSS / physical footprint is authoritative for integrated-device memory behavior.

## Current product-runtime identity

`ProjectOwnedMusicAnalyzer` chunked execution and `AnalysisCurrentDeviceWorkloadRunner` both use `AnalysisCurrentChunkedProductRuntime`.

The stage operations are:

1. `SIGNAL_PREPARATION`
   - pull source chunks;
   - sanitize/resample using W30 semantics;
   - one prepared traversal;
   - W29 shared Tempo/Key/Chord/Section feature extraction;
   - W31 retention mode;
   - W32 Tempo energy mode;
   - W33/W34 Chord spectral preclassification and backend guard.
2. `TEMPO` — finalize Tempo/beat inference from the prepared onset feature.
3. `BEAT` — observe resulting beat cardinality.
4. `KEY` — finalize Key from the collected windows.
5. `CHORD` — finalize timeline segments from already-classified Chord frames.
6. `SECTION` — section inference and boundary hardening.
7. `FINAL_SNAPSHOT_PUBLICATION` — W15/W10 snapshot hardening + canonical snapshot artifact.

Do not interpret the W25 CHORD stage duration as the whole Chord CPU cost. Heavy W33/W34 spectral work occurs during the shared single-pass `SIGNAL_PREPARATION` stage and is intentionally recorded there.

## One execution, two evidence records

Every W36 run creates one fresh `executionID`.

The same execution ID binds:

- W25 `AnalysisDeviceWorkloadReceipt`;
- W35 `AnalysisDeviceAlgorithmExecutionEvidence`.

For a complete run, the W35 companion additionally binds the final snapshot SHA and W31-W34 runtime diagnostics.

For a cancellation probe, W35 uses `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION` and contains no fabricated final runtime identity or snapshot.

## Cancellation procedure with W23

HQ should:

1. start `AnalysisIOSDevicePerformanceSession` for the exact predeclared run ID;
2. start `AnalysisCurrentDeviceWorkloadRunner`;
3. allow real source work to begin;
4. call W23 `recordCancellationRequested()` immediately before cancelling the Analysis task;
5. cancel the task;
6. after W36 returns `CANCELLED`, call W23 `recordCancellationObserved()`;
7. finish W23 with `completedNormally=false`.

W36 records actual pulled chunk/sample counts. A cancellation that observes zero source samples does not receive a W35 cancellation companion and cannot pass the canonical W35 gate.

W25 independently verifies that work timing begins before the W23 cancellation request and terminates consistently with W23 observed termination.

## Complete-run requirements

A complete run is evidence-eligible only when:

- bounded source contract is accepted;
- source descriptor matches the approved W25 source duration/sample rate;
- the seven W25 stages complete in exact order;
- the final snapshot is canonical JSON with matching SHA/output summary;
- W35 companion uses the same execution ID and snapshot SHA;
- feature diagnostics report exact single prepared traversal;
- the W35 current runtime identity validates.

## Canonical new physical gate

For new P021 evidence use:

`W22 -> W26 -> W36 current runner -> W23 telemetry -> W35 algorithm binding -> W25 receipt validation -> W24 acceptance`

The public gate remains `AnalysisDeviceCorpusAlgorithmPerformanceGate`. Its W35/W36 layer now suppresses downstream acceptance unless every planned run carries `BOUNDED_PULL_CONTRACT`.

The historical `AnalysisDeviceWorkloadRunner` and historical `AnalysisDeviceCorpusBoundPerformanceGate` remain regression/replay APIs only.

## Archive

Archive at minimum:

- W22/W26 policy/report;
- W24 profile;
- W23 raw telemetry + validation for every planned run;
- W25 receipt + validation for every planned run;
- W35/W36 algorithm companion for every planned run;
- W36 source-input contract and runtime diagnostics;
- exact source manifest/SHA bindings;
- integrated build/device corroboration;
- W24 acceptance report.

W27 archive inventory predates W35/W36. The archive role set must be extended/frozen before final MOI-P021 evidence can be considered tamper-evident.

## Non-PARITY boundary

Passing W36 portable tests or source-shaped compilation does not prove:

- actual Lane-2 decoder boundedness;
- physical-iPhone RSS/thermal/battery;
- Apple ARM runtime equivalence;
- HQ-approved performance thresholds;
- current-Moises Analysis quality;
- PARITY.

Those remain HQ Late Integration responsibilities.
