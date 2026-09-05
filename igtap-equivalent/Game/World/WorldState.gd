class_name WorldState
extends Node

signal phase_changed(stage_id: StringName, phase: StringName)
signal secret_discovered(stage_id: StringName, secret_id: StringName)
signal shortcut_discovered(stage_id: StringName, shortcut_id: StringName)
signal visibility_changed(stage_id: StringName, visibility_scale: float)
signal world_state_changed(context: Dictionary)

const WorldCatalogType = preload("res://Game/World/WorldCatalog.gd")

var _catalog := WorldCatalogType.new()
var _abilities: Dictionary = {}
var _persistent: Dictionary = {}
var _runtime: Dictionary = {}
var _active_stage_id: StringName = &""
var _loaded := false

func _ready() -> void:
    var error := _catalog.load_from_path()
    if error != OK:
        push_error("World topology failed to load: %s" % error)
        return
    for stage_id in _catalog.stage_ids():
        _persistent[stage_id] = {"secrets": {}, "shortcuts": {}}
        _runtime[stage_id] = _fresh_runtime(stage_id)
    _loaded = true

func _fresh_runtime(stage_id: StringName) -> Dictionary:
    var definition := _catalog.stage(stage_id)
    return {
        "phase": StringName(str(definition.get("default_phase", "neutral"))),
        "visibility_scale": clampf(float(definition.get("default_visibility", 1.0)), 0.15, 1.0)
    }

func set_unlocked_abilities(ability_ids: Array) -> void:
    _abilities.clear()
    for value in ability_ids:
        var ability_id := StringName(str(value))
        if _catalog.is_known_ability(ability_id):
            _abilities[ability_id] = true
    world_state_changed.emit(world_context())

func enter_stage(stage_id: StringName) -> bool:
    if not _loaded or not _catalog.has_stage(stage_id):
        return false
    var definition := _catalog.stage(stage_id)
    var entry_value = definition.get("entry_required_ability", null)
    if entry_value != null:
        var entry_required := StringName(str(entry_value))
        if entry_required != &"" and not _abilities.has(entry_required):
            return false
    _active_stage_id = stage_id
    _runtime[stage_id] = _fresh_runtime(stage_id)
    world_state_changed.emit(world_context(stage_id))
    return true

func set_phase(stage_id: StringName, phase: StringName) -> bool:
    if not _catalog.phase_is_valid(stage_id, phase):
        return false
    var runtime: Dictionary = _runtime.get(stage_id, _fresh_runtime(stage_id))
    if StringName(str(runtime.get("phase", ""))) == phase:
        return true
    runtime["phase"] = phase
    _runtime[stage_id] = runtime
    phase_changed.emit(stage_id, phase)
    world_state_changed.emit(world_context(stage_id))
    return true

func set_visibility(stage_id: StringName, visibility_scale: float) -> bool:
    if not _catalog.has_stage(stage_id):
        return false
    var runtime: Dictionary = _runtime.get(stage_id, _fresh_runtime(stage_id))
    var resolved := clampf(visibility_scale, 0.15, 1.0)
    if is_equal_approx(float(runtime.get("visibility_scale", 1.0)), resolved):
        return true
    runtime["visibility_scale"] = resolved
    _runtime[stage_id] = runtime
    visibility_changed.emit(stage_id, resolved)
    world_state_changed.emit(world_context(stage_id))
    return true

func reset_visibility(stage_id: StringName) -> bool:
    if not _catalog.has_stage(stage_id):
        return false
    var definition := _catalog.stage(stage_id)
    return set_visibility(stage_id, float(definition.get("default_visibility", 1.0)))

func discover_secret(stage_id: StringName, secret_id: StringName) -> bool:
    if not _catalog.contains_discovery(stage_id, &"secret", secret_id):
        return false
    var state: Dictionary = _persistent[stage_id]
    var secrets: Dictionary = state.get("secrets", {})
    if secrets.has(secret_id):
        return true
    secrets[secret_id] = true
    state["secrets"] = secrets
    _persistent[stage_id] = state
    secret_discovered.emit(stage_id, secret_id)
    world_state_changed.emit(world_context(stage_id))
    return true

func discover_shortcut(stage_id: StringName, shortcut_id: StringName) -> bool:
    if not _catalog.contains_discovery(stage_id, &"shortcut", shortcut_id):
        return false
    var state: Dictionary = _persistent[stage_id]
    var shortcuts: Dictionary = state.get("shortcuts", {})
    if shortcuts.has(shortcut_id):
        return true
    shortcuts[shortcut_id] = true
    state["shortcuts"] = shortcuts
    _persistent[stage_id] = state
    shortcut_discovered.emit(stage_id, shortcut_id)
    world_state_changed.emit(world_context(stage_id))
    return true

func can_traverse(stage_id: StringName, edge: Dictionary) -> bool:
    if not _catalog.has_stage(stage_id):
        return false
    var ability := StringName(str(edge.get("requires_ability", "")))
    if ability != &"" and not _abilities.has(ability):
        return false
    var required_phase := StringName(str(edge.get("requires_phase", "")))
    if required_phase != &"":
        var runtime: Dictionary = _runtime.get(stage_id, _fresh_runtime(stage_id))
        if StringName(str(runtime.get("phase", ""))) != required_phase:
            return false
    return true

func is_ability_unlocked(ability_id: StringName) -> bool:
    return _abilities.has(ability_id)

func world_context(stage_id: StringName = &"") -> Dictionary:
    var resolved := stage_id if stage_id != &"" else _active_stage_id
    if resolved == &"" or not _catalog.has_stage(resolved):
        return {"active_stage_id": _active_stage_id, "unlocked_abilities": _abilities.keys()}
    var persistent: Dictionary = _persistent.get(resolved, {"secrets": {}, "shortcuts": {}})
    var runtime: Dictionary = _runtime.get(resolved, _fresh_runtime(resolved))
    return {
        "active_stage_id": _active_stage_id,
        "stage_id": resolved,
        "definition": _catalog.stage(resolved),
        "phase": runtime.get("phase", &"neutral"),
        "visibility_scale": float(runtime.get("visibility_scale", 1.0)),
        "discovered_secrets": (persistent.get("secrets", {}) as Dictionary).keys(),
        "discovered_shortcuts": (persistent.get("shortcuts", {}) as Dictionary).keys(),
        "unlocked_abilities": _abilities.keys()
    }

func serialize_world_state() -> Dictionary:
    var stages: Dictionary = {}
    for stage_id in _persistent.keys():
        var state: Dictionary = _persistent[stage_id]
        stages[str(stage_id)] = {
            "secrets": _string_keys(state.get("secrets", {})),
            "shortcuts": _string_keys(state.get("shortcuts", {}))
        }
    return {"schema_version": 1, "stages": stages}

func restore_world_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    var stored: Dictionary = state.get("stages", {})
    for stage_id in _catalog.stage_ids():
        var raw: Dictionary = stored.get(str(stage_id), {})
        var secrets: Dictionary = {}
        for value in raw.get("secrets", []):
            var secret_id := StringName(str(value))
            if _catalog.contains_discovery(stage_id, &"secret", secret_id):
                secrets[secret_id] = true
        var shortcuts: Dictionary = {}
        for value in raw.get("shortcuts", []):
            var shortcut_id := StringName(str(value))
            if _catalog.contains_discovery(stage_id, &"shortcut", shortcut_id):
                shortcuts[shortcut_id] = true
        _persistent[stage_id] = {"secrets": secrets, "shortcuts": shortcuts}
    world_state_changed.emit(world_context())
    return true

func _string_keys(value) -> Array[String]:
    var result: Array[String] = []
    for key in (value as Dictionary).keys():
        result.append(str(key))
    result.sort()
    return result
