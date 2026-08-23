# L3-AW15｜Coordinator Concurrency / Cancellation Hardening

Result: `COMPLETE_NON_PARITY`

## Goal

Harden `PracticeDSPGenerationCoordinator` for real Swift actor reentrancy: overlapping user-control Tasks, cancellation while suspended at controller awaits, and a newer Playback token arriving while an older operation is still in flight.

## Production gaps found and fixed

### 1. Cancellation was not an authority transition

Before AW15, cancelling the caller Task did not stop the coordinator after an `await`. A transport/tempo/click/recovery operation could continue to click invalidation and publish a replacement binding after its caller had already cancelled it.

AW15 adds cooperative checks before every Lane-3 replacement commit point. If Playback or click generation has already advanced, cancellation records those generations as recovery floors, clears replacement authority and poisons the gate. Cancellation before a click-only mutation has advanced generation can leave the current authority intact. Cancellation after the final click invalidation/combined-binding commit point is intentionally treated as a completed operation rather than disguising committed state as aborted.

### 2. `operationInFlight` rejection alone was unsafe for token-bearing overlaps

Playback advances its own fence before calling the DSP coordinator. Therefore, when operation A is suspended and operation B arrives with a genuinely newer Playback token, simply throwing `operationInFlight` for B is insufficient: B's generation is already externally visible, so A must never later become current.

AW15 changes token-bearing entry points so a newer overlapping token:

1. is compared against both committed and pending Playback generations;
2. becomes the new recovery floor;
3. clears pending/active replacement authority and poisons the gate;
4. still receives `operationInFlight` at its own call site;
5. causes the older suspended operation to fail with `operationSuperseded` when it resumes.

Stale/replayed overlapping tokens do not poison a newer pending/current authority.

### 3. Click-only and recovery work can also be superseded

A new Playback token may arrive while metronome/count-in is suspended in `PracticeDSPProductionController`. The click-only mutation can then finish logically, but AW15 refuses to touch/authorize the old click authority and records any advanced click generation as a recovery floor.

Recovery is also supersedable: if a newer Playback token arrives while backend recovery is suspended, the older recovery token cannot publish a binding.

## New production observability

`PracticeDSPGenerationAuthoritySnapshot` / `authoritySnapshot()` expose gate-only state without awaiting the production controller:

- active binding
- pending Playback generation/reason
- last Playback/click recovery floors
- poison state
- operation serial
- `operationInFlight`

This is specifically useful while the coordinator actor is re-entered at an internal `await`, where the existing full snapshot may itself wait behind the controller actor.

## Repository regression

`DSP/Tests/L3_AW15_CoordinatorConcurrencyCancellationSelfTest.swift` uses a deterministic blocking transactional backend to force real actor suspension and covers:

- newer Playback token superseding suspended transport;
- same-generation recovery reuse rejection;
- cancellation of suspended transport;
- click-only overlap rejection;
- Playback superseding suspended metronome;
- cancellation after count-in generation advance;
- cancellation after transactional tempo application but before replacement authority;
- recovery superseded by a newer Playback token;
- cancellation of suspended recovery;
- final exact replacement-binding validation.

`DSP/Tests/L3_AW15_CoordinatorConcurrencyBenchmark.swift` is the full-source benchmark for the integrated Lane-3 build. It runs deterministic suspended-transport/newer-token/recovery cycles against the actual production coordinator/controller types.

## Portable independent validation

Environment: Swift 6.2.1, Linux x86_64.

An interface-compatible independent actor/generation harness reproduced the AW15 authority rules with a true async suspension point.

- 10,000 cycles PASS.
- Each cycle: start transport generation 1 -> suspend -> deliver generation 2 -> require overlap rejection + poison -> release generation 1 -> require `operationSuperseded` -> reject recovery generation 2 -> recover generation 3.
- Cancellation probe PASS: cancelled suspended transport retained Playback generation 1 and click generation 1 as floors, with no active binding.
- Deterministic checksum: `1333080` for the 10,000-cycle run.

### Portable contention benchmark

20 rounds x 2,000 overlap/recovery cycles:

- median: `247.364 ms / 2,000 cycles`
- p95: `326.057 ms`
- max: `350.856 ms`
- per-round checksum: `262008`

This benchmark measures an interface-compatible actor/generation contention harness. It does **not** measure AVAudioEngine, AudioUnit, PCM, device IO, actual Apple click scheduling or current-Moises behavior. The repository full-source benchmark remains for selected integrated execution.

## Claim boundary

AW15 proves neither audible quality nor physical-device timing and does not promote PARITY. Final P006/P007/P008/P010/P012/P014/P015 judgment still requires selected Xcode/iOS integration, physical-iPhone execution, rights-cleared real audio, AW13 chain-of-custody, listening and current-Moises differential evidence.
