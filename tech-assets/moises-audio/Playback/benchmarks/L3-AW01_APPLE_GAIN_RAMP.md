# L3-AW01｜Apple gain-ramp execution primitive

## Purpose

This Autonomous Macro Wave reduces the Lane-3 MOI-P006 gap without claiming device/audio parity. The existing `AppleMultiTrackPlaybackBackend` still applies mixer state by assigning `AVAudioPlayerNode.volume` directly. L3-AW01 adds a fail-closed, ramp-capable execution primitive and portable transactional preflight so the next lane-local wave can replace that immediate-only path safely.

## Added implementation

### `PlaybackGainRampExecution.swift`

- Builds the complete multi-stem transition batch before any render-side automation is scheduled.
- Validates ramp duration, StemID ownership, finite [0,1] gains, render sample rates and frame-count bounds.
- Derives per-stem ramp frame counts from the actual render sample rate.
- Uses deterministic StemID ordering for durable evidence.
- Omits unchanged gains rather than scheduling redundant parameter automation.
- Missing target entries preserve the currently committed gain instead of implicitly muting or resetting a stem.
- Produces `committedTargetGains` only after the entire plan validates, preventing partial state commitment after a later invalid stem.

### `AppleStemGainRampStage.swift`

- Introduces one `AVAudioMixerNode` gain stage per future stem graph edge.
- Resolves the mixer Audio Unit volume parameter and requires the parameter to advertise ramp capability.
- Fails closed if the parameter is absent or not rampable.
- Uses the Audio Unit scheduled-parameter API with a sample-frame ramp duration instead of implementing an audible playing-state transition with repeated `AVAudioPlayerNode.volume` assignments.
- Does not force a stale explicit start value for a playing-state retarget. The Audio Unit is allowed to continue from its current render-side value toward the new target, avoiding a discontinuity caused by snapping to the previous target before a new ramp.
- Immediate assignment is retained only for graph setup or paused-state initialization.

The default 12 ms duration remains an engineering guardrail inherited from L3-M03. It is not derived from the current Moises reference and must be tuned or rejected by physical-device/audio evidence later.

## Validation

Portable self-test: PASS with Swift 6.2.1 on Linux.

Coverage includes:

- deterministic StemID ordering;
- 12 ms frame derivation at 44.1, 48 and 96 kHz;
- unchanged-gain elision;
- missing-target preservation;
- unknown-stem rejection;
- out-of-range and NaN gain rejection;
- invalid sample-rate rejection;
- invalid ramp-duration rejection;
- 10,000 rapid retarget state transitions.

Optimized portable benchmark: 20 rounds, each 50,000 eight-stem transition plans across 44.1/48/96 kHz render rates.

- median: 688.208 ms
- p95: 705.710 ms
- p99: 705.710 ms
- max: 705.710 ms
- checksum: 5,619,000,000

This benchmark measures CPU planning only. It does not measure Audio Unit render cost or audible behavior.

## Fail-closed / non-PARITY boundary

L3-AW01 does **not** promote MOI-P006 or any other PARITY row. The Apple-specific file is conditionally excluded on Linux, so the following remain mandatory:

1. Wire a dedicated `AVAudioMixerNode` / `AppleStemGainRampStage` into each stem path in `AppleMultiTrackPlaybackBackend`.
2. Make graph staging and cleanup transactional so a gain-stage creation/parameter failure does not destroy a valid prior graph.
3. Use immediate setup gain only while stopped/initializing; use scheduled ramps for playing-state mixer changes.
4. Compile all Lane-3 Apple sources with the selected Xcode/iOS SDK and resolve any API availability/deprecation findings.
5. Verify the target-device mixer exposes the expected rampable volume parameter.
6. Capture physical-iPhone gain transitions and feed the result to L3-M01 click/pop/zipper metrics.
7. Run rights-cleared real tracks and human listening review.
8. Perform current-Moises differential evaluation before any PARITY promotion.

## Next lane-local wave

Unless canonical state changes, the next highest-value Lane-3 wave is backend integration: replace the direct stem `AVAudioPlayerNode -> mainMixer` graph with `AVAudioPlayerNode -> per-stem AVAudioMixerNode gain stage -> mainMixer`, preserve transactional source/stems replacement behavior, ramp playing-state gain changes, and add portable/backend-structure regression evidence while leaving Apple SDK/device gates explicit.
