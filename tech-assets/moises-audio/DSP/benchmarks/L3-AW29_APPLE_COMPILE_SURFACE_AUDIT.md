# L3-AW29 | Apple Compile-surface / Adapter Audit

Result: `COMPLETE_NON_PARITY`

## Goal
Reduce selected-Xcode integration risk across the Lane-3 Apple-only surfaces added/hardened through AW25, AW27 and AW28 without editing `Shared/**`, `App/**`, `Package.swift` or Lane-4 build ownership.

## Canonical contract at wave start
- assignment_epoch: 2
- planning_revision: 4
- integration_epoch observed: 20
- Worker branch start: `c6a1a533da34ad34270725cafb736780c8f3b5d9`
- ownership unchanged: `Playback/**`, `DSP/**`, Worker-3 status only

## Audit findings
The Apple-only API spellings used by the current Lane-3 sources were checked against current Apple Developer Documentation before changing the composition surface:
- `AUParameterTree.parameter(withID:scope:element:)` remains the v2 Audio Unit parameter lookup API used by the Apple system unit.
- `AUAudioUnit.scheduleParameterBlock` and `renderResourcesAllocated` remain available for parameter scheduling/runtime readiness checks.
- `AVAudioFile(forReading:commonFormat:interleaved:)`, `framePosition`, and `read(into:frameCount:)` remain available; Apple documents `framePosition` as the random-access mechanism.

This is documentation/API-surface confirmation only. It is not selected-Xcode compilation or physical-device runtime evidence.

## Production hardening
### `Lane3AppleDSPProductionStack`
Added one selected Apple construction path that:
- creates the `AppleTimePitchBackend` with the exact `AVAudioUnitTimePitch` node inserted by the host graph;
- wraps that backend in `Lane3DSPTelemetryTransactionalBackend` before controller construction;
- constructs the project-scoped `PracticeDSPProductionController` with the AW28 tempo policy and AW25 pitch policy;
- exposes the graph node and controller, but not the raw backend or telemetry backend;
- emits a NON_PARITY composition receipt.

Compile-time generic constraints require both the raw Apple backend and telemetry wrapper to conform to:
- `PracticeDSPTransactionalBackendApplying`
- `PracticeDSPTempoTransitionBackendApplying`
- `PracticeDSPPitchTransitionBackendApplying`

If a selected Apple target accidentally omits the AW25/AW28 conformance sources, this production-stack source is intended to fail compilation rather than silently degrade to a backend bypass.

`AppleSampleAccurateClickExecutor` is also referenced by the DSP compile surface so omission is visible at Apple compile time.

### Playback compile guard
`Lane3ApplePlaybackCompileSurface` requires:
- `Lane3AppleFilePCMChunkSource : Lane3PCMChunkReadable`
- `Lane3AppleLongTrackEvidenceInputFactory`
- `AppleRampedMultiTrackPlaybackBackend`

This is intentionally limited to the selected bounded evidence input and ramped playback path rather than forcing unrelated legacy Apple adapters into the host target.

## Fail-closed composition contract
`Lane3AppleDSPProductionCompositionValidator` rejects:
1. telemetry wrapper absent;
2. transactional conformance absent;
3. tempo-transition conformance absent;
4. pitch-transition conformance absent;
5. backend/node identity not shared;
6. direct backend access exposed by the selected composition;
7. any attempted PARITY promotion.

## Validation performed in this wave
### Portable strict validation
Environment: Swift 6.2.1, Linux x86_64.

Flags:
- `-swift-version 6`
- `-strict-concurrency=complete`
- `-warnings-as-errors`

Result:
`AW29 portable composition PASS negatives=7`

### Conditional Apple-branch syntax/composition probe
A local interface-compatible `AVFAudio` shim module was built solely to make `canImport(AVFAudio)` true on Linux. The exact new DSP production-stack source was then compiled with strict concurrency against interface-compatible project stubs.

Result:
`AW29 synthetic Apple-branch compile-surface PASS`

The Playback compile guard was independently compiled under the same technique:
`AW29 synthetic Playback Apple-branch compile-surface PASS`

This probe is useful for conditional-branch syntax and generic-conformance composition. It is explicitly **not** an Apple SDK, AVFAudio ABI, AudioToolbox constant, simulator, device, or runtime PASS.

Exact source identities used by the probe:
- `DSP/Sources/Lane3AppleDSPProductionStack.swift`: `9b92029dd1e106f1ac3f11f94efefb0f309e78b7`
- `Playback/Sources/Lane3ApplePlaybackCompileSurface.swift`: `99e2f10a9eef41255765d2b6b99abcbaef008924`

### Portable composition benchmark
20 rounds x 100,000 receipt validations:
- median: 1.015 ms
- p95: 1.198 ms
- max: 1.537 ms
- checksum: 2,000,000

This is a tiny fail-closed metadata validator benchmark only. It says nothing about Apple audio/DSP/device latency.

## Repository tests authored
- `DSP/Tests/L3_AW29_AppleProductionCompositionSelfTest.swift`
- `DSP/Tests/L3_AW29_AppleProductionCompositionBenchmark.swift`
- `DSP/Tests/L3_AW29_AppleDSPCompileSurfaceSelfTest.swift`
- `Playback/Tests/L3_AW29_ApplePlaybackCompileSurfaceSelfTest.swift`

The Apple compile probes must still run under the complete selected Xcode/iOS Lane-3 source graph.

## HQ selected integration contract
1. Construct selected time/pitch using `Lane3AppleDSPProductionStack.make(...)` instead of manually layering `AppleTimePitchBackend` and telemetry in App code.
2. Connect `stack.node` into the selected `AVAudioEngine` graph and use `stack.controller` for the project-scoped DSP controller.
3. Keep tempo routed through AW17/coordinator authority and pitch through AW23 unified practice authority; the stack factory does not replace those higher-level authorities.
4. Compile/run both AW29 Apple compile-surface self-tests with AW25, AW27 and AW28 sources present.
5. Keep `Lane3ApplePlaybackCompileSurface` in the selected Playback source surface so missing AW27/ramped-playback dependencies fail at build time.
6. Physical iPhone must still prove actual NewTimePitch pitch/rate parameter presence, `flag_CanRamp`, render-resource state, file decoder behavior, audible artifacts, latency, current-Moises differential and listening quality.

## Claim boundary
- selected Xcode compile: NOT RUN
- Apple SDK compile: NOT RUN
- physical iPhone: NOT RUN
- real AVAudioUnitTimePitch scheduled ramp: NOT RUN
- AVAudioFile real decoder runtime in AW27: NOT RUN
- real audio: NOT RUN
- current Moises differential: NOT RUN
- human listening: NOT RUN
- PARITY promotion: NOT ALLOWED
