class_name StageManager
extends Node

signal stage_started(stage_id: StringName, attempt_id: int)
signal stage_completed(stage_id: StringName, elapsed_seconds: float, is_new_best: bool, checkpoint_count: int)
signal stage_availability_changed(stage_id: StringName, available: bool)
signal checkpoint_changed(stage_id: StringName, checkpoint_id: StringName)
signal retry_requested(stage_id: StringName, retry_target: Dictionary, reason)
signal stage_context_changed(stage_context: Dictionary)

const StageCatalogType = preload("res://Game/Stages/StageCatalog.gd")
const StageRunStateType = preload("res://Game/Stages/StageRunState.gd")

var _catalog := StageCatalogType.new()
var _selected_stage_id: StringName = &""
var _run := StageRunStateType.new()
var _progress: Dictionary = {}
var _loaded := false
var _next_attempt_id := 1

func _ready() -> void:
    var error := _catalog.load_from_path()
    if error != OK:
        push_error("Stage catalog failed to load: %s" % error)
        return
    _initialize_progress()
    _selected_stage_id = _catalog.stage_ids()[0]
    _loaded = true
    stage_context_changed.emit(current_stage_context())

func _physics_process(delta: float) -> void:
    if _loaded:
        _run.advance(delta)

func _initialize_progress() -> void:
    _progress.clear()
    var ids := _catalog.stage_ids()
    for index in range(ids.size()):
        var stage_id := ids[index]
        _progress[stage_id] = {
            "unlocked": index == 0,
            "cleared": false,
            "best_time_seconds": -1.0,
            "clear_count": 0,
            "death_count": 0
        }

func select_stage(stage_id: StringName) -> bool:
    if _run.running and _run.stage_id != stage_id:
        return false
    if not is_stage_available(stage_id):
        return false
    _selected_stage_id = stage_id
    stage_context_changed.emit(current_stage_context())
    return true

func begin_stage(stage_id: StringName = &"") -> bool:
    var resolved_id := stage_id if stage_id != &"" else _selected_stage_id
    if not is_stage_available(resolved_id):
        return false
    _selected_stage_id = resolved_id
    var definition := _catalog.stage(resolved_id)
    var attempt_id := _next_attempt_id
    _next_attempt_id += 1
    _run.begin(definition, attempt_id, bool(definition.get("checkpoint_mode_default", true)))
    stage_started.emit(resolved_id, attempt_id)
    stage_context_changed.emit(current_stage_context())
    return true

func restart_stage() -> bool:
    var stage_id := _run.stage_id if _run.stage_id != &"" else _selected_stage_id
    return begin_stage(stage_id)

func register_checkpoint(stage_id: StringName, checkpoint_id: StringName) -> bool:
    if _run.stage_id != stage_id or not _run.running:
        return false
    if not _run.reach_checkpoint(checkpoint_id):
        return false
    checkpoint_changed.emit(stage_id, checkpoint_id)
    stage_context_changed.emit(current_stage_context())
    return true

func register_death(stage_id: StringName, reason) -> Dictionary:
    if _run.stage_id != stage_id or not _run.running:
        return {}
    var target := _run.register_death()
    var progress: Dictionary = _progress.get(stage_id, {})
    progress["death_count"] = int(progress.get("death_count", 0)) + 1
    _progress[stage_id] = progress
    retry_requested.emit(stage_id, target, reason)
    stage_context_changed.emit(current_stage_context())
    return target

func complete_goal() -> Dictionary:
    if not _run.running:
        return {}
    return _commit_completion(_run.finish())

func register_lap(stage_id: StringName, elapsed_seconds: float, replay_payload: Dictionary = {}) -> Dictionary:
    if not is_stage_available(stage_id) or elapsed_seconds <= 0.0:
        return {}
    if _run.running and _run.stage_id != stage_id:
        return {}
    if _run.stage_id == stage_id and _run.finished:
        return {}
    if not _run.running:
        if not begin_stage(stage_id):
            return {}
    var result := _run.finish(elapsed_seconds)
    result["replay_payload"] = replay_payload
    return _commit_completion(result)

func _commit_completion(result: Dictionary) -> Dictionary:
    if result.is_empty():
        return {}
    var stage_id := StringName(str(result.get("stage_id", "")))
    var elapsed := float(result.get("elapsed_seconds", 0.0))
    if elapsed <= 0.0:
        return {}
    var progress: Dictionary = _progress.get(stage_id, {})
    var previous_best := float(progress.get("best_time_seconds", -1.0))
    var is_new_best := previous_best < 0.0 or elapsed < previous_best
    progress["cleared"] = true
    progress["clear_count"] = int(progress.get("clear_count", 0)) + 1
    if is_new_best:
        progress["best_time_seconds"] = elapsed
    _progress[stage_id] = progress
    var next_id := _catalog.next_stage_id(stage_id)
    if next_id != &"":
        var next_progress: Dictionary = _progress.get(next_id, {})
        if not bool(next_progress.get("unlocked", false)):
            next_progress["unlocked"] = true
            _progress[next_id] = next_progress
            stage_availability_changed.emit(next_id, true)
    result["is_new_best"] = is_new_best
    result["best_time_seconds"] = float(progress.get("best_time_seconds", elapsed))
    stage_completed.emit(stage_id, elapsed, is_new_best, int(result.get("checkpoint_count", 0)))
    stage_context_changed.emit(current_stage_context())
    return result

func unlock_stage(stage_id: StringName) -> bool:
    if not _catalog.has_stage(stage_id):
        return false
    var progress: Dictionary = _progress.get(stage_id, {})
    if bool(progress.get("unlocked", false)):
        return true
    progress["unlocked"] = true
    _progress[stage_id] = progress
    stage_availability_changed.emit(stage_id, true)
    stage_context_changed.emit(current_stage_context())
    return true

func is_stage_available(stage_id: StringName) -> bool:
    if not _catalog.has_stage(stage_id):
        return false
    return bool((_progress.get(stage_id, {}) as Dictionary).get("unlocked", false))

func stage_select_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    for stage_id in _catalog.stage_ids():
        var definition := _catalog.stage(stage_id)
        var progress: Dictionary = _progress.get(stage_id, {})
        entries.append({
            "stage_id": stage_id,
            "display_name": str(definition.get("display_name", stage_id)),
            "available": bool(progress.get("unlocked", false)),
            "cleared": bool(progress.get("cleared", false)),
            "best_time_seconds": float(progress.get("best_time_seconds", -1.0)),
            "target_mastery_seconds": float(definition.get("target_mastery_seconds", -1.0)),
            "selected": stage_id == _selected_stage_id
        })
    return entries

func current_stage_context() -> Dictionary:
    if not _loaded and _selected_stage_id == &"":
        return {}
    var definition := _catalog.stage(_selected_stage_id)
    return {
        "stage_id": _selected_stage_id,
        "definition": definition,
        "progress": (_progress.get(_selected_stage_id, {}) as Dictionary).duplicate(true),
        "run": _run.snapshot(),
        "stage_select": stage_select_entries()
    }

func best_time(stage_id: StringName) -> float:
    return float((_progress.get(stage_id, {}) as Dictionary).get("best_time_seconds", -1.0))

func serialize_stage_state() -> Dictionary:
    var serializable_progress: Dictionary = {}
    for key in _progress.keys():
        serializable_progress[str(key)] = (_progress[key] as Dictionary).duplicate(true)
    return {
        "schema_version": 1,
        "selected_stage_id": str(_selected_stage_id),
        "progress": serializable_progress
    }

func restore_stage_state(state: Dictionary) -> bool:
    if int(state.get("schema_version", -1)) != 1:
        return false
    var stored_progress: Dictionary = state.get("progress", {})
    for stage_id in _catalog.stage_ids():
        var key := str(stage_id)
        if stored_progress.has(key):
            var restored: Dictionary = stored_progress[key]
            var current: Dictionary = _progress[stage_id]
            current["unlocked"] = bool(restored.get("unlocked", current["unlocked"]))
            current["cleared"] = bool(restored.get("cleared", current["cleared"]))
            current["best_time_seconds"] = float(restored.get("best_time_seconds", current["best_time_seconds"]))
            current["clear_count"] = maxi(int(restored.get("clear_count", 0)), 0)
            current["death_count"] = maxi(int(restored.get("death_count", 0)), 0)
            _progress[stage_id] = current
    var selected := StringName(str(state.get("selected_stage_id", _selected_stage_id)))
    if is_stage_available(selected):
        _selected_stage_id = selected
    stage_context_changed.emit(current_stage_context())
    return true
