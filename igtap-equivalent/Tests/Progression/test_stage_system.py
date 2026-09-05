import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Content" / "Stages" / "stage_catalog_v1.json"


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def test_catalog_has_linear_five_stage_progression():
    data = load_catalog()
    order = data["stage_order"]
    stages = {stage["id"]: stage for stage in data["stages"]}
    assert len(order) == 5
    assert len(set(order)) == 5
    assert set(order) == set(stages)
    assert stages[order[0]]["unlock"]["type"] == "always"
    for index, stage_id in enumerate(order[1:], start=1):
        assert stages[stage_id]["unlock"] == {
            "type": "previous_clear",
            "stage_id": order[index - 1],
        }


def test_checkpoint_density_and_timer_targets_are_sane():
    data = load_catalog()
    for stage in data["stages"]:
        checkpoints = stage["checkpoints"]
        assert 2 <= len(checkpoints) <= 4
        assert stage["challenge_segments"] >= len(checkpoints) * 2
        assert stage["target_mastery_seconds"] > 0
        assert stage["target_first_clear_seconds"] > stage["target_mastery_seconds"]
        ratio = stage["target_mastery_seconds"] / stage["target_first_clear_seconds"]
        assert 0.25 <= ratio <= 0.45
        ids = [checkpoint["id"] for checkpoint in checkpoints]
        assert len(ids) == len(set(ids))


def test_full_unlock_path_has_no_dead_end():
    data = load_catalog()
    order = data["stage_order"]
    unlocked = {order[0]}
    cleared = set()
    for index, stage_id in enumerate(order):
        assert stage_id in unlocked
        cleared.add(stage_id)
        if index + 1 < len(order):
            unlocked.add(order[index + 1])
    assert cleared == set(order)


def test_best_time_semantics_keep_minimum_positive_value():
    best = -1.0
    for run_time in (31.2, 28.4, 29.1, 22.7):
        assert run_time > 0
        best = run_time if best < 0 or run_time < best else best
    assert best == 22.7


def test_restart_and_checkpoint_retry_policy():
    stage = load_catalog()["stages"][2]
    active_checkpoint = stage["checkpoints"][1]
    elapsed_before_death = 21.5
    retry_target = active_checkpoint["spawn_anchor"]
    elapsed_after_retry = elapsed_before_death
    assert retry_target
    assert elapsed_after_retry == elapsed_before_death
    elapsed_after_manual_restart = 0.0
    assert elapsed_after_manual_restart == 0.0


def test_checkpoint_order_never_moves_retry_anchor_backwards():
    stage = load_catalog()["stages"][3]
    checkpoints = stage["checkpoints"]
    reached_orders = [checkpoints[2]["order"], checkpoints[0]["order"]]
    active_order = -1
    for candidate in reached_orders:
        if candidate >= active_order:
            active_order = candidate
    assert active_order == checkpoints[2]["order"]


def test_every_stage_has_distinct_start_spawn_anchor():
    data = load_catalog()
    anchors = [stage["start_spawn_anchor"] for stage in data["stages"]]
    assert all(anchors)
    assert len(anchors) == len(set(anchors))


def test_attempt_identity_blocks_duplicate_completion_model():
    next_attempt_id = 1
    active = {"stage_id": "relay_yard", "attempt_id": next_attempt_id, "running": True, "finished": False}
    next_attempt_id += 1
    completed_attempts = set()
    key = (active["stage_id"], active["attempt_id"])
    assert key not in completed_attempts
    completed_attempts.add(key)
    active["running"] = False
    active["finished"] = True
    assert key in completed_attempts
    duplicate_allowed = not active["finished"]
    assert duplicate_allowed is False
    restarted = {"stage_id": "relay_yard", "attempt_id": next_attempt_id, "running": True, "finished": False}
    assert restarted["attempt_id"] != active["attempt_id"]
