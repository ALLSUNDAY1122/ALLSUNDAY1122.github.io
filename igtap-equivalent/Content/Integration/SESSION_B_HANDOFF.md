# Session B → Session C Handoff

Session B branch: `igtap/wp2-progression-world`
Production root: `res://Game/Progression/ProgressionWorld.gd`

## What Session B now owns and provides

- five-stage lifecycle and stage-select data;
- world topology, provisional geometry and prototype stage assembler;
- moving platforms, spring requests, hazards, ability gates, state switching, darkness, shortcuts and secrets;
- large-number Flux economy;
- active rewards, clone rewards and passive Flux/s;
- economic upgrade tracks;
- movement/ability progression;
- global/per-stage clone allocation limits;
- aggregate save/restore state;
- reusable progression HUD model and panel;
- semantic feedback events for original audio/haptics;
- progression/balance audit scripts and evidence.

## Required Session C integration changes

Session B intentionally does not modify C-owned files. Session C should perform these changes on its integration branch.

### 1. Replace MockProgression

Current Bootstrap uses `Integration/Mock/MockProgressionWorld.gd`.

Instantiate `res://Game/Progression/ProgressionWorld.gd` as the progression/world implementation and bind it to `ProgressionWorldAdapter`.

The existing adapter-compatible signals remain:

- `stage_context_changed`
- `currency_changed`
- `upgrade_purchased`
- `ability_unlocked`
- `clone_income_applied`

The existing adapter-compatible methods remain:

- `register_lap`
- `get_unlocked_abilities`
- `current_stage_context`

### 2. Additive adapter surface recommended

For the final UI and progression flow, Session C should additionally expose/relay:

- `stage_availability_changed`
- `movement_effects_changed`
- `clone_capacity_changed`
- `economy_rate_changed`
- `select_stage`
- `begin_stage`
- `stage_select_entries`
- `purchase_upgrade`
- `set_clone_count`
- `clone_allocation_snapshot`
- `progression_snapshot`
- `serialize_state`
- `restore_state`

Do not replace exact BigResource snapshots with float internally. The existing float `currency_changed` remains compatibility-only.

### 3. Ability mapping to Session A

Session B progression IDs map as follows:

- `dash` → Session A `dash`
- `double_jump` → Session A `airJump`
- `wall_jump` → Session A `wallJump`
- `speed_tune` → numeric `run_speed_multiplier`; do not pass as a PlayerAbility enum value
- `phase_shift` → world-only; do not pass as a PlayerAbility enum value
- `jump_tune` → numeric `jump_multiplier`; do not pass as a PlayerAbility enum value

Session C needs a numeric configuration bridge for run/jump multipliers because Session A currently owns Swift `PlayerConfig` and Session B must not edit it.

### 4. World-event bridge

Bind Session B `GimmickRuntime` requests to Session A commands through C:

- `spring_launch_requested` → an explicit Session A/C impulse/launch integration path;
- `hazard_contact` → Session A `kill(reason:)` equivalent;
- checkpoints/Start/Goal from `PrototypeStageAssembler` → Session A checkpoint/lap contracts and Session B StageManager.

The generic spring impulse boundary is still not present in Session A's published Swift contract, so Session C/A must explicitly define it rather than reaching into velocity state.

### 5. UI

Replace the current Mock ENERGY label UI with Session B's original Flux UI surfaces:

- `Game/UI/ProgressionHUDModel.gd`
- `Game/UI/ProgressionPanel.gd`
- `Game/UI/StageSelectModel.gd`

Place the panel inside C's Safe Area system. The panel is intentionally not responsible for iOS safe-area geometry.

Recommended presentation on landscape iPhone: HUD always visible; progression panel as pause/menu side drawer so it cannot overlap movement controls.

### 6. Clone/replay integration

Session B stores economy allocation counts. Session A owns actual replay clone instances.

C should reconcile desired allocation to real clone instances when:

- a route recording becomes available;
- `set_clone_count` changes allocation;
- a save is restored;
- a stage is entered or left if C chooses stage-local rendering.

Rules that must remain true:

- global capacity cannot be exceeded;
- each stage max is 3;
- no clone is created for a stage until a valid replay route exists;
- a slower recording cannot replace a better automation route.

### 7. Save integration

Persist the aggregate `ProgressionWorld.serialize_state()` result through C's Platform/Save implementation and restore using `restore_state()`.

Current schema version is 2 and accepts version-1 aggregate state for migration.

## Remaining integration risks

1. Session A remains Swift/framework-light while Session C's current shell is Godot/GDScript. This is the largest architectural mismatch and must be resolved by Session C.
2. Session A uses abstract world units while Session B's prototype geometry currently assumes a provisional 64 pixels/unit. Calibrate one adapter scale; do not independently retune each stage.
3. Session A does not yet publish a generic spring/impulse command. Add an explicit contract rather than mutating velocity from B/C.
4. Godot runtime/parser validation could not be executed in Session B's environment because Godot is unavailable there.
5. Direct GitHub checkout-based tests could not run in Session B's execution container due DNS resolution failure; data/source invariants and balance simulations were executed in-session instead.

## Acceptance checks for Session C

Before TestFlight, verify on an iPhone build:

- Stage Select never opens a stage before its required ability is purchased.
- Dash, air jump and wall jump unlock exactly once and persist after relaunch.
- Speed/jump tuning changes actual Session A movement by the displayed multiplier.
- Spring, hazard, checkpoint and Goal boundaries work through adapters.
- A first valid recording can auto-use one free clone slot; further recordings do not exceed capacity.
- Per-stage clone count cannot exceed 3.
- Flux/s continues while playing another course.
- Best-time improvements update clone automation without degrading a better route.
- Blackout UI and required geometry remain readable.
- Progression panel respects safe area and does not overlap movement controls.
- Save/restore preserves balances, upgrades, abilities, best times, discoveries and clone allocations.
- No reference-game name, art, music, text or stage geometry appears in the build.
