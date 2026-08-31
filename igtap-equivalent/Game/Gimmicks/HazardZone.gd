class_name HazardZone
extends Area2D

signal hazard_contact(body: Node, hazard_id: StringName, reason: StringName)

@export var hazard_id: StringName = &"hazard"
@export var reason: StringName = &"world_hazard"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        hazard_contact.emit(body, hazard_id, reason)
