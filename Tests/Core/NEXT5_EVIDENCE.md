# Session A / Next 5 Evidence — Final Core Audit

Date: 2026-09-01 JST
Branch: `igtap/wp1-core-gameplay`
Scope: Session A ownership only.

## Final status

- Core Gameplay standalone implementation: complete for Session A scope.
- Public Player/Checkpoint/Lap/Replay/Clone/Camera contracts: integration-ready.
- Known major Session A gameplay defects: none after this audit.
- Session B/C-owned files changed: none.

## Defects found and fixed in Next 5

### 1. Ground dash leaving a ledge could lose its late-jump window

A ground dash could leave the floor early, then normal coyote time could expire before the configured dash duration. A late dash-jump was therefore lost even though the speed-tech window should remain valid.

Fix: a ground-origin dash now owns `groundDashJumpRemaining` for its dash duration. Leaving a ledge does not delete that eligibility. The state is cleared on jump resolution, airborne wall impact, death, respawn, or dash disable.

### 2. Same-tick dash + jump could collapse into an ordinary jump

At 60 Hz presentation, separate human button events may be delivered into the same 120 Hz simulation tick. The previous priority rule let jump consume the dash request, making the intended dash-jump technique frame-grouping dependent.

Fix: after valid wall-jump priority, simultaneous eligible ground dash+jump resolves as one combined action with dash horizontal speed plus jump lift. Existing jump during an already-active ground dash remains supported.

### 3. `lapCompleted` was declared but lacked a concrete producer

Fix: added `FixedTickLapTimer`, which begins/finishes/cancels laps using simulation ticks and emits `.lapCompleted` exactly once on a valid finish.

### 4. Replay could accept a missing fixed tick

A recording with frames 100, 101, 103 was previously structurally valid. Clone playback would then advance 101 -> 103 in one playback tick, silently compressing time.

Fix: Replay V1 requires contiguous ticks. A live capture gap invalidates the full recording; `stopRecording()` returns nil and emits no completion signal. Loaded/constructed recordings reject tick gaps with `nonContiguousTicks`.

### 5. Replay marker tick/frame inconsistency was not rejected

Fix: a marker's stored tick must now equal the tick of its referenced frame or validation fails with `markerTickMismatch`.

## Final verification

Compiler/runtime: Swift 6.2.1 on Linux.

### Next 5 integrated audit

Result:

`PASS: 24 Next5 integration-ready audit groups`

Coverage includes:

1. baseline movement + variable jump;
2. coyote + jump buffer;
3. same-tick ground dash-jump;
4. ground dash off ledge late-jump window;
5. wall-jump priority over dash;
6. air resources + ability disable cleanup;
7. neutral dash facing direction;
8. death/checkpoint/respawn + signal correctness;
9. checkpoint clear fallback;
10. 100 repeated death/respawn cycles;
11. high-speed horizontal/vertical collision + depenetration;
12. 10-minute fixed-clock 60/120 Hz equivalence + stall clamp;
13. integrated Player + Camera + Replay 60/120 Hz exact state equality;
14. camera dead-zone + snap;
15. fixed-tick lap completion/cancel/duplicate-begin handling;
16. Replay contiguous-tick validation and live gap invalidation;
17. recordingCompleted/best-run/clear behavior;
18. Replay marker ordering and future-marker discard;
19. Clone loop/non-loop/marker behavior;
20. 200,000-tick single Clone and 64 Clones x 20,000 ticks stress;
21. actual Player Replay across checkpoint/death/recovery;
22. Replay input clamping;
23. all 32 combinations of the five abilities, each simulated twice for 600 ticks with exact deterministic equality and disabled-resource leak checks;
24. malformed marker tick/frame mismatch rejection.

### Build modes

- Normal warnings-as-errors: PASS.
- Swift 6 production module with `-strict-concurrency=complete -warnings-as-errors`: PASS.
- Optimized `-O` audit test binary: PASS.
- AddressSanitizer audit run: PASS; no sanitizer failure observed.

### Prior regression

The original Next 1 six-group suite was rerun against the final candidate under its original compiler mode:

`PASS: 6 Core Gameplay test groups`

Next 2/3/4 had already passed 18/22/24 groups at their milestone commits. The Next 5 suite deliberately re-covers their critical movement, fixed-step, collision, camera, death/respawn, Replay and Clone behavior plus new cross-system combinations.

## Stress / determinism evidence

- Fixed clock: 10 minutes of simulated time at both 60 Hz and 120 Hz display delivery resolves to identical authoritative tick/state results.
- Ability matrix: 32/32 combinations deterministic across duplicate runs.
- Clone: one Clone 200,000 ticks without state drift.
- Multi-Clone: 64 simultaneous Clones for 20,000 ticks with authoritative frame-state equality.
- Death/respawn: 100 repeated cycles without stale movement/ability-state leakage.

## Public API changes in Next 5

Additive:

- `LapTiming`
- `FixedTickLapTimer`
- explicit public initializers for `LapEvent` and `RecordingEvent`
- Replay validation cases `nonContiguousTicks` and `markerTickMismatch`

No required Player or Replay command was removed or renamed.

## Remaining non-Core integration work

- Session C owns native/Godot/iOS adapter wiring, build, signing and TestFlight.
- Session C owns Replay persistence/serialization if desired.
- Replay V1 is uncompressed 120 Hz authoritative sampling.
- Exact movement constants remain empirically tuned because the reference game does not publish its numeric physics constants.
- Real-device input latency/frame pacing must be validated by Session C on iPhone.

The current integration shell and Session A Core use different runtime layers (Godot/GDScript shell versus Swift Core). Session C must implement a deliberate native bridge or contract-faithful runtime port before release. This is the main remaining integration risk and is outside Session A file ownership.
