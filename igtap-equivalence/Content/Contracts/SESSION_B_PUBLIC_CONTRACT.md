# Session B Public Contract

Project root: `igtap-equivalence/`
Owner: Session B / Progression + World
Consumers: Session C integration, Session A gameplay events

This document defines integration-facing behavior. Concrete Swift type names may evolve, but semantics must remain stable or be documented as a breaking contract change.

## Economy

Required operations:

- `add_resource(amount, source)` — adds non-negative production to the authoritative resource balance.
- `spend_resource(amount, reason) -> Bool` — atomically spends only when affordable; returns false without mutation otherwise.
- `current_resource -> BigResource` — authoritative current balance.
- `resource_per_second -> BigResource` — aggregate passive production from all active clone/stage sources.
- `calculate_clone_reward(stage_id, best_time, clone_profile) -> BigResource` — deterministic reward calculation for one completed clone cycle.

Rules:
- Negative/NaN/infinite inputs are rejected.
- All balance mutations publish `economy_changed`.
- Economy representation must tolerate values far beyond `Double` display range through mantissa/exponent or equivalent big-number representation.
- Formatting and storage are separate concerns; display suffixes must never be used as the stored value.

## Progression

Required operations:

- `unlock_ability(ability_id)` — idempotent.
- `is_ability_unlocked(ability_id) -> Bool`.
- `unlock_stage(stage_id)` — idempotent.
- `is_stage_available(stage_id) -> Bool`.
- `stage_availability(stage_id) -> AvailabilityState` — includes locked reason for UI.

Session B owns unlock state only. Session A owns the actual movement implementation and interprets ability IDs.

## Upgrade

Required operations:

- `purchase(upgrade_id) -> PurchaseResult`.
- `current_level(upgrade_id) -> Int`.
- `current_cost(upgrade_id) -> BigResource`.
- `resulting_effect(upgrade_id) -> UpgradeEffectSnapshot`.

Rules:
- Purchases are atomic and deterministic.
- Repeated purchases follow a declared cost curve.
- Maxed upgrades return a non-mutating terminal result.
- UI can query the next effect before purchase.

## Signals

Session B publishes:

- `upgrade_purchased(upgrade_id, new_level, paid_cost)`
- `ability_unlocked(ability_id)`
- `stage_started(stage_id, attempt_id)`
- `stage_completed(stage_id, elapsed_time, is_new_best, checkpoint_count)`
- `economy_changed(new_balance, delta, source)`

Signal requirements:
- Events are emitted after authoritative state mutation.
- Duplicate unlock requests do not emit duplicate unlock events.
- Stage completion must be uniquely attributable to an attempt ID to prevent duplicate rewards.

## Stage bridge expected from Session A

Session B expects Session A/C to supply gameplay callbacks rather than direct cross-ownership mutation:

- player entered Start trigger
- player reached Checkpoint trigger
- player reached Goal trigger
- player died / requested retry
- clone completed recorded route
- ability implementation became usable

Session B must not write into `Game/Player`, `Game/Physics`, `Game/Abilities`, `Game/Replay` or `Game/Ghost`.

## Stable IDs

Provisional stage IDs:
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

These are data IDs, not copyrighted presentation names and may be remapped by Session C if a shared ID registry is introduced.
