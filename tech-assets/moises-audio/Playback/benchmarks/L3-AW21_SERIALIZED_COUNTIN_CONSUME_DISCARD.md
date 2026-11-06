# L3-AW21｜Serialized Count-in Consume / Discard Authority

Result: `COMPLETE_NON_PARITY`

## Goal

Remove AW20's dependence on quarantining a raw non-nil `pendingCountInClicks` value. Count-in arm, accepted-schedule consume, interruption discard and stale-authority rejection must be ordered under the project-scoped production generation coordinator.

## Design correction

The initial AW21 proposal treated consume and discard as if both should advance click generation and invalidate the click node. That is unsafe after the Apple executor has already accepted the count-in replacement: invalidating that generation would erase the count-in that the commit is confirming.

AW21 therefore separates the semantics:

- **consume after executor acceptance**: exact-generation authorization, raw pending -> nil, generation unchanged, accepted executor schedule preserved;
- **discard at interruption/cancellation boundary**: raw pending -> nil, click generation advances, combined replacement authority revoked, click queue invalidated.

This distinction is required for correct one-shot behavior.

## Production implementation

### `DSP/Sources/PracticeDSPGenerationCoordinator.swift`

Added additive-only AW21 APIs in a same-file actor extension:

- `consumeScheduledCountIn(expectedClickGeneration:expectedClicks:)`
- `discardCurrentCountIn()`
- `discardCountIn(expectedClickGeneration:expectedClicks:)`

The previous coordinator source was preserved byte-for-byte before the extension; comparison against AW20 head reports `+269 / -0` for this file.

Consume rules:

1. Runs under the coordinator's existing `operationInFlight` / operation serial fence.
2. Rejects a poisoned coordinator or pre-mutation cancellation.
3. Requires exact raw schedule generation and exact pending click count.
4. Clears `pendingCountInClicks` through `PracticeDSPProductionController.clearPendingCountIn`.
5. Requires generation to remain exactly unchanged and pending state to read back nil.
6. Does **not** invalidate the click executor on success, preserving the already accepted count-in schedule.
7. If a newer Playback operation poisons authority while consume is suspended, the accepted queue is flushed fail closed and the operation is rejected as superseded.
8. Duplicate consume sees no pending count-in and is rejected.

Discard rules:

1. Runs under the same coordinator operation fence.
2. `discardCurrentCountIn` snapshots the current raw pending value after acquiring the fence; the exact variant additionally binds to generation + click count.
3. Clears raw pending state.
4. Advances `scheduleGeneration` through `invalidateScheduledClicks`.
5. Revokes older combined transport/click replacement authority.
6. Invalidates the click queue at the new generation.
7. Once destructive discard begins, cancellation does not skip queue invalidation.
8. Partial mutation, overlapping newer Playback authority, or click-node invalidation failure poisons the coordinator.
9. If generation advancement fails/overflows after raw clear, equal-generation invalidation is attempted as a stale-queue flush; `DSPClickExecutionState.invalidate(to:)` permits equality.
10. Exact stale authorization never clears a newer count-in arm.

### `Playback/Sources/Lane3SerializedPracticeClickGate.swift`

New AW21 selected product route layered over AW20:

- delegates existing interruption/metronome semantics to `Lane3PracticeInterruptionClickGate`;
- requires exact count-in arm generation before and after planning;
- after the Apple executor accepts replacement, revokes AW20's one-shot authorization and calls coordinator serialized consume;
- on consume failure, attempts an exact-authority discard without touching any newer arm;
- at interruption begin, sets a local boundary fence **before the first await**, calls coordinator serialized discard, then always submits the AW20/AW18 transport interruption boundary;
- prevents a re-entrant selected-route count-in arm during that pre-boundary discard window.

HQ/App should use `Lane3SerializedPracticeClickGate` as the Lane-3 count-in/metronome product surface after AW21, not AW20 directly.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64.

A deterministic actor-based semantic harness passed:

- accepted-schedule consume preserves generation and does not add queue invalidation;
- raw pending becomes nil after consume;
- duplicate consume is rejected;
- stale older authorization cannot consume a newer arm;
- discard clears pending, advances generation and invalidates queue;
- injected invalidation failure leaves raw pending nil and poisons the model;
- explicit model recovery re-establishes a usable generation fence;
- generation-overflow discard remains fail closed and attempts equal-generation queue flush.

Stress: 50,000 arm/consume-or-discard cycles.

- final raw pending: `nil`
- final generation: `83336`
- invalidations: `83336`
- failure -> poison -> recovery: `PASS`
- overflow fail-closed: `PASS`
- checksum: `2083508333`

Console evidence:

`L3-AW21 semantic harness PASS`

`cycles=50000`

`pending=nil`

`generation=83336`

`invalidations=83336`

`failure_recovery=PASS`

`overflow_fail_closed=PASS`

`checksum=2083508333`

## Portable benchmark

Actor semantic microbenchmark: 20 rounds x 2,000 cycles.

Each cycle performs arm and then either accepted-schedule consume or destructive discard.

- median: `36.274 ms / 2,000 cycles`
- p95: `50.049 ms`
- max: `55.714 ms`
- checksum: `66686660`

This is a scheduling/authority microbenchmark only. It excludes production backend transactions, AVAudioEngine/AVAudioSession, Apple click-node work, file/device I/O, real audio and current-Moises execution.

## Repository validation authored

- `Playback/Tests/L3_AW21_SerializedCountInAuthoritySelfTest.swift`
- `Playback/Tests/L3_AW21_SerializedCountInAuthorityBenchmark.swift`

The full-source self-test covers:

- consume -> pending nil with unchanged generation;
- duplicate consume rejection;
- exact-generation plan rejection after a newer click mutation;
- interruption serialized discard -> pending nil;
- stale exact discard does not erase newer arm;
- click invalidation failure after clear -> pending nil + poisoned coordinator.

These repository tests are authored for the selected integrated source set but are **not reported as executed** in this Linux Worker environment.

## HQ Late Integration requirements

1. Construct one project-scoped `PracticeDSPGenerationCoordinator` as before.
2. Construct the existing AW19 instrumented interruption gate and AW20 practice gate on that same coordinator.
3. Wrap AW20 with one project-scoped `Lane3SerializedPracticeClickGate` and route product metronome/count-in/interruption begin/end/retry through AW21.
4. Do not call `Lane3PracticeInterruptionClickGate` directly from App after AW21 except inside the AW21 wrapper.
5. Do not call raw `PracticeDSPClickExecutionPlanner.countIn(state:)` from App/HQ.
6. After Apple count-in replacement acceptance, call AW21 `markCountInScheduleCommitted`; do not separately clear raw pending state.
7. Interruption begin must pass through AW21 so raw pending discard occurs before the transport boundary.
8. Keep AW20 fresh render-origin/common-host-anchor requirements for metronome restore.
9. Keep AW19 telemetry privacy boundary: no raw audio/PCM, filename/path, ProjectID, absolute wall clock, or individual generation identifiers in exported telemetry.
10. Execute the authored repository self-test/benchmark in the selected Xcode/iOS source set.
11. On physical iPhone validate phone/Siri/route interruption, armed/consumed count-in, doubled/early/late clicks, beat phase, final-click -> music-start timing and click/pop before P014/P015 promotion.

## Remaining gates

AW21 removes the Lane-local raw-pending quarantine gap on the selected product route, but it does not establish parity.

Still unverified:

- selected Xcode compile/integrated execution;
- real AVAudioSession interruption delivery;
- real AppleSampleAccurateClickExecutor scheduling;
- fresh render-origin/common-host anchor on device;
- rights-cleared real audio;
- physical-iPhone timing/listening;
- current-Moises differential.

P014/P015 remain `MISSING`. No PARITY promotion is claimed.
