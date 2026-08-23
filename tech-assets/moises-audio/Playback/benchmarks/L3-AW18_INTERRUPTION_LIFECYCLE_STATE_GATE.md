# L3-AW18 — Interruption Lifecycle State Gate

Result: `COMPLETE_NON_PARITY`

Evidence scope: `LANE3_INTERRUPTION_LIFECYCLE_STATE_GATE_NON_PARITY`

## Why this wave exists

AW17 serialized interruption-begin/end tokens with the rest of Lane-3 transport, but token ordering alone did not define product lifecycle semantics. Without an outer state gate, product code could still issue play/seek/tempo while an OS interruption was active, could resume solely because playback had been active before interruption without respecting the OS `shouldResume` signal, or could let an older resume continuation overwrite a newer interruption.

AW18 keeps `Lane3UnifiedProductionTransportAuthority` as the only token-producing authority and adds `Lane3InterruptionLifecycleGate` around it. The gate owns interruption lifecycle state only; it does not create a parallel Playback generation path.

## State model

Phases:
- `idle`
- `beginning`
- `active`
- `ending`
- `endedRecoveryRequired`
- `resuming`
- `poisoned`

While the lifecycle is non-idle, ordinary product transport/DSP commands are rejected before they reach AW17 and therefore before they consume a Playback generation. `pause` is the intentional exception: during interruption it records the user's desire not to auto-resume and consumes no token.

## Resume policy

Automatic resume is permitted only when both are true:
1. playback intent immediately before the interruption resolves to playing; and
2. the OS interruption-ended event supplies `shouldResume == true`.

A pause received during the interruption clears the stored resume intent. A pause received while the automatic resume play is already in flight causes a compensating pause through AW17 after the play finishes, so the already-issued generation is never pretended to have been rolled back.

## Actor reentrancy/order hardening

A local monotonic intent-order serial tracks operations that can change commanded playing state. Interruption begin changes the lifecycle to `beginning` immediately, then waits only for older already-started playing-state operations to resolve before capturing `resumeArmed`. This closes the race where an older play was already queued in AW17 but its response had not returned when the OS interruption arrived.

A separate lifecycle revision prevents an older interruption-ended/resume continuation from writing state after a newer interruption begins. Such old completion returns `supersededByNewerLifecycleEvent=true`.

All serial overflow paths fail closed rather than wrap.

## Failure/recovery behavior

If AW17 is already `recoveryBlocked` when an interruption boundary is received, AW18 first asks AW17 to recover. An interruption-ended boundary that cannot establish a safe generation authority enters `endedRecoveryRequired`; ordinary commands remain pre-token blocked. `retryEndedInterruptionRecovery()` is the only path that can reopen the lifecycle, and it preserves the saved OS `shouldResume` plus user resume intent.

A boundary whose original operation failed but whose AW17 automatic recovery succeeded is treated as generation-safe for lifecycle bookkeeping. This is not an audible/device success claim.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, interface-compatible lightweight AW17/Playback/coordinator harness.

Validated behaviors:
- active interruption rejects seek and tempo before token generation;
- pause during interruption suppresses resume with no token;
- `shouldResume=false` never auto-resumes;
- `shouldResume=true` resumes only when pre-interruption playing intent remains armed;
- interruption begin waits for an older in-flight play before deciding resume eligibility;
- pause during in-flight auto-resume causes compensating AW17 pause;
- a newer interruption during resume stale-marks the older end continuation;
- failed interruption-end authority plus failed automatic recovery enters `endedRecoveryRequired`;
- normal commands cannot bypass `endedRecoveryRequired`;
- explicit retry recovery restores the lifecycle and applies the saved resume policy;
- authority already recovery-blocked at interruption begin is recovered before the boundary is accepted.

Deterministic behavior probe result:
`AW18 PASS generations=33 routes=33 phase=idle`

### Stress

50,000 interruption cycles:
- blocked seek/tempo attempts during interruption: 100,000, all pre-token;
- pause resume suppressions: 10,000;
- automatic resumes: 6,667;
- final Playback generation: 123,334;
- final lifecycle phase: `idle`;
- state leaks: 0.

### Portable benchmark

20 rounds × 2,000 lifecycle cycles:
- median: `38.587 ms / round`
- p95: `57.592 ms / round`
- max: `60.295 ms / round`
- checksum: `150210`

This benchmark isolates AW18 lifecycle/order logic on a lightweight portable authority. It excludes AVAudioEngine, AudioUnit, actual Apple audio-session delivery, real Playback/DSP backend cost, device IO, real audio and current-Moises execution.

## Repository validation prepared

- `Playback/Tests/L3_AW18_InterruptionLifecycleSelfTest.swift`
- `Playback/Tests/L3_AW18_InterruptionLifecycleBenchmark.swift`

The repository self-test includes blocking-play actor reentrancy scenarios and was adjusted for Swift 6 async-autoclosure rules. Full selected-Xcode/Lane-3 execution remains an HQ Late Integration gate.

## HQ integration contract

Use one project-scoped `Lane3InterruptionLifecycleGate` around the one project-scoped AW17 `Lane3UnifiedProductionTransportAuthority`.

Route all product Playback/DSP token-producing commands through the gate once selected. Do not let App code call AW17 or `RescheduleFencedPlaybackBackend` token-producing methods directly, because that bypasses lifecycle blocking.

Map iOS audio-session events as follows:
- interruption began → `submitInterruptionBegan()`;
- interruption ended → pass the actual OS `shouldResume` option into `submitInterruptionEnded(shouldResume:)`;
- user pause while interrupted → `submitPause()` to suppress automatic resume without producing a token;
- `endedRecoveryRequired` → `retryEndedInterruptionRecovery()` before accepting normal commands.

Physical-iPhone validation must exercise real phone/Siri/audio-route interruption delivery, rapid user controls around both boundaries, actual AVAudioEngine restart/resume behavior, audible click/pop/desync and the current-Moises comparison flow.

## Claims deliberately not made

This wave does not claim:
- selected Xcode/iOS compile success;
- physical-device interruption correctness;
- AVAudioSession callback timing equivalence;
- audible artifact quality;
- real-audio behavior;
- current-Moises differential equivalence;
- PARITY for any P006/P007/P008/P010/P012/P014/P015 row.
