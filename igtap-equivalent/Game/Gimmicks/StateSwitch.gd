class_name StateSwitch
extends Area2D

signal phase_requested(stage_id: StringName, target_phase: StringName)

@export var stage_id: StringName
@export var target_phase: StringName = &"amber"

var _armed := true

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if _armed and body.is_in_group("player"):
        _armed = false
        phase_requested.emit(stage_id, target_phase)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        _armed = true
