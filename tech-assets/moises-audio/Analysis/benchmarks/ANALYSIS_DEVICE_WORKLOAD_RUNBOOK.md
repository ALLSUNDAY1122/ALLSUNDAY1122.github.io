# Analysis Device Workload Receipt Runbook — L4-W25

## Purpose

W23 measures physical-device telemetry and W24 evaluates repeated predeclared runs against HQ-approved limits. Neither layer alone proves that a fast/low-memory record actually executed the full Project Analysis workload. W25 adds a fail-closed workload receipt that must validate before a W24 run is eligible for acceptance evaluation.

This is integrity infrastructure, not PARITY evidence. Physical-iPhone execution, source-file loading, corpus approval, production thresholds, evidence archive authenticity and final PARITY remain HQ Late Integration responsibilities.

## Predeclare before the run

HQ must fill `ANALYSIS_DEVICE_WORKLOAD_POLICY_TEMPLATE.json` with:

- exact manifest ID and SHA-256;
- exact fixture IDs and source-audio SHA-256 values;
- canonical source duration, sample rate and channel count from the approved loader/manifest path;
- exact `ProjectOwnedMusicAnalyzer` / analyzer version;
- exact Analysis configuration ID;
- exact integrated build identity;
- an HQ approval reference.

Placeholder values deliberately fail validation. Worker 4 defines no production performance threshold in W25.

## Required execution path

Use `AnalysisDeviceWorkloadRunner` with an `AnalysisSignal` injected by the integration-owned loading path. The runner is not an arbitrary timing closure: it executes `AnalysisCanonicalProductPipeline`, which uses the same bounded/cancellable Worker-4 stages as the product analyzer:

1. signal preparation;
2. tempo;
3. beat output observation;
4. key;
5. chord;
6. song section + boundary hardening;
7. final `AnalysisSnapshot` hardening/publication.

The runner validates original decoded-signal duration/sample-rate against the predeclared source binding before preprocessing. Source-file SHA and original channel metadata are supplied by the approved loader/manifest path; Worker 4 does not duplicate Lane-2 decoding or file lifecycle.

## Complete-analysis run

A complete run is valid only when:

- receipt run ID and kind exactly match W23 evidence;
- manifest, fixture/source binding and analyzer/config/build identity match the HQ policy;
- every required stage appears once, in canonical order, with finite monotonic offsets and `COMPLETED` status;
- W23 says `completedNormally=true`;
- final snapshot bytes are already in deterministic canonical JSON form;
- SHA-256 recomputed from those bytes matches the receipt;
- output decision/cardinality summary matches the decoded snapshot;
- the run-specific execution binding SHA recomputes exactly.

Identical snapshot SHA values across two independent repeats are allowed. Deterministic analysis should often produce identical output. Reuse is detected through run-specific `executionID` / execution-binding reuse, not by incorrectly requiring different snapshot content.

## Cancellation probe

A cancellation receipt has no final snapshot. It must contain a completed canonical prefix followed by one terminal `CANCELLED` stage, while W23 reports `completedNormally=false` and supplies cancellation request/observed offsets. Stage timing must prove canonical work started before the cancellation request and termination is consistent with the W23 observation window. A no-stage/no-op cancellation cannot pass.

## W24 integration

Call `AnalysisDevicePerformanceAcceptanceWithWorkloadEvaluator.evaluate`. It first requires an exact one-to-one receipt inventory for the W23/W24 batch and validates every receipt. If any workload receipt is invalid, `performanceAcceptance` is `nil`; W24 performance limits are not evaluated on that batch.

## Archive requirements

Archive together, without hand editing:

- HQ workload policy;
- W23 performance evidence batch;
- W25 workload receipts;
- W24 performance profile and gate report;
- source manifest + SHA record;
- integrated app build identifier and device-run corroboration.

W25 does not cryptographically attest that a JSON record originated on the declared phone. Evidence archive signing/attestation is a separate remaining integrity gap for HQ/next Worker wave.
