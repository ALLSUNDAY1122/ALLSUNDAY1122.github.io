# Session B Next5 Evidence — Final UI / UX and Balance Audit

Date: 2026-09-01 JST
Branch: `igtap/wp2-progression-world`
Implementation commit: `91b61a612a5c1e1886b3ad30392217985ffec91f`

## Reference re-check

The current public reference description still centers the systemic loop Session B is targeting: short platform routes earn a resource; upgrades expand movement/production; clones automate recorded routes; later movement capabilities make older routes faster and worth revisiting. Session B preserves those system relationships only.

A current public demo comment also reports poor readability around red lights/jump-pad presentation in the reference's fourth track. Session B treats this as an anti-pattern: Blackout Array keeps critical HUD/objective/checkpoint information at full UI opacity and explicitly forbids color-only state communication.

No reference-game names, art, music, text, exact stage layouts or unpublished formulas are used.

## Final Session B scope

Next1:
- Start/Goal/Timer/Best Time/Checkpoint/Death/Retry/Stage Select and five original stages.

Next2:
- moving platforms, spring requests, hazards, ability gates, state switching, darkness, shortcuts, secrets, original topology/geometry scaffold and prototype assembler.

Next3:
- BigResource Flux economy, active rewards, clone rewards, passive Flux/s, three economic upgrade tracks and resource formatting.

Next4:
- authoritative ability/movement progression, composite stage availability, global clone capacity, save schema v2 and Session A mapping.

Next5:
- final progression tuning and anti-softlock audit;
- global + per-stage clone distribution limits;
- reusable progression HUD model and actual Godot panel;
- explicit UI copy/accessibility catalog;
- Stage Select bound to composite availability;
- semantic original feedback bus for C audio/haptics;
- end-to-end progression audit tests/simulation;
- complete Session B → Session C handoff document.

## Final required progression balance

Conservative model: one global clone slot is moved to the newest cleared stage; no economic-upgrade assistance is assumed.

Required ability waits:

- Drive Tuning / speed_tune: 23.81 s
- Vector Burst / dash: 33.06 s
- Air Relay / double_jump: 37.27 s
- Surface Rebound / wall_jump: 54.80 s
- Phase Override / phase_shift: 60.29 s

Maximum mandatory wait: **60.29 s**, below the 90 s target and far below the 180 s failure threshold.

## Active-only anti-softlock path

Clone/replay automation is never mandatory for progression.

If replay payloads are absent and passive income is therefore zero, repeatedly clearing only the current stage can afford each mandatory gate within at most **two clears**.

Final active-only clear counts:

- Relay Yard → Drive Tuning: 2 clears
- Liftworks → Vector Burst: 2 clears
- Phase Foundry → Air Relay: 2 clears
- Blackout Array → Surface Rebound: 2 clears
- Core Spire → Phase Override: 2 clears

This prevents replay/integration failure from becoming an economy softlock.

## Clone distribution / old-stage relevance

A purely global linear clone cap made the mathematically optimal strategy concentrate all clones on the highest-RPS newest course, undermining the design goal that old courses remain meaningful.

Final rule:

- global clone capacity: 1 → 15;
- per-stage clone cap: 3;
- Echo Capacity adds +1 global slot per level, 14 levels;
- at maximum capacity all five stages can hold exactly 3 clones.

Final target-route allocation audit reaches:

- Relay Yard: 3
- Liftworks: 3
- Phase Foundry: 3
- Blackout Array: 3
- Core Spire: 3

Final combined target-route production: approximately **43.323 Flux/s** before later multipliers.

## Optional capacity wait audit

Initial Next5 tuning used Echo Capacity growth ×1.58. Endgame single-slot waits expanded to roughly 285 s, violating the project guardrail.

Final curve:

- base cost: 32 Flux
- growth: ×1.44
- max level: 14

Greedy end-to-end capacity-fill simulation produces a maximum single capacity-purchase wait of **85.38 s**, below the 90 s optional-upgrade target.

## UI / UX delivered

`Content/UI/ui_catalog_v1.json`
- original names/descriptions for all ten purchasable tracks;
- explicit KEY progression marker;
- human-readable lock reasons;
- 48-unit minimum touch target;
- no color-only state communication.

`Game/UI/ProgressionHUDModel.gd`
- exact formatted Flux balance and Flux/s;
- current stage/timer/best;
- explicit next-objective sentence;
- global/per-stage clone allocation;
- Stage cards and Upgrade cards with state/effect/cost data.

`Game/UI/ProgressionPanel.gd`
- reusable vertical-scroll Godot panel;
- Stage READY/CLEARED/MASTERED/LOCKED text;
- explicit lock reason;
- Best + mastery target;
- clone minus/count/plus allocation controls;
- upgrade buttons showing level, cost, current→next effect and status.

`Game/UI/StageSelectModel.gd`
- now consumes aggregate/composite stage availability rather than raw StageManager availability.

`Game/Audio/FeedbackBus.gd`
- semantic original feedback requests for upgrade purchase, ability unlock, clone capacity and stage unlock; Session C may map these to original audio/haptics.

## Failures found and fixed in Next5

1. **Wrong global-clone balance assumption** — an earlier simulation implicitly added one clone per newly cleared stage despite base global capacity 1. Final required-progression simulation uses one global clone moved to the newest stage.
2. **Newest-stage clone concentration** — global linear capacity alone made old stages economically dominated. Added per-stage cap 3 and expanded total max capacity to 15.
3. **Excessive late capacity waits** — ×1.58 Echo Capacity growth produced ~285 s late waits. Reduced to ×1.44; final maximum is 85.38 s.
4. **Borderline final ability wait** — Phase Override at 1500 Flux left insufficient balance margin. Tuned to 1300 Flux; conservative final mandatory maximum becomes 60.29 s.
5. **Optional-upgrade distraction before first key gate** — Jump Tuning/Echo Capacity could compete with the first mandatory Drive Tuning purchase. They now require Drive Tuning first.
6. **Replay softlock risk** — confirmed an active-only path exists; every required gate takes at most two clears without clone income.
7. **UI progression ambiguity** — replaced raw numeric/mock expectations with explicit objective, lock reason, key-upgrade labels and current→next effects.
8. **Darkness readability risk** — UI spec requires critical HUD/checkpoint/objective readability independent of world darkness and never communicates state by color alone.
9. **Raw stage-selection inconsistency** — StageSelectModel now respects composite `ProgressionWorld.is_stage_available()` so raw stage unlock cannot bypass a missing ability.

## Final automated/static audit coverage

Repository tests now cover:

- mandatory ability/entry chain;
- backward revisit use for each core ability;
- Session A mapping integrity;
- direct-unlock level consistency;
- aggregate save migration;
- global and per-stage clone caps;
- first-record auto-clone capacity safety;
- one-global-clone mandatory waits;
- active-only anti-softlock fallback;
- optional-capacity wait ceiling;
- no mandatory secrets;
- non-noop upgrade effects;
- UI catalog completeness;
- explicit lock copy and mobile touch guardrail;
- final ability wait margin.

In-session deterministic assertions/simulations passed with final values:

- required maximum wait: 60.29 s
- active-only maximum clears per mandatory gate: 2
- Echo Capacity maximum single wait: 85.38 s
- final clone allocation: 3 / 3 / 3 / 3 / 3
- final target-route Flux/s: 43.323

## Validation limitations

- Godot is not installed in Session B's execution environment, so GDScript parser/runtime and interactive physics/UI playtesting could not be launched here.
- Direct repository checkout continues to fail in the execution container because `github.com` DNS resolution is unavailable. GitHub connector reads/writes are authoritative; equivalent deterministic data/source assertions were executed in-session.
- Final iPhone Safe Area, touch-control collision and actual visual readability must be verified by Session C on the production Godot/iOS build.

## Session C handoff

Detailed instructions are stored in `Content/Integration/SESSION_B_HANDOFF.md`.

Critical integration items:

1. Replace current MockProgression with `Game/Progression/ProgressionWorld.gd`.
2. Preserve exact BigResource snapshots internally; current float currency signals are compatibility-only.
3. Map B `dash` / `double_jump` / `wall_jump` to A `dash` / `airJump` / `wallJump`.
4. Add a C→A numeric movement configuration bridge for run/jump multipliers; do not treat Speed Tune or Jump Tune as PlayerAbility enum values.
5. Keep `phase_shift` world-only.
6. Reconcile B desired clone allocations with A actual replay clone instances.
7. Define an explicit spring/impulse integration contract; Session A currently exposes no generic impulse command.
8. Calibrate the provisional B geometry scale (currently 64 px/world-unit scaffold) against Session A abstract units.
9. Bind the reusable B progression UI inside Session C's iOS Safe Area/pause drawer.
10. Persist/restore aggregate `ProgressionWorld.serialize_state()` through C Platform/Save.

## Unresolved architectural risk

Session A remains a Swift/framework-light gameplay core while Session C remains a Godot/GDScript integration shell. Session B has kept its contracts adapter-based and has not modified either owner's files, but Session C must resolve this runtime boundary before TestFlight.

No Session A-owned or Session C-owned file was modified by Session B.

**Session B is ready for Session C integration.**
