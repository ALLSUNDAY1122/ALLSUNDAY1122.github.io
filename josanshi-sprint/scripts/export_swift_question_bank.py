#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"
SOURCES = ROOT / "data" / "source-registry.json"
DEFAULT_OUTPUT = (
    ROOT
    / "ios"
    / "JosanshiSprintFeature"
    / "Sources"
    / "JosanshiSprintFeature"
    / "Resources"
    / "questions.json"
)


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    source_doc = json.loads(SOURCES.read_text(encoding="utf-8"))
    source_by_id = {source["id"]: source for source in source_doc.get("sources", [])}

    questions = bank.get("questions", [])
    scenarios = bank.get("scenarios", [])
    if len(questions) != 330:
        fail(f"Swift export requires complete 330-question bank, found {len(questions)}")
    if len(scenarios) != 36:
        fail(f"Swift export requires 36 linked scenarios, found {len(scenarios)}")
    if any(question.get("auditStatus") != "pass" for question in questions):
        fail("Swift export requires every question to have independent audit PASS")
    if any(scenario.get("auditStatus") != "pass" for scenario in scenarios):
        fail("Swift export requires every scenario to have independent audit PASS")

    exported_questions = []
    for question in questions:
        source_ids = question.get("sourceIds", [])
        primary = source_by_id.get(source_ids[0]) if source_ids else None
        exported_questions.append(
            {
                "id": question["id"],
                "mockRound": question["mockRound"],
                "session": question["session"],
                "slotNumber": question["slotNumber"],
                "questionType": question["questionType"],
                "scenarioId": question.get("scenarioId"),
                "scenarioIndex": question.get("scenarioIndex"),
                "scenarioTotal": question.get("scenarioTotal"),
                "subject": question["subject"],
                "topicId": question["topicId"],
                "intentId": question["intentId"],
                "intentFocus": question["intentFocus"],
                "answerType": question["answerType"],
                "prompt": question["prompt"],
                "choices": question.get("choices", []),
                "correctIndices": question.get("correctIndices", []),
                "memoryPoint": question["memoryPoint"],
                "explanation": question["explanation"],
                "sourceTitle": primary.get("title") if primary else None,
                "sourceURL": primary.get("url") if primary else None,
                "sourceRefs": source_ids,
                "sourceCheckedAt": question["sourceCheckedAt"],
                "lawBaselineDate": question["lawBaselineDate"],
                "contentVersion": question["contentVersion"],
                "rightsBasis": question.get("rightsBasis"),
                "premium": bool(question.get("premium", False)),
            }
        )

    exported_scenarios = []
    for scenario in scenarios:
        exported_scenarios.append(
            {
                "scenarioId": scenario["scenarioId"],
                "mockRound": scenario["mockRound"],
                "session": scenario["session"],
                "scenarioFamily": scenario["scenarioFamily"],
                "scenarioTotal": scenario["scenarioTotal"],
                "scenarioText": scenario["scenarioText"],
                "questionIds": scenario["questionIds"],
                "sourceIds": scenario.get("sourceIds", []),
                "sourceCheckedAt": scenario["sourceCheckedAt"],
                "rightsBasis": scenario.get("rightsBasis"),
            }
        )

    payload = {
        "schemaVersion": "1.0",
        "qualification": "助産師国家試験",
        "contentVersion": bank.get("contentVersion", "josanshi-content-v1"),
        "auditMode": "FULL",
        "questionCount": 330,
        "scenarioCount": 36,
        "questions": exported_questions,
        "scenarios": exported_scenarios,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"WROTE: {args.output}")
    print("PASS: Swift resource export 330 questions / 36 scenarios / FULL audit only")


if __name__ == "__main__":
    main()
