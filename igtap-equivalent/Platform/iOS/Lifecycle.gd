extends Node

signal app_backgrounded
signal app_foregrounded
signal save_requested(reason: StringName)

var is_backgrounded := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        if not is_backgrounded:
            is_backgrounded = true
            InputRouter.clear_virtual_actions()
            save_requested.emit(&"application_paused")
            app_backgrounded.emit()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        if is_backgrounded:
            is_backgrounded = false
            app_foregrounded.emit()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_requested.emit(&"close_request")
