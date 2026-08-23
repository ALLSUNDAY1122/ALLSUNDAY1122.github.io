#!/usr/bin/env python3
import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT = ROOT / "data" / "question-blueprint.json"
DEFAULT_OUTPUT = ROOT / "data" / "generation-slots.json"


def build_session(mock_round: int, session: str, general_count: int, scenario_groups: list[int]) -> list[dict]:
    slots: list[dict] = []
    for number in range(1, general_count + 1):
        slots.append({
            "id": f"JOS-R{mock_round}-{session}-Q{number:02d}",
            "mockRound": mock_round,
            "session": session,
            "slotNumber": number,
            "questionType": "general",
            "scenarioId": None,
            "scenarioIndex": None,
            "scenarioTotal": None,
            "topicId": None,
            "status": "planned"
        })

    number = general_count + 1
    for case_index, group_size in enumerate(scenario_groups, start=1):
        scenario_id = f"JOS-R{mock_round}-{session}-SC{case_index:02d}"
        for scenario_index in range(1, group_size + 1):
            slots.append({
                "id": f"JOS-R{mock_round}-{session}-Q{number:02d}",
                "mockRound": mock_round,
                "session": session,
                "slotNumber": number,
                "questionType": "situation",
                "scenarioId": scenario_id,
                "scenarioIndex": scenario_index,
                "scenarioTotal": group_size,
                "topicId": None,
                "status": "planned"
            })
            number += 1
    return slots


def build_slots() -> list[dict]:
    data = json.loads(BLUEPRINT.read_text(encoding="utf-8"))
    exam = data["latestConfirmedExam"]
    slots: list[dict] = []
    for mock_round in range(1, data["productionBank"]["mockSetCount"] + 1):
        slots += build_session(
            mock_round,
            "AM",
            exam["morning"]["general"],
            exam["morning"]["scenarioGroups"]
        )
        slots += build_session(
            mock_round,
            "PM",
            exam["afternoon"]["general"],
            exam["afternoon"]["scenarioGroups"]
        )
    return slots


def validate(slots: list[dict]) -> None:
    if len(slots) != 330:
        raise SystemExit(f"FAIL: expected 330 planned slots, found {len(slots)}")
    if len({slot["id"] for slot in slots}) != 330:
        raise SystemExit("FAIL: generation-slot IDs must be unique")

    by_round = Counter(slot["mockRound"] for slot in slots)
    if by_round != Counter({1: 110, 2: 110, 3: 110}):
        raise SystemExit(f"FAIL: expected 110 slots per mock, found {dict(by_round)}")

    by_type = Counter(slot["questionType"] for slot in slots)
    if by_type != Counter({"general": 225, "situation": 105}):
        raise SystemExit(f"FAIL: expected 225 general + 105 situation, found {dict(by_type)}")

    scenario_slots = [slot for slot in slots if slot["questionType"] == "situation"]
    scenarios = {}
    for slot in scenario_slots:
        scenarios.setdefault(slot["scenarioId"], []).append(slot)
    if len(scenarios) != 36:
        raise SystemExit(f"FAIL: expected 36 scenario cases, found {len(scenarios)}")

    for scenario_id, members in scenarios.items():
        totals = {member["scenarioTotal"] for member in members}
        indices = sorted(member["scenarioIndex"] for member in members)
        if len(totals) != 1:
            raise SystemExit(f"FAIL: {scenario_id} has inconsistent scenarioTotal")
        total = totals.pop()
        if len(members) != total or indices != list(range(1, total + 1)):
            raise SystemExit(f"FAIL: {scenario_id} linkage is broken")

    print("PASS: #14 generation slots")
    print("  330 slots = 225 general + 105 situation")
    print("  3 mocks x 110 questions")
    print("  36 linked scenario cases")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="validate the generated structure without writing a file")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    slots = build_slots()
    validate(slots)
    if not args.check:
        payload = {
            "schemaVersion": "1.0",
            "qualification": "助産師国家試験",
            "generatedFrom": "data/question-blueprint.json",
            "note": "Structural planning slots only. topicId remains null until primary-source-backed semantic assignment; these are not production questions.",
            "slots": slots
        }
        args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"WROTE: {args.output}")


if __name__ == "__main__":
    main()
