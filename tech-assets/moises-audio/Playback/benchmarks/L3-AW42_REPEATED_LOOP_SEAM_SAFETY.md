# L3-AW42｜Repeated Loop Seam Future-Automation Safety Gate

Result: `COMPLETE_NON_PARITY`

## Why this wave exists

P008 requires repeated loop boundaries to remain stable across repeated playback and tempo changes. AW32 already protects interactive discontinuities with immediate fade-out / delayed-generation-checked immediate fade-in, but the runtime snapshot still reports automatic repeated-loop envelope counters as zero. The unresolved proposal was to schedule future gain ramps around every automatic loop boundary.

That proposal is not safe in the currently selected Apple gain path:

- `AppleTransactionalStemGainRampStage.scheduleValidatedRamp` always calls `AUScheduleParameterBlock` with `AUEventSampleTimeImmediate`.
- The selected wrapper exposes no scheduled-event identifier, per-event cancellation operation, or generation-isolated render queue.
- `AppleBoundaryEnvelopedPlaybackBackend` can cancel a Swift `Task` before an immediate ramp is submitted, but that does not prove revocation of an Audio Unit parameter event after it has already been scheduled.
- `AUAudioUnit.reset()` / gain-stage replacement are not accepted substitutes until stale-event flushing semantics and audible transparency are proven on the selected graph and physical iPhone.

Apple API reference inspected for the host scheduling boundary:
- `AUScheduleParameterBlock`
- `AudioUnitScheduleParameters`
- `AUAudioUnit.scheduleParameterBlock`

Those scheduling blocks accept sample time / duration / address / value and do not return a per-event cancellation token. AW42 therefore does not schedule any new future gain event.

## Implementation

`PlaybackRepeatedLoopSeamSafety.swift` adds a fail-closed capability evaluator and generation-stamped authorization gate. Production authorization requires all of the following:

1. selected exact future sample-time scheduling implementation;
2. a revocation or generation-isolation mechanism;
3. proof that stale scheduled events cannot mutate the active gain stage;
4. seek invalidation wiring;
5. tempo invalidation wiring;
6. lifecycle invalidation wiring;
7. audible safety of the revocation/reset/replacement path;
8. selected integration execution;
9. physical-device audible validation.

`AppleRepeatedLoopSeamSafetyCapability.swift` describes the current selected Apple path with those capabilities absent. Its report is therefore blocked and cannot issue future-automation authorization.

The authorization gate uses a monotonic generation. A previously issued authorization becomes stale after invalidation. Generation overflow poisons the gate. Counters saturate rather than wrap. The gate retains no pending automation queue.

## Portable strict validation

Environment:
- Swift 6.2.1
- Linux x86_64
- Swift language mode 6
- strict-concurrency=complete
- warnings-as-errors

Self-test: PASS.
- current selected-Apple descriptor fails closed;
- zero authorizations are issued for current descriptor;
- fully proven synthetic descriptor can issue an authorization only as a structural gate test;
- invalidation rejects an older authorization;
- render-reset-only without stale-event proof and audible proof is rejected;
- generation overflow poisons the gate.

The first strict compile found a Swift exclusivity violation in a mutating counter helper. It was fixed with a value-returning saturating increment before the PASS result.

Stress: PASS.
- 1,000,000 blocked authorization attempts;
- blocked: 1,000,000;
- issued: 0;
- generation: 0;
- counter overflow: false;
- gate poisoned: false;
- local wall time approximately 0.06 s; RSS approximately 16.4 MB for the process, not a device/audio memory claim.

Benchmark: PASS.
- 20 rounds × 1,000,000 blocked authorization attempts;
- median: 55,238,232 ns;
- p95: 59,777,014 ns;
- max: 62,127,755 ns;
- checksum: 20,000,000.

This benchmark measures portable fail-closed bookkeeping only, not playback, loop, render, or iPhone latency.

## Selected Apple / device status

Not executed in AW42:
- complete selected SwiftPM/Xcode compilation of the new AVFAudio extension;
- physical iPhone repeated-loop playback;
- Audio Unit future-event revocation behavior;
- reset/replacement audible safety;
- rights-cleared real-track click/pop measurement;
- current-Moises differential;
- human listening.

No automatic repeated-loop future gain events were added. Existing AW32 interactive envelope semantics remain unchanged.

## Gate to a future implementation

A future repeated-loop seam implementation may move beyond this gate only after the selected implementation supplies a real revocation/isolation path and proves it across seek, tempo and lifecycle generations. If the mechanism relies on render reset or gain-stage replacement, HQ/device evidence must additionally show both stale-event flushing and absence of an audible graph discontinuity. Final P008/P006 PARITY remains HQ authority.
