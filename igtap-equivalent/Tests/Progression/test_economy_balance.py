import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ECONOMY = ROOT / "Content" / "Economy" / "economy_balance_v1.json"
STAGES = ROOT / "Content" / "Stages" / "stage_catalog_v1.json"
ECONOMY_SYSTEM = ROOT / "Game" / "Economy" / "EconomySystem.gd"
PROGRESSION_ROOT = ROOT / "Game" / "Progression" / "ProgressionWorld.gd"


def load():
    economy = json.loads(ECONOMY.read_text(encoding="utf-8"))
    stages = json.loads(STAGES.read_text(encoding="utf-8"))
    return economy, stages


def clone_rps(base_reward, target, cycle, rules):
    speed = (target / cycle) ** rules["speed_power"]
    speed = max(rules["min_speed_factor"], min(rules["max_speed_factor"], speed))
    reward = base_reward * rules["base_fraction"] * speed
    return reward / cycle


def test_economy_stage_ids_match_stage_catalog():
    economy, stages = load()
    reward_ids = {item["stage_id"] for item in economy["stage_rewards"]}
    assert reward_ids == set(stages["stage_order"])


def test_mastery_clone_rate_is_monotonic_and_old_stage_stays_relevant():
    economy, stages = load()
    stage_by_id = {stage["id"]: stage for stage in stages["stages"]}
    rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
    rules = economy["clone_reward"]
    rates = []
    for stage_id in stages["stage_order"]:
        stage = stage_by_id[stage_id]
        first = clone_rps(rewards[stage_id], stage["target_first_clear_seconds"], stage["target_first_clear_seconds"], rules)
        mastery = clone_rps(rewards[stage_id], stage["target_first_clear_seconds"], stage["target_mastery_seconds"], rules)
        assert mastery > first * economy["balance_guardrails"]["mastery_clone_rps_gain_minimum"]
        rates.append(mastery)
    minimum = economy["balance_guardrails"]["previous_stage_pair_share_minimum"]
    for left, right in zip(rates, rates[1:]):
        assert left / (left + right) >= minimum


def test_first_meaningful_upgrade_waits_stay_under_target():
    economy, stages = load()
    stage_by_id = {stage["id"]: stage for stage in stages["stages"]}
    rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
    rules = economy["clone_reward"]
    order = stages["stage_order"]
    target_wait = economy["balance_guardrails"]["meaningful_purchase_target_seconds"]
    balance = 0.0
    income_multiplier = 1.0
    clone_multiplier = 1.0
    first_rates = []
    upgrade_by_unlock = {upgrade["unlocks_after_stage"]: upgrade for upgrade in economy["upgrades"]}
    for stage_id in order:
        stage = stage_by_id[stage_id]
        balance += rewards[stage_id]
        first_rates.append(clone_rps(rewards[stage_id], stage["target_first_clear_seconds"], stage["target_first_clear_seconds"], rules))
        if stage_id not in upgrade_by_unlock:
            continue
        upgrade = upgrade_by_unlock[stage_id]
        rps = sum(first_rates) * income_multiplier * clone_multiplier
        wait = max(0.0, (upgrade["base_cost"] - balance) / rps)
        assert wait <= target_wait
        balance += rps * wait
        balance -= upgrade["base_cost"]
        if upgrade["effect"] == "income_multiplier":
            income_multiplier *= upgrade["per_level_multiplier"]
        elif upgrade["effect"] == "clone_reward_multiplier":
            clone_multiplier *= upgrade["per_level_multiplier"]


def test_upgrade_cost_and_effect_curves_are_strictly_increasing():
    economy, _ = load()
    for upgrade in economy["upgrades"]:
        assert upgrade["cost_growth"] > 1.0
        assert upgrade["per_level_multiplier"] > 1.0
        previous_cost = 0.0
        previous_effect = 0.0
        for level in range(min(upgrade["max_level"], 12)):
            cost = upgrade["base_cost"] * (upgrade["cost_growth"] ** level)
            effect = upgrade["per_level_multiplier"] ** level
            assert cost > previous_cost or level == 0
            assert effect > previous_effect or level == 0
            previous_cost = cost
            previous_effect = effect


def test_production_root_matches_session_c_adapter_surface():
    text = PROGRESSION_ROOT.read_text(encoding="utf-8")
    for token in [
        "signal stage_context_changed",
        "signal currency_changed",
        "signal upgrade_purchased",
        "signal ability_unlocked",
        "signal clone_income_applied",
        "func register_lap",
        "func get_unlocked_abilities",
        "func current_stage_context",
    ]:
        assert token in text


def test_economy_does_not_mutate_session_a_owned_paths():
    text = ECONOMY_SYSTEM.read_text(encoding="utf-8")
    for token in ["Game/Player/", "Game/Physics/", "Game/Abilities/", "Game/Replay/", "Game/Ghost/", ".velocity =", ".kill("]:
        assert token not in text


def test_upgrade_tracks_have_progression_gates():
    economy, stages = load()
    known_stages = set(stages["stage_order"])
    for upgrade in economy["upgrades"]:
        assert upgrade["unlocks_after_stage"] in known_stages
    root_text = PROGRESSION_ROOT.read_text(encoding="utf-8")
    assert "func upgrade_availability" in root_text
    assert "requires_stage_clear" in root_text
