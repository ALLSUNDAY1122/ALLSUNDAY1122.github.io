extends Node

const CoreAdapter = preload("res://Integration/Adapters/CoreGameplayAdapter.gd")
const ProgressionAdapter = preload("res://Integration/Adapters/ProgressionWorldAdapter.gd")
const CoreCompat = preload("res://Integration/CoreGameplayCompat.gd")
const ProgressionWorldType = preload("res://Game/Progression/ProgressionWorld.gd")
const StageAssemblerType = preload("res://Game/World/PrototypeStageAssembler.gd")
const ProgressionPanelType = preload("res://Game/UI/ProgressionPanel.gd")
const MobileControls = preload("res://Platform/Input/MobileControls.gd")

var _core: CoreGameplayAdapter
var _progression: ProgressionWorldAdapter
var _core_impl: Node
var _world_impl: Node
var _assembler: Node2D
var _active_stage_id: StringName = &""
var _ability_gates: Array[Node] = []

var _hud_root: Control
var _currency_label: Label
var _hint_label: Label
var _panel: Control
var _panel_toggle: Button

func _ready() -> void:
    _core = CoreAdapter.new()
    _progression = ProgressionAdapter.new()
    add_child(_progression)
    add_child(_core)

    _world_impl = ProgressionWorldType.new()
    _core_impl = CoreCompat.new()
    _assembler = StageAssemblerType.new()
    _assembler.auto_build = false
    add_child(_world_impl)
    add_child(_assembler)
    add_child(_core_impl)
    _progression.bind(_world_impl)
    _core.bind(_core_impl)

    _assembler.stage_trigger_created.connect(_wire_stage_trigger)
    _assembler.gimmick_created.connect(_wire_gimmick)

    _core.lap_completed.connect(_progression.register_lap)
    _core.lap_completed.connect(_on_lap_completed)
    _core.player_died.connect(_on_player_died)
    _core.checkpoint_reached.connect(func(_id): Haptics.light())
    _core.recording_completed.connect(func(_stage, _payload): SaveStore.request_save(&"recording_completed"))
    _progression.ability_unlocked.connect(_on_ability_unlocked)
    _progression.movement_effects_changed.connect(_on_movement_effects_changed)
    _progression.stage_context_changed.connect(_on_stage_context_changed)

    add_child(MobileControls.new())
    _build_ui()
    _progression.currency_changed.connect(_on_currency_changed)
    IOSLayout.safe_area_changed.connect(func(_rect: Rect2): _layout_ui())
    get_viewport().size_changed.connect(_layout_ui)
    call_deferred("_finish_runtime_setup")

func _finish_runtime_setup() -> void:
    SaveStore.register_section(&"progression", Callable(_progression, "serialize_state"), Callable(_progression, "restore_state"))
    SaveStore.register_section(&"replay", Callable(_core, "serialize_state"), Callable(_core, "restore_state"))
    SaveStore.offline_elapsed.connect(_progression.apply_offline_progress)
    SaveStore.load_and_restore()
    Haptics.set_enabled(bool(SaveStore.get_setting(&"haptics_enabled", true)))
    _apply_audio_settings()
    _core.apply_ability_set(_progression.get_unlocked_abilities())
    _core.apply_movement_effects(_progression.movement_effects())
    _on_stage_context_changed(_progression.current_stage_context())
    _reconcile_all_clones()
    call_deferred("_layout_ui")

func _on_stage_context_changed(context: Dictionary) -> void:
    if context.is_empty():
        return
    _core.set_stage_context(context)
    var stage_id := StringName(str(context.get("stage_id", "relay_yard")))
    if stage_id != _active_stage_id:
        _build_stage(stage_id)

func _build_stage(stage_id: StringName) -> void:
    _active_stage_id = stage_id
    _ability_gates.clear()
    if not bool(_assembler.call("build_stage", stage_id)):
        push_error("Failed to build stage: %s" % stage_id)
        return
    _core.set_stage_context(_progression.current_stage_context())
    _core.begin_lap(stage_id)
    _reconcile_stage_clones(stage_id)

func _wire_stage_trigger(node: Node) -> void:
    if node.has_signal("start_requested"):
        var start_node := node as Node2D
        _core.set_stage_spawn(start_node.global_position + Vector2(-48.0, 0.0))
        node.connect("start_requested", func(stage_id: StringName):
            _progression.begin_stage(stage_id)
            _core.begin_lap(stage_id)
        )
    if node.has_signal("goal_reached"):
        node.connect("goal_reached", func(stage_id: StringName): _core.finish_lap(stage_id))
    if node.has_signal("checkpoint_reached"):
        var checkpoint_node := node as Node2D
        node.connect("checkpoint_reached", func(_stage_id: StringName, checkpoint_id: StringName):
            _core.reach_checkpoint(checkpoint_id, checkpoint_node.global_position + Vector2(0.0, -42.0))
        )

func _wire_gimmick(node: Node) -> void:
    if node.has_signal("launch_requested"):
        node.connect("launch_requested", func(body: Node, launch_velocity: Vector2, _spring_id: StringName):
            if body == _core_impl:
                _core.launch(launch_velocity)
                Haptics.light()
        )
    if node.has_signal("hazard_contact"):
        node.connect("hazard_contact", func(body: Node, _hazard_id: StringName, reason: StringName):
            if body == _core_impl:
                _core.kill(reason)
        )
    if node.has_method("set_unlocked_abilities"):
        _ability_gates.append(node)
        node.call("set_unlocked_abilities", _progression.get_unlocked_abilities())

func _on_player_died(reason: StringName) -> void:
    _progression.register_death(_active_stage_id, reason)
    Haptics.error()
    SaveStore.request_save(&"player_died")

func _on_ability_unlocked(_ability_id: StringName) -> void:
    var abilities := _progression.get_unlocked_abilities()
    _core.apply_ability_set(abilities)
    for gate in _ability_gates:
        if is_instance_valid(gate) and gate.has_method("set_unlocked_abilities"):
            gate.call("set_unlocked_abilities", abilities)
    Haptics.medium()
    SaveStore.request_save(&"ability_unlocked")

func _on_movement_effects_changed(effects: Dictionary) -> void:
    _core.apply_movement_effects(effects)
    SaveStore.request_save(&"movement_effects")

func _on_lap_completed(stage_id: StringName, elapsed_seconds: float, _replay_payload: Dictionary) -> void:
    SaveStore.record_best_time(stage_id, elapsed_seconds)
    Haptics.success()
    SaveStore.request_save(&"lap_completed")
    call_deferred("_reconcile_stage_clones", stage_id)

func _reconcile_all_clones() -> void:
    var allocation := _progression.clone_allocation_snapshot()
    var by_stage: Dictionary = allocation.get("by_stage", {})
    for key in by_stage.keys():
        _core.reconcile_clones(StringName(str(key)), int(by_stage[key]))

func _reconcile_stage_clones(stage_id: StringName) -> void:
    var allocation := _progression.clone_allocation_snapshot()
    var by_stage: Dictionary = allocation.get("by_stage", {})
    _core.reconcile_clones(stage_id, int(by_stage.get(str(stage_id), 0)))

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 110
    add_child(layer)
    _hud_root = Control.new()
    layer.add_child(_hud_root)

    _currency_label = Label.new()
    _currency_label.text = "FLUX  0.00"
    _currency_label.add_theme_font_size_override("font_size", 24)
    _currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud_root.add_child(_currency_label)

    _hint_label = Label.new()
    _hint_label.text = "Move • Jump • Route • Improve • Upgrade • Echo"
    _hint_label.modulate.a = 0.72
    _hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud_root.add_child(_hint_label)

    _panel_toggle = Button.new()
    _panel_toggle.text = "PROGRESSION"
    _panel_toggle.custom_minimum_size = Vector2(160.0, 48.0)
    _panel_toggle.pressed.connect(func():
        _panel.visible = not _panel.visible
        _panel_toggle.text = "CLOSE" if _panel.visible else "PROGRESSION"
    )
    _hud_root.add_child(_panel_toggle)

    _panel = ProgressionPanelType.new()
    _panel.visible = false
    _hud_root.add_child(_panel)
    _panel.call("bind", _world_impl)
    _panel.action_result.connect(_on_panel_action)

func _on_panel_action(action: StringName, result) -> void:
    if action == &"select_stage" and typeof(result) == TYPE_DICTIONARY and bool(result.get("ok", false)):
        _panel.visible = false
        _panel_toggle.text = "PROGRESSION"
        Haptics.light()
    elif action == &"purchase_upgrade" and typeof(result) == TYPE_DICTIONARY and bool(result.get("ok", false)):
        Haptics.medium()
        SaveStore.request_save(&"upgrade_purchased")
    elif action == &"set_clone_count":
        _reconcile_all_clones()
        SaveStore.request_save(&"clone_allocation")

func _layout_ui() -> void:
    if _hud_root == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var safe := IOSLayout.safe_rect_in_viewport(viewport_size)
    _hud_root.position = safe.position + Vector2(18.0, 14.0)
    _hud_root.size = Vector2(maxf(0.0, safe.size.x - 36.0), maxf(0.0, safe.size.y - 28.0))
    _currency_label.position = Vector2.ZERO
    _hint_label.position = Vector2(0.0, 34.0)
    _panel_toggle.position = Vector2(maxf(0.0, _hud_root.size.x - 170.0), 0.0)
    _panel_toggle.size = Vector2(160.0, 48.0)
    var panel_width := minf(470.0, _hud_root.size.x * 0.48)
    _panel.position = Vector2(maxf(0.0, _hud_root.size.x - panel_width), 58.0)
    _panel.size = Vector2(panel_width, maxf(0.0, _hud_root.size.y - 58.0))

func _on_currency_changed(total: float) -> void:
    _currency_label.text = "FLUX  %.2f" % total

func _apply_audio_settings() -> void:
    var master := clampf(float(SaveStore.get_setting(&"master_volume", 1.0)), 0.0, 1.0)
    if AudioServer.bus_count > 0:
        AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
