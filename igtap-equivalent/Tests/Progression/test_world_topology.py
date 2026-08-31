import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "Content" / "World" / "world_topology_v1.json"
STAGES = ROOT / "Content" / "Stages" / "stage_catalog_v1.json"
GIMMICKS = ROOT / "Game" / "Gimmicks"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def shortest(stage, abilities, allow_shortcuts=False, allow_secrets=False):
    nodes = {node["id"]: node for node in stage["nodes"]}
    queue = deque([("start", stage["default_phase"], 0)])
    seen = {("start", stage["default_phase"])}
    while queue:
        node_id, phase, distance = queue.popleft()
        if node_id == "goal":
            return distance
        phase_after_node = nodes[node_id].get("sets_phase", phase)
        for edge in stage["edges"]:
            if edge["from"] != node_id:
                continue
            if edge["kind"] == "shortcut" and not allow_shortcuts:
                continue
            if edge["kind"] == "secret" and not allow_secrets:
                continue
            if edge.get("requires_ability") and edge["requires_ability"] not in abilities:
                continue
            if edge.get("requires_phase") and edge["requires_phase"] != phase_after_node:
                continue
            state = (edge["to"], phase_after_node)
            if state not in seen:
                seen.add(state)
                queue.append((state[0], state[1], distance + 1))
    return None


def test_world_stage_ids_and_checkpoint_counts_match_stage_system():
    world = load(WORLD)
    catalog = load(STAGES)
    assert [stage["id"] for stage in world["stages"]] == catalog["stage_order"]
    world_by_id = {stage["id"]: stage for stage in world["stages"]}
    for stage in catalog["stages"]:
        expected = len(stage["checkpoints"])
        actual = len([node for node in world_by_id[stage["id"]]["nodes"] if node["id"].startswith("cp")])
        assert actual == expected


def test_mandatory_route_is_reachable_without_secret_or_shortcut():
    world = load(WORLD)
    for stage in world["stages"]:
        abilities = set(stage["guaranteed_abilities"])
        entry = stage.get("entry_required_ability")
        assert entry is None or entry in abilities
        assert shortest(stage, abilities, False, False) is not None


def test_every_shortcut_is_real_route_improvement_after_later_unlocks():
    world = load(WORLD)
    all_abilities = set(world["known_abilities"])
    for stage in world["stages"]:
        baseline = shortest(stage, set(stage["guaranteed_abilities"]), False, False)
        optimized = shortest(stage, all_abilities, True, False)
        assert baseline is not None and optimized is not None
        assert optimized <= baseline - 2
        assert any(edge["kind"] == "shortcut" for edge in stage["edges"])


def test_secrets_are_optional_and_present_in_every_stage():
    world = load(WORLD)
    for stage in world["stages"]:
        assert any(edge["kind"] == "secret" for edge in stage["edges"])
        assert shortest(stage, set(stage["guaranteed_abilities"]), False, False) is not None


def test_gimmick_coverage_and_stage_variety():
    world = load(WORLD)
    used = set()
    for stage in world["stages"]:
        stage_types = set(stage["gimmick_types"])
        assert len(stage_types) >= 6
        used |= stage_types
    assert set(world["gimmick_types"]) <= used


def test_state_gates_have_reachable_switches():
    world = load(WORLD)
    for stage in world["stages"]:
        required = {edge["requires_phase"] for edge in stage["edges"] if edge.get("requires_phase")}
        settable = {node["sets_phase"] for node in stage["nodes"] if node.get("sets_phase")}
        assert required <= settable


def test_darkness_is_challenging_but_not_black_screen():
    world = load(WORLD)
    visibilities = [float(stage["default_visibility"]) for stage in world["stages"]]
    assert min(visibilities) >= 0.35
    assert max(visibilities) <= 1.0
    assert any(value < 0.5 for value in visibilities)


def test_gimmicks_do_not_directly_mutate_session_a_owned_code():
    forbidden = ["res://Game/Player", "res://Game/Physics", "res://Game/Abilities", ".kill(", "PlayerController"]
    for path in GIMMICKS.glob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text, f"{path.name} contains forbidden coupling: {token}"
