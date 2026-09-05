class_name UpgradeSystem
extends Node

signal upgrade_purchased_detailed(upgrade_id: StringName, new_level: int, paid_cost: Dictionary)
signal upgrade_effect_changed(upgrade_id: StringName, effect: Dictionary)

const BigResourceType = preload("res://Game/Economy/BigResource.gd")
const EconomyCatalogType = preload("res://Game/Economy/EconomyCatalog.gd")

var _catalog := EconomyCatalogType.new()
var _economy: Node
var _levels: Dictionary = {}
var _loaded := false

func _ready() -> void:
    var error := _catalog.load_from_paths()
    if error != OK:
        push_error("Upgrade catalog failed to load: %s" % error)
        return
    for upgrade_id in _catalog.upgrade_ids():
        _levels[upgrade_id] = 0
    _loaded = true

func bind_economy(economy: Node) -> void:
    _economy = economy

func purchase(upgrade_id: StringName) -> Dictionary:
    if not _loaded or _economy == null:
        return {"ok": false, "reason": "not_ready"}
    var definition := _catalog.upgrade(upgrade_id)
    if definition.is_empty():
        return {"ok": false, "reason": "unknown_upgrade"}
    var level := current_level(upgrade_id)
    var max_level := int(definition.get("max_level", 0))
    if level >= max_level:
        return {"ok": false, "reason": "max_level", "level": level}
    var cost := current_cost(upgrade_id)
    if cost.is_empty():
        return {"ok": false, "reason": "invalid_cost"}
    if not bool(_economy.call("spend_resource", cost, StringName("upgrade_" + str(upgrade_id)))):
        return {"ok": false, "reason": "insufficient_resource", "cost": cost}
    level += 1
    _levels[upgrade_id] = level
    var effect := resulting_effect(upgrade_id)
    upgrade_purchased_detailed.emit(upgrade_id, level, cost)
    upgrade_effect_changed.emit(upgrade_id, effect)
    return {"ok": true, "upgrade_id": upgrade_id, "level": level, "paid_cost": cost, "effect": effect}

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
    var per_level := float(definition.get("per_level_multiplier", 1.0))
    var current_multiplier := pow(per_level, level)
    var max_level := int(definition.get("max_level", 0))
    var next_multiplier := current_multiplier if level >= max_level else pow(per_level, level + 1)
    return {"effect": StringName(str(definition.get("effect", ""))), "level": level, "max_level": max_level, "current_multiplier": current_multiplier, "next_multiplier": next_multiplier}

func upgrade_definition(upgrade_id: StringName) -> Dictionary:
    return _catalog.upgrade(upgrade_id)

func serialize_upgrade_state() -> Dictionary:
    var levels: Dictionary = {}
    for key in _levels.keys():
        levels[str(key)] = current_level(StringName(str(key)))
    return {"schema_version": 1, "levels": levels}

func restore_upgrade_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    var stored: Dictionary = state.get("levels", {})
    for upgrade_id in _catalog.upgrade_ids():
        var resolved_id := StringName(str(upgrade_id))
        var definition := _catalog.upgrade(resolved_id)
        var max_level := int(definition.get("max_level", 0))
        _levels[upgrade_id] = clampi(int(stored.get(str(upgrade_id), 0)), 0, max_level)
        upgrade_effect_changed.emit(resolved_id, resulting_effect(resolved_id))
    return true
