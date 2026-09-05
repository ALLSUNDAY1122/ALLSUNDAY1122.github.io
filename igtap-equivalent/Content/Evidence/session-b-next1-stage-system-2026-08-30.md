# Session B Next1 Evidence — Stage System

Date: 2026-08-30 JST
Branch: `igtap/wp2-progression-world`
Implementation head before evidence commit: `25b51cd8d1b9e6638acd91e6c135337b7de65965`

## Scope completed

- Five-stage original progression catalog.
- Stage selection and availability state.
- Start / goal / timer run state.
- Best-time persistence semantics.
- Checkpoint activation and retry target selection.
- Death tracking without accidental unlocks.
- Manual restart resets timer/checkpoint/death count and creates a new attempt.
- Death retry remains in the same attempt and preserves elapsed time.
- Stage clear unlocks exactly the next stage.
- Explicit `unlock_stage` / `is_stage_available` surface.
- Serialization surface for stage progress.
- Area2D start/goal/checkpoint trigger components.
- Attempt identity and exactly-once completion guard.
- Godot-facing Session B public contract at `Content/Contracts/SESSION_B_PUBLIC_CONTRACT.md`.

## Timer authority

Session A's lap timer remains authoritative when `register_lap(stage_id, elapsed_seconds, replay_payload)` is used. Session B's physics-delta timer exists for HUD/fallback state only. This avoids two clocks competing during integration.

## Retry policy

Death retries at the most recent enabled checkpoint and does not reset elapsed time. A deliberate stage restart resets elapsed time and checkpoint state and starts a new `attempt_id`. Checkpoint order is monotonic: backtracking cannot replace a later retry anchor with an earlier checkpoint.

## Validation

Local logic suite:
- `python3 -m pytest Tests/Progression/test_stage_system.py -q`
- result: `8 passed`

Balance simulation:
- `python3 Tests/Progression/stage_balance_sim.py`
- target mastery reduction: ~64–67% versus first clear.
- challenge segments per recovery interval: 2.33–3.60.
- all five mandatory stages are reachable by the sequential clear chain.

Runtime note: the current execution environment does not contain a Godot executable, so this pass validates data/progression behavior and performs static implementation review rather than launching an interactive Godot scene. Session C's integration branch remains the runtime project owner.

## Failures found and fixed during Next1

1. Backtracking could downgrade the active checkpoint. Fixed by monotonic checkpoint order acceptance.
2. A zero-second external lap could become a best time. Fixed by rejecting non-positive lap/completion times.
3. Retry initially used the start trigger ID as a spawn anchor. Fixed by adding distinct `start_spawn_anchor` data.
4. Stage selection could switch the selected context during another active run. Fixed by rejecting cross-stage selection while a run is active.
5. Duplicate lap delivery could create a second completion after a finished run. Fixed with `attempt_id`, finished-attempt rejection, and public signal signatures that include attempt/checkpoint metadata.
6. Bootstrap contract was written under the provisional `igtap-equivalence/` root while Session C established `igtap-equivalent/`. A current Godot contract is now published under the integration project root; old bootstrap artifacts remain historical only.

## Original balance targets

First clear: 24 / 34 / 46 / 62 / 82 seconds.
Mastery: 8 / 12 / 16 / 22 / 29 seconds.
Checkpoint count: 2 / 3 / 3 / 4 / 4.

These are original tuning targets, not claims about reference-game exact values.

## Public API changes in Next1

Added stage subsystem methods:
- `select_stage`
- `begin_stage`
- `restart_stage`
- `register_checkpoint`
- `register_death`
- `register_lap`
- `complete_goal`
- `unlock_stage`
- `is_stage_available`
- `stage_select_entries`
- `current_stage_context`
- `best_time`
- `serialize_stage_state`
- `restore_stage_state`

Added signals:
- `stage_started(stage_id, attempt_id)`
- `stage_completed(stage_id, elapsed_seconds, is_new_best, checkpoint_count)`
- `stage_availability_changed(stage_id, available)`
- `checkpoint_changed(stage_id, checkpoint_id)`
- `retry_requested(stage_id, retry_target, reason)`
- `stage_context_changed(stage_context)`

## Integration note

Session C currently targets Godot 4/GDScript under `igtap-equivalent/`. Session A currently documents a Swift implementation direction. Session B follows Session C's final integration target and exposes dictionary/signal boundaries that can be adapted to Session A's contract without writing Session A-owned files.
