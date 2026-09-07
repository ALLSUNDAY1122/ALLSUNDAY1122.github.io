# L3-AW12 — Production Combined-Generation Coordinator

Result: `COMPLETE_NON_PARITY`

## Goal

Move AW11's combined generation/recovery invariants into Lane 3 production control so an AW05 Playback transport token, `PracticeDSPProductionController`, click queue invalidation and replacement authority are committed as one fail-closed sequence.

## Production behavior added

- Added `PracticeDSPGenerationCoordinator`, project-scoped around the existing production DSP controller.
- Generic transport discontinuities require a newer AW05 Playback token, advance DSP/click generation, flush the click schedule and publish a replacement binding only after both sides succeed.
- Tempo changes have a dedicated entry point so the transactional time/pitch backend mutation and click-generation invalidation cannot be bypassed by a generic transport bind.
- Recovery has a dedicated entry point and cannot be bypassed by a generic bind.
- Metronome/count-in are click-only mutations: after the DSP generation advances, the old transport+click replacement binding is revoked before the click node is touched.
- Failed two-phase invalidation records externally observed Playback/click generations as recovery floors and poisons the gate. A failed Playback token cannot later be reused as a recovery token.
- Partial-failure bookkeeping never moves observed generation floors backwards.
- Operation serial overflow fails closed and clears replacement authority.
- `AppleSampleAccurateClickExecutor` conforms to the new click invalidation protocol when AVFAudio is available.

## Validation

Portable environment: Swift 6.2.1 / Linux x86_64.

- Exact modified `PracticeDSPTransportRescheduleGate` hardening self-test: PASS.
- Exact AW12 coordinator + exact gate compiled and executed against interface-compatible production-controller/Playback-token types: PASS.
- Repository production self-test source targets the actual `PracticeDSPProductionController`, `PracticeDSPTransactionalBackendApplying`, AW05 token/binding types and the new coordinator; syntax parse PASS. Final selected-Xcode/full-target typecheck remains HQ late-integration work because `Package.swift` is Lane 4-owned and currently excludes DSP from the package target.
- Verified failure cases include stale Playback generation, metronome/count-in binding revocation, click invalidation failure after generation advance, failed-token recovery rejection, newer dual-generation recovery, invalid count-in atomicity, wrong tempo/recovery entry paths and operation-serial exhaustion.
- Successful click invalidation sequence in the deterministic production-coordinator scenario: `1,2,3,4,6,7,9`; failed invalidations at 5 and 8 never became replacement-authorized.

## Benchmark

20 rounds × 10,000 mixed asynchronous coordinator operations (seek, metronome, count-in, tempo, loop):

- median: 200.151 ms / round
- p95: 239.842 ms / round
- max: 327.629 ms / round
- checksum: 520190

The benchmark uses exact AW12 coordinator/gate code with interface-compatible Linux controller/click backends. It measures portable orchestration/actor overhead only. It excludes AVAudioEngine rendering, AudioUnit work, PCM processing, device IO and actual Apple click-node scheduling.

## PARITY boundary

This Wave does not prove audible click/pop freedom, timing quality, Apple runtime behavior, real-track quality, current-Moises equivalence or human-perceived recovery quality. `parityPromotionAllowed` remains false. HQ must instantiate and run this coordinator in the integrated iPhone host and retain real-device/real-audio evidence before P006/P007/P008/P010/P012/P014/P015 can advance.
