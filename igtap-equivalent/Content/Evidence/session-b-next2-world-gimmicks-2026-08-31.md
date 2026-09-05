# Session B Next2 Evidence — World / Gimmicks

Date: 2026-08-31 JST
Branch: `igtap/wp2-progression-world`
Implementation head before evidence commit: `b821f0cefab1afad4c481b729ad836922222c0be`

## Repository preflight

- Session B began Next2 from `99c1fc36bb74239b3ff9afc6aeecd032e6aea1d5`.
- `main` had advanced by unrelated project work; the IGTAP Session branches still share the older common base. Session B intentionally did not rebase unrelated `main` history into the game branch.
- Session A had progressed to Swift player/physics implementation.
- Session C remained a Godot 4/GDScript integration shell.
- No Session A/C owned files were modified.

## Scope completed

- Original five-stage world topology data with mandatory, shortcut and secret routes.
- Ability-gated edges and stage-entry ability declarations.
- Amber/Cyan world-state switching with state-gated traversal.
- Reduced-visibility world state and local visibility zones.
- Persistent secret discovery and shortcut discovery.
- Moving platform component.
- Spring component that emits a launch request without mutating Session A player velocity.
- Hazard component that emits a death/hazard request without calling Session A death methods.
- Ability gate, state switch, state gate, visibility zone and discovery zone components.
- `GimmickRuntime` binder that connects Session B world state to world-owned gimmicks and re-emits only player-affecting requests to Session C/A.
- Original stage-layout guide describing mandatory routes and revisit routes.
- Provisional original geometry anchors and gimmick placements for all five stages.
- `PrototypeStageAssembler` that generates placeholder platforms, Start/Goal/Checkpoint triggers and configured gimmick nodes for integration playtests.
- Public Session B contract updated with World/Gimmick/Prototype assembly surfaces.
- Progression tests extended for topology, checkpoint, geometry, gimmick variety and ownership boundaries.

## Route / balance audit

A Python state-graph simulation was run in this session against the designed route model. Mandatory routes were evaluated with only the abilities guaranteed at that stage and with secrets/shortcuts disabled. All five reached Goal.

Abstract edge counts:

| Stage | Mandatory route | All-ability shortcut route | Saved edges |
| --- | ---: | ---: | ---: |
| relay_yard | 5 | 2 | 3 |
| liftworks | 7 | 5 | 2 |
| phase_foundry | 8 | 3 | 5 |
| blackout_array | 8 | 5 | 3 |
| core_spire | 9 | 3 | 6 |

Every later-ability shortcut saves at least two route edges. Secrets are excluded from every mandatory path.

Checkpoint/geometry consistency audit:

- relay_yard: 2 / 2 checkpoint anchors.
- liftworks: 3 / 3.
- phase_foundry: 3 / 3.
- blackout_array: 4 / 4.
- core_spire: 4 / 4.
- Geometry anchor coverage: all topology nodes covered in all 5 stages.

Visibility guardrail:

- relay_yard: 1.00
- liftworks: 1.00
- phase_foundry: 1.00
- blackout_array: 0.42
- core_spire: 0.68

Minimum baseline visibility is intentionally above 0.35; darkness is a navigation challenge rather than a black-screen challenge.

## Failures found and fixed during Next2

1. `entry_required_ability: null` could be stringified into a fake required ability, blocking Relay Yard. Fixed by handling JSON null explicitly.
2. Visibility-zone exit originally risked restoring to full visibility and breaking a stage whose baseline is intentionally dark. Fixed with `reset_visibility(stage_id)` and a baseline-restore signal.
3. World topology checkpoint counts initially diverged from the Next1 stage catalog for four stages. Fixed by aligning topology to the authoritative checkpoint counts and adding a regression test.
4. Runtime signal wiring was initially drafted against a generic `Node` with direct custom-signal property access. Reworked to `has_signal` / `connect` / `call` boundaries so the binder remains valid with adapter-provided nodes.
5. Prototype assembly placement order was rechecked specifically for moving platforms; placement is set before `add_child`, so the moving-platform origin is captured correctly. No additional code delta was required for that suspicion.

## Validation limitations

- The execution environment does not contain a Godot executable, so interactive physics/runtime playtesting could not be launched.
- A direct `git clone` of the public repository from the execution container failed because the container could not resolve `github.com`. GitHub connector reads/writes and commit verification remained available.
- The repository includes `Tests/Progression/test_world_topology.py` and `world_route_sim.py`; the equivalent route and consistency logic was executed in-session, but a checkout-based `pytest` invocation could not be completed in this environment.

## Public API changes in Next2

World state methods added:

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

World signals added:

- `phase_changed`
- `secret_discovered`
- `shortcut_discovered`
- `visibility_changed`
- `world_state_changed`

GimmickRuntime bridge signals added:

- `spring_launch_requested`
- `hazard_contact`

Prototype assembly surface added:

- `build_stage(stage_id)`
- `gimmick_created(node)`
- `stage_trigger_created(node)`
- `stage_built(stage_id, generated_nodes)`

## Integration attention for Session C / later Session B passes

1. Session A currently uses abstract world units while Session C uses Godot pixels. Prototype geometry declares 64 pixels/unit only as a provisional scaffold. The final adapter must calibrate this rather than independently retuning every stage.
2. Spring launch vectors are emitted as gameplay/world-unit intent; Session C/A owns conversion/application to the actual player implementation.
3. `StageManager` currently unlocks the next stage on clear while `WorldState.enter_stage` can additionally require an ability. Next4 must compose these into one availability result so UI cannot present a stage as playable before its mandatory ability is granted.
4. Session C's current adapter does not yet expose `WorldState`/`GimmickRuntime` directly. Next3/Next4 will create the aggregate production root expected by the adapter without editing Session C-owned files.
5. Secret rewards and shortcut/route income effects deliberately remain unpriced until Next3 economy is authoritative.
