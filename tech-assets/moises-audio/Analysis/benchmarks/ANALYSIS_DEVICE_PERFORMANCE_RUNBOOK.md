# Physical-iPhone Analysis Performance Evidence Runbook

Purpose: collect the physical-iPhone evidence required by MOI-P021 for the Analysis lane without allowing simulator, portable, missing-telemetry, or fabricated-zero results to look like device evidence.

W23 defines the evidence schema, iOS collector, validation and archival procedure. It does **not** execute the HQ-owned physical-device run, choose production thresholds, or declare PARITY.

## Canonical prerequisites

1. Use the exact HQ-selected rights-cleared Analysis manifest that already passed the W22 corpus-coverage gate.
2. Preserve the exact manifest bytes and SHA-256.
3. Use the integrated iOS build selected by HQ Late Integration; record bundle ID, app version and build version from the running binary.
4. Use an actual iPhone for device evidence. Simulator output is deliberately classified `NON_PHYSICAL_RUNTIME_NON_PARITY`.
5. Keep the Project Analysis implementation and fixture identity unchanged during one evidence set. If the build or manifest changes, start a new evidence epoch.

## Collector

Create `AnalysisIOSDevicePerformanceSession` immediately before the Analysis workload.

The session records:

- runtime class: physical iPhone vs simulator;
- hardware model identifier and iOS version;
- app bundle/version/build;
- run ID and run kind;
- exact manifest ID/SHA-256;
- fixture ID and annotated duration;
- monotonic wall time using `ProcessInfo.systemUptime`;
- resident memory and physical footprint through `task_info(TASK_VM_INFO)` when available;
- `ProcessInfo.thermalState` samples and transitions;
- `UIDevice` battery level/state samples and raw start-to-end delta;
- `UIApplication.didReceiveMemoryWarningNotification` events as the public iOS memory-pressure warning channel;
- cooperative cancellation request/observed-termination offsets for cancellation-probe runs.

No unique device identifier is collected.

## Bounded sampling

`Configuration.sampleIntervalSeconds` and `maximumSampleCount` bound telemetry overhead. The default interval/cap are collection defaults only, not product acceptance thresholds.

Call `sample()` periodically while the actual Analysis run is active. The collector ignores calls that arrive before the configured interval. Once the configured cap is reached it stops periodic sampling and records `TELEMETRY_SAMPLE_CAP_REACHED`; `finish(...)` still attempts a final sample.

Do not increase sampling frequency merely to make a trace look smoother. The benchmark workload must remain the subject being measured.

## Complete-analysis run

For each HQ-selected representative long-track fixture:

1. Construct a session with `runKind: .completeAnalysis`.
2. Start the actual integrated Project Analysis workload.
3. Call `sample()` periodically until the workload completes or fails.
4. Call `finish(completedNormally: true)` only if the Analysis workload genuinely completed.
5. On workload failure call `finish(completedNormally: false, failureDescription: ...)` and retain the failed evidence rather than rerunning silently.
6. Encode the exact evidence with `AnalysisDevicePerformanceEvidenceCodec.encodeEvidence`.
7. Validate it against the exact manifest ID/SHA using `AnalysisDevicePerformanceEvidenceValidator`.

A structurally complete record is still only `PHYSICAL_DEVICE_EVIDENCE_STRUCTURALLY_COMPLETE_PENDING_HQ`; it is not a performance PASS.

## Cancellation-probe run

Cancellation responsiveness is measured in a separate run so normal completion and cancellation cannot be mixed.

1. Construct a session with `runKind: .cancellationProbe`.
2. Start the same representative Analysis workload.
3. At the HQ-defined cancellation point call `recordCancellationRequested()` immediately before sending cooperative cancellation to Analysis.
4. When the Analysis task actually terminates due to that cancellation call `recordCancellationObserved()`.
5. Finish the session.
6. The validator derives `cancellationLatencySeconds = observedTermination - requested`; operators must not type the latency manually.

Missing, reversed, or out-of-run cancellation timestamps fail closed.

## Telemetry availability rules

Unavailable telemetry is represented by `nil + explicit unavailableReason`, never by zero.

Examples:

- failed `task_info` => resident/physical-footprint values are nil with the kernel status reason;
- unavailable battery => battery level is nil with an explicit reason;
- unknown thermal mapping => state is `UNAVAILABLE` with an explicit reason.

A physical-device record lacking required usable memory, thermal, battery start/end, or memory-warning observation remains `PHYSICAL_DEVICE_TELEMETRY_INCOMPLETE_PENDING_HQ`.

Zero-byte memory, battery levels outside 0...1, unordered/out-of-run samples, missing unavailable reasons and over-cap arrays are invalid evidence.

## Battery interpretation

W23 stores raw battery level/state and derives only arithmetic delta/drain. It does not claim that battery percentage is a laboratory energy meter and does not define an acceptable battery-drain threshold.

HQ should keep charging state and test conditions controlled and documented when it performs the device gate. Any external energy instrumentation may be archived alongside W23 evidence but must not overwrite the raw `UIDevice` observations.

## Thermal interpretation

W23 records the sampled thermal-state sequence, worst observed state and transition count. It does not define which thermal state is acceptable for PARITY. HQ owns the acceptance profile and must compare representative workloads/builds under controlled conditions.

## Required archive

Archive together:

- exact W22-approved manifest bytes and SHA-256;
- integrated iOS commit/build identity;
- raw W23 evidence JSON for each complete-analysis run;
- raw W23 evidence JSON for each cancellation probe;
- W23 validation reports;
- fixture identity/rights evidence;
- any Xcode Organizer/MetricKit/device logs used as supplemental evidence;
- HQ-owned device-performance acceptance thresholds and final decision.

Do not keep only summarized peak numbers. The ordered raw samples are needed to investigate spikes, thermal transitions and warning timing.

## HQ decision boundary

W23 contains no production thresholds for wall time, peak resident memory, physical footprint, thermal state, battery drain or cancellation latency.

Only HQ Late Integration may decide whether the physical-iPhone measurements satisfy MOI-P021 and update `PARITY_MATRIX.json`.

## NON-PARITY warning

Portable/Linux tests exercise schema, codec, anti-fabrication validation and 50,000-sample scalability. The UIKit/Darwin collector is compiled only in an Apple/iOS-capable environment. Portable tests contain no physical-iPhone telemetry and cannot establish MOI-P021 PARITY.
