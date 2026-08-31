class_name DiscoveryZone
extends Area2D

signal discovered(stage_id: StringName, kind: StringName, discovery_id: StringName)

@export var stage_id: StringName
@export_enum("secret", "shortcut") var discovery_kind := "secret"
@export var discovery_id: StringName

var _reported := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if _reported or not body.is_in_group("player"):
        return
    var kind := StringName(discovery_kind)
    if kind != &"secret" and kind != &"shortcut":
        return
    _reported = true
    discovered.emit(stage_id, kind, discovery_id)
