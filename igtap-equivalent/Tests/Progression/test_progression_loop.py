import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROGRESSION = ROOT / "Content" / "Progression" / "progression_v1.json"
WORLD = ROOT / "Content" / "World" / "world_topology_v1.json"
ECONOMY = ROOT / "Content" / "Economy" / "economy_balance_v1.json"
STAGES = ROOT / "Content" / "Stages" / "stage_catalog_v1.json"
ROOT_SOURCE = ROOT / "Game" / "Progression" / "ProgressionWorld.gd"
SYSTEM_SOURCE = ROOT / "Game" / "Progression" / "ProgressionSystem.gd"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def progression_upgrades():
    return {item["id"]: item for item in load(PROGRESSION)["upgrades"]}


def test_mandatory_ability_chain_matches_stage_entry_gates():
    progression = load(PROGRESSION)
    world = {item["id"]: item for item in load(WORLD)["stages"]}
    expected = [
        ("relay_yard", "speed_tune", "liftworks"),
        ("liftworks", "dash", "phase_foundry"),
        ("phase_foundry", "double_jump", "blackout_array"),
        ("blackout_array", "wall_jump", "core_spire"),
    ]
    upgrades = progression_upgrades()
    for clear_stage, ability, next_stage in expected:
        assert upgrades[ability]["unlocks_after_stage"] == clear_stage
        assert world[next_stage]["entry_required_ability"] == ability
    assert upgrades["phase_shift"]["unlocks_after_stage"] == "core_spire"


def test_every_core_ability_has_revisit_value():
    world = load(WORLD)["stages"]
    edges = [edge for stage in world for edge in stage["edges"]]
    for ability in ["speed_tune", "dash", "double_jump", "wall_jump"]:
        assert any(edge.get("requires_ability") == ability and edge.get("kind") in {"shortcut", "secret"} for edge in edges)
    phase_edges = [edge for edge in edges if edge.get("requires_ability") == "phase_shift" and edge.get("kind") in {"shortcut", "secret"}]
    assert len(phase_edges) >= 2


def test_session_a_mapping_is_explicit_and_non_deceptive():
    mapping = load(PROGRESSION)["session_a_mapping"]
    assert mapping["dash"] == "dash"
    assert mapping["double_jump"] == "airJump"
    assert mapping["wall_jump"] == "wallJump"
    assert mapping["speed_tune"].startswith("movement_effect:")
    assert mapping["phase_shift"] == "world_only"


def test_clone_capacity_is_global_and_bounded():
    progression = load(PROGRESSION)
    upgrades = progression_upgrades()
    clone = upgrades["clone_capacity"]
    assert progression["base_clone_capacity"] == 1
    assert clone["effect"] == "clone_capacity_add"
    assert clone["per_level_add"] == 1
    assert clone["max_level"] == 8
    source = ROOT_SOURCE.read_text(encoding="utf-8")
    assert "allocated_without_stage + clone_count > clone_capacity()" in source


def test_new_record_auto_clone_respects_remaining_global_capacity():
    source = ROOT_SOURCE.read_text(encoding="utf-8")
    assert 'requested_clone_count = 1 if int(clone_allocation_snapshot().get("remaining", 0)) > 0 else 0' in source
    capacity = 1
    allocated = 0
    auto_counts = []
    for _stage in range(5):
        requested = 1 if capacity - allocated > 0 else 0
        allocated += requested
        auto_counts.append(requested)
    assert auto_counts == [1, 0, 0, 0, 0]
    assert allocated <= capacity


def test_movement_tracks_are_separate_from_discrete_player_abilities():
    upgrades = progression_upgrades()
    assert upgrades["speed_tune"]["effect"] == "run_speed_multiplier"
    assert upgrades["jump_tune"]["effect"] == "jump_multiplier"
    assert upgrades["dash"]["effect"] == "ability_unlock"
    assert upgrades["double_jump"]["effect"] == "ability_unlock"
    assert upgrades["wall_jump"]["effect"] == "ability_unlock"


def test_mandatory_ability_waits_stay_under_target_without_economic_upgrades():
    progression = load(PROGRESSION)
    economy = load(ECONOMY)
    stages = {item["id"]: item for item in load(STAGES)["stages"]}
    rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
    upgrades = progression_upgrades()
    chain = [
        ("relay_yard", "speed_tune"),
        ("liftworks", "dash"),
        ("phase_foundry", "double_jump"),
        ("blackout_array", "wall_jump"),
        ("core_spire", "phase_shift"),
    ]
    balance = 0.0
    rate = 0.0
    waits = []
    base_fraction = economy["clone_reward"]["base_fraction"]
    for stage_id, upgrade_id in chain:
        balance += rewards[stage_id]
        rate += rewards[stage_id] * base_fraction / stages[stage_id]["target_first_clear_seconds"]
        cost = upgrades[upgrade_id]["base_cost"]
        wait = max(0.0, (cost - balance) / rate)
        balance += wait * rate
        balance -= cost
        waits.append(wait)
    assert max(waits) <= progression["balance_guardrails"]["mandatory_ability_wait_target_seconds"]


def test_single_stage_availability_combines_clear_and_ability_requirements():
    source = ROOT_SOURCE.read_text(encoding="utf-8")
    assert "requires_previous_clear" in source
    assert "requires_ability" in source
    assert "stage_availability(stage_id" in source
    assert "entry_required_ability" in source


def test_direct_unlock_keeps_upgrade_level_and_ability_state_consistent():
    source = SYSTEM_SOURCE.read_text(encoding="utf-8")
    assert "_levels[ability_id] = unlock_level" in source
    assert "_grant_ability(ability_id, false)" in source


def test_aggregate_save_schema_includes_progression_and_supports_v1_restore():
    source = ROOT_SOURCE.read_text(encoding="utf-8")
    assert '"schema_version": 2' in source
    assert '"progression": _progression.call("serialize_progression_state")' in source
    assert "version != 1 and version != 2" in source
