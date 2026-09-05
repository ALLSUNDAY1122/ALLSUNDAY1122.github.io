import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "Content" / "World" / "world_topology_v1.json"


def shortest(stage, abilities, allow_shortcuts):
    nodes = {node["id"]: node for node in stage["nodes"]}
    queue = deque([("start", stage["default_phase"], 0)])
    seen = {("start", stage["default_phase"])}
    while queue:
        node_id, phase, distance = queue.popleft()
        if node_id == "goal":
            return distance
        phase = nodes[node_id].get("sets_phase", phase)
        for edge in stage["edges"]:
            if edge["from"] != node_id or edge["kind"] == "secret":
                continue
            if edge["kind"] == "shortcut" and not allow_shortcuts:
                continue
            if edge.get("requires_ability") and edge["requires_ability"] not in abilities:
                continue
            if edge.get("requires_phase") and edge["requires_phase"] != phase:
                continue
            state = (edge["to"], phase)
            if state not in seen:
                seen.add(state)
                queue.append((state[0], state[1], distance + 1))
    return None


def main():
    world = json.loads(WORLD.read_text(encoding="utf-8"))
    all_abilities = set(world["known_abilities"])
    print("stage,baseline_edges,all_ability_edges,shortcut_saved_edges")
    for stage in world["stages"]:
        baseline = shortest(stage, set(stage["guaranteed_abilities"]), False)
        optimized = shortest(stage, all_abilities, True)
        if baseline is None or optimized is None or optimized >= baseline:
            raise SystemExit(f"route audit failed: {stage['id']}")
        print(f"{stage['id']},{baseline},{optimized},{baseline - optimized}")


if __name__ == "__main__":
    main()
