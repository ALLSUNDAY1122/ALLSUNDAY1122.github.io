# L3-AW17｜Discrete Transport Serialization / Unified Token Authority

Result: `COMPLETE_NON_PARITY`

Evidence scope: `LANE3_UNIFIED_PRODUCTION_TRANSPORT_AUTHORITY_NON_PARITY`

## Why this wave exists

AW15 made `PracticeDSPGenerationCoordinator` fail closed under actor reentrancy, cancellation and superseding Playback tokens. AW16 then reduced unnecessary supersession by coalescing rapid seek/loop/tempo **before** `RescheduleFencedPlaybackBackend` token generation.

The remaining product gap was that discrete token-producing paths—media load/replacement, play/pause and interruption—could still be invoked outside AW16. A separate outer lock is not sufficient: if it holds a permit while awaiting AW16, rapid continuous calls cannot enter AW16 together and pre-token coalescing disappears.

AW17 therefore provides one product-side authority that owns both behaviors:

- seek / loop / tempo: latest-wins coalescing before token generation;
- play / pause: ordering barrier, forcing older pending continuous intents ready first;
- media load / media replacement / interruption / explicit recovery: lifecycle barrier, superseding older pending continuous intents before they consume a token;
- every actual token-producing operation: one serialized drain;
- post-token failures: reconstruct the already-issued generation from the Playback fence and attempt a strictly newer recovery token;
- failed/unknown recovery: `recoveryBlocked`, rejecting normal product intents before token generation;
- cancellation after actual dispatch: observed in the receipt but never treated as proof that the generation was not issued.

## Production source

`Playback/Sources/Lane3UnifiedProductionTransportAuthority.swift`

The integration target should use a single project-scoped instance around the same project-scoped:

- `RescheduleFencedPlaybackBackend`
- `PracticeDSPGenerationCoordinator`

Do not put another coalescing layer after token creation.

## Barrier semantics

### Continuous family

`seek`, `loop`, `tempo`

A newer same-family pending request supersedes the previous request before either can generate a Playback token. The default quiet period remains provisional at 16 ms and must be tuned on the target iPhone.

### Ordering barrier

`play`, `pause`

Older pending continuous controls are marked ready immediately. Ticket order then guarantees that the older control commits before the later play/pause command. This prevents a user sequence such as seek→play from silently dropping the seek merely because the coalescing quiet period had not elapsed.

### Lifecycle barrier

`mediaLoad`, `mediaReplacement`, `interruptionBegan`, `interruptionEnded`, `recovery`

Older pending continuous controls are superseded **before token generation**. They describe an older playback/lifecycle context and must not cross the lifecycle boundary.

## Routing

- tempo token: `PracticeDSPGenerationCoordinator.applyTempoRatio`
- recovery token: `PracticeDSPGenerationCoordinator.recover`
- all other transport tokens in this authority: `bindTransportDiscontinuity`

The transport binder explicitly rejects `.tempoChange` and `.recovery` as unexpected routes.

## Fail-closed behavior

If a throwing Playback backend fails after the fence was advanced, AW17 compares pre/post `rescheduleTokenSnapshot` and retains the generated token identity. It then attempts a newer recovery token.

If automatic recovery fails, all normal queued work is rejected and new normal calls return `authorityRecoveryBlocked` before token generation. Only explicit `submitRecovery()` is allowed to proceed.

The nonthrowing pause path can return no token if the underlying Playback fence fails closed. In that case AW17 cannot safely claim a recoverable/current binding and enters `recoveryBlocked` rather than continuing.

## Portable validation

Swift 6.2.1 / Linux x86_64, exact AW17 authority source against interface-compatible Playback/coordinator types:

- 500 concurrent seek intents: 1 executed, 499 superseded before token, exactly 1 Playback generation;
- seek→play ordering barrier: seek generation commits immediately before play generation;
- pending seek→media replacement: seek superseded before token, replacement consumes the next generation;
- pending tempo→interruption began: tempo superseded before token, interruption consumes the next generation;
- media load, normal pause and interruption ended: each uses the same serialized generation path;
- forced play backend failure: failed generation reconstructed and automatic recovery uses the next generation;
- forced seek failure + forced recovery failure: authority enters recoveryBlocked; play/tempo attempts consume no additional token; explicit newer recovery reopens dispatch;
- missing pause token: authority enters recoveryBlocked and requires explicit recovery;
- pending caller cancellation: no token generated.

Observed deterministic route sequence in the portable probe:

`seek, seek, play, mediaReplacement, interruptionBegan, mediaLoad, pause, interruptionEnded, play, recovery, seek, recovery, recovery, recovery`

No parallel token-producing path was observed.

## Deterministic barrier stress

- 5,000 `pending seek → play` cycles: all 5,000 seek intents flushed before the later play; 10,000 tokens total;
- 5,000 `pending tempo → interruption` cycles: all 5,000 tempo intents superseded before token; 5,000 interruption tokens total;
- total tokens: 15,000;
- stale continuous tokens crossing lifecycle barrier: 0.

## Portable benchmark

20 rounds × (`2,000` rapid seek submissions + `200` serialized play/pause operations):

- median: `26.794 ms`
- p95: `40.730 ms`
- max: `46.662 ms`
- checksum: `168810`

This benchmark uses the exact AW17 authority source with interface-compatible lightweight Playback/coordinator stubs. It excludes AVAudioEngine, AudioUnit, real backend work, PCM, file/device IO and current-Moises execution. It is an orchestration benchmark, not an audio latency claim.

## Repository validation assets

- `Playback/Tests/L3_AW17_UnifiedTransportAuthoritySelfTest.swift`
- `Playback/Tests/L3_AW17_UnifiedTransportAuthorityBenchmark.swift`
- `Playback/benchmarks/L3-AW17_VALIDATION.json`

Selected full-source Xcode/iPhone execution remains an HQ Late Integration gate because the package/target is Lane 4/HQ owned.

## HQ integration rules

1. Instantiate exactly one `Lane3UnifiedProductionTransportAuthority` per active project.
2. Route product seek/loop/tempo/media load/media replacement/play/pause/interruption/recovery through it before any direct token-producing call.
3. Do not call `RescheduleFencedPlaybackBackend.*AndReturnToken` directly from product UI/lifecycle code once AW17 is selected.
4. Do not route tempo through generic transport binding.
5. Do not reuse a failed/superseded/cancelled Playback generation as recovery.
6. When `recoveryBlocked` is true, do not bypass the authority; use `submitRecovery()` or surface the failure.
7. Retain AW13 evidence receipts and AW15/AW16/AW17 authority receipts with real-device evidence.
8. Tune the provisional 16 ms continuous quiet periods on a physical iPhone using responsiveness plus token/generation churn measurements.

## Non-PARITY boundary

AW17 proves portable control/generation ordering only. It does not prove AVAudioEngine timing, audible click/pop absence, physical-device responsiveness, real-audio quality or current-Moises equivalence. MOI-P006/P007/P008/P010/P012/P014/P015 therefore remain unchanged until HQ device/real-audio/differential gates pass.
