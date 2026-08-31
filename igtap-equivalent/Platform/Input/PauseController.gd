extends Node

signal pause_changed(paused: bool)

var _user_paused := false
var _overlay: CanvasLayer
var _panel: ColorRect
var _label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_overlay()

func _process(_delta: float) -> void:
    if InputRouter.consume_pressed(&"pause"):
        set_user_paused(not _user_paused)

func set_user_paused(paused: bool) -> void:
    if _user_paused == paused:
        return
    _user_paused = paused
    if not Lifecycle.is_backgrounded:
        get_tree().paused = _user_paused
    _update_overlay()
    pause_changed.emit(_user_paused)

func is_user_paused() -> bool:
    return _user_paused

func _build_overlay() -> void:
    _overlay = CanvasLayer.new()
    _overlay.layer = 120
    add_child(_overlay)
    _panel = ColorRect.new()
    _panel.color = Color(0.02, 0.03, 0.05, 0.56)
    _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(_panel)
    _label = Label.new()
    _label.text = "PAUSED"
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", 34)
    _overlay.add_child(_label)
    _update_overlay()

func _update_overlay() -> void:
    if _overlay != null:
        _overlay.visible = _user_paused
