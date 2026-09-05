extends Node

const CoreAdapterType = preload("res://Integration/Adapters/CoreGameplayAdapter.gd")
const ProgressionAdapterType = preload("res://Integration/Adapters/ProgressionWorldAdapter.gd")
const CoreCompatType = preload("res://Integration/CoreGameplayCompat.gd")
const ProgressionWorldType = preload("res://Game/Progression/ProgressionWorld.gd")

var _failed := false

func _ready() -> void:
    await _run()
    if _failed:
        get_tree().quit(1)
    else:
        print("FULL_LOOP_SELF_TEST_PASS")
        get_tree().quit(0)

func _run() -> void:
    var core_adapter := CoreAdapterType.new()
    var progression_adapter := ProgressionAdapterType.new()
    var world := ProgressionWorldType.new()
    var core := CoreCompatType.new()
    add_child(progression_adapter)
    add_child(core_adapter)
    add_child(world)
    add_child(core)
    progression_adapter.bind(world)
    core_adapter.bind(core)
    core_adapter.lap_completed.connect(progression_adapter.register_lap)
    progression_adapter.ability_unlocked.connect(func(_id): core_adapter.apply_ability_set(progression_adapter.get_unlocked_abilities()))
    progression_adapter.movement_effects_changed.connect(core_adapter.apply_movement_effects)
    await get_tree().process_frame
    await get_tree().process_frame

    core.debug_complete_lap(&"relay_yard", 5.0)
    _check(_stage_entry(progression_adapter.stage_select_entries(), &"relay_yard").get("cleared", false), "relay_yard should clear through lap adapter")
    _check(progression_adapter.add_resource(5000.0, &"c3_test"), "test resource injection should succeed")

    var speed_result := progression_adapter.purchase_upgrade(&"speed_tune")
    _check(bool(speed_result.get("ok", false)), "speed_tune should purchase after relay clear")
    core_adapter.apply_movement_effects(progression_adapter.movement_effects())
    _check(float(core_adapter.movement_snapshot().get("run_speed_multiplier", 1.0)) > 1.0, "speed_tune must affect CoreCompat movement")

    core.debug_complete_lap(&"liftworks", 4.0)
    _check(_stage_entry(progression_adapter.stage_select_entries(), &"liftworks").get("cleared", false), "liftworks should clear")
    var dash_result := progression_adapter.purchase_upgrade(&"dash")
    _check(bool(dash_result.get("ok", false)), "dash should purchase after liftworks and speed_tune")
    core_adapter.apply_ability_set(progression_adapter.get_unlocked_abilities())
    _check(core_adapter.has_ability(&"dash"), "Session B dash must map into Session A-compatible dash")

    core.debug_complete_lap(&"relay_yard", 4.0)
    var relay := _stage_entry(progression_adapter.stage_select_entries(), &"relay_yard")
    _check(absf(float(relay.get("best_time_seconds", -1.0)) - 4.0) < 0.001, "faster lap should replace best time")

    var allocation := progression_adapter.clone_allocation_snapshot()
    var by_stage: Dictionary = allocation.get("by_stage", {})
    var desired := int(by_stage.get("relay_yard", 0))
    _check(desired >= 1, "first valid route should allocate at least one echo")
    _check(core_adapter.reconcile_clones(&"relay_yard", desired) == desired, "allocated echo count must create real replay clones")

    var replay_state := core_adapter.serialize_state()
    _check(int(replay_state.get("schema_version", -1)) == 1, "replay persistence schema should be v1")
    var restored_core := CoreCompatType.new()
    add_child(restored_core)
    await get_tree().process_frame
    _check(restored_core.restore_state(replay_state), "replay state must restore")
    _check(not restored_core.best_recording(&"relay_yard").is_empty(), "best route must survive restore")

func _stage_entry(entries: Array[Dictionary], stage_id: StringName) -> Dictionary:
    for entry in entries:
        if StringName(str(entry.get("stage_id", ""))) == stage_id:
            return entry
    return {}

func _check(value, message: String) -> void:
    if not bool(value):
        _failed = true
        push_error("C3 SELF TEST: %s" % message)
