# W35 Physical Analysis Runtime-Algorithm Evidence Runbook

## Purpose

W23 records physical-device telemetry, W25 records workload execution, and W24 evaluates repeated physical runs. After W31-W34, however, the exact Analysis runtime can legitimately differ by duration and active-build Chord guard state. W35 binds the actual executed runtime identity to each physical run so incompatible algorithm states cannot be pooled as if they were the same workload.

W35 is evidence-integrity hardening only. It does not execute an iPhone run, choose production thresholds, prove current-Moises quality, or declare PARITY.

## Critical current-path requirement

A complete W35 record is valid only when its runtime identity reports `exactSinglePreparedTraversal=true` and `algorithmSchemaID=L4-W35-SINGLE_PASS-W34-GUARDED-V1`.

The historical W25 `AnalysisCanonicalProductPipeline` / `AnalysisDeviceWorkloadRunner` still materializes a prepared signal and calls the older separate bounded analyzers. It does not exercise the W29-W34 single-pass runtime or W34 backend guard. Therefore that historical runner alone MUST NOT be used as MOI-P021 current-runtime evidence. W35 deliberately rejects it as `NON_CURRENT_ANALYSIS_RUNTIME_PATH`.

A later/current physical workload runner must execute the same W30-W34 product path and emit the W35 companion evidence from the same execution.

## Exact bindings

For every W24-predeclared run, archive exactly one W35 `AnalysisDeviceAlgorithmExecutionEvidence`. It must bind to:

- exact W24 `runID`, fixture ID and run kind;
- exact W23 performance-evidence run ID, device model, iOS version, bundle/app/build version and manifest;
- exact W25 workload `executionID`;
- exact W25 source binding and workload identity;
- exact manifest ID/SHA;
- exact W25 snapshot SHA for complete runs;
- exact W24 batch/profile identifiers.

The W23, W25 and W35 run-ID inventories must each exactly equal the W24 predeclared run set. Missing, duplicate and post-hoc replacement runs fail closed.

## Complete-analysis runtime identity

Complete runs require `FINALIZED_RUNTIME_IDENTITY` plus canonical SHA-256 of the runtime identity. The identity records:

- current algorithm schema ID;
- exact single prepared traversal flag and prepared sample count;
- W32 Tempo energy mode: `REFERENCE_RESCAN` or `ROLLING_REUSE`;
- W31 extreme-duration compression flag;
- Tempo/Chord/Section retention strides and safety flags;
- W34 Chord backend state;
- W34 verification limit/comparisons/matches;
- fallback state/index;
- reference and vectorized publication counts.

The validator recomputes the runtime identity SHA-256 and validates W34 state/counter invariants.

For repeated complete runs of the same fixture, the runtime-identity SHA must be identical. A fixture whose repeats mix `vectorizedVerified`, `scalarFallback`, different W31 strides, different W32 mode, or another runtime identity is not eligible for W24 aggregation as one comparable performance condition.

Do not require one global runtime identity across different fixtures: W31/W32 modes may legitimately differ with source duration. Homogeneity is enforced per fixture.

## Cancellation probes

Cancellation can occur before the final feature diagnostics exist. A cancellation record therefore uses `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION` and binds the exact run/execution/source/build identity without fabricating final runtime diagnostics or a snapshot SHA.

A cancellation record that claims finalized runtime identity or a final snapshot is invalid. W25 remains responsible for proving that real canonical work began before cancellation.

## W24 gate order

Canonical order for future physical Analysis acceptance:

1. freeze rights-cleared manifest;
2. W22 corpus coverage;
3. W26 physical fixture selection;
4. approve matching W24 profile and W25 workload policy;
5. execute W23 telemetry and W25 workload on the CURRENT W30-W34 product runtime;
6. create one W35 companion record from the same execution;
7. call `AnalysisDevicePerformanceAcceptanceWithAlgorithmEvaluator.evaluate`;
8. W35 validates exact inventory/runtime identity first;
9. only if W35 is valid does the existing W25 workload gate run;
10. only if W25 is valid may W24 performance acceptance execute;
11. HQ archives/corroborates all evidence and decides final PARITY.

If W35 fails, `workloadAndPerformance` is `nil`; W24 limits are not evaluated.

## Archive

Archive W35 policy-free companion evidence with W22/W26/W23/W24/W25/W27 materials. The W27 archive schema predates W35; until HQ extends the final archive inventory, preserve W35 bytes and SHA separately and do not claim that W27 currently requires this new role.

## PARITY boundary

Portable/source-shaped tests can prove validator behavior but cannot prove:

- selected Apple ARM/Xcode execution;
- real physical-iPhone memory/thermal/battery behavior;
- that Lane-2 decoding is truly bounded;
- current-iPhone Moises Chord or Analysis quality;
- final MOI-P013 or MOI-P021 PARITY.

Those remain HQ Late Integration gates.
