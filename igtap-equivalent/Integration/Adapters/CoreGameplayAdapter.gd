class_name CoreGameplayAdapter
extends Node

signal player_died(reason: StringName)
signal player_respawned(checkpoint_id: StringName)
signal checkpoint_reached(checkpoint_id: StringName)
signal lap_completed(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary)

var _implementation: Node
var _ability_ids: Array[StringName] = []
var _stage_context := {}

func bind(implementation: Node) -> void:
    _implementation = implementation
    for signal_name in [&"player_died", &"player_respawned", &"checkpoint_reached", &"lap_completed"]:
        if implementation.has_signal(signal_name):
            implementation.connect(signal_name, func(a = null, b = null, c = null): _relay(signal_name, a, b, c))
    if implementation.has_method("set_input_provider"):
        implementation.set_input_provider(InputRouter)
    apply_ability_set(_ability_ids)
    set_stage_context(_stage_context)

func _relay(signal_name: StringName, a, b, c) -> void:
    match signal_name:
        &"player_died": player_died.emit(a)
        &"player_respawned": player_respawned.emit(a)
        &"checkpoint_reached": checkpoint_reached.emit(a)
        &"lap_completed": lap_completed.emit(a, b, c)

func apply_ability_set(ability_ids: Array[StringName]) -> void:
    _ability_ids = ability_ids.duplicate()
    if _implementation != null and _implementation.has_method("apply_ability_set"):
        _implementation.apply_ability_set(_ability_ids)

func set_stage_context(context: Dictionary) -> void:
    _stage_context = context.duplicate(true)
    if _implementation != null and _implementation.has_method("set_stage_context"):
        _implementation.set_stage_context(_stage_context)
