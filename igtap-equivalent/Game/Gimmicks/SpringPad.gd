class_name SpringPad
extends Area2D

signal launch_requested(body: Node, launch_velocity: Vector2, spring_id: StringName)

@export var spring_id: StringName = &"spring"
@export var launch_velocity := Vector2(0.0, -820.0)

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        launch_requested.emit(body, launch_velocity, spring_id)
