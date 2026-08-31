class_name UICatalog
extends RefCounted

const DEFAULT_PATH := "res://Content/UI/ui_catalog_v1.json"

var _raw: Dictionary = {}
var _loaded := false

func load_from_path(path: String = DEFAULT_PATH) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR
    _raw = parsed
    _loaded = true
    return OK

func upgrade_order() -> Array[StringName]:
    var result: Array[StringName] = []
    for value in _raw.get("upgrade_order", []):
        result.append(StringName(str(value)))
    return result

func upgrade_copy(upgrade_id: StringName) -> Dictionary:
    var upgrades: Dictionary = _raw.get("upgrades", {})
    return (upgrades.get(str(upgrade_id), {}) as Dictionary).duplicate(true)

func lock_reason_label(reason: StringName) -> String:
    var labels: Dictionary = _raw.get("lock_reason_labels", {})
    return str(labels.get(str(reason), str(reason).replace("_", " ")))

func accessibility() -> Dictionary:
    return (_raw.get("accessibility", {}) as Dictionary).duplicate(true)
