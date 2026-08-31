class_name ProgressionHUDModel
extends RefCounted

const ResourceFormatterType = preload("res://Game/UI/ResourceFormatter.gd")
const UICatalogType = preload("res://Game/UI/UICatalog.gd")

var _world: Node
var _formatter := ResourceFormatterType.new()
var _ui := UICatalogType.new()

func bind(progression_world: Node) -> void:
    _world = progression_world
    _formatter.load_catalog()
    _ui.load_from_path()

func snapshot() -> Dictionary:
    if _world == null or not _world.has_method("current_stage_context"):
        return {}
    var context: Dictionary = _world.call("current_stage_context")
    var economy: Dictionary = context.get("economy", {})
    var progression: Dictionary = context.get("progression", {})
    var definition: Dictionary = context.get("definition", {})
    var progress: Dictionary = context.get("progress", {})
    var run: Dictionary = context.get("run", {})
    var allocation: Dictionary = progression.get("clone_allocation", {})
    var best := float(progress.get("best_time_seconds", -1.0))
    return {
        "resource_text": _formatter.format_resource(economy.get("balance", {})),
        "rate_text": _formatter.format_rate(economy.get("resource_per_second", {})),
        "stage_title": str(definition.get("display_name", context.get("stage_id", ""))),
        "timer_text": _format_seconds(float(run.get("elapsed_seconds", 0.0))),
        "best_text": "--" if best < 0.0 else _format_seconds(best),
        "objective_text": _objective_text(context),
        "clone_text": "%d/%d echoes • %d/stage" % [int(allocation.get("allocated", 0)), int(allocation.get("capacity", 1)), int(allocation.get("per_stage_cap", progression.get("per_stage_clone_cap", 3)))],
        "stages": stage_cards(context),
        "upgrades": upgrade_cards(),
        "accessibility": _ui.accessibility()
    }

func stage_cards(context: Dictionary = {}) -> Array[Dictionary]:
    if _world == null or not _world.has_method("stage_select_entries"):
        return []
    var progression: Dictionary = context.get("progression", {}) if not context.is_empty() else _world.call("progression_snapshot")
    var allocation: Dictionary = progression.get("clone_allocation", {})
    var by_stage: Dictionary = allocation.get("by_stage", {})
    var cards: Array[Dictionary] = []
    for value in _world.call("stage_select_entries"):
        var entry: Dictionary = value
        var stage_id := StringName(str(entry.get("stage_id", "")))
        var availability: Dictionary = entry.get("availability", {})
        var reason := StringName(str(availability.get("reason", "available")))
        var best := float(entry.get("best_time_seconds", -1.0))
        var target := float(entry.get("target_mastery_seconds", -1.0))
        cards.append({
            "stage_id": stage_id,
            "title": str(entry.get("display_name", stage_id)),
            "available": bool(entry.get("available", false)),
            "cleared": bool(entry.get("cleared", false)),
            "selected": bool(entry.get("selected", false)),
            "lock_reason": "" if bool(entry.get("available", false)) else _ui.lock_reason_label(reason),
            "best_text": "--" if best < 0.0 else _format_seconds(best),
            "mastery_target_text": "--" if target < 0.0 else _format_seconds(target),
            "mastered": best > 0.0 and target > 0.0 and best <= target,
            "clone_count": int(by_stage.get(str(stage_id), 0)),
            "per_stage_clone_cap": int(allocation.get("per_stage_cap", progression.get("per_stage_clone_cap", 3)))
        })
    return cards

func upgrade_cards() -> Array[Dictionary]:
    if _world == null:
        return []
    var cards: Array[Dictionary] = []
    var balance: Dictionary = _world.call("current_resource") if _world.has_method("current_resource") else {}
    for upgrade_id in _ui.upgrade_order():
        var copy := _ui.upgrade_copy(upgrade_id)
        var availability: Dictionary = _world.call("upgrade_availability", upgrade_id)
        var cost: Dictionary = _world.call("current_cost", upgrade_id)
        var effect: Dictionary = _world.call("resulting_effect", upgrade_id)
        var reason := StringName(str(availability.get("reason", "available")))
        var at_max := reason == &"max_level"
        var affordable := not cost.is_empty() and _resource_gte(balance, cost)
        cards.append({
            "upgrade_id": upgrade_id,
            "title": str(copy.get("label", upgrade_id)),
            "description": str(copy.get("description", "")),
            "key_progression": bool(copy.get("key_progression", false)),
            "level": int(_world.call("current_level", upgrade_id)),
            "cost": cost,
            "cost_text": "MAX" if at_max else _formatter.format_resource(cost),
            "effect_text": _effect_text(effect),
            "available": bool(availability.get("available", false)),
            "affordable": affordable,
            "enabled": bool(availability.get("available", false)) and affordable,
            "status_text": "MAX" if at_max else ("Ready" if bool(availability.get("available", false)) and affordable else ("Need more Flux" if bool(availability.get("available", false)) else _ui.lock_reason_label(reason)))
        })
    return cards

func _objective_text(context: Dictionary) -> String:
    var stage_entries: Array = context.get("stage_select", [])
    var cleared: Dictionary = {}
    for value in stage_entries:
        var entry: Dictionary = value
        cleared[StringName(str(entry.get("stage_id", "")))] = bool(entry.get("cleared", false))
    var chain := [
        {"stage": &"relay_yard", "ability": &"speed_tune", "label": "Drive Tuning", "next": "Liftworks"},
        {"stage": &"liftworks", "ability": &"dash", "label": "Vector Burst", "next": "Phase Foundry"},
        {"stage": &"phase_foundry", "ability": &"double_jump", "label": "Air Relay", "next": "Blackout Array"},
        {"stage": &"blackout_array", "ability": &"wall_jump", "label": "Surface Rebound", "next": "Core Spire"},
        {"stage": &"core_spire", "ability": &"phase_shift", "label": "Phase Override", "next": "revisit routes"}
    ]
    for item in chain:
        var stage_id: StringName = item["stage"]
        var ability_id: StringName = item["ability"]
        if not bool(cleared.get(stage_id, false)):
            return "Objective: clear " + _stage_title(stage_id, stage_entries) + "."
        if not bool(_world.call("is_ability_unlocked", ability_id)):
            return "Objective: buy %s to open %s." % [str(item["label"]), str(item["next"])]
    return "Objective: optimize old routes, beat mastery times, and distribute echoes."

func _stage_title(stage_id: StringName, entries: Array) -> String:
    for value in entries:
        var entry: Dictionary = value
        if StringName(str(entry.get("stage_id", ""))) == stage_id:
            return str(entry.get("display_name", stage_id))
    return str(stage_id)

func _effect_text(effect: Dictionary) -> String:
    if effect.has("current_multiplier"):
        return "×%.2f → ×%.2f" % [float(effect.get("current_multiplier", 1.0)), float(effect.get("next_multiplier", 1.0))]
    if effect.has("current_value"):
        return "%d → %d" % [int(effect.get("current_value", 0)), int(effect.get("next_value", 0))]
    if effect.has("unlocked"):
        return "Unlocked" if bool(effect.get("unlocked", false)) else "Locked → Unlocked"
    return ""

func _resource_gte(left: Dictionary, right: Dictionary) -> bool:
    if right.is_empty():
        return false
    var left_exp := int(left.get("exponent", 0))
    var right_exp := int(right.get("exponent", 0))
    if left_exp != right_exp:
        return left_exp > right_exp
    return float(left.get("mantissa", 0.0)) + 0.0000001 >= float(right.get("mantissa", 0.0))

func _format_seconds(value: float) -> String:
    var safe := maxf(value, 0.0)
    var minutes := int(safe / 60.0)
    var seconds := safe - float(minutes * 60)
    return "%d:%05.2f" % [minutes, seconds]
