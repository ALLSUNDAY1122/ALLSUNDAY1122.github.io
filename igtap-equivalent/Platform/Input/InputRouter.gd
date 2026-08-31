extends Node

signal action_changed(action: StringName, pressed: bool)

const ACTIONS := [&"move_left", &"move_right", &"jump", &"dash", &"pause", &"restart"]
var _virtual_sources: Dictionary = {}
var _previous: Dictionary = {}
var _edges: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for action in ACTIONS:
        _virtual_sources[action] = {}
        _previous[action] = false
        _edges[action] = false

func _process(_delta: float) -> void:
    var keyboard := {
        &"move_left": Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT),
        &"move_right": Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT),
        &"jump": Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Z),
        &"dash": Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_X),
        &"pause": Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_P),
        &"restart": Input.is_key_pressed(KEY_R),
    }
    for action in ACTIONS:
        var now: bool = _has_virtual_source(action) or bool(keyboard.get(action, false))
        var before: bool = bool(_previous.get(action, false))
        if now and not before:
            _edges[action] = true
        if now != before:
            action_changed.emit(action, now)
        _previous[action] = now

func _has_virtual_source(action: StringName) -> bool:
    var sources: Dictionary = _virtual_sources.get(action, {})
    return not sources.is_empty()

func set_virtual_action(action: StringName, pressed: bool, source: StringName = &"legacy") -> void:
    if action not in ACTIONS:
        push_warning("Unknown virtual action: %s" % action)
        return
    var sources: Dictionary = _virtual_sources.get(action, {})
    if pressed:
        sources[source] = true
    else:
        sources.erase(source)
    _virtual_sources[action] = sources

func set_touch_action(action: StringName, finger_id: int, pressed: bool) -> void:
    set_virtual_action(action, pressed, StringName("touch_%d" % finger_id))

func release_source(source: StringName) -> void:
    for action in ACTIONS:
        var sources: Dictionary = _virtual_sources.get(action, {})
        if sources.erase(source):
            _virtual_sources[action] = sources

func is_pressed(action: StringName) -> bool:
    return bool(_previous.get(action, false))

func consume_pressed(action: StringName) -> bool:
    if bool(_edges.get(action, false)):
        _edges[action] = false
        return true
    return false

func clear_virtual_actions() -> void:
    for action in ACTIONS:
        var sources: Dictionary = _virtual_sources.get(action, {})
        sources.clear()
        _virtual_sources[action] = sources
        _edges[action] = false
