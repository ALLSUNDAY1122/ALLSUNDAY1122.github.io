extends Node

signal safe_area_changed(rect: Rect2)
var _last_safe := Rect2()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_viewport().size_changed.connect(_emit_if_changed)
    _emit_if_changed()

func safe_rect_in_viewport(viewport_size: Vector2) -> Rect2:
    var safe_px := DisplayServer.get_display_safe_area()
    var window_px := Vector2(DisplayServer.window_get_size())
    if safe_px.size.x <= 0 or safe_px.size.y <= 0 or window_px.x <= 0 or window_px.y <= 0:
        return Rect2(Vector2.ZERO, viewport_size)
    var scale := Vector2(viewport_size.x / window_px.x, viewport_size.y / window_px.y)
    return Rect2(Vector2(safe_px.position) * scale, Vector2(safe_px.size) * scale)

func _emit_if_changed() -> void:
    var current := safe_rect_in_viewport(get_viewport().get_visible_rect().size)
    if current != _last_safe:
        _last_safe = current
        safe_area_changed.emit(current)
