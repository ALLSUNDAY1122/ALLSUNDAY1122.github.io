# Analysis Device Workload Receipt Runbook — L4-W25 + W35/W36 clarification

## Purpose

W23 measures physical-device telemetry and W24 evaluates repeated predeclared runs. W25 adds a fail-closed workload receipt so a fast/low-memory record cannot pass without proving real Analysis work occurred.

W25 remains the receipt/integrity schema. W35 adds runtime-algorithm identity. W36 supplies the canonical current W30-W34 execution runner without mutating historical W25 receipt bytes or validation rules.

## Predeclare before the run

HQ must fill `ANALYSIS_DEVICE_WORKLOAD_POLICY_TEMPLATE.json` with exact manifest ID/SHA, fixture/source SHA and metadata, analyzer/version, Analysis configuration ID, integrated build identity and approval reference. Placeholder values fail validation.

## Historical runner boundary

The W25 `AnalysisDeviceWorkloadRunner` and its internal `AnalysisCanonicalProductPipeline` were created before W28-W34. They materialize a prepared signal and invoke the older separate Tempo/Key/Chord path.

They remain historical receipt/regression APIs only. They MUST NOT be presented as current W30-W34 MOI-P021 evidence.

For NEW physical evidence use `AnalysisCurrentDeviceWorkloadRunner` with a `BOUNDED_PULL_CONTRACT` `AnalysisChunkedSignal`. It executes the same `AnalysisCurrentChunkedProductRuntime` used by `ProjectOwnedMusicAnalyzer` on its chunked path and emits W25 + W35 evidence from one execution ID.

`AnalysisWholeSignalChunkedCompatibilityAdapter` and `UNSPECIFIED` source contracts are invalid for new bounded-input evidence.

## Stage semantics after W36

The seven W25 stage identifiers are preserved for compatibility, but their honest timing meaning is:

1. `SIGNAL_PREPARATION`: source pull, resampling, single-pass shared feature extraction and W33/W34 Chord spectral preclassification;
2. `TEMPO`: Tempo finalization from precomputed onset;
3. `BEAT`: beat output observation;
4. `KEY`: Key finalization from precollected windows;
5. `CHORD`: timeline finalization from preclassified frames;
6. `SECTION`: section inference/boundary hardening;
7. `FINAL_SNAPSHOT_PUBLICATION`: snapshot hardening + canonical output artifact.

Therefore CHORD stage duration alone is not the complete Chord CPU cost. Heavy spectral work is truthfully included in SIGNAL_PREPARATION.

## Complete-analysis receipt semantics

A complete W25 receipt remains valid only when:

- run ID/kind exactly match W23;
- manifest, source and analyzer/config/build identity match policy;
- required canonical stages occur once in order with valid timing;
- complete run terminates normally;
- final snapshot canonical JSON, SHA-256 and output summary agree;
- run-specific execution binding SHA recomputes exactly.

Identical snapshot SHA across independent repeats is allowed; execution reuse is detected by run/execution binding rather than by requiring nondeterministic outputs.

For W36 physical acceptance additionally require the W35 companion from the same `executionID`, snapshot SHA and `BOUNDED_PULL_CONTRACT` source.

## Cancellation receipt semantics

A W25 cancellation receipt has no final snapshot. It must show a completed canonical prefix followed by one terminal cancelled stage and prove real work began before cancellation.

W36 additionally observes actual source pull progress. A cancellation before any source sample was returned receives no W35 companion and therefore cannot pass the W35/W36 canonical gate.

W35 cancellation evidence binds the same run/execution/source/build but uses `CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION`; it does not fabricate final W31-W34 diagnostics.

## Canonical new-device gate

For new physical Analysis evidence use `AnalysisDeviceCorpusAlgorithmPerformanceGate`, not historical W25-only entry points.

Canonical order:

1. W22 rights-cleared corpus coverage;
2. W26 physical fixture selection;
3. W23 physical telemetry around W36 current workload execution;
4. W36 W25 receipt + W35 companion from one execution;
5. W35/W36 exact inventory/source-contract/runtime validation;
6. W25 receipt validation;
7. W24 repeated worst-case acceptance.

If W35/W36 is invalid, W25/W24 downstream evaluation is suppressed.

## Archive requirements

Archive HQ workload policy, W23 performance evidence, W25 receipts/reports, W35/W36 companion records/runtime hashes/source-contract evidence, W24 profile/report, source manifest/SHA, integrated build corroboration and device evidence. W27 predates W35/W36, so its final archive role inventory must be extended/frozen before claiming these new records are tamper-evident.

## Evidence boundary

A `BOUNDED_PULL_CONTRACT` is a software contract, not proof that a concrete decoder has no hidden retention. Genuine Lane-2 bounded decoding, selected Xcode/Apple execution, actual iPhone RSS/physical-footprint/thermal/battery, current-Moises differential, archive anchoring and final PARITY remain HQ Late Integration responsibilities.
