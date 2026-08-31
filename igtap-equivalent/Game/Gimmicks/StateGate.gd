class_name StateGate
extends StaticBody2D

signal gate_state_changed(gate_id: StringName, open: bool)

@export var stage_id: StringName
@export var gate_id: StringName = &"state_gate"
@export var open_phase: StringName = &"amber"

var _open := false

func set_phase(phase: StringName) -> void:
    _apply_open_state(phase == open_phase)

func is_open() -> bool:
    return _open

func _apply_open_state(value: bool) -> void:
    if _open == value:
        return
    _open = value
    for child in get_children():
        if child is CollisionShape2D:
            child.set_deferred("disabled", _open)
        elif child is CanvasItem:
            child.visible = not _open
    gate_state_changed.emit(gate_id, _open)
