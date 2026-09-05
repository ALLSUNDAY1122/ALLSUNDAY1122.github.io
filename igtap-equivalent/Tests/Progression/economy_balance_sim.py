import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
economy = json.loads((ROOT / "Content/Economy/economy_balance_v1.json").read_text(encoding="utf-8"))
stages = json.loads((ROOT / "Content/Stages/stage_catalog_v1.json").read_text(encoding="utf-8"))
stage_by_id = {stage["id"]: stage for stage in stages["stages"]}
rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
rules = economy["clone_reward"]


def rate(stage_id, cycle):
    stage = stage_by_id[stage_id]
    speed = (stage["target_first_clear_seconds"] / cycle) ** rules["speed_power"]
    speed = max(rules["min_speed_factor"], min(rules["max_speed_factor"], speed))
    return rewards[stage_id] * rules["base_fraction"] * speed / cycle


print("stage,first_rps,mastery_rps")
mastery_rates = []
first_rates = []
for stage_id in stages["stage_order"]:
    stage = stage_by_id[stage_id]
    first = rate(stage_id, stage["target_first_clear_seconds"])
    mastery = rate(stage_id, stage["target_mastery_seconds"])
    first_rates.append(first)
    mastery_rates.append(mastery)
    print(f"{stage_id},{first:.4f},{mastery:.4f}")

print("previous_stage_pair_shares")
for index in range(len(mastery_rates) - 1):
    share = mastery_rates[index] / (mastery_rates[index] + mastery_rates[index + 1])
    print(f"{stages['stage_order'][index]}->{stages['stage_order'][index+1]}:{share:.4f}")

print("sequential_first_upgrade_waits")
balance = 0.0
income_multiplier = 1.0
clone_multiplier = 1.0
upgrade_by_unlock = {upgrade["unlocks_after_stage"]: upgrade for upgrade in economy["upgrades"]}
for index, stage_id in enumerate(stages["stage_order"]):
    balance += rewards[stage_id]
    if stage_id not in upgrade_by_unlock:
        continue
    upgrade = upgrade_by_unlock[stage_id]
    rps = sum(first_rates[: index + 1]) * income_multiplier * clone_multiplier
    wait = max(0.0, (upgrade["base_cost"] - balance) / rps)
    balance += rps * wait
    balance -= upgrade["base_cost"]
    print(f"{upgrade['id']}:{wait:.2f}s")
    if upgrade["effect"] == "income_multiplier":
        income_multiplier *= upgrade["per_level_multiplier"]
    elif upgrade["effect"] == "clone_reward_multiplier":
        clone_multiplier *= upgrade["per_level_multiplier"]
