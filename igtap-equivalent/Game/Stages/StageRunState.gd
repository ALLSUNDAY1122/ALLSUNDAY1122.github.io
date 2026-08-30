class_name StageRunState
extends RefCounted

var stage_id: StringName = &""
var attempt_id := 0
var elapsed_seconds: float = 0.0
var running := false
var finished := false
var checkpoint_mode_enabled := true
var active_checkpoint_id: StringName = &""
var death_count := 0
var reached_checkpoints: Array[StringName] = []
var _definition: Dictionary = {}

func begin(stage_definition: Dictionary, new_attempt_id: int, checkpoint_enabled: bool = true) -> void:
    _definition = stage_definition.duplicate(true)
    stage_id = StringName(str(_definition.get("id", "")))
    attempt_id = new_attempt_id
    elapsed_seconds = 0.0
    running = true
    finished = false
    checkpoint_mode_enabled = checkpoint_enabled
    active_checkpoint_id = &""
    death_count = 0
    reached_checkpoints.clear()

func advance(delta: float) -> void:
    if running and not finished:
        elapsed_seconds += maxf(delta, 0.0)

func reach_checkpoint(checkpoint_id: StringName) -> bool:
    if not running or not checkpoint_mode_enabled:
        return false
    var checkpoints: Array = _definition.get("checkpoints", [])
    var candidate_order := -1
    var active_order := -1
    for checkpoint_value in checkpoints:
        var checkpoint: Dictionary = checkpoint_value
        var current_id := StringName(str(checkpoint.get("id", "")))
        if current_id == checkpoint_id:
            candidate_order = int(checkpoint.get("order", -1))
        if current_id == active_checkpoint_id:
            active_order = int(checkpoint.get("order", -1))
    if candidate_order < 0 or candidate_order < active_order:
        return false
    active_checkpoint_id = checkpoint_id
    if not reached_checkpoints.has(checkpoint_id):
        reached_checkpoints.append(checkpoint_id)
    return true

func register_death() -> Dictionary:
    death_count += 1
    return retry_target()

func retry_target() -> Dictionary:
    if checkpoint_mode_enabled and active_checkpoint_id != &"":
        for checkpoint_value in _definition.get("checkpoints", []):
            var checkpoint: Dictionary = checkpoint_value
            if StringName(str(checkpoint.get("id", ""))) == active_checkpoint_id:
                return {
                    "checkpoint_id": active_checkpoint_id,
                    "spawn_anchor": str(checkpoint.get("spawn_anchor", "")),
                    "full_restart": false
                }
    return {
        "checkpoint_id": &"",
        "spawn_anchor": str(_definition.get("start_spawn_anchor", "")),
        "full_restart": false
    }

func restart() -> void:
    elapsed_seconds = 0.0
    finished = false
    running = true
    active_checkpoint_id = &""
    death_count = 0
    reached_checkpoints.clear()

func finish(authoritative_elapsed_seconds: float = -1.0) -> Dictionary:
    if not running or finished:
        return {}
    if authoritative_elapsed_seconds >= 0.0:
        elapsed_seconds = authoritative_elapsed_seconds
    running = false
    finished = true
    return snapshot()

func snapshot() -> Dictionary:
    return {
        "stage_id": stage_id,
        "attempt_id": attempt_id,
        "elapsed_seconds": elapsed_seconds,
        "running": running,
        "finished": finished,
        "checkpoint_mode_enabled": checkpoint_mode_enabled,
        "active_checkpoint_id": active_checkpoint_id,
        "death_count": death_count,
        "checkpoint_count": reached_checkpoints.size()
    }
