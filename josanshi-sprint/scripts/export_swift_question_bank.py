#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"
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


def clinical_frame(scenario: dict) -> dict:
    raw = scenario.get("clinicalFrame") or {}
    findings = raw.get("keyFindings")
    if not isinstance(findings, list):
        findings = [
            str(raw[key]).strip()
            for key in ("person", "coreTask", "safetyEscalation")
            if raw.get(key) is not None and str(raw[key]).strip()
        ]
    return {
        "phase": str(raw.get("phase") or scenario.get("scenarioFamily") or "clinical"),
        "timeline": str(raw.get("timeline") or scenario.get("scenarioText") or ""),
        "keyFindings": findings,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    bank = json.loads(BANK.read_text(encoding="utf-8"))
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
                "explanation": question["explanation"],
                "memoryPoint": question["memoryPoint"],
                "sourceIds": question.get("sourceIds", []),
                "sourceCheckedAt": question["sourceCheckedAt"],
                "lawBaselineDate": question["lawBaselineDate"],
                "rightsBasis": question.get("rightsBasis") or "original wording; no direct reproduction",
                "originType": question.get("originType") or "original_from_primary_source",
                "contentVersion": question["contentVersion"],
                "auditStatus": question["auditStatus"],
                "evidenceNote": question.get("evidenceNote"),
                "authoringBatch": question.get("authoringBatch"),
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
                "scenarioText": scenario["scenarioText"],
                "clinicalFrame": clinical_frame(scenario),
                "questionIds": scenario["questionIds"],
                "sourceIds": scenario.get("sourceIds", []),
                "sourceCheckedAt": scenario["sourceCheckedAt"],
                "rightsBasis": scenario.get("rightsBasis") or "original scenario wording; no direct reproduction",
                "auditStatus": scenario["auditStatus"],
                "authoringBatch": scenario.get("authoringBatch"),
            }
        )

    payload = {
        "schemaVersion": "1.0",
        "qualification": "助産師国家試験",
        "contentVersion": bank.get("contentVersion", "josanshi-content-v1"),
        "status": "audited",
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
