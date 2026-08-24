# L3-AW28｜Tempo Transition Artifact Hardening

Result: `COMPLETE_NON_PARITY`

## Goal

Remove the avoidable abrupt `AVAudioUnitTimePitch.rate` write from the selected tempo-change path when the live Apple Audio Unit exposes a rampable rate parameter, without weakening AW12/AW15/AW17 generation authority or changing the existing one-generation-per-tempo-command semantics.

## Production change

- Added `PracticeDSPTempoTransitionPolicy`, planner, backend receipt and transition protocol.
- Transition duration is based on `abs(log(toRatio / fromRatio))`, so reciprocal changes such as 1.0→0.5 and 0.5→1.0 receive the same planned duration.
- Provisional policy: 0.01 immediate log-ratio threshold, 8–40 ms ramp envelope, 4 ms settle, maximum 4096 frames. These are device-tunable mechanics, not quality thresholds.
- `PracticeDSPTransactionalApplicationGate` now gives tempo-only mutations their own asynchronous transaction barrier. Other DSP/control mutations are rejected with `transactionInFlight` while a scheduled tempo ramp is pending.
- Begin/finalize/readback failure rolls back to the previously observed tempo/pitch snapshot. Rollback failure marks the gate desynchronized and blocks later writes until recovery.
- `PracticeDSPProductionController.setTempoRatio` still advances `scheduleGeneration` exactly once before the gate. AW28 does not invent an extra click or Playback generation.
- Combined tempo+pitch restore remains on the existing atomic immediate path instead of fabricating a tempo-only ramp receipt.
- `Lane3DSPTelemetryTransactionalBackend` now preserves tempo-transition capability the same way AW25 preserved pitch-transition capability.
- `AppleTimePitchBackend` schedules the live `kNewTimePitchParam_Rate` parameter with `scheduleParameterBlock` only when render resources exist and the rate parameter reports ramp support. It does not assign `node.rate` before scheduling the ramp. Unsupported runtime states use an explicit `immediateFallback` receipt.

## Generation / transport ordering

No coordinator change was required. Existing `PracticeDSPGenerationCoordinator.applyTempoRatio` sequencing remains:

1. Playback tempo-change token admitted.
2. DSP controller tempo transaction completes.
3. Controller `scheduleGeneration` is observed.
4. Click schedule is invalidated to that generation.
5. Current/supersession checks run.
6. Replacement Playback/click binding commits.

Therefore a selected scheduled tempo ramp finishes inside the DSP controller transaction before the replacement binding is committed. A newer Playback token that arrives while the DSP operation is suspended is still caught by the existing post-operation current/supersession checks.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, `-strict-concurrency=complete -warnings-as-errors`.

PASS:
- planner immediate path for very small tempo delta;
- reciprocal 1.0→0.5 and 0.5→1.0 duration symmetry;
- 4096-frame hard cap and invalid ratio/sample-rate rejection;
- scheduled ramp transaction barrier blocks reentrant control-only and competing DSP writes;
- successful ramp commits the caller-supplied schedule generation unchanged by the gate;
- explicit unsupported-backend fallback is accepted but not labeled a scheduled ramp;
- forged transition receipt is rejected and rolled back;
- finalize failure rolls back and leaves the gate synchronized;
- post-finalize readback mismatch rolls back;
- rollback failure poisons/desynchronizes the gate and later mutation is rejected;
- controller successful tempo command preserves exactly one schedule-generation increment;
- same-value tempo command preserves existing generation semantics but produces no transition receipt;
- combined tempo+pitch restore stays on the immediate atomic path;
- exact AW28 transaction + telemetry-adapter source compiles together under strict concurrency with interface-compatible surrounding contracts.

Portable behavior probe output:

`AW28 tempo transition PASS rampFrames=1331 begins=5 finalizes=3 cancels=3`

## Portable benchmark

20 rounds × 5,000 alternating tempo transactions, fake in-memory backend and no-op transition sleeper:

- median: `84.419 ms / 5,000`
- p95: `109.474 ms / 5,000`
- max: `109.474 ms / 5,000`
- checksum: `1250000`

This is transaction/planner overhead only. It excludes AVAudioUnitTimePitch, actual ramp duration, Playback rescheduling, click scheduling, file I/O, device latency and audio rendering.

## Repository validation authored

- `DSP/Tests/L3_AW28_TempoTransitionSelfTest.swift`
- `DSP/Tests/L3_AW28_TempoTransitionBenchmark.swift`
- `DSP/Tests/L3_AW28_AppleTempoTransitionCompileSelfTest.swift`

The selected Apple/Xcode execution is intentionally pending HQ Late Integration.

## Non-PARITY boundary

AW28 does **not** establish audible improvement. Still required on the selected physical iPhone:

- selected Xcode/iOS compile of `kNewTimePitchParam_Rate` scheduling path;
- proof that the live NewTimePitch rate parameter is present and rampable;
- receipt mode distribution (`scheduledRamp` vs each `immediateFallback` reason);
- rapid slow↔fast gestures with rights-cleared real audio;
- click/pop, warble, phasiness, transient and latency measurement;
- metronome/count-in phase continuity across tempo changes;
- current-Moises A/B and human listening review;
- AW24 machine evidence binding and final HQ PARITY judgment.

`immediateFallback` is diagnostic compatibility, not successful artifact hardening evidence.
