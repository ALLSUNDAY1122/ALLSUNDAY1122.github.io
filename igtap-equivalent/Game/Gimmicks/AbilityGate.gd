class_name AbilityGate
extends StaticBody2D

signal gate_state_changed(gate_id: StringName, open: bool)

@export var gate_id: StringName = &"ability_gate"
@export var required_ability: StringName = &"dash"

var _open := false

func _ready() -> void:
    _apply_open_state(false)

func set_unlocked_abilities(ability_ids: Array) -> void:
    var should_open := required_ability == &""
    if not should_open:
        for value in ability_ids:
            if StringName(str(value)) == required_ability:
                should_open = true
                break
    _apply_open_state(should_open)

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
