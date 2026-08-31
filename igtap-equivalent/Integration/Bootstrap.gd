extends Node

const CoreAdapter = preload("res://Integration/Adapters/CoreGameplayAdapter.gd")
const ProgressionAdapter = preload("res://Integration/Adapters/ProgressionWorldAdapter.gd")
const MockCore = preload("res://Integration/Mock/MockCoreGameplay.gd")
const MockProgression = preload("res://Integration/Mock/MockProgressionWorld.gd")
const MobileControls = preload("res://Platform/Input/MobileControls.gd")

var _core: CoreGameplayAdapter
var _progression: ProgressionWorldAdapter
var _hud_root: Control
var _currency_label: Label
var _hint_label: Label

func _ready() -> void:
    _core = CoreAdapter.new()
    _progression = ProgressionAdapter.new()
    add_child(_progression)
    add_child(_core)

    var world_impl := MockProgression.new()
    var core_impl := MockCore.new()
    add_child(world_impl)
    add_child(core_impl)
    _progression.bind(world_impl)
    _core.bind(core_impl)

    _core.lap_completed.connect(_progression.register_lap)
    _progression.ability_unlocked.connect(func(_id): _core.apply_ability_set(_progression.get_unlocked_abilities()))
    _progression.stage_context_changed.connect(_core.set_stage_context)
    _core.set_stage_context(_progression.current_stage_context())

    add_child(MobileControls.new())
    _build_hud()
    _progression.currency_changed.connect(_on_currency_changed)
    IOSLayout.safe_area_changed.connect(func(_rect: Rect2): _layout_hud())
    get_viewport().size_changed.connect(_layout_hud)
    call_deferred("_layout_hud")

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 90
    add_child(layer)
    _hud_root = Control.new()
    _hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(_hud_root)
    _currency_label = Label.new()
    _currency_label.text = "ENERGY  0.00"
    _currency_label.add_theme_font_size_override("font_size", 24)
    _currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud_root.add_child(_currency_label)
    _hint_label = Label.new()
    _hint_label.text = "Mock integration • move / jump / dash • reach the green gate"
    _hint_label.modulate.a = 0.72
    _hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud_root.add_child(_hint_label)

func _layout_hud() -> void:
    if _hud_root == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var safe := IOSLayout.safe_rect_in_viewport(viewport_size)
    _hud_root.position = safe.position + Vector2(18, 14)
    _hud_root.size = Vector2(maxf(0.0, safe.size.x - 36.0), maxf(0.0, safe.size.y - 28.0))
    _currency_label.position = Vector2.ZERO
    _hint_label.position = Vector2(0, 34)

func _on_currency_changed(total: float) -> void:
    _currency_label.text = "ENERGY  %.2f" % total
