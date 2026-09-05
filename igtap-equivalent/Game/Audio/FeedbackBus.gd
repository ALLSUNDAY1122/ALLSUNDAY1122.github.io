class_name FeedbackBus
extends Node

signal feedback_requested(event_id: StringName, intensity: float)

var _progression_world: Node

func bind(progression_world: Node) -> void:
    _progression_world = progression_world
    _connect_if_present(&"upgrade_purchased", Callable(self, "_on_upgrade_purchased"))
    _connect_if_present(&"ability_unlocked", Callable(self, "_on_ability_unlocked"))
    _connect_if_present(&"clone_capacity_changed", Callable(self, "_on_clone_capacity_changed"))
    _connect_if_present(&"stage_availability_changed", Callable(self, "_on_stage_availability_changed"))

func request(event_id: StringName, intensity: float = 1.0) -> void:
    feedback_requested.emit(event_id, clampf(intensity, 0.0, 1.0))

func _on_upgrade_purchased(_upgrade_id: StringName, _level: int) -> void:
    request(&"upgrade_purchase", 0.55)

func _on_ability_unlocked(_ability_id: StringName) -> void:
    request(&"ability_unlock", 0.9)

func _on_clone_capacity_changed(_capacity: int) -> void:
    request(&"clone_capacity", 0.45)

func _on_stage_availability_changed(_stage_id: StringName, availability: Dictionary) -> void:
    if bool(availability.get("available", false)):
        request(&"stage_unlocked", 0.75)

func _connect_if_present(signal_name: StringName, callable: Callable) -> void:
    if _progression_world != null and _progression_world.has_signal(signal_name):
        _progression_world.connect(signal_name, callable)
