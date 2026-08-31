# Session B Public Contract

Project root: `igtap-equivalent/`
Owner: Session B / Progression + World
Target: Godot 4.x / GDScript
Consumers: Session C integration and Session A gameplay signals through adapters.

Session B never mutates Session A Player/Physics/Abilities/Replay/Ghost internals.

## Stage lifecycle — implemented in Next1

Production stage manager surface:

- `select_stage(stage_id: StringName) -> bool`
- `begin_stage(stage_id: StringName = &"") -> bool`
- `restart_stage() -> bool`
- `register_checkpoint(stage_id, checkpoint_id) -> bool`
- `register_death(stage_id, reason) -> Dictionary`
- `register_lap(stage_id, elapsed_seconds, replay_payload = {}) -> Dictionary`
- `complete_goal() -> Dictionary`
- `unlock_stage(stage_id) -> bool`
- `is_stage_available(stage_id) -> bool`
- `stage_select_entries() -> Array[Dictionary]`
- `current_stage_context() -> Dictionary`
- `best_time(stage_id) -> float`
- `serialize_stage_state() -> Dictionary`
- `restore_stage_state(state) -> bool`

Stage signals:

- `stage_started(stage_id, attempt_id)`
- `stage_completed(stage_id, elapsed_seconds, is_new_best, checkpoint_count)`
- `stage_availability_changed(stage_id, available)`
- `checkpoint_changed(stage_id, checkpoint_id)`
- `retry_requested(stage_id, retry_target, reason)`
- `stage_context_changed(stage_context)`

Rules:

- Each manual begin/restart creates a new monotonically increasing `attempt_id`.
- Death/checkpoint retry stays in the same attempt and does not reset elapsed time.
- Manual restart resets elapsed time and reached checkpoints.
- Backtracking cannot downgrade the active checkpoint.
- Non-positive external lap times are rejected.
- A duplicate lap for an already-finished attempt is rejected.
- Best time is the minimum positive completed time.
- Clearing a stage unlocks the next mandatory stage; explicit `unlock_stage` is idempotent.
- Session A lap timing is authoritative when supplied through `register_lap`; Session B's physics-delta timer is HUD/fallback state only.

## World / gimmicks — implemented in Next2

`WorldState` is the authoritative Session B world-state surface. Session C may bind its signals to rendering, Session A commands, and save services.

Methods:

- `set_unlocked_abilities(ability_ids)` — accepts only known progression IDs; no Session A internal mutation.
- `enter_stage(stage_id) -> bool` — resets runtime phase/visibility and rejects entry when the declared mandatory ability is absent.
- `set_phase(stage_id, phase) -> bool`
- `set_visibility(stage_id, visibility_scale) -> bool`
- `reset_visibility(stage_id) -> bool` — restores the stage-specific baseline, not a hard-coded fully-lit value.
- `discover_secret(stage_id, secret_id) -> bool` — idempotent persistent discovery.
- `discover_shortcut(stage_id, shortcut_id) -> bool` — idempotent persistent discovery.
- `can_traverse(stage_id, edge) -> bool` — evaluates declared ability/phase requirements only.
- `is_ability_unlocked(ability_id) -> bool`
- `world_context(stage_id = &"") -> Dictionary`
- `serialize_world_state() -> Dictionary`
- `restore_world_state(state) -> bool`

Signals:

- `phase_changed(stage_id, phase)`
- `secret_discovered(stage_id, secret_id)`
- `shortcut_discovered(stage_id, shortcut_id)`
- `visibility_changed(stage_id, visibility_scale)`
- `world_state_changed(context)`

`GimmickRuntime` is the Session B runtime binder. It consumes world-state signals, updates state/ability gates, validates discoveries through `WorldState`, and re-emits only the two player-affecting requests that must cross ownership boundaries:

- `spring_launch_requested(body, launch_velocity, spring_id)`
- `hazard_contact(body, hazard_id, reason)`

Session C maps those to Session A commands. Session B does not directly assign player velocity or call player death methods.

Gimmick component rules:

- `MovingPlatform` owns only its world-body path motion.
- `SpringPad` emits `launch_requested(body, launch_velocity, spring_id)`; Session A/C applies the player impulse.
- `HazardZone` emits `hazard_contact(body, hazard_id, reason)`; Session A/C owns death handling.
- `AbilityGate` opens/closes Session B world collision from an ability-ID list; it does not unlock or implement the ability.
- `StateSwitch` emits a phase request; `StateGate` consumes the resulting phase.
- `VisibilityZone` emits a reduced-visibility request on entry and a baseline-restore request on exit.
- `DiscoveryZone` reports `secret` or `shortcut` discovery; `WorldState` validates and persists it.

World topology data is `Content/World/world_topology_v1.json`. It defines abstract connectivity and requirements, not copied reference-game geometry. Secrets are never mandatory for main progression. Later abilities must create shorter revisit routes.

## Session C adapter compatibility

Session C's current world adapter expects:

- signal `stage_context_changed(stage_context)`
- method `register_lap(stage_id, elapsed_seconds, replay_payload)`
- method `current_stage_context()`

Next3/Next4 will provide the aggregate ProgressionWorld production root that composes `StageManager` + `WorldState` + `GimmickRuntime` and also exposes currency, upgrades and abilities. These remain subsystems behind that root.

## Economy — contract reserved for Next3

Required operations:

- `add_resource(amount, source)`
- `spend_resource(amount, reason) -> Bool`
- `current_resource()`
- `resource_per_second()`
- `calculate_clone_reward(stage_id, best_time, clone_profile)`

Required signal:

- `economy_changed(new_balance, delta, source)`

Large-number storage must be independent of display suffix formatting.

## Progression / ability unlock — contract reserved for Next4

Required operations:

- `unlock_ability(ability_id)`
- `is_ability_unlocked(ability_id) -> Bool`
- `unlock_stage(stage_id)`
- `is_stage_available(stage_id) -> Bool`

Required signal:

- `ability_unlocked(ability_id)`

Session B owns unlock state; Session A owns actual movement behavior.

## Upgrade — contract reserved for Next3/Next4

Required operations:

- `purchase(upgrade_id)`
- `current_level(upgrade_id)`
- `current_cost(upgrade_id)`
- `resulting_effect(upgrade_id)`

Required signal:

- `upgrade_purchased(upgrade_id, new_level, paid_cost)`

## Stable original IDs

Stages:

- `relay_yard`
- `liftworks`
- `phase_foundry`
- `blackout_array`
- `core_spire`

Provisional ability IDs:

- `speed_tune`
- `dash`
- `double_jump`
- `wall_jump`
- `phase_shift`

These IDs and all presentation are original project content; no reference-game stage layout, names, art, text or audio are copied.
