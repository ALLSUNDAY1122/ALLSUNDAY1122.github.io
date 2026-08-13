#!/usr/bin/env python3
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = ROOT / "data" / "authored-batches"
DEFAULT_OUTPUT = ROOT / "data" / "questions.materialized.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def canonicalize_rights_basis(question: dict) -> dict:
    """Normalize equivalent explicit non-reproduction wording for downstream audit.

    Authored records must still state that wording is original and explicitly prohibit
    some form of reproduction. This does not add a rights guard when one is absent;
    it only appends the canonical token used by the bank auditor when the authored
    metadata already contains an explicit 'no ... reproduction' restriction.
    """
    basis = question.get("rightsBasis")
    if not isinstance(basis, str) or not basis.strip():
        return question

    lower = basis.lower()
    if "no direct reproduction" in lower:
        return question

    has_original = "original" in lower
    has_explicit_no_reproduction = bool(re.search(r"\bno\b[^.;]*\breproduction\b", lower))
    if has_original and has_explicit_no_reproduction:
        normalized = dict(question)
        normalized["rightsBasis"] = basis.rstrip(" ;") + "; no direct reproduction"
        return normalized

    return question


def load_batches() -> tuple[list[dict], list[dict]]:
    questions: list[dict] = []
    scenarios: list[dict] = []
    if not BATCH_DIR.exists():
        return questions, scenarios
    for path in sorted(BATCH_DIR.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload.get("questions", []), list):
            fail(f"{path.name}: questions must be an array")
        if not isinstance(payload.get("scenarios", []), list):
            fail(f"{path.name}: scenarios must be an array")
        for question in payload.get("questions", []):
            questions.append({**canonicalize_rights_basis(question), "authoringBatch": path.name})
        for scenario in payload.get("scenarios", []):
            scenarios.append({**scenario, "authoringBatch": path.name})
    return questions, scenarios


def materialize() -> dict:
    plan = build_plan()
    authored_questions, authored_scenarios = load_batches()
    plan_by_intent = {question["intentId"]: question for question in plan["questions"]}
    plan_by_scenario = {scenario["scenarioId"]: scenario for scenario in plan["scenarios"]}
    questions_by_scenario: dict[str, list[dict]] = defaultdict(list)
    for question in plan["questions"]:
        if question.get("scenarioId"):
            questions_by_scenario[question["scenarioId"]].append(question)

    if len(plan_by_intent) != 330:
        fail("generation plan must contain 330 unique intents")

    seen_intents: set[str] = set()
    questions: list[dict] = []
    for authored in authored_questions:
        intent_id = authored.get("intentId")
        if not intent_id:
            fail(f"{authored.get('authoringBatch')}: authored question missing intentId")
        if intent_id in seen_intents:
            fail(f"duplicate authored intentId: {intent_id}")
        seen_intents.add(intent_id)
        planned = plan_by_intent.get(intent_id)
        if planned is None:
            fail(f"unknown intentId: {intent_id}")

        protected_fields = {
            "id", "mockRound", "session", "slotNumber", "questionType",
            "scenarioId", "scenarioIndex", "scenarioTotal", "subject",
            "topicId", "intentFocus",
        }
        forbidden = sorted(field for field in protected_fields if field in authored)
        if forbidden:
            fail(f"{intent_id}: authored batch must not override planned fields {forbidden}")

        record = {
            "id": planned["id"],
            "mockRound": planned["mockRound"],
            "session": planned["session"],
            "slotNumber": planned["slotNumber"],
            "questionType": planned["questionType"],
            "scenarioId": planned["scenarioId"],
            "scenarioIndex": planned["scenarioIndex"],
            "scenarioTotal": planned["scenarioTotal"],
            "subject": planned["subject"],
            "topicId": planned["topicId"],
            "intentId": planned["intentId"],
            "intentFocus": planned["intentFocus"],
            **authored,
        }
        questions.append(record)

    seen_scenarios: set[str] = set()
    scenarios: list[dict] = []
    for authored in authored_scenarios:
        scenario_id = authored.get("scenarioId")
        if not scenario_id:
            fail(f"{authored.get('authoringBatch')}: authored scenario missing scenarioId")
        if scenario_id in seen_scenarios:
            fail(f"duplicate authored scenarioId: {scenario_id}")
        seen_scenarios.add(scenario_id)
        planned = plan_by_scenario.get(scenario_id)
        if planned is None:
            fail(f"unknown scenarioId: {scenario_id}")

        members = sorted(
            questions_by_scenario.get(scenario_id, []),
            key=lambda q: q["scenarioIndex"],
        )
        if len(members) != planned["scenarioTotal"]:
            fail(
                f"{scenario_id}: generation-plan membership mismatch "
                f"{len(members)}/{planned['scenarioTotal']}"
            )

        # Scenario membership is structural data owned by the generation plan.
        # Older authored batches may contain hand-copied questionIds/session values;
        # never let those stale values override the canonical plan.
        authored_payload = dict(authored)
        for field in ("mockRound", "scenarioFamily", "scenarioTotal", "session", "questionIds"):
            authored_payload.pop(field, None)

        record = {
            **authored_payload,
            "scenarioId": scenario_id,
            "mockRound": planned["mockRound"],
            "scenarioFamily": planned["scenarioFamily"],
            "scenarioTotal": planned["scenarioTotal"],
            "session": members[0]["session"],
            "questionIds": [member["id"] for member in members],
        }
        scenarios.append(record)

    questions.sort(key=lambda q: (q["mockRound"], q["session"], q["slotNumber"]))
    scenarios.sort(key=lambda s: (s["mockRound"], s["scenarioId"]))
    return {
        "schemaVersion": "1.0",
        "qualification": "助産師国家試験",
        "contentVersion": "josanshi-content-v1",
        "status": "draft" if len(questions) < 330 else "candidate",
        "questions": questions,
        "scenarios": scenarios,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    payload = materialize()
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WROTE: {args.output}")
    print(f"questions={len(payload['questions'])}, scenarios={len(payload['scenarios'])}")


if __name__ == "__main__":
    main()
