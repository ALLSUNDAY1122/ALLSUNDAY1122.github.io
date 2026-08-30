class_name GameBridge
extends Node

signal lap_completed(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary)
signal ability_unlocked(ability_id: StringName)
signal currency_changed(total: float)
signal stage_context_changed(context: Dictionary)

func connect_core_to_progression(core: Node, progression: Node) -> void:
    if core.has_signal("lap_completed") and progression.has_method("register_lap"):
        core.lap_completed.connect(progression.register_lap)
    if progression.has_signal("ability_unlocked") and core.has_method("apply_ability_set"):
        progression.ability_unlocked.connect(func(_id): core.apply_ability_set(progression.get_unlocked_abilities()))
    if progression.has_signal("stage_context_changed") and core.has_method("set_stage_context"):
        progression.stage_context_changed.connect(core.set_stage_context)
