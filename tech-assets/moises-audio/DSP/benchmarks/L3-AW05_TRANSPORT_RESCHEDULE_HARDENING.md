# L3-AW05｜Transport Reschedule Token Hardening

## Scope

Lane 3 only: `Playback/**` + `DSP/**`.

Goal: make seek / loop / tempo / interruption / resume transport discontinuities fail closed across Playback scheduling and PracticeDSP click scheduling without changing frozen Shared/App contracts.

## Implementation

- `PlaybackTransportRescheduleFence`
  - monotonic checked generation; no wrapping arithmetic
  - invalidation occurs before old transport work is delegated/stopped
  - stale completion tokens are rejected
  - nonthrowing pause path poisons the fence on exhaustion instead of accepting an old generation
- `RescheduleFencedPlaybackBackend`
  - `PlaybackBackendDriving` decorator for production integration
  - seek / loop / play / pause / media load/replacement create an externally observable token before delegating to the real backend
  - tempo/interruption/recovery can pre-invalidate external schedules without Shared/App changes
- `PracticeDSPTransportRescheduleGate`
  - two-phase `begin -> click queue invalidation -> commit`
  - reused/regressed Playback generations rejected
  - reused/regressed click generations rejected
  - while invalidation is pending, no old binding authorizes replacement work
  - invalidation failure poisons the gate
  - recovery requires both Playback and click generations to advance
- Apple click executor helper
  - `invalidateForTransport(clickGeneration:)` forwards to the dedicated click-node invalidation path from AW04

## Portable validation

Environment: Swift 6.2.1, Linux x86_64. The production Playback decorator was syntax-checked using source-equivalent stubs for frozen shared types/protocols; the generation fences/gates are the exact production source.

Self-test result: PASS.

Covered:

- seek invalidates old audio token before replacement
- old click generation rejected while replacement is pending
- successful dual-generation binding
- loop invalidation failure poisons gate
- poisoned gate rejects replacement
- recovery requires newer Playback + newer click generations
- failed intent replay rejected
- same-generation/re regressed Playback rejection
- same-generation/regressed click rejection
- Playback UInt64 overflow fails closed
- DSP transaction serial overflow fails closed
- 1,000,000 discontinuity stress sequence with stale audio/click rejection

## Benchmark

20 rounds x 100,000 full Playback-token + DSP begin/commit bindings.

- median: 5.936 ms
- p95: 6.203 ms
- p99/max: 6.203 ms
- checksum: 200021000000

This benchmark measures portable coordination overhead only; it is not an AVAudioEngine or physical-device latency benchmark.

## Remaining gates / non-PARITY statement

This wave is `COMPLETE_NON_PARITY`.

Still required at HQ late integration:

- selected Xcode/iOS SDK compile of the new wrapper/helper with real frozen Shared types
- integrated use of `RescheduleFencedPlaybackBackend` around the selected ramped backend
- on seek/loop/tempo/interruption/resume: obtain Playback token, advance PracticeDSP `scheduleGeneration`, invalidate `AppleSampleAccurateClickExecutor`, then commit the generation binding before replacement click scheduling
- physical-iPhone proof that stale AVAudioPlayerNode completion callbacks and queued click buffers cannot affect the replacement transport
- real-audio loop/seek/tempo stress with audible click/pop/drift inspection
- current-Moises differential evidence

No PARITY row is promoted by this portable/synthetic wave.
