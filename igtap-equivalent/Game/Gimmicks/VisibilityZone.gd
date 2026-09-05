class_name VisibilityZone
extends Area2D

signal visibility_requested(stage_id: StringName, visibility_scale: float)
signal visibility_restore_requested(stage_id: StringName)

@export var stage_id: StringName
@export_range(0.15, 1.0, 0.01) var visibility_scale := 0.45

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        visibility_requested.emit(stage_id, visibility_scale)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        visibility_restore_requested.emit(stage_id)
