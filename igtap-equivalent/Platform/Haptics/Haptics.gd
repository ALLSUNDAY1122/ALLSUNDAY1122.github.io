extends Node

signal haptic_fired(kind: StringName)

var enabled := true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_enabled(value: bool) -> void:
    enabled = value

func light() -> void:
    _fire(&"light", 18, 0.35)

func medium() -> void:
    _fire(&"medium", 32, 0.60)

func success() -> void:
    _fire(&"success", 48, 0.85)

func error() -> void:
    _fire(&"error", 70, 1.0)

func _fire(kind: StringName, duration_ms: int, amplitude: float) -> void:
    if not enabled:
        return
    Input.vibrate_handheld(duration_ms, amplitude)
    haptic_fired.emit(kind)
