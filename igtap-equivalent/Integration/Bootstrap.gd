extends Node

const CoreAdapter = preload("res://Integration/Adapters/CoreGameplayAdapter.gd")
const ProgressionAdapter = preload("res://Integration/Adapters/ProgressionWorldAdapter.gd")
const MockCore = preload("res://Integration/Mock/MockCoreGameplay.gd")
const MockProgression = preload("res://Integration/Mock/MockProgressionWorld.gd")
const MobileControls = preload("res://Platform/Input/MobileControls.gd")

var _core: CoreGameplayAdapter
var _progression: ProgressionWorldAdapter
var _currency_label: Label

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

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 90
    add_child(layer)
    _currency_label = Label.new()
    _currency_label.text = "ENERGY  0.00"
    _currency_label.position = Vector2(28, 24)
    _currency_label.add_theme_font_size_override("font_size", 24)
    layer.add_child(_currency_label)
    var hint := Label.new()
    hint.text = "Mock integration • move / jump / dash • reach the green gate"
    hint.position = Vector2(28, 58)
    hint.modulate.a = 0.72
    layer.add_child(hint)

func _on_currency_changed(total: float) -> void:
    _currency_label.text = "ENERGY  %.2f" % total
