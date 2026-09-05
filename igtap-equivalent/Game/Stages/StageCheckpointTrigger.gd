class_name StageCheckpointTrigger
extends Area2D

signal checkpoint_reached(stage_id: StringName, checkpoint_id: StringName)

@export var stage_id: StringName
@export var checkpoint_id: StringName
@export var player_group: StringName = &"player"
var _activated := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func reset_activation() -> void:
    _activated = false

func _on_body_entered(body: Node) -> void:
    if _activated or not body.is_in_group(player_group):
        return
    _activated = true
    checkpoint_reached.emit(stage_id, checkpoint_id)
