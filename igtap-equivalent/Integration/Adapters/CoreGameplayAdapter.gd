class_name CoreGameplayAdapter
extends Node

signal player_died(reason: StringName)
signal player_respawned(checkpoint_id: StringName)
signal checkpoint_reached(checkpoint_id: StringName)
signal lap_completed(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary)
signal recording_completed(stage_id: StringName, replay_payload: Dictionary)

var _implementation: Node
var _ability_ids: Array[StringName] = []
var _stage_context := {}
var _movement_effects := {"run_speed_multiplier": 1.0, "jump_multiplier": 1.0}

func bind(implementation: Node) -> void:
    _implementation = implementation
    for signal_name in [&"player_died", &"player_respawned", &"checkpoint_reached", &"lap_completed", &"recording_completed"]:
        if implementation.has_signal(signal_name):
            implementation.connect(signal_name, func(a = null, b = null, c = null): _relay(signal_name, a, b, c))
    if implementation.has_method("set_input_provider"):
        implementation.set_input_provider(InputRouter)
    apply_ability_set(_ability_ids)
    apply_movement_effects(_movement_effects)
    set_stage_context(_stage_context)

func _relay(signal_name: StringName, a, b, c) -> void:
    match signal_name:
        &"player_died": player_died.emit(a)
        &"player_respawned": player_respawned.emit(a)
        &"checkpoint_reached": checkpoint_reached.emit(a)
        &"lap_completed": lap_completed.emit(a, b, c)
        &"recording_completed": recording_completed.emit(a, b)

func apply_ability_set(ability_ids: Array[StringName]) -> void:
    _ability_ids = ability_ids.duplicate()
    if _implementation != null and _implementation.has_method("apply_ability_set"):
        _implementation.apply_ability_set(_ability_ids)

func apply_movement_effects(effects: Dictionary) -> void:
    _movement_effects = effects.duplicate(true)
    if _implementation != null and _implementation.has_method("apply_movement_effects"):
        _implementation.apply_movement_effects(_movement_effects)

func set_stage_context(context: Dictionary) -> void:
    _stage_context = context.duplicate(true)
    if _implementation != null and _implementation.has_method("set_stage_context"):
        _implementation.set_stage_context(_stage_context)

func set_stage_spawn(world_position: Vector2) -> void:
    if _implementation != null and _implementation.has_method("set_stage_spawn"):
        _implementation.set_stage_spawn(world_position)

func begin_lap(stage_id: StringName) -> bool:
    return bool(_implementation.call("begin_lap", stage_id)) if _implementation != null and _implementation.has_method("begin_lap") else false

func finish_lap(stage_id: StringName) -> bool:
    return bool(_implementation.call("finish_lap", stage_id)) if _implementation != null and _implementation.has_method("finish_lap") else false

func reach_checkpoint(checkpoint_id: StringName, spawn_position: Vector2 = Vector2.INF) -> void:
    if _implementation != null and _implementation.has_method("reach_checkpoint"):
        _implementation.call("reach_checkpoint", checkpoint_id, spawn_position)

func launch(launch_velocity: Vector2) -> void:
    if _implementation != null and _implementation.has_method("launch"):
        _implementation.call("launch", launch_velocity)

func kill(reason: StringName) -> void:
    if _implementation != null and _implementation.has_method("kill"):
        _implementation.call("kill", reason)

func reconcile_clones(stage_id: StringName, desired_count: int) -> int:
    return int(_implementation.call("reconcile_clones", stage_id, desired_count)) if _implementation != null and _implementation.has_method("reconcile_clones") else 0

func best_recording(stage_id: StringName) -> Dictionary:
    return _implementation.call("best_recording", stage_id) if _implementation != null and _implementation.has_method("best_recording") else {}

func has_ability(ability_id: StringName) -> bool:
    return bool(_implementation.call("has_ability", ability_id)) if _implementation != null and _implementation.has_method("has_ability") else false

func movement_snapshot() -> Dictionary:
    return _implementation.call("movement_snapshot") if _implementation != null and _implementation.has_method("movement_snapshot") else {}

func serialize_state() -> Dictionary:
    return _implementation.call("serialize_state") if _implementation != null and _implementation.has_method("serialize_state") else {}

func restore_state(state: Dictionary) -> bool:
    return bool(_implementation.call("restore_state", state)) if _implementation != null and _implementation.has_method("restore_state") else false
