class_name StageStartTrigger
extends Area2D

signal start_requested(stage_id: StringName)

@export var stage_id: StringName
@export var player_group: StringName = &"player"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group(player_group):
        start_requested.emit(stage_id)
