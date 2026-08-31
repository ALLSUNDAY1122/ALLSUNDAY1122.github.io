class_name ProgressionSystem
extends Node

signal ability_unlocked(ability_id: StringName)
signal progression_upgrade_purchased(upgrade_id: StringName, new_level: int, paid_cost: Dictionary)
signal movement_effects_changed(effects: Dictionary)
signal clone_capacity_changed(capacity: int)

const BigResourceType = preload("res://Game/Economy/BigResource.gd")
const ProgressionCatalogType = preload("res://Game/Progression/ProgressionCatalog.gd")

var _catalog := ProgressionCatalogType.new()
var _economy: Node
var _stages: Node
var _levels: Dictionary = {}
var _manual_unlocked: Dictionary = {}
var _unlocked_abilities: Dictionary = {}
var _loaded := false

func _ready() -> void:
    var error := _catalog.load_from_path()
    if error != OK:
        push_error("Progression catalog failed to load: %s" % error)
        return
    for upgrade_id in _catalog.upgrade_ids():
        _levels[upgrade_id] = 0
    _loaded = true

func bind_economy(economy: Node) -> void:
    _economy = economy

func bind_stage_manager(stages: Node) -> void:
    _stages = stages

func has_upgrade(upgrade_id: StringName) -> bool:
    return _catalog.has_upgrade(upgrade_id)

func purchase(upgrade_id: StringName) -> Dictionary:
    var availability := upgrade_availability(upgrade_id)
    if not bool(availability.get("available", false)):
        return {"ok": false, "reason": availability.get("reason", "locked")}
    if _economy == null:
        return {"ok": false, "reason": "not_ready"}
    var cost := current_cost(upgrade_id)
    if cost.is_empty():
        return {"ok": false, "reason": "invalid_cost"}
    if not bool(_economy.call("spend_resource", cost, StringName("progression_" + str(upgrade_id)))):
        return {"ok": false, "reason": "insufficient_resource", "cost": cost}
    var level := current_level(upgrade_id) + 1
    _levels[upgrade_id] = level
    var definition := _catalog.upgrade(upgrade_id)
    var unlock_level := int(definition.get("ability_unlock_on_level", 0))
    if unlock_level > 0 and level >= unlock_level:
        _grant_ability(upgrade_id, false)
    progression_upgrade_purchased.emit(upgrade_id, level, cost)
    _emit_effect_change(definition)
    return {"ok": true, "upgrade_id": upgrade_id, "level": level, "paid_cost": cost, "effect": resulting_effect(upgrade_id)}

func upgrade_availability(upgrade_id: StringName) -> Dictionary:
    if not _loaded or not _catalog.has_upgrade(upgrade_id):
        return {"available": false, "reason": "unknown_upgrade"}
    var definition := _catalog.upgrade(upgrade_id)
    var level := current_level(upgrade_id)
    if level >= int(definition.get("max_level", 0)):
        return {"available": false, "reason": "max_level"}
    var required_stage := StringName(str(definition.get("unlocks_after_stage", "")))
    if required_stage != &"" and not _stage_is_cleared(required_stage):
        return {"available": false, "reason": "requires_stage_clear", "stage_id": required_stage}
    for value in definition.get("requires_upgrades", []):
        var required_upgrade := StringName(str(value))
        if current_level(required_upgrade) <= 0:
            return {"available": false, "reason": "requires_upgrade", "upgrade_id": required_upgrade}
    return {"available": true, "reason": "available"}

func current_level(upgrade_id: StringName) -> int:
    return maxi(int(_levels.get(upgrade_id, 0)), 0)

func current_cost(upgrade_id: StringName) -> Dictionary:
    var definition := _catalog.upgrade(upgrade_id)
    if definition.is_empty():
        return {}
    var level := current_level(upgrade_id)
    if level >= int(definition.get("max_level", 0)):
        return {}
    var cost = BigResourceType.from_number(float(definition.get("base_cost", 0.0)))
    if cost == null:
        return {}
    var growth := float(definition.get("cost_growth", 1.0))
    for _index in range(level):
        cost.multiply_assign(growth)
    return cost.snapshot()

func resulting_effect(upgrade_id: StringName) -> Dictionary:
    var definition := _catalog.upgrade(upgrade_id)
    if definition.is_empty():
        return {}
    var level := current_level(upgrade_id)
    var max_level := int(definition.get("max_level", 0))
    var effect := StringName(str(definition.get("effect", "")))
    if effect == &"clone_capacity_add":
        var per_level_add := int(definition.get("per_level_add", 1))
        var current_value := _catalog.base_clone_capacity() + level * per_level_add
        var next_value := current_value if level >= max_level else current_value + per_level_add
        return {"effect": effect, "level": level, "max_level": max_level, "current_value": current_value, "next_value": next_value}
    if effect == &"ability_unlock":
        return {"effect": effect, "level": level, "max_level": max_level, "unlocked": is_ability_unlocked(upgrade_id), "next_unlocked": true}
    var per_level := float(definition.get("per_level_multiplier", 1.0))
    var current_multiplier := pow(per_level, level)
    var next_multiplier := current_multiplier if level >= max_level else pow(per_level, level + 1)
    return {"effect": effect, "level": level, "max_level": max_level, "current_multiplier": current_multiplier, "next_multiplier": next_multiplier}

func unlock_ability(ability_id: StringName) -> bool:
    if not _catalog.ability_order().has(ability_id):
        return false
    if is_ability_unlocked(ability_id):
        return true
    if _catalog.has_upgrade(ability_id):
        var definition := _catalog.upgrade(ability_id)
        var unlock_level := int(definition.get("ability_unlock_on_level", 0))
        if unlock_level > 0 and current_level(ability_id) < unlock_level:
            _levels[ability_id] = unlock_level
            _emit_effect_change(definition)
    else:
        _manual_unlocked[ability_id] = true
    return _grant_ability(ability_id, false)

func is_ability_unlocked(ability_id: StringName) -> bool:
    return _unlocked_abilities.has(ability_id)

func get_unlocked_abilities() -> Array[StringName]:
    var result: Array[StringName] = []
    for ability_id in _catalog.ability_order():
        if _unlocked_abilities.has(ability_id):
            result.append(ability_id)
    return result

func movement_effects() -> Dictionary:
    return {
        "run_speed_multiplier": float(resulting_effect(&"speed_tune").get("current_multiplier", 1.0)),
        "jump_multiplier": float(resulting_effect(&"jump_tune").get("current_multiplier", 1.0))
    }

func clone_capacity() -> int:
    return int(resulting_effect(&"clone_capacity").get("current_value", _catalog.base_clone_capacity()))

func session_a_mapping() -> Dictionary:
    return _catalog.session_a_mapping()

func progression_snapshot() -> Dictionary:
    var levels: Dictionary = {}
    for upgrade_id in _catalog.upgrade_ids():
        levels[str(upgrade_id)] = current_level(upgrade_id)
    return {
        "levels": levels,
        "unlocked_abilities": get_unlocked_abilities(),
        "movement_effects": movement_effects(),
        "clone_capacity": clone_capacity(),
        "session_a_mapping": session_a_mapping()
    }

func serialize_progression_state() -> Dictionary:
    var state := progression_snapshot()
    var manual: Array[String] = []
    for key in _manual_unlocked.keys():
        manual.append(str(key))
    manual.sort()
    state["schema_version"] = 1
    state["manual_unlocked_abilities"] = manual
    return state

func restore_progression_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    var levels: Dictionary = state.get("levels", {})
    for upgrade_id in _catalog.upgrade_ids():
        var definition := _catalog.upgrade(upgrade_id)
        _levels[upgrade_id] = clampi(int(levels.get(str(upgrade_id), 0)), 0, int(definition.get("max_level", 0)))
    _manual_unlocked.clear()
    for value in state.get("manual_unlocked_abilities", []):
        var ability_id := StringName(str(value))
        if _catalog.ability_order().has(ability_id):
            _manual_unlocked[ability_id] = true
    _rebuild_abilities()
    movement_effects_changed.emit(movement_effects())
    clone_capacity_changed.emit(clone_capacity())
    return true

func _rebuild_abilities() -> void:
    _unlocked_abilities.clear()
    for ability_id in _manual_unlocked.keys():
        _unlocked_abilities[ability_id] = true
    for upgrade_id in _catalog.upgrade_ids():
        var definition := _catalog.upgrade(upgrade_id)
        var unlock_level := int(definition.get("ability_unlock_on_level", 0))
        if unlock_level > 0 and current_level(upgrade_id) >= unlock_level:
            _unlocked_abilities[upgrade_id] = true

func _grant_ability(ability_id: StringName, silent: bool) -> bool:
    if _unlocked_abilities.has(ability_id):
        return true
    _unlocked_abilities[ability_id] = true
    if not silent:
        ability_unlocked.emit(ability_id)
    return true

func _emit_effect_change(definition: Dictionary) -> void:
    var effect_name := StringName(str(definition.get("effect", "")))
    if effect_name == &"run_speed_multiplier" or effect_name == &"jump_multiplier":
        movement_effects_changed.emit(movement_effects())
    elif effect_name == &"clone_capacity_add":
        clone_capacity_changed.emit(clone_capacity())

func _stage_is_cleared(stage_id: StringName) -> bool:
    if _stages == null or not _stages.has_method("stage_select_entries"):
        return false
    for value in _stages.call("stage_select_entries"):
        var entry: Dictionary = value
        if StringName(str(entry.get("stage_id", ""))) == stage_id:
            return bool(entry.get("cleared", false))
    return false
