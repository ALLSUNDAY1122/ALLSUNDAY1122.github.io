# L3-AW33｜Selected Stack Reconstruction / Poison Recovery

Result: `COMPLETE_NON_PARITY`

## Goal

Prevent an AW31/AW32 Apple Playback/DSP composition that has suffered an unrecoverable boundary/restart failure from being reused in place. Convert permanent selected-backend poison into a one-way reconstruction requirement and make selected-facade replacement generation/ticket fenced.

## Product hardening

- Added `Lane3SelectedTransportRecoveryTicket` and one-way `Lane3SelectedTransportRecoveryState`.
- `Lane3TempoBoundarySelectedTransportFacade` now permanently latches reconstruction after:
  - tempo-boundary commit restart failure,
  - tempo-boundary cancel restart failure,
  - selected Playback backend reports permanent poison after seek/load/play/recovery/interruption/prepare paths,
  - admission counter overflow.
- After the latch is set, every later product operation is rejected before touching Playback/DSP. There is no in-place reset API.
- Added `Lane3SelectedTransportReconstructionSlot`:
  - current facade is not exposed,
  - product calls acquire shared operation leases,
  - replacement closes admission and drains already-issued operations,
  - exact recovery ticket is required,
  - stale ticket is rejected,
  - poisoned replacement facade is rejected,
  - slot generation advances exactly once on successful replacement,
  - old facade is never declared reused.
- `AppleBoundaryEnvelopedPlaybackBackend` now reports permanent selected-stack poison and remains muted/fail-closed when envelope or underlying tempo-boundary authority becomes unrecoverable.
- `Lane3AppleTempoAwarePlaybackDSPStack` now exposes the recovery slot as the public selected route; the raw selected-facade factory is module-internal.
- Apple compile-surface guard includes AW33 recovery models/slot/composition receipt.

## Portable validation actually executed

Environment: Swift 6.2.1, Linux x86_64.

A strict-concurrency portable semantic model matching the AW33 recovery-ticket/state/replacement invariants was compiled with:

`-swift-version 6 -strict-concurrency=complete -warnings-as-errors -O`

Result:

- 1,000,000 recovery cycles PASS.
- first failure ticket remained authoritative in 1,000,000 / 1,000,000 cycles.
- stale replacement ticket rejected: 1,000,000 / 1,000,000.
- clean exact-ticket replacement accepted: 1,000,000 / 1,000,000.
- replacement generation advanced only on accepted exact-ticket replacement.
- portable checksum: `15500023499964`.

Portable recovery bookkeeping benchmark, 20 rounds x 100,000 operations:

- median: `3.056 ms`
- p95: `3.130 ms`
- max: `3.240 ms`
- checksum: `100024000000`

This benchmark measures only recovery-ticket/latch/replacement-policy CPU bookkeeping. It does not measure AVAudioEngine reconstruction, file decode, graph startup, device latency or audible downtime.

## Repository regression authored

`Playback/Tests/L3_AW33_SelectedStackReconstructionSelfTest.swift` exercises the actual Lane-3 selected facade/slot surface with protocol-compatible production dependencies:

- forced tempo commit restart failure -> reconstruction ticket,
- subsequent seek rejected before old backend call,
- stale replacement ticket rejected,
- exact clean replacement advances slot generation 1 -> 2,
- replaced old facade remains permanently latched,
- non-tempo seek/backend poison is detected and latched,
- forced DSP failure + cancel restart failure is terminal.

`Playback/Tests/L3_AW33_SelectedStackRecoveryBenchmark.swift` benchmarks the actual recovery-state latch in the repository source surface.

These repository tests are authored but were not executed against the complete selected SwiftPM/Xcode source graph in this Worker environment.

## Negative / recovery semantics

- A transient prepare failure that does not poison the selected backend remains a normal prepare failure and does not invent a reconstruction ticket.
- A backend that explicitly reports permanent poison always wins over normal retry semantics.
- `submitRecovery()` is not a backdoor around AW33; once the facade is latched it is rejected before old-stack access.
- Reconstruction does not mutate/reset the old facade. The replacement is a newly constructed selected stack/facade.
- A replacement facade that is itself already reconstruction-required is rejected.
- Slot generation overflow poisons the slot and fails closed.

## Integration contract

HQ/App should retain `Lane3SelectedTransportReconstructionSlot` as the selected product transport object, not retain a raw `Lane3TempoBoundarySelectedTransportFacade`. When the slot exposes a recovery ticket, HQ must construct a fresh AW31/AW32/AW33 Apple composition from current durable project/media state, construct fresh coordinator/AW17/AW18/AW21 dependencies for that composition, and install its clean facade with the exact pending ticket. Old graph/facade references must be discarded.

State restoration after a full Apple graph rebuild remains a late-integration responsibility because durable project/media state crosses Lane 2/Shared/App ownership. AW33 does not copy or invent that state inside Lane 3.

## Explicit non-PARITY boundary

Not executed here:

- complete selected Xcode/iOS compile,
- actual AVAudioEngine teardown/recreation,
- AVAudioSession interruption/runtime reconstruction,
- restoration from real persisted project/media state,
- physical-iPhone restart downtime measurement,
- real-audio PCM/listening checks,
- current-Moises differential.

Therefore this wave does not promote any PARITY row. `MOI-P006/P007/P008/P010/P012/P014/P015` remain `MISSING` until HQ's real-device/real-audio differential gates are satisfied.
