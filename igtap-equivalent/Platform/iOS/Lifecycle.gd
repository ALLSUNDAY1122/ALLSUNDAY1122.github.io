extends Node

signal app_backgrounded
signal app_foregrounded
signal save_requested(reason: StringName)

var is_backgrounded := false
var _paused_before_background := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        _enter_background()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        _return_foreground()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_requested.emit(&"close_request")

func _enter_background() -> void:
    if is_backgrounded:
        return
    is_backgrounded = true
    _paused_before_background = get_tree().paused
    get_tree().paused = true
    InputRouter.clear_virtual_actions()
    save_requested.emit(&"application_paused")
    app_backgrounded.emit()

func _return_foreground() -> void:
    if not is_backgrounded:
        return
    InputRouter.clear_virtual_actions()
    is_backgrounded = false
    get_tree().paused = _paused_before_background
    app_foregrounded.emit()
