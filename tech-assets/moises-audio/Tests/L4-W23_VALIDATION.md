# L4-W23 Validation — Physical-iPhone Analysis performance evidence harness

Date: 2026-08-24 JST
Lane: `LANE-4-IOS-ANALYSIS`
Evidence class: `NON_PARITY_SYNTHETIC_PORTABLE`

## Goal

Address MOI-P021 directly by making the future HQ physical-iPhone long-track Analysis run measurable and auditable without pretending that simulator/Linux measurements are device evidence.

## Production changes

### `Analysis/AnalysisDevicePerformanceEvidence.swift`

Adds a platform-neutral evidence schema, deterministic codec and fail-closed validator for:

- exact run ID and run kind;
- physical iPhone / simulator / portable runtime classification;
- device model and OS version;
- app bundle/version/build;
- exact manifest ID/SHA-256 and fixture identity/duration;
- monotonic wall duration;
- resident memory and physical footprint samples;
- thermal-state samples;
- battery level/state samples;
- memory-warning / pressure-observation events;
- cancellation request/observed-termination timestamps;
- explicit per-channel telemetry availability and limitations.

Derived summaries include peak resident bytes, peak physical footprint, worst thermal state, thermal transition count, battery delta/drain, memory-warning count and cancellation latency.

No performance acceptance thresholds are embedded.

### `iOS/HostCore/AnalysisIOSDevicePerformanceSession.swift`

Adds the iOS collector used by the integrated app/device gate. On Apple/iOS it records:

- physical device vs simulator at compile environment;
- hardware model identifier;
- `ProcessInfo.systemUptime` monotonic timing;
- `task_info(TASK_VM_INFO)` resident/physical-footprint memory;
- `ProcessInfo.thermalState`;
- `UIDevice` battery monitoring;
- `UIApplication.didReceiveMemoryWarningNotification`;
- cooperative cancellation request/termination anchors.

Sampling is interval-limited and count-bounded. The collector restores the prior battery-monitoring setting at finish.

### Package/test/runbook

- Package source list includes the W23 schema and guarded iOS collector.
- `AnalysisDevicePerformanceEvidenceTests.swift` covers structural summaries, simulator rejection, unavailable telemetry, cancellation derivation, corrupt memory/manifest binding and codec round-trip.
- `ANALYSIS_DEVICE_PERFORMANCE_RUNBOOK.md` defines the HQ physical-device procedure.
- `ANALYSIS_DEVICE_PERFORMANCE_EVIDENCE_TEMPLATE.json` is intentionally invalid/non-device until populated by a real run.

## Fail-closed behavior

W23 rejects or downgrades:

1. simulator/portable runtime as physical evidence;
2. wrong manifest ID/SHA-256;
3. empty provenance or invalid fixture duration;
4. zero/non-finite/negative wall timing;
5. unbounded sample configuration;
6. sample arrays beyond their configured cap;
7. zero-byte available memory;
8. missing memory values without explicit unavailable reasons;
9. unavailable telemetry channels without an explicit reason;
10. non-monotonic or out-of-run memory/thermal/battery/event offsets;
11. thermal `UNAVAILABLE` without a reason;
12. battery outside 0...1 or missing without a reason;
13. incomplete/reversed/out-of-run cancellation probes;
14. complete-analysis runs that secretly contain cancellation timestamps;
15. physical-device claims without usable memory, thermal and battery start/end telemetry.

Missing telemetry is never replaced by zero.

## Portable validation

Environment: Swift 6.2.1, x86_64 Linux.

- W23 core + guarded iOS source-shaped module typecheck: PASS.
- W23 XCTest source-shaped typecheck against an `-enable-testing` temporary module: PASS.
- Optimized portable adversarial harness: `18/18 PASS` in each of five runs.
- Stress input: 50,000 memory + 50,000 thermal + 50,000 battery samples per run.
- Internal validation seconds: `0.051182`, `0.049692`, `0.054248`, `0.052114`, `0.057806`.
- Process wall: approximately `0.06s` each run.
- Max RSS KB: `29828`, `29752`, `29740`, `29780`, `29760`.
- Worst internal: `0.057806s`.
- Maximum RSS: `29,828 KB`.

These are validator scalability numbers only. They are not Analysis runtime performance and are not physical-iPhone measurements.

## Apple-specific validation boundary

Linux cannot activate/typecheck the UIKit/Darwin branch. Therefore the active `AnalysisIOSDevicePerformanceSession` Apple-SDK compile, integrated Xcode build and actual telemetry acquisition remain HQ Late Integration gates.

This is intentionally recorded rather than treating the inactive conditional branch as physical-device validation.

## MOI-P021 state

`MOI-P021` remains `MISSING`.

W23 removes the instrumentation/schema gap, but the following are still required:

- actual integrated build on a physical iPhone;
- representative rights-cleared long-track fixtures;
- complete-analysis device runs;
- cancellation-probe device runs;
- real peak resident/physical-footprint measurements;
- real memory-warning observations;
- real thermal trajectory;
- real battery trajectory;
- HQ-approved acceptance thresholds and repeatability requirements;
- HQ final PARITY judgment.

`PHYSICAL_DEVICE_EVIDENCE_STRUCTURALLY_COMPLETE_PENDING_HQ` means only that a supplied record passed structural integrity checks. It does not prove that the device claim is truthful, that performance is acceptable, or that PARITY has been achieved.

## Newly exposed next gap

Once single-run telemetry is captured correctly, a favorable single run can still mask variance or a bad long-track case. The next useful hardening wave is a device-performance acceptance/repeatability aggregator that binds multiple physical runs to one exact build/device/iOS/manifest epoch, requires externally approved thresholds and minimum repetitions, reports worst-case memory/thermal/battery/wall/cancel results, and rejects cherry-picked/mixed-environment runs. HQ remains the sole owner of those thresholds and final device judgment.
