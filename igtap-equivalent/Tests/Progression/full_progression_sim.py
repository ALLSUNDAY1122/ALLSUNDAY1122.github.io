import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
progression = json.loads((ROOT / "Content" / "Progression" / "progression_v1.json").read_text(encoding="utf-8"))
economy = json.loads((ROOT / "Content" / "Economy" / "economy_balance_v1.json").read_text(encoding="utf-8"))
stages = {item["id"]: item for item in json.loads((ROOT / "Content" / "Stages" / "stage_catalog_v1.json").read_text(encoding="utf-8"))["stages"]}
upgrades = {item["id"]: item for item in progression["upgrades"]}
rewards = {item["stage_id"]: item["base_reward"] for item in economy["stage_rewards"]}
chain = [("relay_yard", "speed_tune"), ("liftworks", "dash"), ("phase_foundry", "double_jump"), ("blackout_array", "wall_jump"), ("core_spire", "phase_shift")]


def rps(stage_id):
    return rewards[stage_id] * economy["clone_reward"]["base_fraction"] / stages[stage_id]["target_first_clear_seconds"]

balance = 0.0
mandatory_rows = []
for stage_id, ability_id in chain:
    balance += rewards[stage_id]
    rate = rps(stage_id)
    cost = upgrades[ability_id]["base_cost"]
    wait = max(0.0, (cost - balance) / rate)
    balance += wait * rate
    balance -= cost
    mandatory_rows.append((stage_id, ability_id, cost, rate, wait))

active_balance = 0.0
active_rows = []
for stage_id, ability_id in chain:
    runs = 1
    active_balance += rewards[stage_id]
    while active_balance < upgrades[ability_id]["base_cost"]:
        active_balance += rewards[stage_id]
        runs += 1
    active_balance -= upgrades[ability_id]["base_cost"]
    active_rows.append((stage_id, ability_id, runs))

stage_rps = {stage_id: rps(stage_id) for stage_id in stages}
allocation_order = sorted(stage_rps, key=stage_rps.get, reverse=True)
counts = {stage_id: 0 for stage_id in stages}
counts[allocation_order[0]] = progression["base_clone_capacity"]
rate = stage_rps[allocation_order[0]]
capacity_rows = []
capacity = progression["base_clone_capacity"]
capacity_definition = upgrades["clone_capacity"]
for level in range(capacity_definition["max_level"]):
    cost = capacity_definition["base_cost"] * capacity_definition["cost_growth"] ** level
    wait = cost / rate
    capacity += capacity_definition["per_level_add"]
    for stage_id in allocation_order:
        if counts[stage_id] < progression["per_stage_clone_cap"]:
            counts[stage_id] += 1
            rate += stage_rps[stage_id]
            break
    capacity_rows.append((level + 1, cost, wait, capacity, rate, dict(counts)))

print("Required progression: one global clone moved to newest stage")
for stage_id, ability_id, cost, rate, wait in mandatory_rows:
    print(f"{stage_id:16s} -> {ability_id:12s} cost={cost:7.1f} rps={rate:6.3f} wait={wait:6.2f}s")
print(f"required_max_wait={max(row[4] for row in mandatory_rows):.2f}s")

print("\nActive-only fallback")
for stage_id, ability_id, runs in active_rows:
    print(f"{stage_id:16s} -> {ability_id:12s} clears={runs}")
print(f"active_only_max_clears={max(row[2] for row in active_rows)}")

print("\nEcho Capacity fill")
for level, cost, wait, capacity, current_rate, current_counts in capacity_rows:
    print(f"L{level:02d} cost={cost:8.2f} wait={wait:6.2f}s capacity={capacity:2d} rps={current_rate:7.3f} allocation={current_counts}")
print(f"capacity_max_wait={max(row[2] for row in capacity_rows):.2f}s")
print(f"final_allocation={counts}")
print(f"final_target_route_rps={rate:.3f}")
