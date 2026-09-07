# MOI-DSP-001 implementation validation

Captured: 2026-08-22 JST
Worker: `Moises-Worker-3`
Work package: `MOI-WP3-PLAYBACK-DSP`
Branch: `moises/wp3-playback-dsp`

## Scope implemented

The implementation follows the VERIFIED `MOI-DSP-R001` architecture without redefining HQ Shared/App contracts.

- `PracticeDSPController` implements the HQ `PracticeDSPConfiguring` surface for per-project tempo, pitch, metronome and count-in configuration.
- `SampleTimelinePlanner` maps Analysis source-beat times onto the Playback-owned render sample timeline. It never uses a wall-clock/UI timer.
- tempo or transport-discontinuity related state increments a schedule generation so stale click events can be rejected/rescheduled.
- `AppleTimePitchBackend` wraps `AVAudioUnitTimePitch` as the Apple production baseline while leaving `AVAudioEngine` and transport ownership to Playback.
- `AppleSampleTimeClickScheduler` schedules click PCM buffers at absolute `AVAudioTime(sampleTime:atRate:)` values and rejects stale generations.
- `AppleOfflineTimePitchRenderer` supplies a deterministic real-track offline rendering seam for the required macOS/iPhone quality measurements.

The capability ranges in code are AVAudioUnitTimePitch/backend safety bounds, not Moises entitlement limits. Reference/UI limits must be enforced by the product layer after current entitlement verification.

## Commits

- `73cfe23aab98dc5275d9a8dabaccafdb6934d9ec` — project-scoped DSP configuration/controller.
- `bcbae199068c7154a572875302473a58e7da34d3` — sample-time click/count-in planner.
- `8de82ea63791a4453c128a0d125e1a06e4d9051c` — Apple TimePitch/click scheduling/offline-render backend.
- `2bf18fd4d26aed24c5e4653b4e4b432c3250bd16` — core self-test source.
- `560ee4e0bdf793963172cb6eb1711e262eb30fbc` — 60-minute planner microbenchmark source.
- `6e9201302d14d1ec879092c4ed4bff77e671d298` — Int64 timeline overflow and invalid-range hardening.
- `b1ed01eb3a0984cfcb142ab81cd1a4e8f3b65150` — boundary/overflow regression tests.
- `09c0bdeee22d1cb8abe25451a41aff5a640d938b` — offline-render completion synchronization and bounded-failure guard.

## Executed validation in the current worker environment

Environment: Swift 6.2.1 on Linux. `AVFAudio` is unavailable here and the canonical baseline still records `IOS_APP_TARGET_MISSING`, so Apple audio rendering was not claimed as executed.

A local contract-compatible compile harness supplied only the fetched HQ `ProjectID` / `PracticeDSPConfiguring` signatures because the canonical `Package.swift` intentionally excludes future DSP sources and is owned by the build-harness work package. No Shared or Package file was modified by WP3.

Core self-test result:

`MOI-DSP-001 core self-test: PASS`

Covered:
- 0.5x and 2.0x source-time to render-sample mapping.
- four-click sample-time count-in.
- 10-minute / 1200-beat click mapping at 1.25x with <= 1 frame planner error.
- 100 loop repetitions at 0.9x with no accumulated planner rounding drift.
- project-scoped tempo/pitch/metronome/count-in state and generation invalidation.
- render-origin Int64 overflow rejection.
- count-in preroll multiplication overflow rejection.
- non-finite source range rejection.
- invalid downbeat stride rejection instead of silently emitting an empty schedule.

Pure planner microbenchmark, 7,200 beats (60 minutes at 120 BPM), 200 iterations, optimized Swift:

`events=7200 iterations=200 median_ms=0.0384 p99_ms=0.0700 max_ms=0.1055`

This is only CPU time for producing the click schedule. It is NOT AVAudioEngine render latency, click-onset latency, device audio latency, or an artifact-quality measurement.

## Static Apple-backend hardening while target executor is unavailable

A second review of the Apple-only backend found that the initial offline renderer used a completion Bool captured by an asynchronous player completion callback. Current Apple documentation exposes the callback-type schedule API as a `@Sendable` completion surface and provides `.dataRendered` as the explicit signal that scheduled file data has been rendered. The renderer was changed to:

- use the callback-type `scheduleFile` API with `.dataRendered`;
- mutate/read completion state through a lock-protected `@unchecked Sendable` flag instead of an unsynchronized captured variable;
- bound pre-completion render attempts using the expected tempo-adjusted output length plus a conservative safety budget;
- throw `renderDidNotComplete` rather than spin indefinitely when the render callback/runtime fails to make progress.

This hardening is source-reviewed only until AVFAudio compilation is available; it is not counted as an executed Apple-backend PASS.

## Acceptance gate status

`MOI-DSP-001` acceptance is NOT fully satisfied in this environment.

Satisfied/implemented evidence:
- tempo/pitch implementation path exists behind the HQ contract.
- metronome/count-in sample-time scheduling path exists and pure timeline math is regression-tested.
- deterministic planner latency is measured and negligible relative to audio-buffer time.
- pure planner arithmetic fails closed on invalid/non-finite/overflowing schedule inputs.

Still mandatory before `INTEGRATION_READY` / any PARITY consideration:
1. Compile/run the Apple backend on a macOS/iOS executor with AVFAudio.
2. Run rights-cleared real multi-genre tracks through `AppleOfflineTimePitchRenderer` at the DSP-R001 ratios/semitone shifts.
3. Measure actual rendered duration/tempo accuracy and pitch shift accuracy.
4. Perform objective plus listening artifact gates for transients, phase/image, formant/timbre and silence/noise-floor behavior.
5. Schedule real click buffers on the Playback-owned engine and measure onset error/drift on target iPhone, including 60-second and long-track runs, tempo changes, seek and loop rescheduling.
6. If Apple fails the quality gate, evaluate the already-audited Rubber Band Commercial challenger; do not silently switch to an unlicensed route.

## Current blocker

As of the latest refresh, HQ fixed the Shared `ProcessingSnapshot: Hashable` mismatch that had blocked WP4 build-harness work. However, WP4 had not yet rerun/integrated its build task after that fix, the integration `Package.swift` still excludes `DSP/**`, and the canonical baseline still has no iOS app target. Therefore the real-track `AVAudioUnitTimePitch` artifact/latency and actual click-onset gates still cannot be truthfully completed by the current Linux-only Worker 3 execution environment.

HQ/build-harness request: let WP4 rerun after the Shared fix, then provide or route a macOS/iPhone execution target that compiles the existing DSP-owned sources unchanged (or add them through the WP4-controlled build harness), and return the measured outputs to WP3 for this same task. This is an execution prerequisite, not permission to relax the acceptance gate.

## PARITY

No PARITY state is changed by this task attempt. `MOI-P010`, `MOI-P012`, `MOI-P014`, and `MOI-P015` remain `MISSING` until real-track/device and Reference A/B evidence satisfies their gates.
