# W35/W36 Physical Analysis Runtime-Algorithm Evidence Runbook

## Purpose

W23 records physical-device telemetry, W25 records workload execution, and W24 evaluates repeated physical runs. W35 binds the exact W31-W34 runtime identity to each run. W36 supplies the current W30-W34 chunked physical workload runner and binds the source-input contract.

These are evidence-integrity/readiness layers. They do not execute a physical iPhone by themselves, choose production thresholds, prove current-Moises quality, or declare PARITY.

## Critical current-path requirement

A complete W35 record is valid only when its runtime identity reports `exactSinglePreparedTraversal=true` and `algorithmSchemaID=L4-W35-SINGLE_PASS-W34-GUARDED-V1`.

For NEW P021 physical evidence, use `AnalysisCurrentDeviceWorkloadRunner`. It executes `AnalysisCurrentChunkedProductRuntime`, the same runtime used by the chunked branch of `ProjectOwnedMusicAnalyzer`.

The historical W25 `AnalysisCanonicalProductPipeline` / `AnalysisDeviceWorkloadRunner` remains regression-only. It does not exercise W30-W34 and MUST NOT be used as current-runtime P021 evidence.

New W35 records must additionally carry `sourceInputContract=BOUNDED_PULL_CONTRACT`. Historical W35 JSON without this optional field remains decodable, but the current public performance gate suppresses W25/W24 for such records.

`UNSPECIFIED` and `WHOLE_SIGNAL_COMPATIBILITY_MATERIALIZED` are not valid new P021 source contracts.

## Exact bindings

For every W24-predeclared run, archive exactly one W35 `AnalysisDeviceAlgorithmExecutionEvidence`. It must bind to:

- exact W24 run ID, fixture and kind;
- exact W23 performance run/device/iOS/app/build/manifest provenance;
- exact W25 workload execution ID;
- exact W25 source/workload identity;
- exact manifest ID/SHA;
- exact W25 snapshot SHA for complete runs;
- exact W24 batch/profile identifiers;
- W36 bounded-pull source contract for new physical evidence.

The W23, W25 and W35 run-ID inventories must each exactly equal the W24 predeclared set. Missing, duplicate and post-hoc replacement runs fail closed.

## Complete-analysis runtime identity

Complete runs require `FINALIZED_RUNTIME_IDENTITY` plus canonical SHA-256 of the runtime identity. The identity records:

- current algorithm schema ID;
- exact single prepared traversal and prepared sample count;
- W32 Tempo energy mode;
- W31 compression flag and Tempo/Chord/Section retention strides/safety;
- W34 Chord backend state;
- W34 verification limit/comparisons/matches;
- fallback state/index;
- reference/vectorized publication counts.

Repeated complete runs of one fixture must have the same runtime-identity SHA. Do not require one global identity across fixtures because duration-dependent W31/W32 modes can legitimately differ.

## Cancellation probes

Cancellation may occur before final feature diagnostics exist. It therefore uses `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION` and must not invent final runtime identity or snapshot SHA.

W36 also records actual source pull progress. Cancellation before any source sample was observed receives no W35 companion, so a stage-start-only/no-op cancellation cannot enter the canonical W35/W36 gate.

W25/W23 remains responsible for checking request/termination timing relative to actual workload execution.

## Canonical gate order

1. freeze rights-cleared manifest;
2. W22 corpus coverage;
3. W26 physical fixture selection;
4. approve W24 profile and W25 workload policy;
5. start W23 physical telemetry;
6. execute `AnalysisCurrentDeviceWorkloadRunner` with genuine bounded-pull Lane-2 input;
7. obtain W25 receipt and W35 companion from one execution ID;
8. call `AnalysisDeviceCorpusAlgorithmPerformanceGate`;
9. W35/W36 validates exact inventory, runtime identity and bounded source contract;
10. only then W25 validates workload receipt;
11. only then W24 evaluates worst-case performance;
12. HQ archives/corroborates and decides final PARITY.

If W35/W36 fails, W25/W24 downstream evaluation is absent.

## Archive

Archive W35/W36 evidence with W22/W26/W23/W24/W25 materials. W27 predates W35/W36, so preserve these exact bytes/SHA separately until the archive schema is extended to make the new roles mandatory.

## PARITY boundary

`BOUNDED_PULL_CONTRACT` is a software declaration; it does not prove a concrete decoder has no hidden buffers. Portable/source-shaped tests also cannot prove selected Apple execution, physical-iPhone RSS/thermal/battery, current-Moises quality, or final P013/P021 PARITY. HQ Late Integration remains authoritative.
