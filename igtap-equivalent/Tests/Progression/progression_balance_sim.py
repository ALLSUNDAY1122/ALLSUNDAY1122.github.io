import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
progression = json.loads((ROOT / "Content" / "Progression" / "progression_v1.json").read_text(encoding="utf-8"))
economy = json.loads((ROOT / "Content" / "Economy" / "economy_balance_v1.json").read_text(encoding="utf-8"))
stages = {item["id"]: item for item in json.loads((ROOT / "Content" / "Stages" / "stage_catalog_v1.json").read_text(encoding="utf-8"))["stages"]}
upgrades = {item["id"]: item for item in progression["upgrades"]}
rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
chain = [("relay_yard", "speed_tune"), ("liftworks", "dash"), ("phase_foundry", "double_jump"), ("blackout_array", "wall_jump"), ("core_spire", "phase_shift")]

balance = 0.0
rows = []
for stage_id, upgrade_id in chain:
    balance += rewards[stage_id]
    rate = rewards[stage_id] * economy["clone_reward"]["base_fraction"] / stages[stage_id]["target_first_clear_seconds"]
    cost = upgrades[upgrade_id]["base_cost"]
    wait = max(0.0, (cost - balance) / rate)
    balance += wait * rate
    balance -= cost
    rows.append((stage_id, upgrade_id, cost, rate, wait))

print("Mandatory progression waits with one global clone moved to newest stage")
for stage_id, upgrade_id, cost, current_rate, wait in rows:
    print(f"{stage_id:16s} -> {upgrade_id:12s} cost={cost:7.1f} rate={current_rate:7.3f}/s wait={wait:6.2f}s")
print(f"max_wait={max(row[4] for row in rows):.2f}s")
print(f"clone_capacity={progression['base_clone_capacity']}..{progression['base_clone_capacity'] + upgrades['clone_capacity']['max_level'] * upgrades['clone_capacity']['per_level_add']}")
print(f"per_stage_clone_cap={progression['per_stage_clone_cap']}")
