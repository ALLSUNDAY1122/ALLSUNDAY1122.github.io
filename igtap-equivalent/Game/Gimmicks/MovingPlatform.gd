class_name MovingPlatform
extends AnimatableBody2D

@export var travel_offset := Vector2(180.0, 0.0)
@export_range(0.1, 30.0, 0.1) var one_way_seconds := 2.5
@export_range(0.0, 1.0, 0.01) var phase_offset := 0.0

var _origin := Vector2.ZERO
var _elapsed := 0.0

func _ready() -> void:
    _origin = position
    _elapsed = phase_offset * one_way_seconds * 2.0

func _physics_process(delta: float) -> void:
    if one_way_seconds <= 0.0:
        return
    var period := one_way_seconds * 2.0
    _elapsed = fmod(_elapsed + maxf(delta, 0.0), period)
    var t := _elapsed / one_way_seconds
    var ping_pong := t if t <= 1.0 else 2.0 - t
    position = _origin.lerp(_origin + travel_offset, clampf(ping_pong, 0.0, 1.0))
