extends Node

signal save_completed(reason: StringName, path: String)
signal save_failed(reason: StringName, message: String)
signal load_completed(source: StringName, schema_version: int)
signal recovery_used(source: StringName)
signal offline_elapsed(seconds: float)
signal setting_changed(key: StringName, value: Variant)

const CURRENT_SCHEMA_VERSION := 2
const DEFAULT_SAVE_PATH := "user://loopforge-save.json"
const MAX_OFFLINE_SECONDS := 60.0 * 60.0 * 24.0 * 7.0

var save_path := DEFAULT_SAVE_PATH
var backup_path := DEFAULT_SAVE_PATH + ".bak"
var temp_path := DEFAULT_SAVE_PATH + ".tmp"

var _capture_callbacks: Dictionary = {}
var _restore_callbacks: Dictionary = {}
var _best_times: Dictionary = {}
var _settings: Dictionary = {
    "master_volume": 1.0,
    "music_volume": 1.0,
    "sfx_volume": 1.0,
    "haptics_enabled": true,
}
var _last_saved_at_unix := 0.0
var _primary_needs_repair := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Lifecycle.save_requested.connect(_on_save_requested)
    Lifecycle.app_foregrounded.connect(_on_app_foregrounded)

func configure_paths(primary_path: String) -> void:
    save_path = primary_path
    backup_path = primary_path + ".bak"
    temp_path = primary_path + ".tmp"

func register_section(section_name: StringName, capture: Callable, restore: Callable) -> void:
    if not capture.is_valid() or not restore.is_valid():
        push_error("SaveStore: invalid callbacks for %s" % section_name)
        return
    _capture_callbacks[section_name] = capture
    _restore_callbacks[section_name] = restore

func unregister_section(section_name: StringName) -> void:
    _capture_callbacks.erase(section_name)
    _restore_callbacks.erase(section_name)

func record_best_time(stage_id: StringName, elapsed_seconds: float) -> bool:
    if elapsed_seconds <= 0.0:
        return false
    var key := String(stage_id)
    var previous := float(_best_times.get(key, INF))
    if elapsed_seconds >= previous:
        return false
    _best_times[key] = elapsed_seconds
    return true

func get_best_time(stage_id: StringName, fallback := INF) -> float:
    return float(_best_times.get(String(stage_id), fallback))

func set_setting(key: StringName, value: Variant) -> void:
    _settings[String(key)] = value
    setting_changed.emit(key, value)

func get_setting(key: StringName, fallback: Variant = null) -> Variant:
    return _settings.get(String(key), fallback)

func request_save(reason: StringName = &"manual") -> bool:
    return save_now(reason)

func save_now(reason: StringName = &"manual") -> bool:
    var payload := _build_payload()
    var payload_json := JSON.stringify(payload)
    var envelope := {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "payload_json": payload_json,
        "checksum_sha256": payload_json.sha256_text(),
    }
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        save_failed.emit(reason, "unable to open temp save")
        return false
    file.store_string(JSON.stringify(envelope))
    file.flush()
    file.close()

    var primary_abs := ProjectSettings.globalize_path(save_path)
    var backup_abs := ProjectSettings.globalize_path(backup_path)
    var temp_abs := ProjectSettings.globalize_path(temp_path)

    if FileAccess.file_exists(save_path):
        if _primary_needs_repair:
            DirAccess.remove_absolute(primary_abs)
        else:
            if FileAccess.file_exists(backup_path):
                DirAccess.remove_absolute(backup_abs)
            var backup_error := DirAccess.rename_absolute(primary_abs, backup_abs)
            if backup_error != OK:
                save_failed.emit(reason, "unable to rotate primary save to backup")
                DirAccess.remove_absolute(temp_abs)
                return false

    var promote_error := DirAccess.rename_absolute(temp_abs, primary_abs)
    if promote_error != OK:
        save_failed.emit(reason, "unable to promote temp save")
        return false

    _primary_needs_repair = false
    _last_saved_at_unix = float(payload["saved_at_unix"])
    save_completed.emit(reason, save_path)
    return true

func load_and_restore() -> bool:
    var source: StringName = &"primary"
    var result := _read_verified(save_path)
    if not bool(result.get("ok", false)):
        if FileAccess.file_exists(save_path):
            _primary_needs_repair = true
        source = &"backup"
        result = _read_verified(backup_path)

    if not bool(result.get("ok", false)):
        if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(backup_path):
            _last_saved_at_unix = Time.get_unix_time_from_system()
            load_completed.emit(&"new_game", CURRENT_SCHEMA_VERSION)
            return true
        push_error("SaveStore: no valid primary or backup save")
        return false

    if source == &"backup":
        recovery_used.emit(&"backup")

    var payload_variant: Variant = result.get("payload", {})
    if typeof(payload_variant) != TYPE_DICTIONARY:
        return false
    var migrated := _migrate_payload(payload_variant)
    if migrated.is_empty():
        return false

    _apply_builtin_state(migrated)
    var sections_variant: Variant = migrated.get("sections", {})
    if typeof(sections_variant) == TYPE_DICTIONARY:
        var sections: Dictionary = sections_variant
        for section_name in _restore_callbacks.keys():
            var key := String(section_name)
            if sections.has(key):
                var restore: Callable = _restore_callbacks[section_name]
                restore.call(sections[key])

    _emit_offline_elapsed()
    load_completed.emit(source, int(migrated.get("schema_version", CURRENT_SCHEMA_VERSION)))
    return true

func _build_payload() -> Dictionary:
    var sections: Dictionary = {}
    for section_name in _capture_callbacks.keys():
        var capture: Callable = _capture_callbacks[section_name]
        sections[String(section_name)] = capture.call()
    return {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "saved_at_unix": Time.get_unix_time_from_system(),
        "best_times": _best_times.duplicate(true),
        "settings": _settings.duplicate(true),
        "sections": sections,
    }

func _read_verified(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "reason": "missing"}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "reason": "open_failed"}
    var text := file.get_as_text()
    file.close()
    var envelope_variant: Variant = JSON.parse_string(text)
    if typeof(envelope_variant) != TYPE_DICTIONARY:
        return {"ok": false, "reason": "invalid_envelope"}
    var envelope: Dictionary = envelope_variant
    var payload_json := String(envelope.get("payload_json", ""))
    var checksum := String(envelope.get("checksum_sha256", ""))
    if payload_json.is_empty() or checksum.is_empty() or payload_json.sha256_text() != checksum:
        return {"ok": false, "reason": "checksum_mismatch"}
    var payload_variant: Variant = JSON.parse_string(payload_json)
    if typeof(payload_variant) != TYPE_DICTIONARY:
        return {"ok": false, "reason": "invalid_payload"}
    return {"ok": true, "payload": payload_variant}

func _migrate_payload(source: Dictionary) -> Dictionary:
    var payload := source.duplicate(true)
    var version := int(payload.get("schema_version", 1))
    if version < 1 or version > CURRENT_SCHEMA_VERSION:
        push_error("SaveStore: unsupported schema version %d" % version)
        return {}
    while version < CURRENT_SCHEMA_VERSION:
        match version:
            1:
                if payload.has("best_time_seconds") and not payload.has("best_times"):
                    payload["best_times"] = {"legacy": float(payload.get("best_time_seconds", INF))}
                payload.erase("best_time_seconds")
                if not payload.has("settings"):
                    payload["settings"] = _settings.duplicate(true)
                if not payload.has("sections"):
                    payload["sections"] = {}
                version = 2
            _:
                return {}
    payload["schema_version"] = CURRENT_SCHEMA_VERSION
    return payload

func _apply_builtin_state(payload: Dictionary) -> void:
    var best_variant: Variant = payload.get("best_times", {})
    _best_times = best_variant.duplicate(true) if typeof(best_variant) == TYPE_DICTIONARY else {}
    var settings_variant: Variant = payload.get("settings", {})
    if typeof(settings_variant) == TYPE_DICTIONARY:
        var loaded_settings: Dictionary = settings_variant
        for key in loaded_settings.keys():
            _settings[String(key)] = loaded_settings[key]
    _last_saved_at_unix = float(payload.get("saved_at_unix", Time.get_unix_time_from_system()))

func _emit_offline_elapsed() -> void:
    if _last_saved_at_unix <= 0.0:
        return
    var now := Time.get_unix_time_from_system()
    var elapsed := clampf(now - _last_saved_at_unix, 0.0, MAX_OFFLINE_SECONDS)
    if elapsed > 0.0:
        offline_elapsed.emit(elapsed)
    _last_saved_at_unix = now

func _on_save_requested(reason: StringName) -> void:
    save_now(reason)

func _on_app_foregrounded() -> void:
    _emit_offline_elapsed()
