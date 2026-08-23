# L3-AW03｜Transactional Practice DSP production path

## Goal
Prevent logical PracticeDSP state from advancing unless the real tempo/pitch backend has applied and read back the requested state. Detect partial writes, silent mismatches and external backend mutation without editing Shared/App or another Lane.

## Added production path
- `PracticeDSPTransactionalApplicationGate`
  - validates candidate before mutation
  - snapshots backend before mutation
  - rejects pre-existing backend/logical divergence
  - rolls back partial backend failures
  - reads back after nominal success and rolls back silent mismatch
  - poisons normal apply if rollback cannot be verified
  - exposes explicit recovery to the last committed state
- `PracticeDSPProductionController`
  - active-project `PracticeDSPConfiguring` implementation
  - tempo changes invalidate click generation only after backend success
  - pitch changes do not increment click generation
  - metronome/count-in control changes remain local but verify that backend time/pitch did not diverge
  - restore uses a fresh generation and commits only after backend transaction succeeds
- `AppleTimePitchTransactionalBackend`
  - exposes `AVAudioUnitTimePitch` rate/pitch read-back as a transactional snapshot adapter.

## Portable verification
Swift 6.2.1 Linux self-test: PASS.

Covered success, partial-write rejection + rollback, silent post-apply mismatch + rollback, rollback failure poison, recovery, external divergence, active-project isolation, generation semantics and generation overflow before backend write.

Optimized benchmark: 20 rounds × 10,000 successful tempo/pitch transactions. Median 163.189 ms, p95 194.047 ms, p99/max 196.366 ms. This measures portable actor/control/read-back overhead only; it is not AudioUnit render latency.

## Quality boundary
This Wave does not establish MOI-P010 or MOI-P012 PARITY. Apple sources are still conditionally compiled and require selected Xcode/iOS SDK verification. Real audio, physical iPhone artifact capture, listening review and current-Moises differential comparison remain mandatory.

## HQ late-integration actions
1. Compile the complete Lane-3 DSP source set with the selected Xcode/iOS SDK.
2. Instantiate `PracticeDSPProductionController` for the active project using `AppleTimePitchBackend` through its transactional adapter.
3. Verify read-back tolerance on target iPhones, including repeated tempo/pitch retargets.
4. Feed real rights-cleared multi-genre material through physical-device capture and Lane-3 measurement evidence.
5. Run human listening and current-Moises A/B before any P010/P012 promotion.
