# L3-M02｜Portable multitrack transport semantics

## Scope

Lane 3 only. This bundle hardens transport behavior that can be proven without an iOS host target. It does not edit Shared/App/Package/PARITY/Queue and does not claim device or PARITY evidence.

Frozen epoch-2 contract reference remains the Worker-3 `frozen_integration_sha` recorded in status. The six inherited post-PR #4456 Playback hardening commits and L3-M01 work are preserved; no reset/rebase/discard was performed.

## Production additions

### `PortableTransportSemantics.swift`

- Canonical project frame clock with explicit finite/range validation.
- Seconds -> frame conversion with selectable rounding and Int64 overflow rejection.
- Frame -> seconds conversion.
- Absolute-frame loop normalization using integer modulo rather than incremental floating-point addition.
- Stem project-window projection across mixed source sample rates.
- Explicit active/delayed/ended stem classification at a project position.
- Source -> stems transition plan with three states:
  - `preservedClock`
  - `waitingForDelayedStem`
  - `clampedToStemEnd`
- Source/stem duration mismatch accounting:
  - `sourceTailGapSeconds`
  - `stemsExtendPastSourceSeconds`
- Interruption snapshot semantics that require both pre-interruption play intent and system permission before automatic resume.

### `PlaybackTransportStateMachine.swift`

Portable reducer for:

- play / pause
- seek
- set/clear loop
- source -> stems replacement
- interruption begin/end
- natural end

Important behavior:

- `play` while interrupted records resume intent but does not pretend audio is playing.
- explicit `pause` clears interruption resume intent.
- source -> stems replacement during interruption preserves the replacement plan's resume intent while remaining paused until interruption end.
- a loop seek is normalized in integer project-frame space.
- natural end without a loop stops the transport; loop end wraps by absolute frame modulo.

## Mismatch policy

The portable semantics do not silently assume all separated stems have identical timing metadata.

- Mixed 44.1/48/96 kHz stems are projected onto one project frame clock.
- Non-zero stem offsets are represented as delayed windows rather than moving the project clock.
- If all replacement stems have ended before the current source clock, the transition clamps to the latest real stem end and sets `resumePlayback=false`. This prevents a false `playing` state over a silent tail.
- If stems start later than the current source clock, the transition preserves current time and explicitly reports `waitingForDelayedStem`.
- Source-tail gaps and stem-overrun beyond source duration remain evidence fields rather than hidden corrections.

## Portable validation

Swift 6.2.1 Linux, contract-compatible frozen Shared type stubs. This verifies the portable Lane 3 logic but is not an Apple SDK compile.

`L3_M02_PortableTransportSelfTest.swift` passed all assertions:

- 72-hour track at 48 kHz -> `12,441,600,000` frames and exact tested round-trip.
- 1,000,000 absolute loop repetitions -> expected frame with no accumulated planner drift.
- source -> stems preserves 31.25 s and play intent when replacement stems cover that position.
- delayed-stem transition preserves project clock.
- short replacement stems clamp from a 100 s source position to the actual 90 s stem end and stop false playback.
- explicit source-tail and stem-extension accounting.
- interruption begin/end resume intent.
- explicit pause during interruption cancels automatic resume.
- 87.5 s seek under 55...65 s loop -> 57.5 s.
- 50,000 deterministic pseudo-random long-position loop invariants.
- overflow and invalid loop ranges fail closed.

Output:

`L3-M02 portable transport self-test: PASS`

## Stress benchmark

`L3_M02_TransportBenchmark.swift`, Swift `-O`, 25 rounds.

Each round:

- 250,000 absolute loop normalizations.
- 20,000 source -> stems transition plans.
- four six-hour stems with 44.1/48/96 kHz sample rates and non-zero offsets.
- periodic interruption begin/end transitions.

Observed local planner CPU time:

- median: `53.476 ms`
- p95: `59.058 ms`
- p99: `61.044 ms`
- max: `61.044 ms`

This benchmark measures portable planning CPU only. It is not AVAudioEngine render latency, seek audible gap, UI latency, or iPhone performance evidence.

Machine-readable evidence: `L3-M02_VALIDATION.json`.

## Done-when assessment

`portable transport semantics pass deterministic stress tests with no accumulated timing drift` -> satisfied for Lane 3 portable semantics.

No PARITY row is promoted. MOI-P006/P007/P008 remain dependent on HQ late-integration, Apple runtime/device capture, real-audio listening and Reference differential evidence.
