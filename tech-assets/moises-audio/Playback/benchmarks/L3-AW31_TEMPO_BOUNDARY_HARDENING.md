# L3-AW31｜Tempo-aware seek/loop boundary hardening

Result: `COMPLETE_NON_PARITY`

## Problem found

The prior selected Apple Playback baselines maintained project position as `anchor + host elapsed` and scheduled the next loop host boundary using project/source duration directly. Once `AVAudioUnitTimePitch.rate != 1`, both assumptions are wrong: project/source time advances by `host elapsed * tempoRatio`, and a project duration occupies `projectDuration / tempoRatio` host seconds. The prior Playback and DSP construction also did not make one shared `AVAudioEngine` + exact `AVAudioUnitTimePitch` node mandatory.

Adding a click/pop fade before fixing those invariants would only mask a boundary whose source position could still be wrong after tempo changes.

## Implementation

AW31 adds:

- `PlaybackTempoClockMath`: project/source time advances by tempo ratio; loop wrapping remains in project/source coordinates; project durations are converted to host durations by division by the active tempo ratio.
- `PlaybackTempoBoundaryRescheduling`: exact two-phase `prepare -> commit/cancel` contract with non-PARITY receipt.
- `AppleTempoAwareRampedMultiTrackPlaybackBackend`: one Apple graph `player(s) -> per-stem gain -> transport mixer -> shared AVAudioUnitTimePitch -> main mixer`; source/stem starts share one host anchor; delayed stem starts and loop boundaries are tempo-scaled.
- `Lane3TempoBoundarySelectedTransportFacade`: rapid tempo latest-wins happens before Playback is frozen; tempo then takes exclusive admission against seek/loop/play/pause/media/interruption/recovery, captures the old source position, executes the existing AW18 -> AW17 -> coordinator tempo authority, and commits or cancels Playback accordingly.
- `Lane3AppleTempoAwarePlaybackDSPStack`: constructs Playback and DSP with the same engine graph and exact time/pitch node. Its selected AW17 factory forces upstream `tempoQuietPeriod = 0`; the outer facade alone owns tempo coalescing so there is no second 16 ms debounce while Playback is stopped.
- `Lane3ApplePlaybackCompileSurface`: Apple-target compile guard now requires the AW31 backend, two-phase boundary conformance, selected stack and selected facade.

Public Playback token authority is unchanged. A successful tempo operation still creates exactly one `.tempoChange` token through AW17; the Apple backend's private schedule generation is only for stale callback rejection. Recovery may create the existing additional `.recovery` token when an operation has already failed.

## Failure semantics

- DSP failure after Playback prepare: existing coordinator recovery runs, then the AW31 facade cancels the Playback boundary and restores the captured old source position/tempo.
- Interruption lifecycle non-idle: tempo is rejected by AW18 before a Playback tempo boundary is started.
- Seek/loop/media/play/pause/recovery/interruption already in flight: tempo waits until shared admission drains before prepare.
- Boundary serial or internal schedule generation overflow: fail closed.
- Apple restart failure during boundary commit/cancel: the low-level backend poisons itself and leaves the boundary non-current. Selected product integration must reconstruct the Lane-3 Apple stack before accepting further playback; AW31 does not claim in-place recovery from an AVAudioEngine restart failure.

## Portable validation executed

Environment: Swift 6.2.1, Linux x86_64, `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`.

Clock/source-time stress:
- 1,000,000 project-position calculations: PASS
- 2.0x and 0.5x host/project conversion: PASS
- loop wrapping in project coordinates: PASS
- checksum: `5061869.057960`

Admission/failure semantic model:
- 20,000 rapid tempo intents across 100 bursts: PASS
- executed boundaries: 100
- superseded before boundary: 19,900
- shared-operation boundary violations: 0
- injected failed transition: prepare 1 / commit 0 / cancel 1 for the failure case

Portable clock benchmark:
- 20 rounds
- 1,000,000 math operations per round (500k position + 500k duration conversions)
- median: `7.413 ms`
- p95: `7.558 ms`
- max: `7.849 ms`
- checksum: `94495496.064050`

This benchmark measures only portable clock/boundary arithmetic. It excludes AVAudioEngine, AVAudioUnitTimePitch, Audio Unit ramps, file IO, output hardware, audible restart gaps and device scheduling latency.

## Repository validation authored

- `L3_AW31_TempoBoundaryClockSelfTest.swift`
- `L3_AW31_TempoBoundarySelectedFacadeSelfTest.swift`
- `L3_AW31_TempoBoundaryClockStress.swift`
- `L3_AW31_TempoBoundaryClockBenchmark.swift`
- existing `L3_AW29_ApplePlaybackCompileSurfaceSelfTest.swift` now reaches the AW31 compile guard when built on Apple SDKs.

The repository-integrated Apple target was not executed in this Worker environment.

## Source identity

- `Playback/Sources/PlaybackTempoBoundaryReschedule.swift`: `ef3a135131347504bd8c30064392fe5e2662af8e`
- `Playback/Sources/AppleTempoAwareRampedMultiTrackPlaybackBackend.swift`: `77cd4638ff5cfe18035a791111b414824b992bff`
- `Playback/Sources/Lane3TempoBoundarySelectedTransportFacade.swift`: `5620719d364f2d2f7247766714f5a010096f0779`
- `Playback/Sources/Lane3AppleTempoAwarePlaybackDSPStack.swift`: `8fdd1315f3d4fb6389aecd92d2b85b89f058b6c4`
- `Playback/Sources/Lane3ApplePlaybackCompileSurface.swift`: `33922df6088c02a13951748f99e7c729bf958f48`
- `Playback/Tests/L3_AW31_TempoBoundaryClockSelfTest.swift`: `920e844245f020e5e5ca7ecaaa792c7209015293`
- `Playback/Tests/L3_AW31_TempoBoundarySelectedFacadeSelfTest.swift`: `dedd9d699f6cbeb515cf4ea79c8a9c234ddeec04`
- `Playback/Tests/L3_AW31_TempoBoundaryClockStress.swift`: `2bddd1b7f87b69547834d29c68ffd16c03ded3fd`
- `Playback/Tests/L3_AW31_TempoBoundaryClockBenchmark.swift`: `24ff0773376db69d794aa9fc6118a9199fcc4b57`

## PARITY boundary

AW31 is not proof of audible parity. No selected-Xcode compile, physical iPhone, real audio, AVAudioSession interruption, actual Apple graph execution, click/pop listening, latency measurement or current-Moises differential was run here. `MOI-P007`, `MOI-P008` and `MOI-P010` therefore remain `MISSING`, as do the other Lane-3 PARITY rows.

HQ Late Integration should construct AW17 through `makeTempoBoundaryCompatibleTransportAuthority`, assemble AW18/AW21 around that exact authority, then create the AW31 facade. A selected route that instead constructs AW17 with its historical 16 ms tempo quiet period or bypasses the facade invalidates the AW31 timing evidence.
