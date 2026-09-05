class_name ProgressionPanel
extends PanelContainer

signal action_result(action: StringName, result)

const HUDModelType = preload("res://Game/UI/ProgressionHUDModel.gd")

var _world: Node
var _model := HUDModelType.new()
var _scroll: ScrollContainer
var _content: VBoxContainer

func _ready() -> void:
    custom_minimum_size = Vector2(420.0, 0.0)
    _scroll = ScrollContainer.new()
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(_scroll)
    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 10)
    _scroll.add_child(_content)
    _refresh()

func bind(progression_world: Node) -> void:
    _world = progression_world
    _model.bind(progression_world)
    for signal_name in [&"stage_context_changed", &"economy_changed", &"economy_rate_changed", &"upgrade_purchased", &"ability_unlocked", &"clone_capacity_changed"]:
        if _world != null and _world.has_signal(signal_name):
            _world.connect(signal_name, Callable(self, "_on_world_changed"))
    if is_inside_tree():
        call_deferred("_refresh")

func _on_world_changed(_a = null, _b = null, _c = null) -> void:
    call_deferred("_refresh")

func _refresh() -> void:
    if _content == null:
        return
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()
    if _world == null:
        _content.add_child(_label("Progression UI waiting for ProgressionWorld", 18))
        return
    var data := _model.snapshot()
    if data.is_empty():
        _content.add_child(_label("Progression data unavailable", 18))
        return

    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 20)
    title_row.add_child(_label(str(data.get("resource_text", "0 Flux")), 24))
    title_row.add_child(_label(str(data.get("rate_text", "0 Flux/s")), 18))
    title_row.add_child(_label(str(data.get("clone_text", "0/1 echoes")), 18))
    _content.add_child(title_row)

    _content.add_child(_label(str(data.get("stage_title", "")) + "  •  " + str(data.get("timer_text", "0:00.00")) + "  •  Best " + str(data.get("best_text", "--")), 20))
    var objective := _label(str(data.get("objective_text", "")), 18)
    objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _content.add_child(objective)
    _content.add_child(HSeparator.new())

    _content.add_child(_label("Stages", 22))
    var allocation: Dictionary = _world.call("clone_allocation_snapshot")
    var global_remaining := int(allocation.get("remaining", 0))
    for stage_value in data.get("stages", []):
        _content.add_child(_stage_row(stage_value, global_remaining))

    _content.add_child(HSeparator.new())
    _content.add_child(_label("Upgrades", 22))
    for upgrade_value in data.get("upgrades", []):
        _content.add_child(_upgrade_row(upgrade_value))

func _stage_row(stage: Dictionary, global_remaining: int) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var stage_id := StringName(str(stage.get("stage_id", "")))
    var open_button := Button.new()
    open_button.custom_minimum_size = Vector2(210.0, 48.0)
    open_button.text = str(stage.get("title", stage_id))
    open_button.disabled = not bool(stage.get("available", false))
    open_button.pressed.connect(_on_stage_pressed.bind(stage_id))
    row.add_child(open_button)

    var clone_count := int(stage.get("clone_count", 0))
    var per_stage_cap := int(stage.get("per_stage_clone_cap", 3))
    var minus := Button.new()
    minus.text = "−"
    minus.custom_minimum_size = Vector2(48.0, 48.0)
    minus.disabled = clone_count <= 0
    minus.pressed.connect(_on_clone_change.bind(stage_id, clone_count - 1))
    row.add_child(minus)
    var clone_label := _label("%d/%d" % [clone_count, per_stage_cap], 18)
    clone_label.custom_minimum_size = Vector2(54.0, 48.0)
    clone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    clone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(clone_label)
    var plus := Button.new()
    plus.text = "+"
    plus.custom_minimum_size = Vector2(48.0, 48.0)
    plus.disabled = clone_count >= per_stage_cap or global_remaining <= 0 or not bool(stage.get("cleared", false))
    plus.pressed.connect(_on_clone_change.bind(stage_id, clone_count + 1))
    row.add_child(plus)
    box.add_child(row)

    var status_parts: Array[String] = []
    if not bool(stage.get("available", false)):
        status_parts.append("LOCKED: " + str(stage.get("lock_reason", "Unavailable")))
    elif bool(stage.get("mastered", false)):
        status_parts.append("MASTERED")
    elif bool(stage.get("cleared", false)):
        status_parts.append("CLEARED")
    else:
        status_parts.append("READY")
    status_parts.append("Best " + str(stage.get("best_text", "--")))
    status_parts.append("Target " + str(stage.get("mastery_target_text", "--")))
    box.add_child(_label(" • ".join(status_parts), 16))
    return box

func _upgrade_row(card: Dictionary) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, 48.0)
    var prefix := "KEY • " if bool(card.get("key_progression", false)) else ""
    button.text = "%s%s  L%d  •  %s  •  %s" % [prefix, str(card.get("title", "Upgrade")), int(card.get("level", 0)), str(card.get("cost_text", "")), str(card.get("effect_text", ""))]
    button.disabled = not bool(card.get("enabled", false))
    button.pressed.connect(_on_upgrade_pressed.bind(StringName(str(card.get("upgrade_id", "")))))
    box.add_child(button)
    var description := _label(str(card.get("description", "")) + "  [" + str(card.get("status_text", "")) + "]", 16)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(description)
    return box

func _on_stage_pressed(stage_id: StringName) -> void:
    var ok := bool(_world.call("select_stage", stage_id))
    action_result.emit(&"select_stage", {"ok": ok, "stage_id": stage_id})
    _refresh()

func _on_upgrade_pressed(upgrade_id: StringName) -> void:
    var result = _world.call("purchase_upgrade", upgrade_id)
    action_result.emit(&"purchase_upgrade", result)
    _refresh()

func _on_clone_change(stage_id: StringName, count: int) -> void:
    var ok := bool(_world.call("set_clone_count", stage_id, count))
    action_result.emit(&"set_clone_count", {"ok": ok, "stage_id": stage_id, "count": count})
    _refresh()

func _label(text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    return label
