class_name ProgressionWorldAdapter
extends Node

signal stage_context_changed(context: Dictionary)
signal currency_changed(total: float)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal ability_unlocked(ability_id: StringName)
signal clone_income_applied(stage_id: StringName, amount: float)

var _implementation: Node

func bind(implementation: Node) -> void:
    _implementation = implementation
    for signal_name in [&"stage_context_changed", &"currency_changed", &"upgrade_purchased", &"ability_unlocked", &"clone_income_applied"]:
        if implementation.has_signal(signal_name):
            implementation.connect(signal_name, func(a = null, b = null): _relay(signal_name, a, b))

func _relay(signal_name: StringName, a, b) -> void:
    match signal_name:
        &"stage_context_changed": stage_context_changed.emit(a)
        &"currency_changed": currency_changed.emit(a)
        &"upgrade_purchased": upgrade_purchased.emit(a, b)
        &"ability_unlocked": ability_unlocked.emit(a)
        &"clone_income_applied": clone_income_applied.emit(a, b)

func register_lap(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary) -> void:
    if _implementation != null and _implementation.has_method("register_lap"):
        _implementation.register_lap(stage_id, elapsed_seconds, replay_payload)

func get_unlocked_abilities() -> Array[StringName]:
    if _implementation != null and _implementation.has_method("get_unlocked_abilities"):
        return _implementation.get_unlocked_abilities()
    return []

func current_stage_context() -> Dictionary:
    if _implementation != null and _implementation.has_method("current_stage_context"):
        return _implementation.current_stage_context()
    return {}
