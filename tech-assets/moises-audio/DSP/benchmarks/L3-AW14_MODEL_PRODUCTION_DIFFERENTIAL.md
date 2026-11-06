# L3-AW14｜Model-vs-Production Differential Fuzzing

Result: `COMPLETE_NON_PARITY`

## Goal

Differentially exercise the AW11-derived combined-generation oracle against the AW12 production `PracticeDSPGenerationCoordinator` contract under repeated transport, tempo, metronome/count-in, stale-token, wrong-route, half-failure and recovery ordering.

This wave also hardened a production safety gap discovered while designing the differential model: a Playback token advances outside the DSP coordinator first. Therefore a newer token rejected because the coordinator is already poisoned, or because it was routed through the wrong coordinator API, is still externally observable and must become a recovery floor. Preserving the older combined replacement binding in that situation is unsafe.

## Production hardening

`PracticeDSPGenerationCoordinator` now:

- records a newer Playback generation even when a normal operation is rejected while the coordinator is poisoned;
- revokes replacement authority and poisons when a genuinely newer Playback token reaches the wrong coordinator entry point;
- preserves a valid binding for stale/replayed wrong-route tokens that do not advance the Playback generation;
- prevents a rejected/newly observed Playback generation from being reused as the recovery generation;
- retains the click generation advanced by a failed recovery attempt as an additional recovery floor.

The prior AW12 regression test was updated to fix these semantics permanently.

## Independent oracle

`DSP/Sources/Lane3GenerationDifferentialOracle.swift` predicts, without reading production results:

- Playback generation;
- click/schedule generation;
- operation serial;
- active replacement binding and reason;
- poison state;
- tempo ratio;
- metronome state;
- pending count-in state.

It models successful transport/tempo/click-only operations, transport and click-only half failures, invalid controls, stale Playback calls, newer wrong-route Playback tokens, new Playback tokens arriving while poisoned, failed recovery using the current generation, and successful dual-generation recovery.

## Portable differential validation

Environment:

- Swift 6.2.1
- Linux x86_64
- deterministic seed `0xA14D1FF3E2`
- 200,000 randomized operations plus one final recovery when required
- interface-compatible production semantic harness

Result: PASS.

Final state:

- operation serial: 200,001
- Playback generation: 125,929
- click generation: 133,399
- successful click invalidations: 118,760

Operation counts:

- successful transport: 37,563
- successful tempo: 7,508
- successful click-only metronome/count-in: 14,981
- forced transport click failure: 7,377
- forced click-only failure: 7,262
- invalid control rejection: 14,823
- stale/replayed token rejection: 14,987
- newer wrong-route Playback token fail-closed: 7,356
- new Playback token rejected while already poisoned: 29,436
- same-generation recovery reuse rejected: 29,366
- successful recovery: 29,342

After every operation the oracle and production semantic harness were compared for operation serial, click generation, poison state, exact active binding, tempo, metronome and pending count-in state. The final active binding was replacement-validated.

## Portable benchmark

The same interface-compatible differential executable was rebuilt with 10,000 randomized operations and executed 20 times as separate processes.

- median: 432.860 ms / 10,000 operations
- p95: 530.156 ms
- max: 530.661 ms

Observed round times (ms):

`504.722, 328.020, 371.812, 341.564, 439.117, 371.097, 440.094, 373.327, 372.749, 394.691, 425.886, 494.710, 412.091, 443.782, 530.661, 530.156, 486.342, 434.991, 430.729, 498.276`

Benchmark scope is coordinator/oracle/control-state orchestration only. It excludes AVAudioEngine, AudioUnit rendering, PCM analysis, file IO, physical-device IO and current-Moises execution.

## Repository evidence

- `DSP/Sources/PracticeDSPGenerationCoordinator.swift`
- `DSP/Sources/Lane3GenerationDifferentialOracle.swift`
- `DSP/Tests/L3_AW12_ProductionGenerationCoordinatorSelfTest.swift`
- `DSP/Tests/L3_AW14_ModelProductionDifferentialSelfTest.swift`
- `DSP/benchmarks/L3-AW14_VALIDATION.json`

The new oracle source passed portable Swift typecheck against interface-compatible production types. The repository AW14 test source passed Swift syntax parse and the equivalent production-semantic executable completed the 200k differential run above.

## Claim boundary

Evidence scope: `LANE3_MODEL_PRODUCTION_DIFFERENTIAL_NON_PARITY`.

This does not establish Apple SDK compilation, physical-device timing, audible click/pop freedom, tempo/pitch perceptual quality, current-Moises differential quality, or PARITY. Those remain HQ Late Integration gates.
