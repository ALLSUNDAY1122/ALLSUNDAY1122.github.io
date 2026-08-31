class_name ProgressionCatalog
extends RefCounted

const DEFAULT_PATH := "res://Content/Progression/progression_v1.json"

var _raw: Dictionary = {}
var _by_id: Dictionary = {}
var _order: Array[StringName] = []

func load_from_path(path: String = DEFAULT_PATH) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR
    _raw = parsed
    _by_id.clear()
    _order.clear()
    for value in _raw.get("upgrades", []):
        if typeof(value) != TYPE_DICTIONARY:
            return ERR_INVALID_DATA
        var definition: Dictionary = value
        var upgrade_id := StringName(str(definition.get("id", "")))
        if upgrade_id == &"" or _by_id.has(upgrade_id):
            return ERR_INVALID_DATA
        _by_id[upgrade_id] = definition.duplicate(true)
        _order.append(upgrade_id)
    return OK

func has_upgrade(upgrade_id: StringName) -> bool:
    return _by_id.has(upgrade_id)

func upgrade(upgrade_id: StringName) -> Dictionary:
    return (_by_id.get(upgrade_id, {}) as Dictionary).duplicate(true)

func upgrade_ids() -> Array[StringName]:
    return _order.duplicate()

func base_clone_capacity() -> int:
    return maxi(int(_raw.get("base_clone_capacity", 1)), 1)

func per_stage_clone_cap() -> int:
    return maxi(int(_raw.get("per_stage_clone_cap", 3)), 1)

func ability_order() -> Array[StringName]:
    var result: Array[StringName] = []
    for value in _raw.get("ability_order", []):
        result.append(StringName(str(value)))
    return result

func session_a_mapping() -> Dictionary:
    return (_raw.get("session_a_mapping", {}) as Dictionary).duplicate(true)

func guardrails() -> Dictionary:
    return (_raw.get("balance_guardrails", {}) as Dictionary).duplicate(true)
