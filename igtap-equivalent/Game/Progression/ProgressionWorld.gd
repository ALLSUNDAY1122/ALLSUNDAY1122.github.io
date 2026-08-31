class_name ProgressionWorld
extends Node

signal stage_context_changed(context: Dictionary)
signal currency_changed(total: float)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal upgrade_purchase_committed(upgrade_id: StringName, level: int, paid_cost: Dictionary)
signal ability_unlocked(ability_id: StringName)
signal clone_income_applied(stage_id: StringName, amount: float)
signal economy_changed(total: Dictionary, delta: Dictionary, source: StringName)
signal economy_rate_changed(rate: Dictionary)

const StageManagerType = preload("res://Game/Stages/StageManager.gd")
const WorldStateType = preload("res://Game/World/WorldState.gd")
const EconomySystemType = preload("res://Game/Economy/EconomySystem.gd")
const UpgradeSystemType = preload("res://Game/Upgrades/UpgradeSystem.gd")

var _stages: Node
var _world: Node
var _economy: Node
var _upgrades: Node

func _ready() -> void:
    _stages = StageManagerType.new()
    _world = WorldStateType.new()
    _economy = EconomySystemType.new()
    _upgrades = UpgradeSystemType.new()
    add_child(_stages)
    add_child(_world)
    add_child(_economy)
    add_child(_upgrades)
    _upgrades.call("bind_economy", _economy)
    _stages.stage_context_changed.connect(_on_stage_context_changed)
    _economy.economy_changed.connect(_on_economy_changed)
    _economy.rate_changed.connect(func(rate): economy_rate_changed.emit(rate))
    _economy.clone_income_tick.connect(_on_clone_income_tick)
    _upgrades.upgrade_purchased_detailed.connect(_on_upgrade_purchased)
    _upgrades.upgrade_effect_changed.connect(func(_id, _effect): _refresh_economy_multipliers())
    call_deferred("_finish_ready")

func _finish_ready() -> void:
    _refresh_economy_multipliers()
    stage_context_changed.emit(current_stage_context())
    currency_changed.emit(float(_economy.call("current_resource_float")))

func register_lap(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary = {}) -> Dictionary:
    var result: Dictionary = _stages.call("register_lap", stage_id, elapsed_seconds, replay_payload)
    if result.is_empty():
        return {}
    var reward: Dictionary = _economy.call("calculate_active_lap_reward", stage_id, elapsed_seconds)
    if not reward.is_empty():
        _economy.call("add_resource", reward, &"active_lap")
    if not replay_payload.is_empty():
        var current_profile: Dictionary = _economy.call("clone_profile", stage_id)
        var profile := {
            "clone_count": int(current_profile.get("clone_count", 1)),
            "route_quality": clampf(float(replay_payload.get("route_quality", 1.0)), 0.5, 1.5)
        }
        _economy.call("register_clone_route", stage_id, elapsed_seconds, profile)
    result["active_reward"] = reward
    result["economy"] = economy_snapshot()
    return result

func register_death(stage_id: StringName, reason) -> Dictionary:
    return _stages.call("register_death", stage_id, reason)

func purchase_upgrade(upgrade_id: StringName) -> Dictionary:
    var availability := upgrade_availability(upgrade_id)
    if not bool(availability.get("available", false)):
        return {"ok": false, "reason": availability.get("reason", "locked")}
    return _upgrades.call("purchase", upgrade_id)

func purchase(upgrade_id: StringName) -> Dictionary:
    return purchase_upgrade(upgrade_id)

func upgrade_availability(upgrade_id: StringName) -> Dictionary:
    var definition: Dictionary = _upgrades.call("upgrade_definition", upgrade_id)
    if definition.is_empty():
        return {"available": false, "reason": "unknown_upgrade"}
    var required_stage := StringName(str(definition.get("unlocks_after_stage", "")))
    if required_stage != &"" and not _stage_is_cleared(required_stage):
        return {"available": false, "reason": "requires_stage_clear", "stage_id": required_stage}
    if int(_upgrades.call("current_level", upgrade_id)) >= int(definition.get("max_level", 0)):
        return {"available": false, "reason": "max_level"}
    return {"available": true, "reason": "available"}

func current_level(upgrade_id: StringName) -> int:
    return int(_upgrades.call("current_level", upgrade_id))

func current_cost(upgrade_id: StringName) -> Dictionary:
    return _upgrades.call("current_cost", upgrade_id)

func resulting_effect(upgrade_id: StringName) -> Dictionary:
    return _upgrades.call("resulting_effect", upgrade_id)

func add_resource(amount, source: StringName = &"integration") -> bool:
    return bool(_economy.call("add_resource", amount, source))

func spend_resource(amount, reason: StringName = &"integration") -> bool:
    return bool(_economy.call("spend_resource", amount, reason))

func current_resource() -> Dictionary:
    return _economy.call("current_resource")

func resource_per_second() -> Dictionary:
    return _economy.call("resource_per_second")

func calculate_clone_reward(stage_id: StringName, best_time: float, clone_profile: Dictionary = {}) -> Dictionary:
    return _economy.call("calculate_clone_reward", stage_id, best_time, clone_profile)

func set_clone_count(stage_id: StringName, clone_count: int) -> bool:
    return bool(_economy.call("set_clone_count", stage_id, clone_count))

func get_unlocked_abilities() -> Array[StringName]:
    var result: Array[StringName] = []
    var context: Dictionary = _world.call("world_context")
    for value in context.get("unlocked_abilities", []):
        result.append(StringName(str(value)))
    return result

func set_unlocked_abilities(ability_ids: Array) -> void:
    _world.call("set_unlocked_abilities", ability_ids)

func current_stage_context() -> Dictionary:
    if _stages == null:
        return {}
    var context: Dictionary = _stages.call("current_stage_context")
    if _economy != null:
        context["economy"] = economy_snapshot()
    if _world != null:
        context["world"] = _world.call("world_context", StringName(str(context.get("stage_id", ""))))
    return context

func economy_snapshot() -> Dictionary:
    return {} if _economy == null else _economy.call("economy_snapshot")

func serialize_state() -> Dictionary:
    return {
        "schema_version": 1,
        "stage": _stages.call("serialize_stage_state"),
        "world": _world.call("serialize_world_state"),
        "economy": _economy.call("serialize_economy_state"),
        "upgrades": _upgrades.call("serialize_upgrade_state")
    }

func restore_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    if not bool(_stages.call("restore_stage_state", state.get("stage", {}))):
        return false
    if not bool(_world.call("restore_world_state", state.get("world", {}))):
        return false
    if not bool(_economy.call("restore_economy_state", state.get("economy", {}))):
        return false
    if not bool(_upgrades.call("restore_upgrade_state", state.get("upgrades", {}))):
        return false
    _refresh_economy_multipliers()
    stage_context_changed.emit(current_stage_context())
    return true

func _on_stage_context_changed(_context: Dictionary) -> void:
    stage_context_changed.emit(current_stage_context())

func _on_economy_changed(total: Dictionary, delta: Dictionary, source: StringName) -> void:
    economy_changed.emit(total, delta, source)
    currency_changed.emit(float(_economy.call("current_resource_float")))

func _on_clone_income_tick(stage_id: StringName, amount: Dictionary) -> void:
    var value := minf(_resource_snapshot_to_float(amount), 1.0e300)
    clone_income_applied.emit(stage_id, value)

func _on_upgrade_purchased(upgrade_id: StringName, level: int, paid_cost: Dictionary) -> void:
    _refresh_economy_multipliers()
    upgrade_purchased.emit(upgrade_id, level)
    upgrade_purchase_committed.emit(upgrade_id, level, paid_cost)

func _refresh_economy_multipliers() -> void:
    if _economy == null or _upgrades == null:
        return
    var income: Dictionary = _upgrades.call("resulting_effect", &"flux_coils")
    var clone: Dictionary = _upgrades.call("resulting_effect", &"loop_compression")
    var active: Dictionary = _upgrades.call("resulting_effect", &"route_dividend")
    _economy.call("set_income_multiplier", float(income.get("current_multiplier", 1.0)))
    _economy.call("set_clone_reward_multiplier", float(clone.get("current_multiplier", 1.0)))
    _economy.call("set_active_reward_multiplier", float(active.get("current_multiplier", 1.0)))

func _stage_is_cleared(stage_id: StringName) -> bool:
    for entry_value in _stages.call("stage_select_entries"):
        var entry: Dictionary = entry_value
        if StringName(str(entry.get("stage_id", ""))) == stage_id:
            return bool(entry.get("cleared", false))
    return false

func _resource_snapshot_to_float(snapshot: Dictionary) -> float:
    var mantissa := float(snapshot.get("mantissa", 0.0))
    var exponent := int(snapshot.get("exponent", 0))
    if exponent >= 100:
        return 1.0e300
    return mantissa * pow(1000.0, exponent)
