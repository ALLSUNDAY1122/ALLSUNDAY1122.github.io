# L3-AW37 — Actual-Authority Cancellation Race Probe

Result: `COMPLETE_NON_PARITY`

## Why this wave

AW36 removed the real unbounded-retention bug in cancellation admission bookkeeping, but its million-event validation exercised the extracted admission fence directly. The remaining Lane-3 gap was a reusable way to drive `Task.cancel()` at several scheduler phases through the real `Lane3UnifiedProductionTransportAuthority`, then prove that admission/cancellation state returns to zero after the actor becomes quiescent.

This wave does not change AW34 fixed-window coalescing, discrete barrier ordering, recovery behavior, or the selected AW31 tempo route.

## Implementation

- `Lane3CancellationRaceProbe.swift`
  - reusable `Sendable` probe driver contract;
  - immediate / one-yield / two-yield cancellation schedule across each batch;
  - complete outcome accounting;
  - caller-cancellation-after-dispatch accounting from production receipts;
  - late-retired cancellation counter delta;
  - boundedness/quiescence/invariant result;
  - explicit post-operation scheduler settlement before terminal telemetry capture;
  - no PARITY promotion path.
- `Lane3UnifiedTransportCancellationRaceAdapter.swift`
  - maps real unified-authority seek/loop operations to the probe contract;
  - maps the AW36 cancellation-admission snapshot without exposing or mutating private authority state;
  - validates finite/non-negative operation geometry.
- `L3_AW37_UnifiedAuthorityCancellationRaceSelfTest.swift`
  - constructs the actual unified authority over Lane-local portable Playback/DSP fakes;
  - uses zero quiet periods to avoid wall-clock dependence;
  - drives 5,000 seek operations with 3,750 cancellation requests;
  - requires complete accounting and terminal zero retained admission/cancellation markers.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64, Swift 6 language mode, strict concurrency complete, warnings as errors. Stress/benchmark used `-O`.

### Probe self-test

`PASS`

- operations: 4,096
- cancellation requests: 3,072
- cancelled-before-dispatch observed in this run: 2,351
- executed observed in this run: 1,745
- accounting loss: 0
- delayed-quiescence polling: 1 poll
- synthetic counter-regression case: rejected from boundedness PASS
- final retained admission/cancellation state: 0

The executed/cancelled split is scheduler-dependent; complete accounting, final boundedness, and fail-closed counter regression are the invariant assertions.

### Probe stress

`PASS`

- operations: 1,000,000
- cancellation requests: 750,000
- cancelled-before-dispatch observed: 396,304
- executed observed: 603,696
- accounting loss: 0
- boundedness: PASS
- elapsed: 2,627.853 ms

### Probe benchmark

20 rounds × 20,000 operations:

- median: 52.257 ms
- p95: 81.760 ms
- max: 104.529 ms
- checksum: 412,500

Scope is Task cancellation/probe bookkeeping and driver dispatch only. It is not Apple audio latency or product UX latency.

### Adapter compile-surface check

The exact AW37 adapter shape was compiled in Swift 6 strict-concurrency mode against structural stubs for the already-existing authority/outcome/snapshot contracts. This catches Lane-local syntax/Sendable/interface mistakes but is not a selected repository/Xcode compile.

## Authored but not executed in this environment

`L3_AW37_UnifiedAuthorityCancellationRaceSelfTest.swift` is authored against the actual `Lane3UnifiedProductionTransportAuthority`, `RescheduleFencedPlaybackBackend`, `PracticeDSPProductionController`, and `PracticeDSPGenerationCoordinator`. The current execution environment does not contain the complete repository dependency graph/Xcode/AVFAudio target, so this test is deliberately recorded as **authored / pending selected execution**, not PASS.

HQ should execute it with AW17/AW34/AW36 in the complete selected SwiftPM/Xcode graph and assert after quiescence:

1. `admittingTicketCount == 0`
2. `cancelledBeforeEnqueueTicketCount == 0`
3. admission invariant remains true
4. cancellation counter does not overflow/regress
5. no unexpected rejected/failed operation appears
6. AW34 fixed-window behavior remains unchanged

## Gates intentionally still open

- complete selected SwiftPM/Xcode authority regression
- AVFAudio / Apple runtime
- physical iPhone cancellation/continuous-control run
- AW35 exact first-intent → token / audible-result device observations
- rights-cleared real audio
- current Moises differential
- human listening
- automatic repeated-loop seam automation
- PARITY promotion

`MOI-P006`, `MOI-P007`, `MOI-P008`, `MOI-P010`, `MOI-P012`, `MOI-P014`, and `MOI-P015` remain `MISSING` until HQ Late Integration satisfies their real-device / real-audio / differential gates.
