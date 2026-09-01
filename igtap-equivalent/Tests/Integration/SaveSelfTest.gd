extends Node

const TEST_PATH := "user://loopforge-c2-selftest.json"

var _failed := false

func _ready() -> void:
    _cleanup()
    SaveStore.configure_paths(TEST_PATH)

    SaveStore.set_setting(&"haptics_enabled", false)
    SaveStore.record_best_time(&"stage_a", 12.5)
    _check(SaveStore.save_now(&"selftest_first"), "first save failed")

    SaveStore.set_setting(&"master_volume", 0.75)
    _check(SaveStore.save_now(&"selftest_second"), "second save failed")
    _check(FileAccess.file_exists(TEST_PATH + ".bak"), "backup was not created")

    SaveStore.set_setting(&"haptics_enabled", true)
    _check(SaveStore.load_and_restore(), "primary load failed")
    _check(bool(SaveStore.get_setting(&"haptics_enabled", true)) == false, "settings restore failed")
    _check(absf(SaveStore.get_best_time(&"stage_a") - 12.5) < 0.001, "best time restore failed")

    var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    _check(corrupt != null, "unable to open primary for corruption test")
    if corrupt != null:
        corrupt.store_string("corrupted-primary")
        corrupt.close()
    _check(SaveStore.load_and_restore(), "backup recovery failed")
    _check(absf(SaveStore.get_best_time(&"stage_a") - 12.5) < 0.001, "backup best time restore failed")

    _write_v1_save()
    if FileAccess.file_exists(TEST_PATH + ".bak"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + ".bak"))
    _check(SaveStore.load_and_restore(), "v1 migration load failed")
    _check(absf(SaveStore.get_best_time(&"legacy") - 8.0) < 0.001, "v1 best time migration failed")

    _cleanup()
    if _failed:
        get_tree().quit(1)
    else:
        print("Loopforge C2 save self-test: PASS")
        get_tree().quit(0)

func _write_v1_save() -> void:
    var payload := {
        "schema_version": 1,
        "saved_at_unix": Time.get_unix_time_from_system(),
        "best_time_seconds": 8.0,
    }
    var payload_json := JSON.stringify(payload)
    var envelope := {
        "schema_version": 1,
        "payload_json": payload_json,
        "checksum_sha256": payload_json.sha256_text(),
    }
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    _check(file != null, "unable to write v1 fixture")
    if file != null:
        file.store_string(JSON.stringify(envelope))
        file.close()

func _check(value: bool, message: String) -> void:
    if value:
        return
    _failed = true
    push_error(message)

func _cleanup() -> void:
    for path in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
