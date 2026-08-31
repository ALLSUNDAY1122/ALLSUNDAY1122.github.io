# Session B Public Contract

Project root: `igtap-equivalent/`  
Owner: Session B / Progression + World  
Target: Godot 4.x / GDScript  
Primary integration root: `Game/Progression/ProgressionWorld.gd`

Session B never mutates Session A Player/Physics/Abilities/Replay/Ghost internals. Player-affecting world events cross the Session C adapter boundary.

## Aggregate production root

`ProgressionWorld` is the Session C binding target from Next3 onward.

Session C-compatible signals:

- `stage_context_changed(context: Dictionary)`
- `currency_changed(total: float)` — compatibility projection only; precision may be clamped at extreme magnitudes.
- `upgrade_purchased(upgrade_id: StringName, level: int)`
- `ability_unlocked(ability_id: StringName)` — reserved; authoritative unlock flow is completed in Next4.
- `clone_income_applied(stage_id: StringName, amount: float)` — compatibility projection only.

Precision-preserving Session B signals:

- `economy_changed(total: Dictionary, delta: Dictionary, source: StringName)`
- `economy_rate_changed(rate: Dictionary)`
- `upgrade_purchase_committed(upgrade_id, level, paid_cost: Dictionary)`

State surface:

- `register_lap(stage_id, elapsed_seconds, replay_payload = {})`
- `register_death(stage_id, reason)`
- `current_stage_context()`
- `serialize_state()`
- `restore_state(state)`
- `get_unlocked_abilities()`

## Stage lifecycle — implemented Next1

Stage subsystem: `Game/Stages/StageManager.gd`.

Methods:

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

Rules:

- Manual begin/restart creates a new `attempt_id`.
- Death retry preserves the attempt and elapsed time.
- Backtracking cannot downgrade the active checkpoint.
- Non-positive or duplicate finished laps are rejected.
- Best time is the minimum positive completion time.
- Stage clear unlocks the next stage at the stage subsystem level.
- Session A lap timing is authoritative when supplied.

## World / gimmicks — implemented Next2

Authoritative world state: `Game/World/WorldState.gd`.

Methods:

- `set_unlocked_abilities`
- `enter_stage`
- `set_phase`
- `set_visibility`
- `reset_visibility`
- `discover_secret`
- `discover_shortcut`
- `can_traverse`
- `is_ability_unlocked`
- `world_context`
- `serialize_world_state`
- `restore_world_state`

`GimmickRuntime` re-emits only:

- `spring_launch_requested(body, launch_velocity, spring_id)`
- `hazard_contact(body, hazard_id, reason)`

Session C maps these to Session A. Session B never assigns player velocity or calls player death APIs.

## Economy — implemented Next3

Authoritative stored resource is `BigResource`, represented externally as:

```text
{
  "mantissa": float,
  "exponent": int
}
```

The value is `mantissa × 1000^exponent`. Storage is independent from UI suffixes.

Required public operations are implemented on `ProgressionWorld`:

- `add_resource(amount, source) -> bool`
- `spend_resource(amount, reason) -> bool`
- `current_resource() -> Dictionary`
- `resource_per_second() -> Dictionary`
- `calculate_clone_reward(stage_id, best_time, clone_profile) -> Dictionary`

Additional economy operations:

- `set_clone_count(stage_id, clone_count) -> bool`
- `economy_snapshot() -> Dictionary`

Economy rules:

- Negative, NaN and infinite additions are rejected.
- Spending is atomic and cannot make the authoritative balance negative.
- Passive production ticks at a data-configured cadence rather than every render frame.
- Active lap reward rises with faster completion but is bounded.
- Clone cycle reward rises with better best time and route quality but is bounded.
- Clone RPS benefits from both faster cycles and higher speed reward.
- Improved recorded routes may replace slower clone cycles; slower routes never degrade an existing best automation route.
- Large balances remain in scientific group form. `float` conversion exists only for Session C legacy compatibility and is clamped at extreme magnitudes.

## Upgrade — implemented Next3 economic tracks

Operations:

- `purchase(upgrade_id) -> Dictionary`
- `purchase_upgrade(upgrade_id) -> Dictionary`
- `current_level(upgrade_id) -> int`
- `current_cost(upgrade_id) -> Dictionary`
- `resulting_effect(upgrade_id) -> Dictionary`
- `upgrade_availability(upgrade_id) -> Dictionary`

Economic tracks:

- `flux_coils` → global passive income multiplier.
- `loop_compression` → clone-cycle reward multiplier.
- `route_dividend` → active lap reward multiplier.

Prices use declared geometric curves in `Content/Economy/economy_balance_v1.json`. Purchases are atomic, max levels are terminal, and UI can query both current cost and next resulting effect. Track access is gated by declared stage-clear milestones.

Movement, ability and clone-capacity progression is intentionally completed in Next4 rather than being hidden inside these economy upgrades.

## Resource display — implemented Next3

`Game/UI/ResourceFormatter.gd` formats exact snapshots without altering stored values.

Default original unit is `Flux`:

- Flux
- kFlux
- MFlux
- GFlux
- TFlux
- PFlux
- EFlux
- ZFlux
- YFlux
- then scientific `eN Flux`

## Clone registration

`ProgressionWorld.register_lap` performs exactly one active reward after `StageManager` accepts the completion.

When a non-empty replay payload is supplied, it also registers/updates the stage clone route. The replay payload may optionally contain `route_quality`; Session B does not inspect Session A replay internals.

Clone count defaults to one only when no prior capacity/profile exists. Next4 owns clone-capacity progression.

## Progression / ability unlock — reserved for Next4

Required operations remain:

- `unlock_ability`
- `is_ability_unlocked`
- `unlock_stage`
- composite stage availability including mandatory ability requirements.

Required signal:

- `ability_unlocked(ability_id)`

Session B owns unlock state. Session A owns movement implementation.

## Stable original IDs

Stages:

- `relay_yard`
- `liftworks`
- `phase_foundry`
- `blackout_array`
- `core_spire`

Abilities:

- `speed_tune`
- `dash`
- `double_jump`
- `wall_jump`
- `phase_shift`

All IDs, presentation, economy constants and world layouts are project-original. No reference-game stage geometry, text, art, audio or exact unpublished numeric formula is represented as canonical.
