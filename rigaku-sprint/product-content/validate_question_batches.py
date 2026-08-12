#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from validate_exam_structure import load_classification_records

ROOT = Path(__file__).resolve().parent
BATCH_DIR = ROOT / "question-batches"

REQUIRED = {
    "id", "subject", "topic", "answerType", "prompt", "choices",
    "correctIndices", "memoryPoint", "explanation", "sourceURL",
    "sourceCheckedAt", "lawBaselineDate", "contentVersion", "rightsBasis",
    "examRound", "questionNumber", "originType", "officialScoringStatus"
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def accepted_sets(question: dict) -> list[list[int]]:
    values = question.get("acceptedIndexSets")
    if values:
        return values
    indices = question.get("correctIndices", [])
    return [indices] if indices else []


def main() -> int:
    errors: list[str] = []
    classifications, classification_errors = load_classification_records()
    errors.extend(classification_errors)
    class_by_id = {item["id"]: item for item in classifications}

    questions: list[dict] = []
    main_path = ROOT / "questions.json"
    if main_path.exists():
        main_questions = load_json(main_path)
        if not isinstance(main_questions, list):
            errors.append("questions.json must be an array")
        else:
            questions.extend(main_questions)

    if BATCH_DIR.exists():
        for path in sorted(BATCH_DIR.glob("questions-*.json")):
            try:
                batch = load_json(path)
            except json.JSONDecodeError as exc:
                errors.append(f"{path.name}: invalid JSON: {exc}")
                continue
            if not isinstance(batch, list):
                errors.append(f"{path.name}: root must be an array")
                continue
            questions.extend(batch)

    ids: set[str] = set()
    for index, question in enumerate(questions):
        sid = question.get("id", f"index:{index}")
        if sid in ids:
            errors.append(f"duplicate question id: {sid}")
        ids.add(sid)

        missing = REQUIRED - set(question)
        if missing:
            errors.append(f"{sid}: missing fields {sorted(missing)}")
            continue

        classification = class_by_id.get(sid)
        if classification is None:
            errors.append(f"{sid}: no verified classification")
        else:
            if question["subject"] != classification["subject"]:
                errors.append(
                    f"{sid}: subject mismatch question={question['subject']} classification={classification['subject']}"
                )
            if classification["mediaStatus"] == "excluded_unresolved_rights" and question["originType"] == "official_text_with_media":
                errors.append(f"{sid}: unresolved official media cannot ship")

        if not str(question["prompt"]).strip():
            errors.append(f"{sid}: empty prompt")
        if not str(question["explanation"]).strip():
            errors.append(f"{sid}: empty explanation")
        if not str(question["memoryPoint"]).strip():
            errors.append(f"{sid}: empty memoryPoint")
        if not str(question["sourceURL"]).startswith("https://"):
            errors.append(f"{sid}: sourceURL must be HTTPS")
        if not str(question["rightsBasis"]).strip():
            errors.append(f"{sid}: rightsBasis missing")
        if question["officialScoringStatus"] not in {"scored", "excluded"}:
            errors.append(f"{sid}: invalid officialScoringStatus")

        choices = question.get("choices", [])
        if len(choices) < 2:
            errors.append(f"{sid}: choice question needs at least 2 choices")
            continue
        alternatives = accepted_sets(question)
        if not alternatives:
            errors.append(f"{sid}: no correct answer pattern")
            continue
        for pattern in alternatives:
            if not pattern:
                errors.append(f"{sid}: empty accepted answer pattern")
            if len(pattern) != len(set(pattern)):
                errors.append(f"{sid}: duplicate index in answer pattern {pattern}")
            if any(not isinstance(value, int) or value < 0 or value >= len(choices) for value in pattern):
                errors.append(f"{sid}: invalid answer index pattern {pattern}")

        if question["answerType"] == "singleChoice" and any(len(pattern) != 1 for pattern in alternatives):
            errors.append(f"{sid}: singleChoice answer pattern must contain one index")
        if question["answerType"] == "multiChoice" and any(len(pattern) < 2 for pattern in alternatives):
            errors.append(f"{sid}: multiChoice answer pattern must contain two or more indices")
        if question["answerType"] not in {"singleChoice", "multiChoice"}:
            errors.append(f"{sid}: PT first release supports singleChoice/multiChoice only")

    if errors:
        print("RIGAKU QUESTION BATCHES: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RIGAKU QUESTION BATCHES: PASS")
    print(f"audited release questions: {len(questions)} / 600")
    print(f"remaining: {600 - len(questions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
