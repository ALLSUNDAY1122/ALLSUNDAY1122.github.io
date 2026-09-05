class_name GimmickRuntime
extends Node

signal spring_launch_requested(body: Node, launch_velocity: Vector2, spring_id: StringName)
signal hazard_contact(body: Node, hazard_id: StringName, reason: StringName)

var _world_state: Node
var _state_gates: Array[Node] = []
var _ability_gates: Array[Node] = []

func bind_world_state(world_state: Node) -> void:
    _world_state = world_state
    if _world_state.has_signal("phase_changed") and not _world_state.is_connected("phase_changed", _on_phase_changed):
        _world_state.connect("phase_changed", _on_phase_changed)
    if _world_state.has_signal("world_state_changed") and not _world_state.is_connected("world_state_changed", _on_world_state_changed):
        _world_state.connect("world_state_changed", _on_world_state_changed)

func bind_gimmick(node: Node) -> void:
    _connect_once(node, &"launch_requested", _on_launch_requested)
    _connect_once(node, &"hazard_contact", _on_hazard_contact)
    _connect_once(node, &"phase_requested", _on_phase_requested)
    _connect_once(node, &"visibility_requested", _on_visibility_requested)
    _connect_once(node, &"visibility_restore_requested", _on_visibility_restore_requested)
    _connect_once(node, &"discovered", _on_discovered)
    if node.has_method("set_unlocked_abilities") and not _ability_gates.has(node):
        _ability_gates.append(node)
    if node.has_method("set_phase") and node.has_signal("gate_state_changed") and not _state_gates.has(node):
        _state_gates.append(node)
    if _world_state != null and _world_state.has_method("world_context"):
        _apply_context_to_gimmick(node, _world_state.call("world_context"))

func _connect_once(node: Node, signal_name: StringName, callable: Callable) -> void:
    if node.has_signal(signal_name) and not node.is_connected(signal_name, callable):
        node.connect(signal_name, callable)

func _on_launch_requested(body: Node, launch_velocity: Vector2, spring_id: StringName) -> void:
    spring_launch_requested.emit(body, launch_velocity, spring_id)

func _on_hazard_contact(body: Node, hazard_id: StringName, reason: StringName) -> void:
    hazard_contact.emit(body, hazard_id, reason)

func _on_phase_requested(stage_id: StringName, target_phase: StringName) -> void:
    if _world_state != null and _world_state.has_method("set_phase"):
        _world_state.call("set_phase", stage_id, target_phase)

func _on_visibility_requested(stage_id: StringName, visibility_scale: float) -> void:
    if _world_state != null and _world_state.has_method("set_visibility"):
        _world_state.call("set_visibility", stage_id, visibility_scale)

func _on_visibility_restore_requested(stage_id: StringName) -> void:
    if _world_state != null and _world_state.has_method("reset_visibility"):
        _world_state.call("reset_visibility", stage_id)

func _on_discovered(stage_id: StringName, kind: StringName, discovery_id: StringName) -> void:
    if _world_state == null:
        return
    if kind == &"secret" and _world_state.has_method("discover_secret"):
        _world_state.call("discover_secret", stage_id, discovery_id)
    elif kind == &"shortcut" and _world_state.has_method("discover_shortcut"):
        _world_state.call("discover_shortcut", stage_id, discovery_id)

func _on_phase_changed(stage_id: StringName, phase: StringName) -> void:
    for gate in _state_gates:
        if is_instance_valid(gate) and StringName(str(gate.get("stage_id"))) == stage_id:
            gate.call("set_phase", phase)

func _on_world_state_changed(context: Dictionary) -> void:
    for gate in _ability_gates:
        if is_instance_valid(gate):
            gate.call("set_unlocked_abilities", context.get("unlocked_abilities", []))
    var stage_id := StringName(str(context.get("stage_id", "")))
    var phase := StringName(str(context.get("phase", "")))
    if stage_id != &"" and phase != &"":
        _on_phase_changed(stage_id, phase)

func _apply_context_to_gimmick(node: Node, context: Dictionary) -> void:
    if node.has_method("set_unlocked_abilities"):
        node.call("set_unlocked_abilities", context.get("unlocked_abilities", []))
    if node.has_method("set_phase"):
        var node_stage := StringName(str(node.get("stage_id")))
        if node_stage == StringName(str(context.get("stage_id", ""))):
            node.call("set_phase", StringName(str(context.get("phase", "neutral"))))
