#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

from build_intent_seeds import build_payload as build_intent_payload

ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT = ROOT / "data" / "question-blueprint.json"
TOPIC_MAP = ROOT / "data" / "topic-source-map.json"
DEFAULT_OUTPUT = ROOT / "data" / "generation-plan.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def family(cluster: str) -> str:
    if cluster in {"pregnancy", "pregnancy-risk", "infection", "maternal-comorbidity", "fetal"}:
        return "pregnancy"
    if cluster in {"labor", "labor-risk", "fetal-risk", "obstetric-procedure", "emergency"}:
        return "labor"
    if cluster in {"postpartum", "postpartum-risk", "breastfeeding", "parenting-support", "mental-health"}:
        return "postpartum"
    if cluster in {"neonatal", "neonatal-immediate", "neonatal-risk", "preterm", "infant", "infant-risk"}:
        return "neonatal"
    return "general"


def make_slots(exam: dict, mock_round: int) -> list[dict]:
    slots = []
    for session_key, session_name in (("morning", "AM"), ("afternoon", "PM")):
        spec = exam[session_key]
        for number in range(1, spec["general"] + 1):
            slots.append({
                "id": f"JOS-R{mock_round}-{session_name}-Q{number:02d}",
                "mockRound": mock_round,
                "session": session_name,
                "slotNumber": number,
                "questionType": "general",
                "scenarioId": None,
                "scenarioIndex": None,
                "scenarioTotal": None,
            })
        number = spec["general"] + 1
        for case_index, case_size in enumerate(spec["scenarioGroups"], start=1):
            scenario_id = f"JOS-R{mock_round}-{session_name}-SC{case_index:02d}"
            for scenario_index in range(1, case_size + 1):
                slots.append({
                    "id": f"JOS-R{mock_round}-{session_name}-Q{number:02d}",
                    "mockRound": mock_round,
                    "session": session_name,
                    "slotNumber": number,
                    "questionType": "situation",
                    "scenarioId": scenario_id,
                    "scenarioIndex": scenario_index,
                    "scenarioTotal": case_size,
                })
                number += 1
    return slots


def choose_topic(candidates: list[str], remaining: Counter, used_in_case: Counter) -> str:
    available = [tid for tid in candidates if remaining[tid] > 0]
    if not available:
        return ""
    return sorted(
        available,
        key=lambda tid: (-remaining[tid], used_in_case[tid], tid)
    )[0]


def build_plan() -> dict:
    blueprint = json.loads(BLUEPRINT.read_text(encoding="utf-8"))
    topic_map = json.loads(TOPIC_MAP.read_text(encoding="utf-8"))
    intent_payload = build_intent_payload()
    topics = {t["topicId"]: t for t in blueprint["topics"]}
    evidence = {t["topicId"]: t for t in topic_map["topics"]}
    intents = {t["topicId"]: t["intents"] for t in intent_payload["topics"]}

    family_topics = defaultdict(list)
    situation_topics = []
    for tid, item in evidence.items():
        if item["situationEligible"]:
            situation_topics.append(tid)
            family_topics[family(item["caseCluster"])].append(tid)

    # 12 cases per mock. The sequence is intentionally balanced across the four
    # clinical phases while retaining the official AM/PM case sizes.
    case_family_sequence = [
        "pregnancy", "labor", "postpartum", "neonatal",
        "pregnancy", "labor", "postpartum", "neonatal",
        "pregnancy", "labor", "postpartum", "neonatal",
    ]

    plan = []
    case_records = []
    topic_occurrence = Counter()
    for mock_round in range(1, blueprint["productionBank"]["mockSetCount"] + 1):
        slots = make_slots(blueprint["latestConfirmedExam"], mock_round)
        remaining = Counter({
            tid: topic["mockDistribution"][mock_round - 1]
            for tid, topic in topics.items()
        })
        if sum(remaining.values()) != 110:
            fail(f"R{mock_round}: blueprint quota must total 110")

        situation_slots = [s for s in slots if s["questionType"] == "situation"]
        grouped = []
        for scenario_id in dict.fromkeys(s["scenarioId"] for s in situation_slots):
            grouped.append([s for s in situation_slots if s["scenarioId"] == scenario_id])
        if len(grouped) != 12:
            fail(f"R{mock_round}: expected 12 scenario cases, found {len(grouped)}")

        assignments = {}
        for case_number, case_slots in enumerate(grouped):
            target_family = case_family_sequence[case_number]
            candidates = family_topics[target_family]
            used_in_case = Counter()
            assigned_topics = []
            for slot in case_slots:
                tid = choose_topic(candidates, remaining, used_in_case)
                if not tid:
                    # Preserve item count even if a family quota is exhausted;
                    # only another situation-eligible clinical topic may be used.
                    tid = choose_topic(situation_topics, remaining, used_in_case)
                if not tid:
                    fail(f"R{mock_round} {slot['scenarioId']}: no situation-eligible quota remains")
                assignments[slot["id"]] = tid
                remaining[tid] -= 1
                used_in_case[tid] += 1
                assigned_topics.append(tid)
            case_records.append({
                "mockRound": mock_round,
                "scenarioId": case_slots[0]["scenarioId"],
                "scenarioTotal": len(case_slots),
                "scenarioFamily": target_family,
                "topicIds": assigned_topics,
                "status": "planned",
            })

        general_slots = [s for s in slots if s["questionType"] == "general"]
        remaining_list = []
        for tid in sorted(remaining):
            remaining_list.extend([tid] * remaining[tid])
        if len(remaining_list) != len(general_slots):
            fail(
                f"R{mock_round}: remaining general quota {len(remaining_list)} "
                f"!= general slots {len(general_slots)}"
            )
        for slot, tid in zip(general_slots, remaining_list):
            assignments[slot["id"]] = tid
            remaining[tid] -= 1

        if any(remaining.values()):
            fail(f"R{mock_round}: non-zero quota after assignment {dict(remaining)}")

        for slot in slots:
            tid = assignments[slot["id"]]
            topic = topics[tid]
            source_meta = evidence[tid]
            occurrence = topic_occurrence[tid]
            if occurrence >= len(intents[tid]):
                fail(f"{tid}: more planned slots than semantic intents")
            intent = intents[tid][occurrence]
            topic_occurrence[tid] += 1
            plan.append({
                **slot,
                "subject": topic["subject"],
                "topicId": tid,
                "topicTitle": topic["title"],
                "intentId": intent["intentId"],
                "intentFocus": intent["focus"],
                "cognitiveMode": intent["cognitiveMode"],
                "officialKeywords": intent["officialKeywords"],
                "risk": source_meta["risk"],
                "caseCluster": source_meta["caseCluster"],
                "sourceIds": source_meta["sourceIds"],
                "contentStatus": "planned",
            })

    for tid, seed_list in intents.items():
        if topic_occurrence[tid] != len(seed_list):
            fail(f"{tid}: semantic intents used {topic_occurrence[tid]} / {len(seed_list)}")

    return {
        "schemaVersion": "1.1",
        "qualification": blueprint["qualification"],
        "generatedFrom": [
            "question-blueprint.json",
            "topic-source-map.json",
            "build_intent_seeds.py",
        ],
        "policy": "Structural and semantic plan only. No question wording is approved until source-level content audit passes.",
        "questions": plan,
        "scenarios": case_records,
    }


def validate(payload: dict) -> None:
    questions = payload["questions"]
    scenarios = payload["scenarios"]
    if len(questions) != 330:
        fail(f"expected 330 questions, found {len(questions)}")
    if len({q["id"] for q in questions}) != 330:
        fail("question IDs are not unique")
    if Counter(q["mockRound"] for q in questions) != Counter({1: 110, 2: 110, 3: 110}):
        fail("mock-round item counts are not 110 each")
    if Counter(q["questionType"] for q in questions) != Counter({"general": 225, "situation": 105}):
        fail("question-type totals are not 225 general + 105 situation")
    if len(scenarios) != 36:
        fail(f"expected 36 scenario cases, found {len(scenarios)}")

    blueprint = json.loads(BLUEPRINT.read_text(encoding="utf-8"))
    expected_total = {t["topicId"]: t["bankTarget"] for t in blueprint["topics"]}
    actual_total = Counter(q["topicId"] for q in questions)
    if actual_total != Counter(expected_total):
        fail("bank topic totals do not equal 66 topics x 5")
    for round_no in (1, 2, 3):
        actual = Counter(q["topicId"] for q in questions if q["mockRound"] == round_no)
        expected = Counter({t["topicId"]: t["mockDistribution"][round_no - 1] for t in blueprint["topics"]})
        if actual != expected:
            fail(f"R{round_no}: topic distribution mismatch")

    intent_ids = [q["intentId"] for q in questions]
    if len(intent_ids) != len(set(intent_ids)) or len(intent_ids) != 330:
        fail("each semantic intent must be assigned exactly once")
    if any(not q["intentFocus"] or not q["officialKeywords"] for q in questions):
        fail("semantic intent metadata missing")

    for scenario in scenarios:
        members = [q for q in questions if q["scenarioId"] == scenario["scenarioId"]]
        if len(members) != scenario["scenarioTotal"]:
            fail(f"{scenario['scenarioId']}: broken scenario membership")
        if any(q["questionType"] != "situation" for q in members):
            fail(f"{scenario['scenarioId']}: non-situation question in scenario")
        if not all(q["sourceIds"] for q in members):
            fail(f"{scenario['scenarioId']}: source-less question")

    print("PASS: #14 generation plan")
    print("  330 questions = 225 general + 105 situation")
    print("  36 linked scenarios")
    print("  66 topics x 5 questions")
    print("  330 distinct semantic intents assigned exactly once")
    print("  per-mock topic distributions preserved")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    payload = build_plan()
    validate(payload)
    if not args.check:
        args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"WROTE: {args.output}")


if __name__ == "__main__":
    main()
