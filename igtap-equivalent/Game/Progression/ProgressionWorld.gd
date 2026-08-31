class_name ProgressionWorld
extends Node

signal stage_context_changed(context: Dictionary)
signal stage_availability_changed(stage_id: StringName, availability: Dictionary)
signal currency_changed(total: float)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal upgrade_purchase_committed(upgrade_id: StringName, level: int, paid_cost: Dictionary)
signal ability_unlocked(ability_id: StringName)
signal movement_effects_changed(effects: Dictionary)
signal clone_capacity_changed(capacity: int)
signal clone_income_applied(stage_id: StringName, amount: float)
signal economy_changed(total: Dictionary, delta: Dictionary, source: StringName)
signal economy_rate_changed(rate: Dictionary)

const StageManagerType = preload("res://Game/Stages/StageManager.gd")
const WorldStateType = preload("res://Game/World/WorldState.gd")
const EconomySystemType = preload("res://Game/Economy/EconomySystem.gd")
const UpgradeSystemType = preload("res://Game/Upgrades/UpgradeSystem.gd")
const ProgressionSystemType = preload("res://Game/Progression/ProgressionSystem.gd")

var _stages: Node
var _world: Node
var _economy: Node
var _upgrades: Node
var _progression: Node

func _ready() -> void:
    _stages = StageManagerType.new()
    _world = WorldStateType.new()
    _economy = EconomySystemType.new()
    _upgrades = UpgradeSystemType.new()
    _progression = ProgressionSystemType.new()
    add_child(_stages)
    add_child(_world)
    add_child(_economy)
    add_child(_upgrades)
    add_child(_progression)
    _upgrades.call("bind_economy", _economy)
    _progression.call("bind_economy", _economy)
    _progression.call("bind_stage_manager", _stages)
    _connect_if_present(_stages, &"stage_context_changed", Callable(self, "_on_stage_context_changed"))
    _connect_if_present(_stages, &"stage_availability_changed", Callable(self, "_on_raw_stage_availability_changed"))
    _connect_if_present(_economy, &"economy_changed", Callable(self, "_on_economy_changed"))
    _connect_if_present(_economy, &"rate_changed", Callable(self, "_on_rate_changed"))
    _connect_if_present(_economy, &"clone_income_tick", Callable(self, "_on_clone_income_tick"))
    _connect_if_present(_upgrades, &"upgrade_purchased_detailed", Callable(self, "_on_economic_upgrade_purchased"))
    _connect_if_present(_upgrades, &"upgrade_effect_changed", Callable(self, "_on_economic_upgrade_effect_changed"))
    _connect_if_present(_progression, &"progression_upgrade_purchased", Callable(self, "_on_progression_upgrade_purchased"))
    _connect_if_present(_progression, &"ability_unlocked", Callable(self, "_on_ability_unlocked"))
    _connect_if_present(_progression, &"movement_effects_changed", Callable(self, "_on_movement_effects_changed"))
    _connect_if_present(_progression, &"clone_capacity_changed", Callable(self, "_on_clone_capacity_changed"))
    call_deferred("_finish_ready")

func _finish_ready() -> void:
    _refresh_economy_multipliers()
    _sync_world_abilities()
    movement_effects_changed.emit(movement_effects())
    clone_capacity_changed.emit(clone_capacity())
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
        var requested_clone_count := int(current_profile.get("clone_count", -1))
        if requested_clone_count < 0:
            requested_clone_count = 1 if int(clone_allocation_snapshot().get("remaining", 0)) > 0 else 0
        var profile := {
            "clone_count": requested_clone_count,
            "route_quality": clampf(float(replay_payload.get("route_quality", 1.0)), 0.5, 1.5)
        }
        _economy.call("register_clone_route", stage_id, elapsed_seconds, profile)
    result["active_reward"] = reward
    result["economy"] = economy_snapshot()
    result["progression"] = progression_snapshot()
    return result

func register_death(stage_id: StringName, reason) -> Dictionary:
    return _stages.call("register_death", stage_id, reason)

func purchase_upgrade(upgrade_id: StringName) -> Dictionary:
    if bool(_progression.call("has_upgrade", upgrade_id)):
        return _progression.call("purchase", upgrade_id)
    var availability := upgrade_availability(upgrade_id)
    if not bool(availability.get("available", false)):
        return {"ok": false, "reason": availability.get("reason", "locked")}
    return _upgrades.call("purchase", upgrade_id)

func purchase(upgrade_id: StringName) -> Dictionary:
    return purchase_upgrade(upgrade_id)

func upgrade_availability(upgrade_id: StringName) -> Dictionary:
    if bool(_progression.call("has_upgrade", upgrade_id)):
        return _progression.call("upgrade_availability", upgrade_id)
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
    if bool(_progression.call("has_upgrade", upgrade_id)):
        return int(_progression.call("current_level", upgrade_id))
    return int(_upgrades.call("current_level", upgrade_id))

func current_cost(upgrade_id: StringName) -> Dictionary:
    if bool(_progression.call("has_upgrade", upgrade_id)):
        return _progression.call("current_cost", upgrade_id)
    return _upgrades.call("current_cost", upgrade_id)

func resulting_effect(upgrade_id: StringName) -> Dictionary:
    if bool(_progression.call("has_upgrade", upgrade_id)):
        return _progression.call("resulting_effect", upgrade_id)
    return _upgrades.call("resulting_effect", upgrade_id)

func unlock_ability(ability_id: StringName) -> bool:
    return bool(_progression.call("unlock_ability", ability_id))

func is_ability_unlocked(ability_id: StringName) -> bool:
    return bool(_progression.call("is_ability_unlocked", ability_id))

func get_unlocked_abilities() -> Array[StringName]:
    var result: Array[StringName] = []
    for value in _progression.call("get_unlocked_abilities"):
        result.append(StringName(str(value)))
    return result

func set_unlocked_abilities(ability_ids: Array) -> void:
    for value in ability_ids:
        unlock_ability(StringName(str(value)))
    _sync_world_abilities()

func movement_effects() -> Dictionary:
    return _progression.call("movement_effects")

func session_a_ability_mapping() -> Dictionary:
    return _progression.call("session_a_mapping")

func clone_capacity() -> int:
    return int(_progression.call("clone_capacity"))

func set_clone_count(stage_id: StringName, clone_count: int) -> bool:
    if clone_count < 0:
        return false
    var profiles: Dictionary = economy_snapshot().get("clone_profiles", {})
    var allocated_without_stage := 0
    for key in profiles.keys():
        if StringName(str(key)) == stage_id:
            continue
        allocated_without_stage += maxi(int((profiles[key] as Dictionary).get("clone_count", 0)), 0)
    if allocated_without_stage + clone_count > clone_capacity():
        return false
    return bool(_economy.call("set_clone_count", stage_id, clone_count))

func clone_allocation_snapshot() -> Dictionary:
    var profiles: Dictionary = economy_snapshot().get("clone_profiles", {})
    var allocated := 0
    var by_stage: Dictionary = {}
    for key in profiles.keys():
        var count := maxi(int((profiles[key] as Dictionary).get("clone_count", 0)), 0)
        allocated += count
        by_stage[str(key)] = count
    return {"capacity": clone_capacity(), "allocated": allocated, "remaining": maxi(clone_capacity() - allocated, 0), "by_stage": by_stage}

func stage_availability(stage_id: StringName) -> Dictionary:
    var raw := _raw_stage_entry(stage_id)
    if raw.is_empty():
        return {"available": false, "reason": "unknown_stage", "stage_id": stage_id}
    if not bool(raw.get("available", false)):
        return {"available": false, "reason": "requires_previous_clear", "stage_id": stage_id}
    var world_context: Dictionary = _world.call("world_context", stage_id)
    var definition: Dictionary = world_context.get("definition", {})
    var required_value = definition.get("entry_required_ability", null)
    if required_value != null:
        var required := StringName(str(required_value))
        if required != &"" and not is_ability_unlocked(required):
            return {"available": false, "reason": "requires_ability", "stage_id": stage_id, "ability_id": required}
    return {"available": true, "reason": "available", "stage_id": stage_id}

func is_stage_available(stage_id: StringName) -> bool:
    return bool(stage_availability(stage_id).get("available", false))

func unlock_stage(stage_id: StringName) -> bool:
    return bool(_stages.call("unlock_stage", stage_id))

func select_stage(stage_id: StringName) -> bool:
    if not is_stage_available(stage_id):
        return false
    if not bool(_stages.call("select_stage", stage_id)):
        return false
    return bool(_world.call("enter_stage", stage_id))

func begin_stage(stage_id: StringName = &"") -> bool:
    var resolved := stage_id
    if resolved == &"":
        resolved = StringName(str(current_stage_context().get("stage_id", "")))
    if not is_stage_available(resolved):
        return false
    if not bool(_stages.call("begin_stage", resolved)):
        return false
    _world.call("enter_stage", resolved)
    return true

func stage_select_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in _stages.call("stage_select_entries"):
        var entry: Dictionary = (value as Dictionary).duplicate(true)
        var stage_id := StringName(str(entry.get("stage_id", "")))
        var availability := stage_availability(stage_id)
        entry["available"] = bool(availability.get("available", false))
        entry["availability"] = availability
        result.append(entry)
    return result

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

func current_stage_context() -> Dictionary:
    if _stages == null:
        return {}
    var context: Dictionary = _stages.call("current_stage_context")
    context["stage_select"] = stage_select_entries()
    if _economy != null:
        context["economy"] = economy_snapshot()
    if _world != null:
        context["world"] = _world.call("world_context", StringName(str(context.get("stage_id", ""))))
    if _progression != null:
        context["progression"] = progression_snapshot()
        context["current_stage_availability"] = stage_availability(StringName(str(context.get("stage_id", ""))))
    return context

func economy_snapshot() -> Dictionary:
    return {} if _economy == null else _economy.call("economy_snapshot")

func progression_snapshot() -> Dictionary:
    if _progression == null:
        return {}
    var result: Dictionary = _progression.call("progression_snapshot")
    result["clone_allocation"] = clone_allocation_snapshot()
    return result

func serialize_state() -> Dictionary:
    return {
        "schema_version": 2,
        "stage": _stages.call("serialize_stage_state"),
        "world": _world.call("serialize_world_state"),
        "economy": _economy.call("serialize_economy_state"),
        "upgrades": _upgrades.call("serialize_upgrade_state"),
        "progression": _progression.call("serialize_progression_state")
    }

func restore_state(state: Dictionary) -> bool:
    var version := int(state.get("schema_version", -1))
    if version != 1 and version != 2:
        return false
    if not bool(_stages.call("restore_stage_state", state.get("stage", {}))):
        return false
    if not bool(_world.call("restore_world_state", state.get("world", {}))):
        return false
    if not bool(_economy.call("restore_economy_state", state.get("economy", {}))):
        return false
    if not bool(_upgrades.call("restore_upgrade_state", state.get("upgrades", {}))):
        return false
    if version >= 2:
        if not bool(_progression.call("restore_progression_state", state.get("progression", {}))):
            return false
    _refresh_economy_multipliers()
    _sync_world_abilities()
    stage_context_changed.emit(current_stage_context())
    movement_effects_changed.emit(movement_effects())
    clone_capacity_changed.emit(clone_capacity())
    return true

func _on_stage_context_changed(_context: Dictionary) -> void:
    stage_context_changed.emit(current_stage_context())

func _on_raw_stage_availability_changed(stage_id: StringName, _available: bool) -> void:
    stage_availability_changed.emit(stage_id, stage_availability(stage_id))

func _on_economy_changed(total: Dictionary, delta: Dictionary, source: StringName) -> void:
    economy_changed.emit(total, delta, source)
    currency_changed.emit(float(_economy.call("current_resource_float")))

func _on_rate_changed(rate: Dictionary) -> void:
    economy_rate_changed.emit(rate)

func _on_clone_income_tick(stage_id: StringName, amount: Dictionary) -> void:
    var value := minf(_resource_snapshot_to_float(amount), 1.0e300)
    clone_income_applied.emit(stage_id, value)

func _on_economic_upgrade_purchased(upgrade_id: StringName, level: int, paid_cost: Dictionary) -> void:
    _refresh_economy_multipliers()
    upgrade_purchased.emit(upgrade_id, level)
    upgrade_purchase_committed.emit(upgrade_id, level, paid_cost)

func _on_economic_upgrade_effect_changed(_upgrade_id: StringName, _effect: Dictionary) -> void:
    _refresh_economy_multipliers()

func _on_progression_upgrade_purchased(upgrade_id: StringName, level: int, paid_cost: Dictionary) -> void:
    upgrade_purchased.emit(upgrade_id, level)
    upgrade_purchase_committed.emit(upgrade_id, level, paid_cost)
    stage_context_changed.emit(current_stage_context())

func _on_ability_unlocked(ability_id: StringName) -> void:
    _sync_world_abilities()
    ability_unlocked.emit(ability_id)
    for entry in _stages.call("stage_select_entries"):
        var stage_id := StringName(str((entry as Dictionary).get("stage_id", "")))
        stage_availability_changed.emit(stage_id, stage_availability(stage_id))
    stage_context_changed.emit(current_stage_context())

func _on_movement_effects_changed(effects: Dictionary) -> void:
    movement_effects_changed.emit(effects)
    stage_context_changed.emit(current_stage_context())

func _on_clone_capacity_changed(capacity: int) -> void:
    clone_capacity_changed.emit(capacity)
    stage_context_changed.emit(current_stage_context())

func _refresh_economy_multipliers() -> void:
    if _economy == null or _upgrades == null:
        return
    var income: Dictionary = _upgrades.call("resulting_effect", &"flux_coils")
    var clone: Dictionary = _upgrades.call("resulting_effect", &"loop_compression")
    var active: Dictionary = _upgrades.call("resulting_effect", &"route_dividend")
    _economy.call("set_income_multiplier", float(income.get("current_multiplier", 1.0)))
    _economy.call("set_clone_reward_multiplier", float(clone.get("current_multiplier", 1.0)))
    _economy.call("set_active_reward_multiplier", float(active.get("current_multiplier", 1.0)))

func _sync_world_abilities() -> void:
    if _world != null and _progression != null:
        _world.call("set_unlocked_abilities", get_unlocked_abilities())

func _raw_stage_entry(stage_id: StringName) -> Dictionary:
    for value in _stages.call("stage_select_entries"):
        var entry: Dictionary = value
        if StringName(str(entry.get("stage_id", ""))) == stage_id:
            return entry
    return {}

func _stage_is_cleared(stage_id: StringName) -> bool:
    var entry := _raw_stage_entry(stage_id)
    return not entry.is_empty() and bool(entry.get("cleared", false))

func _connect_if_present(node: Node, signal_name: StringName, callable: Callable) -> void:
    if node != null and node.has_signal(signal_name):
        node.connect(signal_name, callable)

func _resource_snapshot_to_float(snapshot: Dictionary) -> float:
    var mantissa := float(snapshot.get("mantissa", 0.0))
    var exponent := int(snapshot.get("exponent", 0))
    if exponent >= 100:
        return 1.0e300
    return mantissa * pow(1000.0, exponent)
