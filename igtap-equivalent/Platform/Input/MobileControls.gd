extends CanvasLayer

var _root: Control
var _regions: Dictionary = {}
var _visuals: Dictionary = {}
var _finger_actions: Dictionary = {}

func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _make_pad(&"move_left", "◀")
    _make_pad(&"move_right", "▶")
    _make_pad(&"jump", "JUMP")
    _make_pad(&"dash", "DASH")
    _make_pad(&"pause", "Ⅱ")
    get_viewport().size_changed.connect(_layout)
    IOSLayout.safe_area_changed.connect(func(_rect: Rect2): _layout())
    Lifecycle.app_backgrounded.connect(cancel_all_touches)
    call_deferred("_layout")

func _make_pad(action: StringName, label_text: String) -> void:
    var pad := ColorRect.new()
    pad.color = Color(0.09, 0.14, 0.18, 0.58)
    pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var label := Label.new()
    label.text = label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 20)
    pad.add_child(label)
    _root.add_child(pad)
    _visuals[action] = pad

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _assign_finger(touch.index, touch.position)
        else:
            _release_finger(touch.index)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        _assign_finger(drag.index, drag.position)

func _assign_finger(finger_id: int, position: Vector2) -> void:
    var next_action := _action_at(position)
    var previous_action: StringName = StringName(_finger_actions.get(finger_id, &""))
    if next_action == previous_action:
        return
    if previous_action != &"":
        InputRouter.set_touch_action(previous_action, finger_id, false)
    if next_action != &"":
        _finger_actions[finger_id] = next_action
        InputRouter.set_touch_action(next_action, finger_id, true)
    else:
        _finger_actions.erase(finger_id)

func _release_finger(finger_id: int) -> void:
    if not _finger_actions.has(finger_id):
        return
    var action: StringName = StringName(_finger_actions[finger_id])
    InputRouter.set_touch_action(action, finger_id, false)
    _finger_actions.erase(finger_id)

func cancel_all_touches() -> void:
    var finger_ids := _finger_actions.keys()
    for finger_id in finger_ids:
        _release_finger(int(finger_id))
    _finger_actions.clear()

func _action_at(position: Vector2) -> StringName:
    for action in [&"move_left", &"move_right", &"jump", &"dash", &"pause"]:
        var rect: Rect2 = _regions.get(action, Rect2())
        if rect.has_point(position):
            return action
    return &""

func _layout() -> void:
    if _root == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var safe := IOSLayout.safe_rect_in_viewport(viewport_size)
    var unit := clampf(viewport_size.y * 0.14, 76.0, 112.0)
    var gap := unit * 0.16
    var bottom := safe.end.y - gap
    _set_region(&"move_left", Rect2(Vector2(safe.position.x + gap, bottom - unit), Vector2(unit, unit)))
    _set_region(&"move_right", Rect2(Vector2(safe.position.x + gap * 2.0 + unit, bottom - unit), Vector2(unit, unit)))
    _set_region(&"jump", Rect2(Vector2(safe.end.x - gap * 2.0 - unit * 2.0, bottom - unit), Vector2(unit, unit)))
    _set_region(&"dash", Rect2(Vector2(safe.end.x - gap - unit, bottom - unit), Vector2(unit, unit)))
    _set_region(&"pause", Rect2(Vector2(safe.end.x - gap - unit * 0.72, safe.position.y + gap), Vector2(unit * 0.72, unit * 0.58)))

func _set_region(action: StringName, rect: Rect2) -> void:
    _regions[action] = rect
    var pad: ColorRect = _visuals[action]
    pad.position = rect.position
    pad.size = rect.size
