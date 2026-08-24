# Analysis Device Workload Receipt Runbook — L4-W25 + W35 clarification

## Purpose

W23 measures physical-device telemetry and W24 evaluates repeated predeclared runs. W25 adds a fail-closed workload receipt so a fast/low-memory record cannot pass without proving real Analysis work occurred.

W25 remains valid as a receipt/integrity schema. W35 adds a separate runtime-algorithm companion rather than mutating W25 receipt semantics.

## Predeclare before the run

HQ must fill `ANALYSIS_DEVICE_WORKLOAD_POLICY_TEMPLATE.json` with exact manifest ID/SHA, fixture/source SHA and metadata, analyzer/version, Analysis configuration ID, integrated build identity and approval reference. Placeholder values fail validation.

## Historical runner boundary

The W25 `AnalysisDeviceWorkloadRunner` and its internal `AnalysisCanonicalProductPipeline` were created before W28-W34. They materialize a prepared signal and invoke the older separate Tempo/Key/Chord path.

They remain useful for historical W25 receipt regression and do not need to be deleted, but they MUST NOT be presented as the current W30-W34 product runtime for new MOI-P021 evidence.

A current physical workload runner must exercise the same single-pass/chunk-capable W30-W34 runtime used by `ProjectOwnedMusicAnalyzer` and must emit W35 companion runtime-algorithm evidence from that same execution. W35 rejects complete records with `exactSinglePreparedTraversal=false` or a non-current algorithm schema.

## Complete-analysis receipt semantics

A W25 complete receipt remains valid only when:

- run ID/kind exactly match W23;
- manifest, source and analyzer/config/build identity match policy;
- required canonical stages occur once in order with valid timing;
- complete run terminates normally;
- final snapshot canonical JSON, SHA-256 and output summary agree;
- run-specific execution binding SHA recomputes exactly.

Identical snapshot SHA across independent repeats is allowed; execution reuse is detected by run/execution binding rather than by requiring nondeterministic outputs.

For post-W35 physical acceptance, additionally supply one finalized W35 runtime identity bound to the exact W25 `executionID` and snapshot SHA.

## Cancellation receipt semantics

A W25 cancellation receipt has no final snapshot. It must show a completed canonical prefix followed by one terminal cancelled stage and prove real work began before cancellation.

W35 cancellation evidence binds the same run/execution/source/build but uses `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION`; it must not fabricate a final runtime identity when cancellation happens before feature finalization.

## Canonical post-W35 gate

For new physical Analysis evidence use `AnalysisDeviceCorpusAlgorithmPerformanceGate`, not the historical W25-only acceptance entry point.

Canonical order:

1. W22 rights-cleared corpus coverage;
2. W26 physical fixture selection;
3. W23 telemetry and W25 workload receipt on the CURRENT W30-W34 runtime;
4. W35 runtime-algorithm companion evidence;
5. W35 exact inventory/binding validation;
6. W25 receipt validation;
7. W24 repeated worst-case acceptance.

If W35 is invalid, W25/W24 downstream evaluation is suppressed.

## Archive requirements

Archive HQ workload policy, W23 performance evidence, W25 receipts/reports, W35 companion records/runtime hashes, W24 profile/report, source manifest/SHA, integrated build corroboration and device evidence. W27 predates W35, so HQ must extend/freeze the final archive inventory before claiming the new W35 role is covered by W27.

## Evidence boundary

W25/W35 integrity infrastructure is not PARITY. Genuine Lane-2 bounded decoding, selected Xcode/Apple execution, real iPhone RSS/thermal/battery, current-Moises differential, archive anchoring and final PARITY remain HQ Late Integration responsibilities.
