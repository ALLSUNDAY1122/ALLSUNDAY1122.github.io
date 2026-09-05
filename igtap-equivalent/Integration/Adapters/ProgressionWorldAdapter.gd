class_name ProgressionWorldAdapter
extends Node

signal stage_context_changed(context: Dictionary)
signal stage_availability_changed(stage_id: StringName, availability: Dictionary)
signal currency_changed(total: float)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal ability_unlocked(ability_id: StringName)
signal movement_effects_changed(effects: Dictionary)
signal clone_capacity_changed(capacity: int)
signal clone_income_applied(stage_id: StringName, amount: float)
signal economy_rate_changed(rate: Dictionary)

var _implementation: Node

func bind(implementation: Node) -> void:
    _implementation = implementation
    for signal_name in [&"stage_context_changed", &"stage_availability_changed", &"currency_changed", &"upgrade_purchased", &"ability_unlocked", &"movement_effects_changed", &"clone_capacity_changed", &"clone_income_applied", &"economy_rate_changed"]:
        if implementation.has_signal(signal_name):
            implementation.connect(signal_name, func(a = null, b = null, c = null): _relay(signal_name, a, b, c))

func _relay(signal_name: StringName, a, b, _c) -> void:
    match signal_name:
        &"stage_context_changed": stage_context_changed.emit(a)
        &"stage_availability_changed": stage_availability_changed.emit(a, b)
        &"currency_changed": currency_changed.emit(a)
        &"upgrade_purchased": upgrade_purchased.emit(a, b)
        &"ability_unlocked": ability_unlocked.emit(a)
        &"movement_effects_changed": movement_effects_changed.emit(a)
        &"clone_capacity_changed": clone_capacity_changed.emit(a)
        &"clone_income_applied": clone_income_applied.emit(a, b)
        &"economy_rate_changed": economy_rate_changed.emit(a)

func register_lap(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary) -> void:
    if _implementation != null and _implementation.has_method("register_lap"):
        _implementation.register_lap(stage_id, elapsed_seconds, replay_payload)

func register_death(stage_id: StringName, reason) -> Dictionary:
    return _implementation.call("register_death", stage_id, reason) if _implementation != null and _implementation.has_method("register_death") else {}

func get_unlocked_abilities() -> Array[StringName]:
    if _implementation != null and _implementation.has_method("get_unlocked_abilities"):
        return _implementation.get_unlocked_abilities()
    return []

func movement_effects() -> Dictionary:
    return _implementation.call("movement_effects") if _implementation != null and _implementation.has_method("movement_effects") else {}

func current_stage_context() -> Dictionary:
    return _implementation.call("current_stage_context") if _implementation != null and _implementation.has_method("current_stage_context") else {}

func select_stage(stage_id: StringName) -> bool:
    return bool(_implementation.call("select_stage", stage_id)) if _implementation != null and _implementation.has_method("select_stage") else false

func begin_stage(stage_id: StringName = &"") -> bool:
    return bool(_implementation.call("begin_stage", stage_id)) if _implementation != null and _implementation.has_method("begin_stage") else false

func stage_select_entries() -> Array[Dictionary]:
    return _implementation.call("stage_select_entries") if _implementation != null and _implementation.has_method("stage_select_entries") else []

func purchase_upgrade(upgrade_id: StringName) -> Dictionary:
    return _implementation.call("purchase_upgrade", upgrade_id) if _implementation != null and _implementation.has_method("purchase_upgrade") else {"ok": false, "reason": "not_bound"}

func set_clone_count(stage_id: StringName, clone_count: int) -> bool:
    return bool(_implementation.call("set_clone_count", stage_id, clone_count)) if _implementation != null and _implementation.has_method("set_clone_count") else false

func clone_allocation_snapshot() -> Dictionary:
    return _implementation.call("clone_allocation_snapshot") if _implementation != null and _implementation.has_method("clone_allocation_snapshot") else {}

func progression_snapshot() -> Dictionary:
    return _implementation.call("progression_snapshot") if _implementation != null and _implementation.has_method("progression_snapshot") else {}

func add_resource(amount, source: StringName = &"integration") -> bool:
    return bool(_implementation.call("add_resource", amount, source)) if _implementation != null and _implementation.has_method("add_resource") else false

func serialize_state() -> Dictionary:
    if _implementation != null and _implementation.has_method("serialize_state"):
        var state: Variant = _implementation.serialize_state()
        return state if typeof(state) == TYPE_DICTIONARY else {}
    return {}

func restore_state(state: Dictionary) -> void:
    if _implementation != null and _implementation.has_method("restore_state"):
        _implementation.restore_state(state)

func apply_offline_progress(elapsed_seconds: float) -> void:
    if _implementation != null and _implementation.has_method("apply_offline_progress"):
        _implementation.apply_offline_progress(elapsed_seconds)
