class_name MockCoreGameplay
extends Node2D

signal player_died(reason: StringName)
signal player_respawned(checkpoint_id: StringName)
signal checkpoint_reached(checkpoint_id: StringName)
signal lap_completed(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary)

var _input: Node
var _position := Vector2(120, 500)
var _velocity := Vector2.ZERO
var _elapsed := 0.0
var _dash_left := 0.0
var _can_dash := true
var _abilities: Array[StringName] = []
var _context := {"stage_id": &"mock_loop", "goal_x": 1140.0}
var _trace: Array = []

func set_input_provider(provider: Node) -> void:
    _input = provider

func apply_ability_set(ability_ids: Array[StringName]) -> void:
    _abilities = ability_ids.duplicate()

func set_stage_context(context: Dictionary) -> void:
    if not context.is_empty():
        _context = context.duplicate(true)

func spawn_at(_checkpoint_id: StringName) -> void:
    _position = Vector2(120, 500)
    _velocity = Vector2.ZERO
    _elapsed = 0.0
    _can_dash = true
    _trace.clear()
    player_respawned.emit(&"start")
    queue_redraw()

func _ready() -> void:
    set_physics_process(true)
    spawn_at(&"start")

func _physics_process(delta: float) -> void:
    if _input == null:
        return
    _elapsed += delta
    var axis := float(_input.is_pressed(&"move_right")) - float(_input.is_pressed(&"move_left"))
    _velocity.x = axis * 330.0
    if _dash_left > 0.0:
        _dash_left -= delta
        _velocity.x = (1.0 if axis >= 0.0 else -1.0) * 760.0
    elif _input.consume_pressed(&"dash") and _can_dash:
        _dash_left = 0.14
        _can_dash = false
    _velocity.y += 1350.0 * delta
    if _position.y >= 500.0:
        _position.y = 500.0
        _velocity.y = 0.0
        _can_dash = true
        if _input.consume_pressed(&"jump"):
            _velocity.y = -570.0
    _position += _velocity * delta
    if _position.y > 760.0:
        player_died.emit(&"fall")
        spawn_at(&"start")
    if _position.x >= float(_context.get("goal_x", 1140.0)):
        var payload := {"samples": _trace.duplicate(true), "duration": _elapsed}
        lap_completed.emit(StringName(_context.get("stage_id", &"mock_loop")), _elapsed, payload)
        spawn_at(&"start")
    _position.x = clampf(_position.x, 40.0, 1240.0)
    _trace.append({"t": _elapsed, "x": _position.x, "y": _position.y})
    if _trace.size() > 3600:
        _trace.pop_front()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0, 540, 1280, 180), Color("18242e"))
    draw_rect(Rect2(1110, 380, 28, 160), Color("7ed6a5"))
    draw_circle(_position, 24.0, Color("f4d35e"))
    draw_line(Vector2(0, 540), Vector2(1280, 540), Color("8ba6b2"), 4.0)
