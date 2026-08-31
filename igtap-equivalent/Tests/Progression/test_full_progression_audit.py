import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROGRESSION = json.loads((ROOT / "Content" / "Progression" / "progression_v1.json").read_text(encoding="utf-8"))
ECONOMY = json.loads((ROOT / "Content" / "Economy" / "economy_balance_v1.json").read_text(encoding="utf-8"))
STAGES = {item["id"]: item for item in json.loads((ROOT / "Content" / "Stages" / "stage_catalog_v1.json").read_text(encoding="utf-8"))["stages"]}
WORLD = json.loads((ROOT / "Content" / "World" / "world_topology_v1.json").read_text(encoding="utf-8"))
UI = json.loads((ROOT / "Content" / "UI" / "ui_catalog_v1.json").read_text(encoding="utf-8"))
ROOT_SOURCE = (ROOT / "Game" / "Progression" / "ProgressionWorld.gd").read_text(encoding="utf-8")
PANEL_SOURCE = (ROOT / "Game" / "UI" / "ProgressionPanel.gd").read_text(encoding="utf-8")
STAGE_MODEL_SOURCE = (ROOT / "Game" / "UI" / "StageSelectModel.gd").read_text(encoding="utf-8")

UPGRADES = {item["id"]: item for item in PROGRESSION["upgrades"]}
REWARDS = {item["stage_id"]: item["base_reward"] for item in ECONOMY["stage_rewards"]}
CHAIN = [("relay_yard", "speed_tune"), ("liftworks", "dash"), ("phase_foundry", "double_jump"), ("blackout_array", "wall_jump"), ("core_spire", "phase_shift")]


def target_clone_rps(stage_id):
    return REWARDS[stage_id] * ECONOMY["clone_reward"]["base_fraction"] / STAGES[stage_id]["target_first_clear_seconds"]


def test_required_progression_waits_under_target_with_one_global_clone():
    balance = 0.0
    waits = []
    for stage_id, ability_id in CHAIN:
        balance += REWARDS[stage_id]
        rate = target_clone_rps(stage_id)
        cost = UPGRADES[ability_id]["base_cost"]
        wait = max(0.0, (cost - balance) / rate)
        balance += wait * rate
        balance -= cost
        waits.append(wait)
    assert max(waits) <= PROGRESSION["balance_guardrails"]["mandatory_ability_wait_target_seconds"]


def test_active_only_progression_never_requires_more_than_two_clears_per_gate():
    balance = 0.0
    for stage_id, ability_id in CHAIN:
        runs = 1
        balance += REWARDS[stage_id]
        while balance < UPGRADES[ability_id]["base_cost"]:
            balance += REWARDS[stage_id]
            runs += 1
        assert runs <= 2
        balance -= UPGRADES[ability_id]["base_cost"]


def test_clone_distribution_preserves_old_stage_reason_to_exist():
    assert PROGRESSION["per_stage_clone_cap"] == 3
    capacity_upgrade = UPGRADES["clone_capacity"]
    maximum_capacity = PROGRESSION["base_clone_capacity"] + capacity_upgrade["max_level"] * capacity_upgrade["per_level_add"]
    assert maximum_capacity == 15
    assert maximum_capacity == PROGRESSION["per_stage_clone_cap"] * len(STAGES)
    assert "clone_count > stage_clone_cap()" in ROOT_SOURCE


def test_clone_capacity_curve_has_no_overlong_single_wait_at_endgame():
    stage_rps = {stage_id: target_clone_rps(stage_id) for stage_id in STAGES}
    allocation_order = sorted(stage_rps, key=stage_rps.get, reverse=True)
    counts = {stage_id: 0 for stage_id in STAGES}
    counts[allocation_order[0]] = 1
    rate = stage_rps[allocation_order[0]]
    waits = []
    definition = UPGRADES["clone_capacity"]
    for level in range(definition["max_level"]):
        cost = definition["base_cost"] * definition["cost_growth"] ** level
        waits.append(cost / rate)
        for stage_id in allocation_order:
            if counts[stage_id] < PROGRESSION["per_stage_clone_cap"]:
                counts[stage_id] += 1
                rate += stage_rps[stage_id]
                break
    assert max(waits) <= PROGRESSION["balance_guardrails"]["optional_capacity_wait_target_seconds"]
    assert all(count == 3 for count in counts.values())


def test_optional_tracks_cannot_distract_before_first_key_gate():
    assert UPGRADES["jump_tune"]["requires_upgrades"] == ["speed_tune"]
    assert UPGRADES["clone_capacity"]["requires_upgrades"] == ["speed_tune"]


def test_no_secret_is_mandatory_for_stage_main_chain():
    for stage in WORLD["stages"]:
        main_edges = [edge for edge in stage["edges"] if edge.get("kind") == "main"]
        assert main_edges
        assert all("secret_id" not in edge and edge.get("kind") != "secret" for edge in main_edges)


def test_upgrade_effects_are_meaningful_not_noop():
    assert UPGRADES["speed_tune"]["per_level_multiplier"] >= 1.05
    assert UPGRADES["jump_tune"]["per_level_multiplier"] >= 1.05
    assert UPGRADES["clone_capacity"]["per_level_add"] >= 1
    for definition in ECONOMY["upgrades"]:
        assert definition["per_level_multiplier"] >= 1.10


def test_ui_has_explicit_lock_copy_and_mobile_touch_guardrail():
    assert UI["accessibility"]["minimum_touch_height"] >= 48
    assert UI["accessibility"]["never_color_only"] is True
    assert "LOCKED:" in PANEL_SOURCE
    assert "stage_availability" in ROOT_SOURCE
    assert "is_stage_available" in STAGE_MODEL_SOURCE


def test_ui_catalog_covers_every_purchasable_upgrade():
    all_ids = set(UPGRADES) | {item["id"] for item in ECONOMY["upgrades"]}
    assert all_ids == set(UI["upgrade_order"])
    assert all_ids == set(UI["upgrades"])


def test_final_ability_wait_has_margin_below_failure_threshold():
    assert UPGRADES["phase_shift"]["base_cost"] == 1300.0
    core_rate = target_clone_rps("core_spire")
    wait_after_first_clear = max(0.0, (UPGRADES["phase_shift"]["base_cost"] - REWARDS["core_spire"]) / core_rate)
    assert wait_after_first_clear < 90.0
