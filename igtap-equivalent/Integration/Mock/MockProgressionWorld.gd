class_name MockProgressionWorld
extends Node

signal stage_context_changed(context: Dictionary)
signal currency_changed(total: float)
signal upgrade_purchased(upgrade_id: StringName, level: int)
signal ability_unlocked(ability_id: StringName)
signal clone_income_applied(stage_id: StringName, amount: float)

var _currency := 0.0
var _laps := 0
var _unlocked: Array[StringName] = []
var _context := {"stage_id": &"mock_loop", "goal_x": 1140.0, "mock": true}

func _ready() -> void:
    call_deferred("_announce")

func _announce() -> void:
    stage_context_changed.emit(_context.duplicate(true))
    currency_changed.emit(_currency)

func register_lap(stage_id: StringName, elapsed_seconds: float, _replay_payload: Dictionary) -> void:
    _laps += 1
    var amount := maxf(1.0, 30.0 / maxf(elapsed_seconds, 1.0))
    _currency += amount
    clone_income_applied.emit(stage_id, amount)
    currency_changed.emit(_currency)
    if _laps == 2 and &"dash" not in _unlocked:
        _unlocked.append(&"dash")
        ability_unlocked.emit(&"dash")

func get_unlocked_abilities() -> Array[StringName]:
    return _unlocked.duplicate()

func current_stage_context() -> Dictionary:
    return _context.duplicate(true)

func serialize_state() -> Dictionary:
    return {"currency": _currency, "laps": _laps, "unlocked": _unlocked.duplicate()}

func restore_state(state: Dictionary) -> void:
    _currency = float(state.get("currency", 0.0))
    _laps = int(state.get("laps", 0))
    _unlocked.assign(state.get("unlocked", []))
    _announce()
