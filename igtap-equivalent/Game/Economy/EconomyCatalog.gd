class_name EconomyCatalog
extends RefCounted

const ECONOMY_PATH := "res://Content/Economy/economy_balance_v1.json"
const STAGE_PATH := "res://Content/Stages/stage_catalog_v1.json"

var _economy: Dictionary = {}
var _stage_rewards: Dictionary = {}
var _stages: Dictionary = {}
var _upgrades: Dictionary = {}

func load_from_paths(economy_path: String = ECONOMY_PATH, stage_path: String = STAGE_PATH) -> Error:
    var economy_result = _read_dictionary(economy_path)
    if typeof(economy_result) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR
    var stage_result = _read_dictionary(stage_path)
    if typeof(stage_result) != TYPE_DICTIONARY:
        return ERR_PARSE_ERROR
    _economy = economy_result
    _stage_rewards.clear()
    _stages.clear()
    _upgrades.clear()
    for value in _economy.get("stage_rewards", []):
        if typeof(value) != TYPE_DICTIONARY:
            return ERR_INVALID_DATA
        var item: Dictionary = value
        var stage_id := StringName(str(item.get("stage_id", "")))
        var base_reward := float(item.get("base_reward", 0.0))
        if stage_id == &"" or base_reward <= 0.0 or not is_finite(base_reward):
            return ERR_INVALID_DATA
        _stage_rewards[stage_id] = item.duplicate(true)
    for value in stage_result.get("stages", []):
        if typeof(value) != TYPE_DICTIONARY:
            return ERR_INVALID_DATA
        var stage: Dictionary = value
        var stage_id := StringName(str(stage.get("id", "")))
        if stage_id == &"":
            return ERR_INVALID_DATA
        _stages[stage_id] = stage.duplicate(true)
    if _stage_rewards.size() != _stages.size():
        return ERR_INVALID_DATA
    for stage_id in _stages.keys():
        if not _stage_rewards.has(stage_id):
            return ERR_INVALID_DATA
    for value in _economy.get("upgrades", []):
        if typeof(value) != TYPE_DICTIONARY:
            return ERR_INVALID_DATA
        var definition: Dictionary = value
        var upgrade_id := StringName(str(definition.get("id", "")))
        if upgrade_id == &"" or _upgrades.has(upgrade_id):
            return ERR_INVALID_DATA
        if float(definition.get("base_cost", 0.0)) <= 0.0:
            return ERR_INVALID_DATA
        if float(definition.get("cost_growth", 0.0)) <= 1.0:
            return ERR_INVALID_DATA
        if int(definition.get("max_level", 0)) <= 0:
            return ERR_INVALID_DATA
        _upgrades[upgrade_id] = definition.duplicate(true)
    return OK

func stage_economy(stage_id: StringName) -> Dictionary:
    if not _stage_rewards.has(stage_id) or not _stages.has(stage_id):
        return {}
    var result: Dictionary = (_stage_rewards[stage_id] as Dictionary).duplicate(true)
    result["target_first_clear_seconds"] = float((_stages[stage_id] as Dictionary).get("target_first_clear_seconds", 1.0))
    result["target_mastery_seconds"] = float((_stages[stage_id] as Dictionary).get("target_mastery_seconds", 1.0))
    return result

func upgrade(upgrade_id: StringName) -> Dictionary:
    return (_upgrades.get(upgrade_id, {}) as Dictionary).duplicate(true)

func upgrade_ids() -> Array:
    return _upgrades.keys()

func active_reward_rules() -> Dictionary:
    return (_economy.get("active_reward", {}) as Dictionary).duplicate(true)

func clone_reward_rules() -> Dictionary:
    return (_economy.get("clone_reward", {}) as Dictionary).duplicate(true)

func passive_tick_seconds() -> float:
    return maxf(float(_economy.get("passive_tick_seconds", 0.25)), 0.05)

func display_suffixes() -> Array:
    return (_economy.get("display_suffixes", []) as Array).duplicate()

func resource_name() -> String:
    return str(_economy.get("resource_name", "Flux"))

func balance_guardrails() -> Dictionary:
    return (_economy.get("balance_guardrails", {}) as Dictionary).duplicate(true)

func _read_dictionary(path: String):
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    return JSON.parse_string(file.get_as_text())
