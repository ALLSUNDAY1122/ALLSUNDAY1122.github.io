# L3-AW11 — Combined Playback / DSP Recovery Stress

Result: `COMPLETE_NON_PARITY`

## Goal
Exercise Lane-3 mixer, transport, tempo/pitch, metronome/count-in and interruption/recovery semantics as one interleaved state machine rather than isolated unit paths. The wave specifically targets stale-generation reuse, half-invalidated transport recovery, click-only schedule invalidation, invalid-control atomicity and generation exhaustion.

## Implementation

- `Lane3CombinedRecoveryMachine`
  - bounded stem gains, tempo, pitch, loop, seek, metronome and count-in state
  - dual Playback/click generations for transport discontinuities
  - click-only generation invalidation for metronome/count-in changes
  - combined replacement binding is cleared whenever click-only state advances, preventing a transport binding created against an older click generation from authorizing replacement
  - forced half-invalidation poisons the machine and clears replacement authority
  - only recovery advances both generations and restores a current binding
  - stale completion and stale replacement acceptance are explicit checks
  - invalid controls are atomic; generation overflow is intentionally not rolled back because the transport may already be partially invalidated
- `Lane3CombinedRecoveryAW05Adapter`
  - binds the existing AW05 Playback token and PracticeDSP generation binding to AW11 evidence
  - rejects generation mismatch, reason mismatch and stale active click generation
  - emits non-PARITY receipt only

## Portable validation

Swift 6.2.1 / Linux x86_64.

Self-test PASS:
- mixer gain + pitch + tempo + seek + loop combined state flow
- click-only metronome invalidation clears older combined transport binding
- stale completion rejection
- stale replacement rejection
- deliberate half-invalidation poison and dual-generation recovery
- operations while poisoned reject without logical mutation
- invalid gain / tempo / pitch / count-in / loop are atomic
- Playback generation overflow poisons fail-closed
- click generation overflow after Playback advance preserves the partial advance and poison state; exhausted recovery remains rejected
- Codable report round-trip
- AW05 adapter valid receipt + generation/reason/stale-click negative cases

Long stress: 1,000,000 requested operations, 6 stems, seed `0xA11A11A11`.

- applied: 992,033
- forced half failures: 1,003
- recoveries: 1,003
- stale completion attempts/rejected: 4,731 / 4,731
- stale replacement attempts/rejected: 3,236 / 3,236
- final invariant: PASS
- checksum: `4abf951ddb94dac7`

## Benchmark

20 rounds × 100,000 mixed operations, 6 stems:

- median: 6.365 ms / 100,000 operations
- p95: 6.750 ms
- max: 7.356 ms
- checksum: 2,763,516

This benchmark measures only the portable state/recovery oracle. It excludes AVAudioEngine, real PCM rendering, gain-ramp audio execution, STFT/cepstral analysis and device I/O.

## Evidence limits

This wave does **not** prove audible click/pop/zipper freedom, device timing, long-track thermal stability, Apple AudioUnit behavior, real-audio tempo/pitch quality or current-Moises parity. It prepares a deterministic combined-state recovery gate for HQ late integration. Physical iPhone capture, rights-cleared real tracks, current-Moises differential and human listening remain required before affected PARITY rows can move.
