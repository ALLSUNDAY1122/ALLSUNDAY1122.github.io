# Interface Contract v1

This is the shared boundary between Session A (core), Session B (world/progression), and Session C (platform/integration). Concrete implementations may differ internally but integration-visible behavior must remain compatible.

## Normalized input (C -> A)

Actions: `move_left`, `move_right`, `jump`, `dash`, `pause`, `restart`.

`InputRouter` exposes:

- `is_pressed(action: StringName) -> bool`
- `consume_pressed(action: StringName) -> bool` (edge-trigger, at most once per press)
- `set_virtual_action(action: StringName, pressed: bool)` for touch controls
- signal `action_changed(action, pressed)`

A must not depend on Button/TouchScreenButton nodes.

## Core gameplay surface (A -> C/B)

Session A production root SHOULD expose these signals (adapter may translate equivalent names):

- `player_died(reason)`
- `player_respawned(checkpoint_id)`
- `checkpoint_reached(checkpoint_id)`
- `lap_completed(stage_id, elapsed_seconds, replay_payload)`
- `ability_used(ability_id)`

And accept:

- `spawn_at(checkpoint_id)`
- `apply_ability_set(ability_ids)`
- `set_stage_context(stage_context)`
- `set_input_provider(provider)`

Replay payload must be deterministic enough for the Session A clone system and serializable without native object references.

## World/progression surface (B -> C/A)

Session B production root SHOULD expose:

- `stage_context_changed(stage_context)`
- `currency_changed(total)`
- `upgrade_purchased(upgrade_id, level)`
- `ability_unlocked(ability_id)`
- `clone_income_applied(stage_id, amount)`

And accept:

- `register_lap(stage_id, elapsed_seconds, replay_payload)`
- `register_death(stage_id, reason)`
- `purchase_upgrade(upgrade_id)`
- `serialize_state() -> Dictionary`
- `restore_state(state: Dictionary)`

It must provide the current `stage_context` and unlocked ability IDs without reading Session A internals.

## Integration loop

1. C normalizes keyboard/touch to actions.
2. A moves the player and reports checkpoint/death/lap events.
3. C forwards lap results to B.
4. B computes currency, clones, upgrades, unlocks and stage changes.
5. C forwards ability/stage changes back to A.
6. Save Service persists B state plus best-time/settings metadata.

## Compatibility policy

Adapters may map naming and data-shape differences. C may only patch A/B owned files when an adapter cannot reasonably resolve a release-blocking mismatch; such changes must be minimal and logged.
