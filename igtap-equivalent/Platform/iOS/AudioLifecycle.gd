extends Node

signal audio_suspended(reason: StringName)
signal audio_resumed(reason: StringName)

var _suspended := false
var _saved_bus_mutes: Array[bool] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Lifecycle.app_backgrounded.connect(func(): suspend(&"background"))
    Lifecycle.app_foregrounded.connect(func(): resume(&"foreground"))
    Lifecycle.app_focus_lost.connect(func(): suspend(&"focus_lost"))
    Lifecycle.app_focus_gained.connect(func(): resume(&"focus_gained"))

func suspend(reason: StringName) -> void:
    if _suspended:
        return
    _suspended = true
    _saved_bus_mutes.clear()
    for index in range(AudioServer.bus_count):
        _saved_bus_mutes.append(AudioServer.is_bus_mute(index))
        AudioServer.set_bus_mute(index, true)
    audio_suspended.emit(reason)

func resume(reason: StringName) -> void:
    if not _suspended:
        return
    var count := mini(AudioServer.bus_count, _saved_bus_mutes.size())
    for index in range(count):
        AudioServer.set_bus_mute(index, _saved_bus_mutes[index])
    _saved_bus_mutes.clear()
    _suspended = false
    audio_resumed.emit(reason)
