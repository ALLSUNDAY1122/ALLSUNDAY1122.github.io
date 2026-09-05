class_name WorldCatalog
extends RefCounted

const DEFAULT_PATH := "res://Content/World/world_topology_v1.json"

var _stages: Dictionary = {}
var _known_abilities: Dictionary = {}
var _loaded := false

func load_from_path(path: String = DEFAULT_PATH) -> Error:
    if not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR
    if int(parsed.get("schema_version", -1)) != 1:
        return ERR_PARSE_ERROR
    _stages.clear()
    for stage_value in parsed.get("stages", []):
        var stage: Dictionary = stage_value
        var stage_id := StringName(str(stage.get("id", "")))
        if stage_id == &"" or _stages.has(stage_id):
            return ERR_INVALID_DATA
        _stages[stage_id] = stage.duplicate(true)
    _known_abilities.clear()
    for ability in parsed.get("known_abilities", []):
        _known_abilities[StringName(str(ability))] = true
    _loaded = not _stages.is_empty()
    return OK if _loaded else ERR_INVALID_DATA

func is_loaded() -> bool:
    return _loaded

func has_stage(stage_id: StringName) -> bool:
    return _stages.has(stage_id)

func stage(stage_id: StringName) -> Dictionary:
    return (_stages.get(stage_id, {}) as Dictionary).duplicate(true)

func stage_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for key in _stages.keys():
        result.append(StringName(key))
    return result

func is_known_ability(ability_id: StringName) -> bool:
    return _known_abilities.has(ability_id)

func phase_is_valid(stage_id: StringName, phase: StringName) -> bool:
    var definition := stage(stage_id)
    for value in definition.get("phases", []):
        if StringName(str(value)) == phase:
            return true
    return false

func contains_discovery(stage_id: StringName, kind: StringName, discovery_id: StringName) -> bool:
    if kind == &"secret":
        for node_value in stage(stage_id).get("nodes", []):
            var node: Dictionary = node_value
            if StringName(str(node.get("secret_id", ""))) == discovery_id:
                return true
    elif kind == &"shortcut":
        for edge_value in stage(stage_id).get("edges", []):
            var edge: Dictionary = edge_value
            if StringName(str(edge.get("shortcut_id", ""))) == discovery_id:
                return true
    return false
