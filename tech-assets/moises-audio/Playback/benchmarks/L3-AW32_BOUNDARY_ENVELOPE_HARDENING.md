# L3-AW32 Boundary Envelope / Restart-Gap Hardening

Result: `COMPLETE_NON_PARITY`

## Goal

Harden AW31 seek / loop-mutation / tempo / restart discontinuities without pretending portable evidence proves audible quality. The selected Apple graph now crosses explicit reschedule boundaries through a master output envelope after the exact shared `AVAudioUnitTimePitch`:

`shared time/pitch -> AW32 master gain -> main mixer`

For active restart boundaries the intended sequence is:

1. ramp master gain toward 0 with a provisional 8 ms fade-out,
2. wait for the fade-out safety interval even if the initiating caller is cancelled,
3. perform the existing AW31 source-clock reschedule / tempo two-phase boundary,
4. keep the restart muted through the existing common-host start lead,
5. arm a generation-guarded 8 ms fade-in,
6. reject a cancelled/stale fade-in after any newer boundary.

The raw AW31 Playback backend remains private in the selected stack. AW17/AW18/AW21 authority remains required above it.

## Restart-gap correction

AW31 stops Playback before the existing DSP tempo transaction. The AW28 live transition policy can otherwise wait for a scheduled rate ramp plus settle time while no audible content is flowing. AW32 adds `PracticeDSPTempoTransitionPolicy.boundaryMutedImmediate` and makes it the selected shared-graph default. The portable planner probe showed:

- selected muted boundary: recommended DSP barrier `0 ns`
- existing live 0.5x -> 2.0x transition at 48 kHz: `44,000,000 ns`

This removes that redundant muted wait from the selected boundary path without deleting or weakening AW28's live/in-place transition policy.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, strict concurrency complete, warnings as errors.

- planner self-test: PASS
  - 48 kHz fade-out = 384 frames
  - 48 kHz fade-in = 384 frames
  - 75 ms start lead retained as provisional device-tunable safety margin
  - invalid sample rate / invalid lead / invalid fade policy fail closed
  - short-loop `lateArming` and envelope-window overlap risk are explicit
- 1,000,000-cycle planner stress: PASS
  - safe plans: 999,066
  - overlap-risk plans: 934
  - late-arm plans: 433
  - checksum: 1625.424550
- generation fence stress: PASS
  - 500,000 stale restart fade-ins rejected
  - 500,000 current restart fade-ins consumed
  - final generation: 1,000,000
- planner benchmark: PASS
  - 20 rounds x 250,000 operations
  - median: 7.661 ms
  - p95: 8.456 ms
  - max: 8.456 ms
  - checksum: 3733982613.420
- muted-boundary tempo policy probe: PASS
  - selected boundary barrier = 0 ns
  - live 0.5x -> 2.0x baseline barrier = 44,000,000 ns

The benchmark is planner/fence CPU cost only. It excludes AVAudioEngine, AudioUnit parameter scheduling, device IO, render latency, real audio and listening.

## Explicit non-claims

AW32 does **not** prove click/pop elimination. The Apple decorator and selected stack have not been compiled/executed in the complete iOS/Xcode graph or on a physical iPhone in this Worker environment. No real PCM discontinuity capture, headphones/speaker listening, AVAudioSession interruption run, current-Moises A/B or PARITY judgment was performed.

Automatic repeated-loop seam envelope runtime is intentionally **not** claimed. AW31 owns the exact internal host-time schedule of repeated loop cycles. An outer timer that is not tied to that exact Apple scheduling authority could fire late or stale and create a worse artifact. AW32 therefore provides loop envelope planning and overlap-risk detection, but the selected composition receipt records `automaticRepeatedLoopSeamEnvelopeAvailable=false`. Repeated-loop seam hardening remains a device/Xcode-follow-up unless a generation-safe exact-host integration is added.

The retained 75 ms common-host start lead is still provisional and can dominate perceived restart latency. Do not reduce it based on the portable benchmark; tune it only with physical-iPhone underrun/start reliability evidence.

## Source identity

- `Playback/Sources/PlaybackBoundaryEnvelope.swift`: `3e9aa2bd43201814124ac8e603dfe343a4a41cca`
- `Playback/Sources/AppleBoundaryEnvelopedPlaybackBackend.swift`: `6154df37f7a0ed545b551fd82989174f19091abb`
- `Playback/Sources/Lane3AppleTempoAwarePlaybackDSPStack.swift`: `8f08a1ab313802bc2060bbacef140cd541ce07df`
- `DSP/Sources/PracticeDSPBoundaryTempoPolicy.swift`: `2c00d8e67d2589d46e7f662657581755e397056f`
- `Playback/Tests/L3_AW32_BoundaryEnvelopePlannerSelfTest.swift`: `63c5bda2c1d06547163d77495e9e0c28a736f7f8`
- `Playback/Tests/L3_AW32_BoundaryEnvelopeStress.swift`: `eb5b6cfe3c68735cad14ea3a4a4c665abea455c5`
- `Playback/Tests/L3_AW32_BoundaryEnvelopeBenchmark.swift`: `bbf5d2c8db8e63c659a877ad3fcbcedaf989bfb6`
- `Playback/Tests/L3_AW32_BoundaryEnvelopeGenerationFenceSelfTest.swift`: `cb6074e31711b805025bbbd51adeedfac281b800`
- `DSP/Tests/L3_AW32_BoundaryMutedTempoPolicySelfTest.swift`: `2ec4abe411026b7ddc7eb4ab569d497dd7ede382`

## HQ device gate

For selected iPhone validation:

1. compile the complete AW32 selected stack and compile guard,
2. confirm the master gain stage is physically after the exact shared time/pitch node,
3. verify App/HQ uses AW32 stack construction plus AW17/AW18/AW21/AW31 facade authority with no direct backend bypass,
4. capture PCM around seek, loop-setting changes, tempo changes, play/pause/restart and interruption recovery,
5. measure fade timing, restart muted interval, actual common-host start delay and stale fade-in rejection,
6. measure click/pop/discontinuity with AW07 metrics and listening on speaker/headphones,
7. tune 8 ms envelope and 75 ms start lead only from device evidence,
8. separately validate repeated automatic loop seams; AW32 has not implemented that runtime envelope,
9. compare current Moises on rights-cleared real tracks before changing PARITY.
