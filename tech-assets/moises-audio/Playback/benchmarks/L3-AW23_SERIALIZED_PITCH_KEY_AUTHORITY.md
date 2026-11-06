# L3-AW23｜Serialized Pitch / Key Production Authority

Result: `COMPLETE_NON_PARITY`

Evidence scope: `LANE3_SERIALIZED_PITCH_KEY_AUTHORITY_NON_PARITY`

## Goal

Create one selected product-facing Lane-3 authority that serializes pitch/key mutation against coordinator-backed transport/practice DSP work without inventing Playback or click generations, while preserving AW16 continuous-control concurrency and AW18 interruption fail-closed semantics.

## Why this wave was required

AW22 can attribute pitch runtime cost to the real DSP backend, but measurement alone does not make the product route safe. `PracticeDSPProductionController.setPitchSemitones` mutates the same transactional DSP state that tempo uses. A direct pitch call can suspend inside the controller/gate while a tempo or click-related mutation commits, then resume with a stale candidate and overwrite newer state.

Pitch/key is not a transport discontinuity, so solving this by generating a fake Playback token or click generation would be semantically wrong. AW23 instead adds a product-facing shared/exclusive authority:

- transport, seek, loop, tempo, play/pause, media, recovery, metronome and count-in are shared operations;
- pitch/key is an exclusive DSP mutation;
- normal shared operations remain concurrent whenever no pitch is executing, preserving AW16 pre-token coalescing;
- an exclusive pitch waits already-started shared operations to finish, then blocks new shared admission only for the pitch transaction;
- rapid pitch submissions retain at most one pending latest value; older pending values are superseded before backend dispatch;
- interruption begin closes pitch admission before its first await; pending pitch is rejected and an already-dispatched pitch is allowed to settle before the interruption boundary.

## Production source

- `Playback/Sources/Lane3UnifiedPracticeControlAuthority.swift`

The authority is constructed from the exact project-scoped objects selected for the product:

- `ProjectID`
- `Lane3InstrumentedInterruptionGate` (AW19/AW18/AW17 route)
- `Lane3SerializedPracticeClickGate` (AW21/AW20 route)
- `PracticeDSPProductionController`
- `PracticeDSPGenerationCoordinator`
- optional AW22 `Lane3DSPRuntimeTelemetryProbe`

### Pitch invariants

A successful pitch operation must prove after backend readback that:

1. lifecycle phase remains `idle`;
2. lifecycle revision is unchanged;
3. transport recovery was not blocked at admission;
4. coordinator was not poisoned or independently in-flight at admission;
5. coordinator operation serial and active binding are unchanged;
6. click `scheduleGeneration` is unchanged;
7. committed pitch equals the requested semitone value within the production tolerance;
8. no synthetic Playback generation or click generation was consumed.

A structural violation after dispatch fails closed and attempts the existing transport/coordinator recovery route. Backend desynchronization also triggers an automatic recovery attempt.

### Cancellation

- cancellation before backend dispatch returns `cancelledBeforeDispatch` and does not issue DSP mutation;
- cancellation after backend dispatch is recorded in the receipt but cannot pretend an issued DSP transaction was rolled back.

### Interruption

Interruption begin sets `interruptionBlocksPitch = true` before awaiting any lower layer. Pending, not-yet-dispatched pitch is rejected. A backend-dispatched pitch completes under the exclusive barrier, after which the AW21/AW20/AW18 interruption path runs. Pitch admission reopens only after interruption end/retry produces an idle lifecycle with transport recovery not blocked.

## Portable validation

Environment:

- Swift 6.2.1
- Linux x86_64
- strict concurrency: complete
- warnings treated as errors

### Strict-concurrency compile

PASS after removing actor-isolated closure transfer from non-pitch telemetry wrappers. AW23 directly scopes AW22 TaskLocal telemetry only around pitch using Sendable local captures. Existing AW19/AW22 integration remains responsible for other telemetry surfaces.

### Exact-source behavior probe

PASS:

- rapid pitch submissions: `1,000`
- executed: `2`
- superseded before dispatch: `998`
- interruption-time pitch rejection: PASS
- post-interruption pitch reopen: PASS
- final pitch barrier/shared state: clean

Output:

`AW23 exact-source portable PASS executed=2 superseded=998`

### Mixed-operation concurrency stress

PASS:

- total mixed operations: `20,000`
- tempo operations: `10,000`
- pitch operations: `10,000`
- pitch executed: `2`
- pitch superseded before dispatch: `9,998`
- other pitch outcomes: `0`
- observed shared-operation / pitch-backend overlap violations: `0`

Output:

`AW23 STRESS PASS ops=20000 pitchExecuted=2 pitchSuperseded=9998 other=0 overlapViolations=0`

The overlap probe intentionally fails if a shared transport/DSP mutation and the pitch backend mutation are active simultaneously.

### Portable benchmark

20 rounds × 2,000 rapid pitch submissions:

- median: `12.573 ms`
- p95: `16.522 ms`
- max: `16.838 ms`
- checksum: `40270`

This measures portable authority/coalescing overhead only. It excludes AVAudioEngine, AVAudioUnitTimePitch, physical-device scheduling, audio IO, real audio and Moises execution.

## Repository tests authored

- `Playback/Tests/L3_AW23_UnifiedPracticeControlAuthoritySelfTest.swift`
- `Playback/Tests/L3_AW23_UnifiedPracticeControlAuthorityBenchmark.swift`

The full-source self-test covers:

- pitch mutation and exact backend readback;
- click generation preservation;
- invalid semitone rejection;
- rapid latest-wins pitch coalescing;
- tempo/pitch mixed operation sequencing;
- interruption-time pitch rejection and post-end reopen;
- backend desynchronization with automatic recovery attempt;
- AW22 pitch telemetry receipt presence;
- clean final barrier state.

Selected complete Xcode/iOS execution is pending HQ Late Integration.

## Integration contract for HQ

1. Construct exactly one project-scoped `Lane3UnifiedPracticeControlAuthority` from the same AW19 transport gate, AW21 practice gate, controller and coordinator used by the product.
2. Route all Lane-3 product transport/practice controls through AW23 so the shared/exclusive barrier is authoritative.
3. Do not call `PracticeDSPProductionController.setPitchSemitones` directly from App or another adapter.
4. Preserve AW21 as the count-in/interruption route under AW23; do not bypass it.
5. Inject the AW22 telemetry probe into AW23 for pitch runtime telemetry when collecting device evidence.
6. Run repository AW23 self-test/benchmark in the selected complete Xcode/iOS source set.
7. On physical iPhone verify representative negative/positive semitone sweeps, rapid slider changes, tempo→pitch and pitch→tempo ordering, interruption during active pitch, backend recovery, and no click-generation movement attributable solely to pitch.
8. Measure real submission→DSP-entry and backend execution p50/p95/p99 using AW22.
9. Perform rights-cleared real-track listening and current-Moises A/B for latency, pitch stability, warble/phasiness/formant damage and click/pop artifacts.
10. P012 also requires chord-display transpose consistency. That is a cross-lane/HQ integration gate; AW23 does not claim it.

## Non-PARITY boundaries

Not executed in this wave:

- selected Xcode/iOS full-source compile
- AVAudioUnitTimePitch runtime
- physical iPhone
- real audio
- AVAudioSession runtime
- current-Moises differential
- human listening
- chord-display transpose integration

Therefore `MOI-P012` remains `MISSING`, and this evidence cannot promote any PARITY row.
