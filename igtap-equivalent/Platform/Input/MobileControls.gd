extends CanvasLayer

var _root: Control
var _buttons := {}

func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_root)
    _make_hold_button(&"move_left", "◀")
    _make_hold_button(&"move_right", "▶")
    _make_hold_button(&"jump", "JUMP")
    _make_hold_button(&"dash", "DASH")
    _make_tap_button(&"pause", "Ⅱ")
    get_viewport().size_changed.connect(_layout)
    call_deferred("_layout")

func _make_hold_button(action: StringName, label: String) -> void:
    var button := Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_NONE
    button.modulate.a = 0.72
    button.button_down.connect(func(): InputRouter.set_virtual_action(action, true))
    button.button_up.connect(func(): InputRouter.set_virtual_action(action, false))
    button.mouse_exited.connect(func(): InputRouter.set_virtual_action(action, false))
    _root.add_child(button)
    _buttons[action] = button

func _make_tap_button(action: StringName, label: String) -> void:
    var button := Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_NONE
    button.modulate.a = 0.72
    button.button_down.connect(func(): InputRouter.set_virtual_action(action, true))
    button.button_up.connect(func(): InputRouter.set_virtual_action(action, false))
    _root.add_child(button)
    _buttons[action] = button

func _layout() -> void:
    if _root == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var safe := IOSLayout.safe_rect_in_viewport(viewport_size)
    var unit := clampf(viewport_size.y * 0.14, 76.0, 112.0)
    var gap := unit * 0.16
    var bottom := safe.end.y - gap
    _place(&"move_left", Vector2(safe.position.x + gap, bottom - unit), Vector2(unit, unit))
    _place(&"move_right", Vector2(safe.position.x + gap * 2.0 + unit, bottom - unit), Vector2(unit, unit))
    _place(&"jump", Vector2(safe.end.x - gap * 2.0 - unit * 2.0, bottom - unit), Vector2(unit, unit))
    _place(&"dash", Vector2(safe.end.x - gap - unit, bottom - unit), Vector2(unit, unit))
    _place(&"pause", Vector2(safe.end.x - gap - unit * 0.72, safe.position.y + gap), Vector2(unit * 0.72, unit * 0.58))

func _place(action: StringName, position: Vector2, size: Vector2) -> void:
    var button: Button = _buttons[action]
    button.position = position
    button.size = size
