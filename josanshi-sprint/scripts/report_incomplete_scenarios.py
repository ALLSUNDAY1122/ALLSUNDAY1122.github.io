#!/usr/bin/env python3
import json
from collections import defaultdict
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = ROOT / "data" / "authored-batches"

plan = build_plan()
planned_by_scenario: dict[str, list[dict]] = defaultdict(list)
for question in plan["questions"]:
    if question.get("scenarioId"):
        planned_by_scenario[question["scenarioId"]].append(question)

questions_by_intent: dict[str, dict] = {}
scenarios_by_id: dict[str, dict] = {}
for path in sorted(BATCH_DIR.glob("*.json")):
    payload = json.loads(path.read_text(encoding="utf-8"))
    for question in payload.get("questions", []):
        questions_by_intent[question["intentId"]] = question
    for scenario in payload.get("scenarios", []):
        scenarios_by_id[scenario["scenarioId"]] = scenario

incomplete = []
for scenario_id, members in planned_by_scenario.items():
    members = sorted(members, key=lambda q: q["scenarioIndex"])
    authored = [q for q in members if q["intentId"] in questions_by_intent]
    if 0 < len(authored) < len(members):
        incomplete.append((scenario_id, members))

print(f"INCOMPLETE LINKED SCENARIOS: {len(incomplete)}")
for scenario_id, members in incomplete:
    scenario = scenarios_by_id.get(scenario_id, {})
    print(f"\n{scenario_id} | {scenario.get('scenarioText', '<scenario text missing>')}")
    for member in members:
        authored = questions_by_intent.get(member["intentId"])
        prompt = authored.get("prompt") if authored else "<MISSING>"
        print(
            f"  index={member['scenarioIndex']}/{member['scenarioTotal']} "
            f"{member['id']} | {member['intentId']} | {member['intentFocus']} | {prompt}"
        )
