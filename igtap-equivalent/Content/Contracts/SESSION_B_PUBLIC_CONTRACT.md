# Session B Public Contract

Project root: `igtap-equivalent/`  
Owner: Session B / Progression + World  
Target: Godot 4.x / GDScript  
Primary integration root: `Game/Progression/ProgressionWorld.gd`

Session B never mutates Session A Player/Physics/Abilities/Replay/Ghost internals. Player-affecting world events and movement-effect changes cross the Session C adapter boundary.

## Aggregate production root

`ProgressionWorld` is the Session C binding target.

Session C-compatible signals:

- `stage_context_changed(context: Dictionary)`
- `currency_changed(total: float)` — compatibility projection only.
- `upgrade_purchased(upgrade_id: StringName, level: int)`
- `ability_unlocked(ability_id: StringName)`
- `clone_income_applied(stage_id: StringName, amount: float)` — compatibility projection only.

Additional precision/progression signals:

- `stage_availability_changed(stage_id, availability)`
- `economy_changed(total, delta, source)`
- `economy_rate_changed(rate)`
- `upgrade_purchase_committed(upgrade_id, level, paid_cost)`
- `movement_effects_changed(effects)`
- `clone_capacity_changed(capacity)`

Core state surface:

- `register_lap(stage_id, elapsed_seconds, replay_payload = {})`
- `register_death(stage_id, reason)`
- `current_stage_context()`
- `serialize_state()` / `restore_state(state)`
- `stage_select_entries()`
- `stage_availability(stage_id)` / `is_stage_available(stage_id)`
- `select_stage(stage_id)` / `begin_stage(stage_id = &"")`

## Stage lifecycle — Next1

`StageManager` owns attempts, checkpoints, best times, raw sequential stage unlocks and retry state. Manual restart creates a new attempt; death retry preserves attempt/time; duplicate/non-positive completions are rejected.

UI/integration must use `ProgressionWorld.stage_availability`, not raw `StageManager.is_stage_available`, because a raw-unlocked stage can still require a purchased ability.

## World / gimmicks — Next2

`WorldState` owns phase, visibility, discoveries and declared ability gates. `GimmickRuntime` re-emits spring/hazard requests; Session B never writes player velocity or invokes Session A death methods.

World topology is `Content/World/world_topology_v1.json`. Secrets are optional. Every core movement/world unlock creates revisit value in earlier content.

## Economy — Next3

Authoritative resource snapshots are `{mantissa: float, exponent: int}` representing `mantissa × 1000^exponent`. UI suffixes are presentation only.

Public operations:

- `add_resource`
- `spend_resource`
- `current_resource`
- `resource_per_second`
- `calculate_clone_reward`
- `economy_snapshot`

Active and clone rewards use bounded speed/quality factors. Passive economy ticks at 0.25 s. Slower recordings cannot degrade a better automated route.

Economic tracks:

- `flux_coils` → passive income multiplier
- `loop_compression` → clone reward multiplier
- `route_dividend` → active lap reward multiplier

## Progression / abilities — Next4

Authoritative subsystem: `Game/Progression/ProgressionSystem.gd` with data in `Content/Progression/progression_v1.json`.

Public operations through `ProgressionWorld`:

- `unlock_ability`
- `is_ability_unlocked`
- `get_unlocked_abilities`
- `movement_effects`
- `session_a_ability_mapping`
- `clone_capacity`
- `stage_clone_cap`
- `set_clone_count`
- `clone_allocation_snapshot`
- `progression_snapshot`

Unified `purchase/current_level/current_cost/resulting_effect/upgrade_availability` routes economic and progression upgrade IDs.

Mandatory progression:

1. clear `relay_yard` → buy `speed_tune` → `liftworks`
2. clear `liftworks` → buy `dash` → `phase_foundry`
3. clear `phase_foundry` → buy `double_jump` → `blackout_array`
4. clear `blackout_array` → buy `wall_jump` → `core_spire`
5. clear `core_spire` → buy `phase_shift` → endgame revisit/mastery

Optional progression:

- higher `speed_tune` levels → run-speed multiplier
- `jump_tune` → jump multiplier
- `clone_capacity` → +1 global clone slot/level

`jump_tune` and `clone_capacity` require `speed_tune` first, preventing optional spending from obscuring the first mandatory gate.

### Session A mapping

- `dash` → Session A `dash`
- `double_jump` → Session A `airJump`
- `wall_jump` → Session A `wallJump`
- `speed_tune` → numeric `run_speed_multiplier`, not a PlayerAbility enum
- `jump_tune` → numeric `jump_multiplier`, not a PlayerAbility enum
- `phase_shift` → world-only

Session C must adapt numeric movement effects through an explicit configuration bridge. Session B does not edit Session A config directly.

### Composite stage availability

`ProgressionWorld.stage_availability(stage_id)` combines:

1. raw previous-stage clear/unlock; and
2. `WorldState.entry_required_ability` against ProgressionSystem ability state.

Explicit reasons include `unknown_stage`, `requires_previous_clear`, and `requires_ability`.

### Clone allocation — finalized Next5

Clone allocation uses two simultaneous caps:

- global capacity: base 1, up to 15 through Echo Capacity;
- per-stage capacity: 3.

`set_clone_count(stage_id, count)` rejects either cap violation. New valid recordings auto-use one slot only when global capacity remains. At maximum capacity all five stages can hold three clones, preventing a dominant newest-stage-only allocation from making old routes economically irrelevant.

## UI / UX — Next5

Reusable Session B UI surfaces:

- `Game/UI/ProgressionHUDModel.gd`
- `Game/UI/ProgressionPanel.gd`
- `Game/UI/StageSelectModel.gd`
- `Content/UI/ui_catalog_v1.json`

HUD model exposes formatted balance/rate, current stage/timer/best, explicit next objective, clone allocation, stage cards and upgrade cards.

Stage cards expose READY/CLEARED/MASTERED/LOCKED text, locked reason, best/mastery times and clone allocation. Upgrade cards expose cost, current→next effect, KEY progression marker, description and explicit status.

Session C owns final safe-area placement. Session B's panel uses vertical scrolling and minimum 48-unit interactive heights so it can be placed as a landscape-iPhone pause/menu drawer without colliding with movement controls.

## Feedback — Next5

`Game/Audio/FeedbackBus.gd` emits semantic original feedback requests only:

- `upgrade_purchase`
- `ability_unlock`
- `clone_capacity`
- `stage_unlocked`

Session C may map these to original audio and haptics. No reference audio is included.

## Save contract

Aggregate save schema is version 2 and contains stage, world, economy, economic upgrades and progression. Version-1 aggregate saves remain readable; absent progression state restores to default locked progression.

## Stable original IDs

Stages: `relay_yard`, `liftworks`, `phase_foundry`, `blackout_array`, `core_spire`.

Abilities: `speed_tune`, `dash`, `double_jump`, `wall_jump`, `phase_shift`.

Optional progression IDs include `jump_tune` and `clone_capacity`.

All IDs, presentation, economy constants and world layouts are project-original. No reference-game stage geometry, text, art, audio or exact unpublished numeric formula is represented as canonical.
