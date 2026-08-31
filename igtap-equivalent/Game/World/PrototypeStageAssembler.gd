class_name PrototypeStageAssembler
extends Node2D

signal gimmick_created(node: Node)
signal stage_trigger_created(node: Node)
signal stage_built(stage_id: StringName, generated_nodes: int)

@export var stage_id: StringName = &"relay_yard"
@export var auto_build := true
@export var pixels_per_unit_override := 0.0

const GEOMETRY_PATH := "res://Content/World/stage_geometry_v1.json"
const StageCatalogType = preload("res://Game/Stages/StageCatalog.gd")
const StartTriggerType = preload("res://Game/Stages/StageStartTrigger.gd")
const GoalTriggerType = preload("res://Game/Stages/StageGoalTrigger.gd")
const CheckpointTriggerType = preload("res://Game/Stages/StageCheckpointTrigger.gd")
const MovingPlatformType = preload("res://Game/Gimmicks/MovingPlatform.gd")
const SpringPadType = preload("res://Game/Gimmicks/SpringPad.gd")
const HazardZoneType = preload("res://Game/Gimmicks/HazardZone.gd")
const AbilityGateType = preload("res://Game/Gimmicks/AbilityGate.gd")
const StateSwitchType = preload("res://Game/Gimmicks/StateSwitch.gd")
const StateGateType = preload("res://Game/Gimmicks/StateGate.gd")
const VisibilityZoneType = preload("res://Game/Gimmicks/VisibilityZone.gd")
const DiscoveryZoneType = preload("res://Game/Gimmicks/DiscoveryZone.gd")

var _generated_root: Node2D
var _ppu := 64.0

func _ready() -> void:
    if auto_build:
        build_stage(stage_id)

func build_stage(requested_stage_id: StringName) -> bool:
    var geometry_doc := _load_geometry()
    if geometry_doc.is_empty():
        return false
    var geometry := _find_stage_geometry(geometry_doc, requested_stage_id)
    if geometry.is_empty():
        return false
    var stage_catalog := StageCatalogType.new()
    if stage_catalog.load_from_path() != OK or not stage_catalog.has_stage(requested_stage_id):
        return false
    _clear_generated()
    _ppu = pixels_per_unit_override if pixels_per_unit_override > 0.0 else float(geometry_doc.get("pixels_per_unit", 64.0))
    _generated_root = Node2D.new()
    _generated_root.name = "Generated_%s" % str(requested_stage_id)
    add_child(_generated_root)
    var default_platform: Array = geometry_doc.get("default_platform_size", [3.2, 0.45])
    var anchors: Dictionary = geometry.get("anchors", {})
    for anchor_name in anchors.keys():
        _create_platform(_as_vector(anchors[anchor_name]), default_platform, str(anchor_name))
    _create_stage_triggers(requested_stage_id, stage_catalog.stage(requested_stage_id), anchors)
    for placement_value in geometry.get("placements", []):
        _create_placement(requested_stage_id, placement_value)
    stage_id = requested_stage_id
    stage_built.emit(stage_id, _generated_root.get_child_count())
    return true

func _load_geometry() -> Dictionary:
    if not FileAccess.file_exists(GEOMETRY_PATH):
        push_error("Missing stage geometry: %s" % GEOMETRY_PATH)
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
    if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", -1)) != 1:
        push_error("Invalid stage geometry document")
        return {}
    return parsed

func _find_stage_geometry(document: Dictionary, requested_stage_id: StringName) -> Dictionary:
    for stage_value in document.get("stages", []):
        var stage: Dictionary = stage_value
        if StringName(str(stage.get("id", ""))) == requested_stage_id:
            return stage
    return {}

func _clear_generated() -> void:
    if _generated_root != null and is_instance_valid(_generated_root):
        _generated_root.queue_free()
        _generated_root = null

func _create_platform(unit_position: Vector2, size_units: Array, label: String) -> void:
    var body := StaticBody2D.new()
    body.name = "Platform_%s" % label
    body.position = unit_position * _ppu
    _generated_root.add_child(body)
    _add_rect_shape(body, size_units)
    _add_rect_visual(body, size_units, Color(0.24, 0.27, 0.31, 1.0))

func _create_stage_triggers(current_stage_id: StringName, definition: Dictionary, anchors: Dictionary) -> void:
    var start := StartTriggerType.new()
    start.stage_id = current_stage_id
    start.position = (_as_vector(anchors.get("start", [0, 0])) + Vector2(0, -1.0)) * _ppu
    _generated_root.add_child(start)
    _add_rect_shape(start, [1.2, 2.0])
    stage_trigger_created.emit(start)

    var goal := GoalTriggerType.new()
    goal.stage_id = current_stage_id
    goal.position = (_as_vector(anchors.get("goal", [0, 0])) + Vector2(0, -1.0)) * _ppu
    _generated_root.add_child(goal)
    _add_rect_shape(goal, [1.4, 2.2])
    stage_trigger_created.emit(goal)

    var checkpoints: Array = definition.get("checkpoints", [])
    for index in range(checkpoints.size()):
        var checkpoint_definition: Dictionary = checkpoints[index]
        var anchor_key := "cp%d" % (index + 1)
        if not anchors.has(anchor_key):
            continue
        var checkpoint := CheckpointTriggerType.new()
        checkpoint.stage_id = current_stage_id
        checkpoint.checkpoint_id = StringName(str(checkpoint_definition.get("id", "")))
        checkpoint.position = (_as_vector(anchors[anchor_key]) + Vector2(0, -1.0)) * _ppu
        _generated_root.add_child(checkpoint)
        _add_rect_shape(checkpoint, [1.2, 2.0])
        stage_trigger_created.emit(checkpoint)

func _create_placement(current_stage_id: StringName, value) -> void:
    var placement: Dictionary = value
    var kind := str(placement.get("type", ""))
    var node: Node2D
    match kind:
        "moving_platform":
            var moving = MovingPlatformType.new()
            moving.travel_offset = _as_vector(placement.get("offset", [0, 0])) * _ppu
            moving.one_way_seconds = float(placement.get("seconds", 2.5))
            node = moving
        "spring":
            var spring = SpringPadType.new()
            spring.spring_id = StringName(str(placement.get("id", "spring")))
            spring.launch_velocity = _as_vector(placement.get("launch", [0, -12]))
            node = spring
        "hazard":
            var hazard = HazardZoneType.new()
            hazard.hazard_id = StringName(str(placement.get("id", "hazard")))
            hazard.reason = StringName(str(placement.get("reason", "world_hazard")))
            node = hazard
        "ability_gate":
            var ability_gate = AbilityGateType.new()
            ability_gate.gate_id = StringName(str(placement.get("id", "ability_gate")))
            ability_gate.required_ability = StringName(str(placement.get("ability", "")))
            node = ability_gate
        "state_switch":
            var state_switch = StateSwitchType.new()
            state_switch.stage_id = current_stage_id
            state_switch.target_phase = StringName(str(placement.get("phase", "amber")))
            node = state_switch
        "state_gate":
            var state_gate = StateGateType.new()
            state_gate.stage_id = current_stage_id
            state_gate.gate_id = StringName(str(placement.get("id", "state_gate")))
            state_gate.open_phase = StringName(str(placement.get("phase", "amber")))
            node = state_gate
        "visibility":
            var visibility = VisibilityZoneType.new()
            visibility.stage_id = current_stage_id
            visibility.visibility_scale = float(placement.get("scale", 0.45))
            node = visibility
        "discovery":
            var discovery = DiscoveryZoneType.new()
            discovery.stage_id = current_stage_id
            discovery.discovery_kind = str(placement.get("kind", "secret"))
            discovery.discovery_id = StringName(str(placement.get("id", "")))
            node = discovery
        _:
            return
    node.name = "%s_%s" % [kind, str(placement.get("id", "node"))]
    node.position = _as_vector(placement.get("pos", [0, 0])) * _ppu
    _generated_root.add_child(node)
    _add_rect_shape(node, placement.get("size", [1.0, 1.0]))
    if kind in ["moving_platform", "ability_gate", "state_gate"]:
        _add_rect_visual(node, placement.get("size", [1.0, 1.0]), Color(0.38, 0.42, 0.48, 1.0))
    gimmick_created.emit(node)

func _add_rect_shape(parent: CollisionObject2D, size_units) -> void:
    var size := _as_vector(size_units)
    var rectangle := RectangleShape2D.new()
    rectangle.size = size * _ppu
    var collision := CollisionShape2D.new()
    collision.shape = rectangle
    parent.add_child(collision)

func _add_rect_visual(parent: Node2D, size_units, color: Color) -> void:
    var size := _as_vector(size_units) * _ppu
    var half := size * 0.5
    var polygon := Polygon2D.new()
    polygon.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
    polygon.color = color
    parent.add_child(polygon)

func _as_vector(value) -> Vector2:
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO
