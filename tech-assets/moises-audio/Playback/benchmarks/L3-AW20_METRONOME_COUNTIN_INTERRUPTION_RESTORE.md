# L3-AW20｜Metronome / Count-in Interruption Restore

Result: `COMPLETE_NON_PARITY`

## Goal

Prevent an AVAudioSession interruption from reviving a stale metronome/count-in schedule after AW18 resumes transport. Preserve metronome user intent, but require a fresh post-interruption render origin/common-host anchor. Treat count-in as one-shot: a count-in armed before an interruption is never automatically restored.

## Production implementation

Added `Playback/Sources/Lane3PracticeInterruptionClickGate.swift`.

The selected click lifecycle route is layered on the existing AW19 instrumented interruption facade and the production `PracticeDSPGenerationCoordinator`.

Key behavior:

- `scheduleCountIn` is accepted only while AW18 lifecycle phase is `idle`.
- A successful count-in arm creates a local authorization tied to the current AW18 lifecycle revision and the click generation returned by the production coordinator.
- `submitInterruptionBegan` revokes that authorization **before** awaiting the transport boundary, so actor reentrancy cannot let the old one-shot authorization survive while AW18 is suspended.
- Pre-interruption count-in is never automatically restored. `countInAutoRestoreAllowed` is always false.
- The raw controller can still contain `pendingCountInClicks`; selected product planning quarantines that raw value and requires an AW20 authorization. Direct use of `PracticeDSPClickExecutionPlanner.countIn(state:)` from App/HQ would bypass the quarantine and is forbidden on the selected route.
- A later explicit `scheduleCountIn` overwrites the raw pending value, advances click generation through the existing coordinator, and creates a new current-lifecycle authorization.
- `markCountInScheduleCommitted` clears the local authorization only after the Apple click executor has accepted the replacement schedule, preventing duplicate one-shot scheduling through the selected route.
- Metronome enable/disable is allowed while lifecycle is `active`; transition phases (`beginning`, `ending`, `resuming`) reject click-only mutation so it does not intentionally race a lifecycle boundary.
- Interruption end produces a metronome restore authorization only when:
  - AW18 boundary is safe,
  - end does not require recovery,
  - end completion was not superseded by a newer lifecycle event,
  - playback actually resumed,
  - AW18 snapshot is now `idle` at the same episode/revision,
  - coordinator is not poisoned,
  - metronome remains enabled.
- `makeMetronomeRestorePlan` revalidates the same lifecycle episode/revision and exact click generation immediately before planning.
- A newer interruption or any later click-generation mutation makes the old metronome restore authorization stale.
- Restore authorization explicitly requires a **fresh render origin** and **fresh common host anchor**. AW20 does not reuse pre-interruption AVAudioTime anchors.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, interface-compatible Lane-3 contracts.

Exact AW20 gate source was typechecked in a self-contained harness.

Deterministic behavior probe: PASS.

Covered:

1. Metronome enabled + count-in armed before interruption.
2. Count-in plan valid before interruption.
3. Interruption begin revokes selected-route count-in authorization immediately.
4. Raw pending count-in remains observable but old selected-route plan is rejected.
5. `shouldResume=true` produces metronome restore authorization when metronome remains enabled.
6. Restore plan uses the post-interruption click generation and a caller-supplied fresh render origin.
7. New interruption makes the previous metronome restore authorization stale.
8. `shouldResume=false` produces no metronome restore authorization.
9. Re-armed post-interruption count-in can plan once; commit clears authorization and duplicate planning is rejected.
10. Metronome generation change after an end invalidates the previously issued restore authorization.
11. Count-in scheduling racing an interruption does not leave a current authorization.
12. Metronome disabled during active interruption -> no restore; enabled during active interruption -> restore allowed when transport resumes.

Portable deterministic console evidence:

`AW20 portable click interruption PASS gen=5 phase=active`

`AW20 active-toggle PASS`

## Stress

50,000 interruption cycles:

- count-in authorizations revoked at interruption begin: `50,000`
- old count-in plan attempts rejected: `50,000`
- automatic count-in restores: `0`
- metronome restores when the synthetic `shouldResume` policy allowed them: `33,333`
- final selected-route count-in authorization: none
- final lifecycle phase: `idle`
- checksum: `833383333`

Console:

`AW20 stress PASS cycles=50000 revoked=50000 countInAutoRestore=0 staleRejected=50000 metronomeRestore=33333 checksum=833383333`

## Portable benchmark

20 rounds x 2,000 cycles. Each cycle performs count-in arm -> interruption begin -> interruption end/resume -> metronome restore plan validation.

- median: `128.041 ms / 2,000 cycles`
- p95: `154.978 ms`
- max: `170.651 ms`
- checksum: `40440000`

Scope: exact AW20 lifecycle/authorization logic over lightweight interface-compatible transport/coordinator/planner types. Excludes AVAudioEngine, AVAudioSession delivery, Apple click node scheduling, real DSP/backend cost, device/file I/O, real audio and current-Moises execution.

## Repository validation authored

- `Playback/Tests/L3_AW20_PracticeInterruptionClickSelfTest.swift`
- `Playback/Tests/L3_AW20_PracticeInterruptionClickBenchmark.swift`

These use the actual repository Lane-3 production types and are authored for the selected integrated Xcode/iPhone source set. They are **not reported as executed** in this Worker environment.

## HQ Late Integration requirements

1. Keep `Lane3InstrumentedInterruptionGate` as the product transport/interruption telemetry surface from AW19.
2. Construct one project-scoped `Lane3PracticeInterruptionClickGate` with that exact AW19 facade and the exact production `PracticeDSPGenerationCoordinator` used by AW17/AW18.
3. Route AVAudioSession interruption begin/end/retry through AW20, not directly through AW19/AW18, so count-in authorization revocation and metronome restore authorization are always applied.
4. Route product metronome and count-in controls through AW20.
5. Do not call raw `PracticeDSPClickExecutionPlanner.countIn(state:)` from App/HQ. Raw `pendingCountInClicks` is not sufficient authorization after an interruption.
6. After count-in replacement is accepted by the Apple click executor, call `markCountInScheduleCommitted`; do not schedule the same authorization twice.
7. For metronome restore, obtain a fresh post-interruption render origin/common-host anchor, call `makeMetronomeRestorePlan`, then schedule through the selected Apple click executor. Never reuse the old AVAudioTime anchor.
8. If a newer interruption or click mutation occurs between authorization and scheduling, regenerate/re-evaluate rather than bypassing the stale rejection.
9. Execute the repository self-test/benchmark on the selected Xcode/iOS source set.
10. On physical iPhone, capture phone/Siri/route interruption behavior and verify no stale click, doubled count-in, early click, late click, click/pop or beat-phase discontinuity before P014/P015 promotion.

## Remaining gate

This Wave does not prove audible or device parity. P014/P015 remain MISSING until selected Xcode/iPhone execution, actual AVAudioSession interruption delivery, common-host anchor integration, real-audio timing evidence and current-Moises differential/listening are complete.
