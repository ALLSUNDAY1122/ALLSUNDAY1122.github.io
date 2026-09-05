class_name CoreGameplayCompat
extends CharacterBody2D

signal player_died(reason: StringName)
signal player_respawned(checkpoint_id: StringName)
signal checkpoint_reached(checkpoint_id: StringName)
signal lap_completed(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary)
signal recording_completed(stage_id: StringName, replay_payload: Dictionary)

const FIXED_HZ := 120.0
const PPU := 64.0
const MAX_REPLAY_FRAMES := 18000

var _input: Node
var _abilities: Dictionary = {}
var _stage_context: Dictionary = {"stage_id": &"relay_yard"}
var _movement_effects := {"run_speed_multiplier": 1.0, "jump_multiplier": 1.0}

var _tick := 0
var _facing := 1.0
var _jump_buffer_left := 0.0
var _coyote_left := 0.0
var _wall_grace_left := 0.0
var _wall_normal := Vector2.ZERO
var _dash_left := 0.0
var _wall_control_lock_left := 0.0
var _air_jumps_left := 0
var _air_dash_available := true
var _jump_was_pressed := false
var _alive := true
var _dead_left := 0.0

var _stage_spawn := Vector2.ZERO
var _checkpoint_spawn := Vector2.ZERO
var _checkpoint_id: StringName = &"start"

var _lap_active := false
var _lap_stage_id: StringName = &""
var _lap_start_tick := 0
var _recording_frames: Array[Dictionary] = []
var _recording_markers: Array[Dictionary] = []
var _pending_finish_stage: StringName = &""
var _best_recordings: Dictionary = {}

var _clones: Dictionary = {}
var _ghost_nodes: Dictionary = {}
var _next_clone_id := 1

var _config := {
    "half_size": Vector2(0.35, 0.45),
    "max_run_speed": 7.0,
    "ground_acceleration": 60.0,
    "ground_deceleration": 70.0,
    "air_acceleration": 34.0,
    "air_deceleration": 18.0,
    "air_overspeed_deceleration": 7.0,
    "jump_speed": 12.0,
    "air_jump_speed": 11.5,
    "gravity": 34.0,
    "max_fall_speed": 22.0,
    "jump_cut_multiplier": 0.45,
    "coyote_time": 0.10,
    "jump_buffer_time": 0.11,
    "wall_grace_time": 0.10,
    "wall_jump_horizontal_speed": 9.0,
    "wall_jump_vertical_speed": 11.5,
    "wall_jump_control_lock_time": 0.09,
    "max_air_jumps": 1,
    "dash_speed": 15.5,
    "dash_duration": 0.13,
    "dash_buffer_time": 0.10,
    "dash_exit_speed_retain": 0.82,
    "respawn_delay": 0.20
}

func _ready() -> void:
    add_to_group(&"player")
    up_direction = Vector2.UP
    floor_snap_length = 6.0
    _build_body()
    _checkpoint_spawn = global_position
    _stage_spawn = global_position
    _air_jumps_left = int(_config["max_air_jumps"])

func _build_body() -> void:
    if get_node_or_null("CollisionShape2D") == null:
        var shape := RectangleShape2D.new()
        shape.size = Vector2(_config["half_size"]) * 2.0 * PPU
        var collision := CollisionShape2D.new()
        collision.name = "CollisionShape2D"
        collision.shape = shape
        add_child(collision)
    if get_node_or_null("PlayerVisual") == null:
        var half := Vector2(_config["half_size"]) * PPU
        var visual := Polygon2D.new()
        visual.name = "PlayerVisual"
        visual.polygon = PackedVector2Array([
            Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
            Vector2(half.x, half.y), Vector2(-half.x, half.y)
        ])
        visual.color = Color(0.95, 0.72, 0.20, 1.0)
        add_child(visual)
    if get_node_or_null("Camera2D") == null:
        var camera := Camera2D.new()
        camera.name = "Camera2D"
        camera.enabled = true
        camera.position = Vector2(150.0, -70.0)
        camera.position_smoothing_enabled = true
        camera.position_smoothing_speed = 8.0
        add_child(camera)

func set_input_provider(provider: Node) -> void:
    _input = provider

func apply_ability_set(ability_ids: Array[StringName]) -> void:
    _abilities.clear()
    for value in ability_ids:
        var ability_id := StringName(str(value))
        match ability_id:
            &"dash": _abilities[&"dash"] = true
            &"double_jump", &"airJump", &"air_jump": _abilities[&"airJump"] = true
            &"wall_jump", &"wallJump": _abilities[&"wallJump"] = true
            _: pass
    if not has_ability(&"airJump"):
        _air_jumps_left = 0
    if not has_ability(&"dash"):
        _dash_left = 0.0
        _air_dash_available = false

func apply_movement_effects(effects: Dictionary) -> void:
    _movement_effects["run_speed_multiplier"] = clampf(float(effects.get("run_speed_multiplier", 1.0)), 0.5, 4.0)
    _movement_effects["jump_multiplier"] = clampf(float(effects.get("jump_multiplier", 1.0)), 0.5, 4.0)

func set_stage_context(context: Dictionary) -> void:
    if context.is_empty():
        return
    _stage_context = context.duplicate(true)
    var stage_id := StringName(str(context.get("stage_id", _lap_stage_id)))
    if stage_id != &"" and stage_id != _lap_stage_id and _lap_active:
        cancel_lap()

func set_stage_spawn(world_position: Vector2) -> void:
    _stage_spawn = world_position
    _checkpoint_spawn = world_position
    _checkpoint_id = &"start"
    _respawn_now(false)

func begin_lap(stage_id: StringName) -> bool:
    if stage_id == &"":
        return false
    if _lap_active and _lap_stage_id == stage_id:
        return false
    _lap_active = true
    _lap_stage_id = stage_id
    _lap_start_tick = _tick
    _recording_frames.clear()
    _recording_markers.clear()
    _pending_finish_stage = &""
    return true

func finish_lap(stage_id: StringName) -> bool:
    if not _lap_active or stage_id != _lap_stage_id:
        return false
    _pending_finish_stage = stage_id
    return true

func cancel_lap() -> void:
    _lap_active = false
    _lap_stage_id = &""
    _recording_frames.clear()
    _recording_markers.clear()
    _pending_finish_stage = &""

func reach_checkpoint(checkpoint_id: StringName, spawn_position: Vector2 = Vector2.INF) -> void:
    if checkpoint_id == &"" or checkpoint_id == _checkpoint_id:
        return
    _checkpoint_id = checkpoint_id
    if spawn_position != Vector2.INF:
        _checkpoint_spawn = spawn_position
    _record_marker(&"checkpoint")
    checkpoint_reached.emit(checkpoint_id)

func launch(launch_velocity: Vector2) -> void:
    var resolved := launch_velocity * PPU if launch_velocity.length() < 100.0 else launch_velocity
    velocity = resolved
    _dash_left = 0.0
    _air_dash_available = has_ability(&"dash")

func kill(reason: StringName = &"world_hazard") -> void:
    if not _alive:
        return
    _alive = false
    _dead_left = float(_config["respawn_delay"])
    velocity = Vector2.ZERO
    _record_marker(&"death")
    player_died.emit(reason)

func has_ability(ability_id: StringName) -> bool:
    return bool(_abilities.get(ability_id, false))

func effective_max_run_speed_px() -> float:
    return float(_config["max_run_speed"]) * PPU * float(_movement_effects["run_speed_multiplier"])

func movement_snapshot() -> Dictionary:
    return {
        "run_speed_multiplier": float(_movement_effects["run_speed_multiplier"]),
        "jump_multiplier": float(_movement_effects["jump_multiplier"]),
        "max_run_speed_px": effective_max_run_speed_px(),
        "abilities": _abilities.keys()
    }

func _physics_process(delta: float) -> void:
    _tick += 1
    if not _alive:
        _dead_left = maxf(0.0, _dead_left - delta)
        if _lap_active:
            _capture_frame(0.0)
        _step_clones()
        if _dead_left <= 0.0:
            _respawn_now(true)
        return
    if _input == null:
        _step_clones()
        return

    var on_floor_before := is_on_floor()
    var on_wall_before := is_on_wall()
    if on_floor_before:
        _coyote_left = float(_config["coyote_time"])
        _air_jumps_left = int(_config["max_air_jumps"]) if has_ability(&"airJump") else 0
        _air_dash_available = has_ability(&"dash")
    else:
        _coyote_left = maxf(0.0, _coyote_left - delta)
    if on_wall_before:
        _wall_grace_left = float(_config["wall_grace_time"])
        _wall_normal = get_wall_normal()
    else:
        _wall_grace_left = maxf(0.0, _wall_grace_left - delta)

    var axis := float(_input.is_pressed(&"move_right")) - float(_input.is_pressed(&"move_left"))
    if absf(axis) > 0.01:
        _facing = signf(axis)
    var jump_edge := bool(_input.consume_pressed(&"jump"))
    var dash_edge := bool(_input.consume_pressed(&"dash"))
    var jump_pressed := bool(_input.is_pressed(&"jump"))
    if jump_edge:
        _jump_buffer_left = float(_config["jump_buffer_time"])
    else:
        _jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

    var jump_pending := _jump_buffer_left > 0.0
    var wall_valid := has_ability(&"wallJump") and _wall_grace_left > 0.0
    if jump_pending and wall_valid:
        _perform_wall_jump()
    elif jump_pending and dash_edge and (on_floor_before or _coyote_left > 0.0) and has_ability(&"dash"):
        _perform_ground_dash_jump(axis)
    elif jump_pending:
        _attempt_jump(on_floor_before)
    elif dash_edge:
        _attempt_dash(axis, on_floor_before)

    if _wall_control_lock_left > 0.0:
        _wall_control_lock_left = maxf(0.0, _wall_control_lock_left - delta)
    if _dash_left > 0.0:
        _dash_left = maxf(0.0, _dash_left - delta)
        velocity.x = _facing * float(_config["dash_speed"]) * PPU
        velocity.y = minf(velocity.y, 0.0)
        if _dash_left <= 0.0:
            velocity.x *= float(_config["dash_exit_speed_retain"])
    else:
        _apply_horizontal(axis, on_floor_before, delta)
        velocity.y = minf(velocity.y + float(_config["gravity"]) * PPU * delta, float(_config["max_fall_speed"]) * PPU)

    if _jump_was_pressed and not jump_pressed and velocity.y < 0.0 and _dash_left <= 0.0:
        velocity.y *= float(_config["jump_cut_multiplier"])
    _jump_was_pressed = jump_pressed

    move_and_slide()
    if is_on_floor():
        _air_jumps_left = int(_config["max_air_jumps"]) if has_ability(&"airJump") else 0
        _air_dash_available = has_ability(&"dash")
    if global_position.y > 1800.0:
        kill(&"fall")

    if _lap_active:
        _capture_frame(axis)
    _step_clones()
    if _pending_finish_stage != &"":
        _finalize_lap(_pending_finish_stage)

func _apply_horizontal(axis: float, on_floor_before: bool, delta: float) -> void:
    if _wall_control_lock_left > 0.0:
        return
    var target := axis * effective_max_run_speed_px()
    var accel_units := float(_config["ground_acceleration"] if on_floor_before else _config["air_acceleration"])
    var decel_units := float(_config["ground_deceleration"] if on_floor_before else _config["air_deceleration"])
    var rate := accel_units if absf(axis) > 0.01 else decel_units
    if not on_floor_before and absf(velocity.x) > effective_max_run_speed_px() and absf(axis) > 0.01:
        rate = float(_config["air_overspeed_deceleration"])
    velocity.x = move_toward(velocity.x, target, rate * PPU * delta)

func _attempt_jump(on_floor_before: bool) -> bool:
    if on_floor_before or _coyote_left > 0.0:
        velocity.y = -float(_config["jump_speed"]) * PPU * float(_movement_effects["jump_multiplier"])
        _jump_buffer_left = 0.0
        _coyote_left = 0.0
        return true
    if has_ability(&"airJump") and _air_jumps_left > 0:
        velocity.y = -float(_config["air_jump_speed"]) * PPU * float(_movement_effects["jump_multiplier"])
        _air_jumps_left -= 1
        _jump_buffer_left = 0.0
        return true
    return false

func _perform_wall_jump() -> void:
    var away := _wall_normal.x
    if absf(away) < 0.1:
        away = -_facing
    _facing = signf(away)
    velocity.x = _facing * float(_config["wall_jump_horizontal_speed"]) * PPU
    velocity.y = -float(_config["wall_jump_vertical_speed"]) * PPU * float(_movement_effects["jump_multiplier"])
    _wall_control_lock_left = float(_config["wall_jump_control_lock_time"])
    _wall_grace_left = 0.0
    _jump_buffer_left = 0.0

func _perform_ground_dash_jump(axis: float) -> void:
    if absf(axis) > 0.01:
        _facing = signf(axis)
    _dash_left = float(_config["dash_duration"])
    velocity.x = _facing * float(_config["dash_speed"]) * PPU
    velocity.y = -float(_config["jump_speed"]) * PPU * float(_movement_effects["jump_multiplier"])
    _jump_buffer_left = 0.0
    _air_dash_available = false

func _attempt_dash(axis: float, on_floor_before: bool) -> bool:
    if not has_ability(&"dash"):
        return false
    if not on_floor_before and not _air_dash_available:
        return false
    if absf(axis) > 0.01:
        _facing = signf(axis)
    _dash_left = float(_config["dash_duration"])
    velocity.x = _facing * float(_config["dash_speed"]) * PPU
    velocity.y = 0.0
    if not on_floor_before:
        _air_dash_available = false
    return true

func _record_marker(kind: StringName) -> void:
    if _lap_active:
        _recording_markers.append({"tick": _tick, "kind": str(kind)})

func _capture_frame(axis: float) -> void:
    if _recording_frames.size() >= MAX_REPLAY_FRAMES:
        cancel_lap()
        return
    _recording_frames.append({
        "tick": _tick,
        "position": [global_position.x, global_position.y],
        "velocity": [velocity.x, velocity.y],
        "input": {"move_axis": axis, "jump": _jump_was_pressed, "dash_active": _dash_left > 0.0},
        "locomotion": _locomotion_state(),
        "air_jumps_left": _air_jumps_left,
        "air_dash_available": _air_dash_available,
        "facing": int(_facing),
        "alive": _alive
    })

func _locomotion_state() -> String:
    if not _alive:
        return "dead"
    if _dash_left > 0.0:
        return "dash"
    if is_on_floor():
        return "ground"
    if is_on_wall():
        return "wall"
    return "air"

func _finalize_lap(stage_id: StringName) -> void:
    _pending_finish_stage = &""
    if not _lap_active or stage_id != _lap_stage_id:
        return
    if _recording_frames.is_empty():
        _capture_frame(0.0)
    _record_marker(&"lap_complete")
    var payload := _build_recording_payload(stage_id, _recording_frames, _recording_markers)
    var elapsed_seconds := maxf(1.0 / FIXED_HZ, float(_tick - _lap_start_tick + 1) / FIXED_HZ)
    _lap_active = false
    if not payload.is_empty():
        var previous: Dictionary = _best_recordings.get(stage_id, {})
        if previous.is_empty() or int(payload.get("duration_ticks", 0)) < int(previous.get("duration_ticks", 1 << 30)):
            _best_recordings[stage_id] = payload.duplicate(true)
        recording_completed.emit(stage_id, payload)
    lap_completed.emit(stage_id, elapsed_seconds, payload)
    _checkpoint_id = &"start"
    _checkpoint_spawn = _stage_spawn
    _respawn_now(false)
    begin_lap(stage_id)

func _build_recording_payload(stage_id: StringName, frames: Array, markers: Array) -> Dictionary:
    if frames.is_empty():
        return {}
    var first_tick := int((frames[0] as Dictionary).get("tick", -1))
    for index in range(frames.size()):
        if int((frames[index] as Dictionary).get("tick", -1)) != first_tick + index:
            return {}
    var resolved_markers: Array[Dictionary] = []
    for marker_value in markers:
        var marker: Dictionary = marker_value
        var frame_index := int(marker.get("tick", -1)) - first_tick
        if frame_index >= 0 and frame_index < frames.size():
            resolved_markers.append({"tick": int(marker["tick"]), "frame_index": frame_index, "kind": str(marker.get("kind", ""))})
    return {
        "format_version": 1,
        "course_id": str(stage_id),
        "fixed_hz": int(FIXED_HZ),
        "duration_ticks": frames.size(),
        "duration": float(frames.size()) / FIXED_HZ,
        "route_quality": 1.0,
        "frames": frames.duplicate(true),
        "markers": resolved_markers
    }

func validate_recording(recording: Dictionary) -> bool:
    if int(recording.get("format_version", -1)) != 1:
        return false
    var frames: Array = recording.get("frames", [])
    if frames.is_empty():
        return false
    var first_tick := int((frames[0] as Dictionary).get("tick", -1))
    for index in range(frames.size()):
        if int((frames[index] as Dictionary).get("tick", -1)) != first_tick + index:
            return false
    for marker_value in recording.get("markers", []):
        var marker: Dictionary = marker_value
        var frame_index := int(marker.get("frame_index", -1))
        if frame_index < 0 or frame_index >= frames.size():
            return false
        if int(marker.get("tick", -2)) != int((frames[frame_index] as Dictionary).get("tick", -1)):
            return false
    return true

func best_recording(stage_id: StringName) -> Dictionary:
    var value: Dictionary = _best_recordings.get(stage_id, {})
    return value.duplicate(true)

func reconcile_clones(stage_id: StringName, desired_count: int) -> int:
    desired_count = maxi(desired_count, 0)
    var recording := best_recording(stage_id)
    _remove_stage_clones(stage_id)
    if desired_count <= 0 or not validate_recording(recording):
        return 0
    var frames: Array = recording.get("frames", [])
    for index in range(desired_count):
        var clone_id := _next_clone_id
        _next_clone_id += 1
        var phase := 0 if desired_count <= 1 else int(float(index) * float(frames.size()) / float(desired_count))
        _clones[clone_id] = {"stage_id": stage_id, "recording": recording.duplicate(true), "cursor": phase, "loop": true}
        _ghost_nodes[clone_id] = _create_ghost()
    return desired_count

func clone_count(stage_id: StringName = &"") -> int:
    var count := 0
    for clone_value in _clones.values():
        var clone: Dictionary = clone_value
        if stage_id == &"" or StringName(str(clone.get("stage_id", ""))) == stage_id:
            count += 1
    return count

func _remove_stage_clones(stage_id: StringName) -> void:
    var ids: Array = _clones.keys()
    for clone_id in ids:
        var clone: Dictionary = _clones[clone_id]
        if StringName(str(clone.get("stage_id", ""))) == stage_id:
            _clones.erase(clone_id)
            var ghost: Node = _ghost_nodes.get(clone_id)
            if ghost != null and is_instance_valid(ghost):
                ghost.queue_free()
            _ghost_nodes.erase(clone_id)

func _create_ghost() -> Node2D:
    var ghost := Polygon2D.new()
    var half := Vector2(_config["half_size"]) * PPU
    ghost.polygon = PackedVector2Array([
        Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
        Vector2(half.x, half.y), Vector2(-half.x, half.y)
    ])
    ghost.color = Color(0.40, 0.82, 1.0, 0.35)
    if get_parent() != null:
        get_parent().add_child(ghost)
    return ghost

func _step_clones() -> void:
    for clone_id in _clones.keys():
        var clone: Dictionary = _clones[clone_id]
        var recording: Dictionary = clone.get("recording", {})
        var frames: Array = recording.get("frames", [])
        if frames.is_empty():
            continue
        var cursor := int(clone.get("cursor", 0))
        if cursor >= frames.size():
            if bool(clone.get("loop", true)):
                cursor = 0
            else:
                continue
        var frame: Dictionary = frames[cursor]
        var pos: Array = frame.get("position", [0.0, 0.0])
        var ghost: Node2D = _ghost_nodes.get(clone_id)
        if ghost != null and is_instance_valid(ghost) and pos.size() >= 2:
            ghost.global_position = Vector2(float(pos[0]), float(pos[1]))
            ghost.visible = bool(frame.get("alive", true))
        clone["cursor"] = cursor + 1
        _clones[clone_id] = clone

func serialize_state() -> Dictionary:
    var best: Dictionary = {}
    for stage_id in _best_recordings.keys():
        var recording: Dictionary = _best_recordings[stage_id]
        if validate_recording(recording):
            best[str(stage_id)] = recording.duplicate(true)
    return {"schema_version": 1, "best_recordings": best}

func restore_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    _best_recordings.clear()
    var best: Dictionary = state.get("best_recordings", {})
    for key in best.keys():
        var recording: Dictionary = best[key]
        if validate_recording(recording):
            _best_recordings[StringName(str(key))] = recording.duplicate(true)
    return true

func debug_complete_lap(stage_id: StringName, elapsed_seconds: float) -> Dictionary:
    var frame_count := clampi(int(round(maxf(elapsed_seconds, 0.1) * FIXED_HZ)), 2, 2400)
    var frames: Array[Dictionary] = []
    for index in range(frame_count):
        frames.append({
            "tick": index,
            "position": [float(index), 0.0],
            "velocity": [1.0, 0.0],
            "input": {"move_axis": 1.0, "jump": false, "dash_active": false},
            "locomotion": "ground",
            "air_jumps_left": 0,
            "air_dash_available": false,
            "facing": 1,
            "alive": true
        })
    var payload := _build_recording_payload(stage_id, frames, [])
    var previous: Dictionary = _best_recordings.get(stage_id, {})
    if previous.is_empty() or int(payload.get("duration_ticks", 0)) < int(previous.get("duration_ticks", 1 << 30)):
        _best_recordings[stage_id] = payload.duplicate(true)
    recording_completed.emit(stage_id, payload)
    lap_completed.emit(stage_id, elapsed_seconds, payload)
    return payload

func _respawn_now(emit_signal: bool) -> void:
    _alive = true
    _dead_left = 0.0
    global_position = _checkpoint_spawn
    velocity = Vector2.ZERO
    _dash_left = 0.0
    _air_jumps_left = int(_config["max_air_jumps"]) if has_ability(&"airJump") else 0
    _air_dash_available = has_ability(&"dash")
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera.reset_smoothing()
    if emit_signal:
        player_respawned.emit(_checkpoint_id)
