# L3-M03｜Gain / Solo-Mute / Practice DSP control safety

Status: PORTABLE CONTROL SEMANTICS COMPLETE / AUDIBLE QUALITY PENDING DEVICE EVIDENCE

This bundle does not claim PARITY. It hardens the control plane that can be completed without an iOS host or physical device. Audible click/pop/zipper behavior, TimePitch artifacts and actual interaction latency remain HQ Late Integration gates using rights-cleared real audio on an iPhone.

## Implemented

### 1. Gain ramp strategy
`Playback/Sources/PlaybackControlSafety.swift`

- mixer transitions are converted from previous effective gains to next effective gains;
- mute has priority over solo, and any active solo suppresses non-solo tracks;
- gain values must be finite and in `0...1`;
- duplicate StemID input is rejected;
- default engineering ramp is 12 ms, converted once to an integer frame count from the actual sample rate;
- the ramp is deterministic and has exact start/end values with no overshoot;
- the 12 ms value is an engineering guardrail, not a Reference-derived parity threshold.

The live Apple graph still needs a sample/ramp-capable execution path at Late Integration. Direct `AVAudioPlayerNode.volume` behavior must not be described as click/pop/zipper-free before device capture and listening evidence.

### 2. Solo / mute precedence
The existing `PlaybackTimelinePlanner.effectiveGains` rule is preserved and exhaustively regression-tested for the two-stem Boolean matrix:

1. muted always resolves to zero, including a muted+soloed stem;
2. if at least one stem is soloed, every non-soloed stem resolves to zero;
3. otherwise an audible stem resolves to its validated user volume.

The transition planner applies the same resolved gains to ramp endpoints, preventing a separate mixer/ramp precedence rule from diverging.

### 3. Tempo / pitch validation and state restore
`DSP/Sources/PracticeDSPConfiguration.swift`
`DSP/Sources/PracticeDSPControlSafety.swift`

- tempo, pitch and pending count-in are validated against the configured backend capabilities;
- non-finite and out-of-range values fail before state mutation;
- persisted practice state can be restored atomically;
- a restored schedule generation is advanced once so a pre-interruption click token cannot be treated as current;
- generation increment uses checked arithmetic; `UInt64.max` fails closed instead of wrapping to zero;
- invalid restore leaves the previous project state unchanged.

The capability limits remain backend limits. They are not used to invent a Moises entitlement/UI range.

### 4. Backend unavailable / rejection behavior
`PracticeDSPApplicationGate` owns a last-known-applied snapshot.

- missing backend -> explicit `backendUnavailable`;
- backend rejection -> explicit `backendRejected`;
- candidate state is committed only after backend acceptance;
- failure never silently records an unapplied tempo/pitch state.

This provides a portable failure-safe seam for the Apple TimePitch node or a future lawful challenger. Actual Apple wiring/compile remains Late Integration.

### 5. Metronome / count-in scheduling edge cases
`DSP/Sources/SampleTimelinePlanner.swift`

- source beat times must be strictly increasing;
- two beats that quantize to the same render sample are rejected rather than stacking click buffers;
- a mapped negative render sample fails as insufficient preroll;
- count-in still uses checked multiplication/addition and now also guarantees strictly increasing sample positions;
- invalid sample rate, tempo ratio, downbeat stride, source bounds and preroll remain fail-closed.

No wall-clock/UI timer is introduced. Scheduling remains on the playback-provided sample timeline.

## Portable validation
Environment: Swift 6.2.1, x86_64 Linux, contract-compatible frozen Shared stubs for isolated Lane-3 compilation.

Self-test: PASS

Coverage includes:
- 16 exhaustive two-stem mute/solo combinations;
- 48 kHz default ramp = 576 frames for the 12 ms engineering policy;
- ramp endpoints/midpoint bounds;
- NaN gain, duplicate StemID and zero sample-rate rejection;
- boundary tempo/pitch/count-in settings;
- rejected tempo preserving prior state;
- valid restore + generation invalidation;
- invalid restored pitch preserving prior state;
- generation-overflow restore preserving prior state;
- missing backend preserving last-applied state;
- backend rejection preserving last-applied state;
- duplicate beat-time rejection;
- same-render-sample collision rejection;
- negative render sample / insufficient count-in preroll rejection;
- valid four-click count-in remains `[0, 24000, 48000, 72000]` at 48 kHz / 120 BPM.

## Stress benchmark
Optimized Swift build, 20 rounds. Each round executes:

- 50,000 eight-stem gain-transition plans;
- 5,000 validated practice states;
- 5,000 metronome plans x 256 beat events = 1,280,000 planned click events.

Observed planner CPU time per round:

- median: 1059.026 ms
- p95: 1094.893 ms
- p99/max: 1094.893 ms

This is portable control/planning CPU time only. It is not render latency, audio I/O latency or device interaction latency.

## Remaining Late Integration gates

- compile the complete Lane-3 Apple sources against AVFAudio;
- connect the deterministic gain-transition plan to an actual sample/ramp-capable Apple mixer path;
- wire `PracticeDSPApplicationGate` to the selected Apple/approved backend;
- rights-cleared real-track tempo/pitch rendering;
- physical-iPhone measurement of click/pop/zipper, gain-transition duration, metronome/count-in onset/drift and control latency;
- human artifact/listening review and Differential Moises evidence.

MOI-P006/P010/P012/P014/P015 remain MISSING until those gates and the broader product criteria are satisfied.
