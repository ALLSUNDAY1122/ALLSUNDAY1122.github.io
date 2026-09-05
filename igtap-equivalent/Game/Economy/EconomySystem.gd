class_name EconomySystem
extends Node

signal economy_changed(total: Dictionary, delta: Dictionary, source: StringName)
signal rate_changed(rate: Dictionary)
signal clone_income_tick(stage_id: StringName, amount: Dictionary)

const BigResourceType = preload("res://Game/Economy/BigResource.gd")
const EconomyCatalogType = preload("res://Game/Economy/EconomyCatalog.gd")

var _catalog := EconomyCatalogType.new()
var _balance = BigResourceType.new()
var _clone_profiles: Dictionary = {}
var _income_multiplier := 1.0
var _clone_reward_multiplier := 1.0
var _active_reward_multiplier := 1.0
var _passive_accumulator := 0.0
var _loaded := false

func _ready() -> void:
    var error := _catalog.load_from_paths()
    if error != OK:
        push_error("Economy catalog failed to load: %s" % error)
        return
    _loaded = true
    rate_changed.emit(resource_per_second())

func _physics_process(delta: float) -> void:
    if not _loaded or delta <= 0.0:
        return
    _passive_accumulator += delta
    var tick := _catalog.passive_tick_seconds()
    if _passive_accumulator < tick:
        return
    var elapsed := _passive_accumulator
    _passive_accumulator = 0.0
    _apply_passive_income(elapsed)

func add_resource(amount, source: StringName = &"unknown") -> bool:
    var resolved = _coerce_resource(amount)
    if resolved == null or resolved.is_negative():
        return false
    if resolved.is_zero():
        return true
    _balance.add_assign(resolved)
    economy_changed.emit(current_resource(), resolved.snapshot(), source)
    return true

func spend_resource(amount, reason: StringName = &"spend") -> bool:
    var resolved = _coerce_resource(amount)
    if resolved == null or resolved.is_negative() or resolved.is_zero():
        return false
    if not _balance.subtract_assign(resolved):
        return false
    economy_changed.emit(current_resource(), resolved.signed_snapshot(-1.0), reason)
    return true

func current_resource() -> Dictionary:
    return _balance.snapshot()

func current_resource_float() -> float:
    return _balance.to_float_clamped()

func resource_per_second() -> Dictionary:
    return _resource_per_second_value().snapshot()

func resource_per_second_float() -> float:
    return _resource_per_second_value().to_float_clamped()

func calculate_active_lap_reward(stage_id: StringName, elapsed_seconds: float) -> Dictionary:
    var value = _calculate_active_reward_value(stage_id, elapsed_seconds)
    return {} if value == null else value.snapshot()

func calculate_clone_reward(stage_id: StringName, best_time: float, clone_profile: Dictionary = {}) -> Dictionary:
    var value = _calculate_clone_reward_value(stage_id, best_time, clone_profile)
    return {} if value == null else value.snapshot()

func register_clone_route(stage_id: StringName, best_time: float, clone_profile: Dictionary = {}) -> bool:
    if best_time <= 0.0 or not is_finite(best_time):
        return false
    if _catalog.stage_economy(stage_id).is_empty():
        return false
    var existing: Dictionary = _clone_profiles.get(stage_id, {})
    var previous_time := float(existing.get("cycle_seconds", -1.0))
    var resolved_time := best_time if previous_time <= 0.0 else minf(previous_time, best_time)
    var requested_count := maxi(int(clone_profile.get("clone_count", existing.get("clone_count", 1))), 0)
    var rules := _catalog.clone_reward_rules()
    var requested_quality := clampf(
        float(clone_profile.get("route_quality", existing.get("route_quality", 1.0))),
        float(rules.get("route_quality_min", 0.5)),
        float(rules.get("route_quality_max", 1.5))
    )
    var existing_quality := float(existing.get("route_quality", requested_quality))
    var resolved_quality := requested_quality
    if previous_time > 0.0:
        if best_time > previous_time and not is_equal_approx(best_time, previous_time):
            resolved_quality = existing_quality
        elif is_equal_approx(best_time, previous_time):
            resolved_quality = maxf(existing_quality, requested_quality)
    _clone_profiles[stage_id] = {
        "cycle_seconds": resolved_time,
        "clone_count": requested_count,
        "route_quality": resolved_quality
    }
    rate_changed.emit(resource_per_second())
    return true

func set_clone_count(stage_id: StringName, clone_count: int) -> bool:
    if clone_count < 0 or _catalog.stage_economy(stage_id).is_empty():
        return false
    var profile: Dictionary = _clone_profiles.get(stage_id, {
        "cycle_seconds": 0.0,
        "clone_count": 0,
        "route_quality": 1.0
    })
    profile["clone_count"] = clone_count
    _clone_profiles[stage_id] = profile
    rate_changed.emit(resource_per_second())
    return true

func clone_profile(stage_id: StringName) -> Dictionary:
    return (_clone_profiles.get(stage_id, {}) as Dictionary).duplicate(true)

func set_income_multiplier(value: float) -> bool:
    if not is_finite(value) or value <= 0.0:
        return false
    _income_multiplier = value
    rate_changed.emit(resource_per_second())
    return true

func set_clone_reward_multiplier(value: float) -> bool:
    if not is_finite(value) or value <= 0.0:
        return false
    _clone_reward_multiplier = value
    rate_changed.emit(resource_per_second())
    return true

func set_active_reward_multiplier(value: float) -> bool:
    if not is_finite(value) or value <= 0.0:
        return false
    _active_reward_multiplier = value
    return true

func economy_snapshot() -> Dictionary:
    var profiles: Dictionary = {}
    for stage_id in _clone_profiles.keys():
        profiles[str(stage_id)] = (_clone_profiles[stage_id] as Dictionary).duplicate(true)
    return {
        "balance": current_resource(),
        "resource_per_second": resource_per_second(),
        "clone_profiles": profiles,
        "income_multiplier": _income_multiplier,
        "clone_reward_multiplier": _clone_reward_multiplier,
        "active_reward_multiplier": _active_reward_multiplier
    }

func serialize_economy_state() -> Dictionary:
    var result := economy_snapshot()
    result["schema_version"] = 1
    return result

func restore_economy_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    var restored_balance = BigResourceType.from_snapshot(state.get("balance", {}))
    if restored_balance == null or restored_balance.is_negative():
        return false
    var restored_profiles: Dictionary = {}
    for key in (state.get("clone_profiles", {}) as Dictionary).keys():
        var stage_id := StringName(str(key))
        if _catalog.stage_economy(stage_id).is_empty():
            continue
        var raw: Dictionary = (state.get("clone_profiles", {}) as Dictionary)[key]
        var cycle := float(raw.get("cycle_seconds", 0.0))
        var count := maxi(int(raw.get("clone_count", 0)), 0)
        var quality := float(raw.get("route_quality", 1.0))
        if cycle > 0.0 and is_finite(cycle) and is_finite(quality):
            restored_profiles[stage_id] = {"cycle_seconds": cycle, "clone_count": count, "route_quality": quality}
    _balance = restored_balance
    _clone_profiles = restored_profiles
    _income_multiplier = maxf(float(state.get("income_multiplier", 1.0)), 0.000001)
    _clone_reward_multiplier = maxf(float(state.get("clone_reward_multiplier", 1.0)), 0.000001)
    _active_reward_multiplier = maxf(float(state.get("active_reward_multiplier", 1.0)), 0.000001)
    economy_changed.emit(current_resource(), BigResourceType.new().snapshot(), &"restore")
    rate_changed.emit(resource_per_second())
    return true

func _apply_passive_income(elapsed_seconds: float) -> void:
    var total = BigResourceType.new()
    for stage_id_value in _clone_profiles.keys():
        var stage_id := StringName(str(stage_id_value))
        var profile: Dictionary = _clone_profiles[stage_id]
        var cycle_seconds := float(profile.get("cycle_seconds", 0.0))
        var clone_count := maxi(int(profile.get("clone_count", 0)), 0)
        if cycle_seconds <= 0.0 or clone_count <= 0:
            continue
        var cycle_reward = _calculate_clone_reward_value(stage_id, cycle_seconds, profile)
        if cycle_reward == null:
            continue
        cycle_reward.divide_assign(cycle_seconds)
        cycle_reward.multiply_assign(float(clone_count) * elapsed_seconds * _income_multiplier)
        total.add_assign(cycle_reward)
        clone_income_tick.emit(stage_id, cycle_reward.snapshot())
    if not total.is_zero():
        _balance.add_assign(total)
        economy_changed.emit(current_resource(), total.snapshot(), &"clone_passive")

func _resource_per_second_value():
    var total = BigResourceType.new()
    for stage_id_value in _clone_profiles.keys():
        var stage_id := StringName(str(stage_id_value))
        var profile: Dictionary = _clone_profiles[stage_id]
        var cycle_seconds := float(profile.get("cycle_seconds", 0.0))
        var clone_count := maxi(int(profile.get("clone_count", 0)), 0)
        if cycle_seconds <= 0.0 or clone_count <= 0:
            continue
        var cycle_reward = _calculate_clone_reward_value(stage_id, cycle_seconds, profile)
        if cycle_reward == null:
            continue
        cycle_reward.divide_assign(cycle_seconds)
        cycle_reward.multiply_assign(float(clone_count))
        total.add_assign(cycle_reward)
    total.multiply_assign(_income_multiplier)
    return total

func _calculate_active_reward_value(stage_id: StringName, elapsed_seconds: float):
    if elapsed_seconds <= 0.0 or not is_finite(elapsed_seconds):
        return null
    var stage := _catalog.stage_economy(stage_id)
    if stage.is_empty():
        return null
    var rules := _catalog.active_reward_rules()
    var target := maxf(float(stage.get("target_first_clear_seconds", elapsed_seconds)), 0.001)
    var speed_factor := pow(target / elapsed_seconds, float(rules.get("speed_power", 0.45)))
    speed_factor = clampf(speed_factor, float(rules.get("min_speed_factor", 0.75)), float(rules.get("max_speed_factor", 2.2)))
    return BigResourceType.from_number(float(stage.get("base_reward", 0.0)) * speed_factor * _active_reward_multiplier)

func _calculate_clone_reward_value(stage_id: StringName, best_time: float, clone_profile: Dictionary):
    if best_time <= 0.0 or not is_finite(best_time):
        return null
    var stage := _catalog.stage_economy(stage_id)
    if stage.is_empty():
        return null
    var rules := _catalog.clone_reward_rules()
    var target := maxf(float(stage.get("target_first_clear_seconds", best_time)), 0.001)
    var speed_factor := pow(target / best_time, float(rules.get("speed_power", 0.35)))
    speed_factor = clampf(speed_factor, float(rules.get("min_speed_factor", 0.75)), float(rules.get("max_speed_factor", 1.8)))
    var route_quality := clampf(float(clone_profile.get("route_quality", 1.0)), float(rules.get("route_quality_min", 0.5)), float(rules.get("route_quality_max", 1.5)))
    return BigResourceType.from_number(float(stage.get("base_reward", 0.0)) * float(rules.get("base_fraction", 0.72)) * speed_factor * route_quality * _clone_reward_multiplier)

func _coerce_resource(value):
    match typeof(value):
        TYPE_INT, TYPE_FLOAT:
            return BigResourceType.from_number(float(value))
        TYPE_DICTIONARY:
            return BigResourceType.from_snapshot(value)
        _:
            return null
