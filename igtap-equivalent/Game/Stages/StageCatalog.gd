class_name StageCatalog
extends RefCounted

const DEFAULT_PATH := "res://Content/Stages/stage_catalog_v1.json"

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
    var stages: Array = _raw.get("stages", [])
    for stage_value in stages:
        if typeof(stage_value) != TYPE_DICTIONARY:
            return ERR_INVALID_DATA
        var stage: Dictionary = stage_value
        var stage_id := StringName(str(stage.get("id", "")))
        if stage_id == &"" or _by_id.has(stage_id):
            return ERR_INVALID_DATA
        _by_id[stage_id] = stage.duplicate(true)
    for stage_id_value in _raw.get("stage_order", []):
        var stage_id := StringName(str(stage_id_value))
        if not _by_id.has(stage_id):
            return ERR_INVALID_DATA
        _order.append(stage_id)
    if _order.size() != _by_id.size():
        return ERR_INVALID_DATA
    return OK

func stage(stage_id: StringName) -> Dictionary:
    return _by_id.get(stage_id, {}).duplicate(true)

func stage_ids() -> Array[StringName]:
    return _order.duplicate()

func next_stage_id(stage_id: StringName) -> StringName:
    var index := _order.find(stage_id)
    if index < 0 or index + 1 >= _order.size():
        return &""
    return _order[index + 1]

func has_stage(stage_id: StringName) -> bool:
    return _by_id.has(stage_id)
