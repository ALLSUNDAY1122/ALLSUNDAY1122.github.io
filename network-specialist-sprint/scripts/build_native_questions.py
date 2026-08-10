#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

EXPECTED_YEARS = (2025, 2024, 2023)
EXPECTED_OCCURRENCES = 75
EXPECTED_UNIQUE = 68


def extract_json_assignment(text: str, name: str):
    match = re.search(rf"window\.{re.escape(name)}\s*=\s*(.+?);\s*(?:\n|$)", text, re.S)
    if not match:
        raise ValueError(f"Could not find window.{name}")
    return json.loads(match.group(1))


def extract_content_version(text: str) -> str:
    match = re.search(r'window\.NW_CONTENT_VERSION\s*=\s*"([^"]+)"', text)
    if not match:
        raise ValueError("Could not find NW_CONTENT_VERSION")
    return match.group(1)


def extract_question_array(text: str, path: Path):
    match = re.search(r"window\.NW_EXAM_OCCURRENCES\.push\(\.\.\.(\[.*\])\);\s*$", text, re.S)
    if not match:
        raise ValueError(f"Could not parse question array from {path}")
    return json.loads(match.group(1))


def read_ui_fix(path: Path) -> tuple[set[str], str] | None:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    target = re.search(r"q\.uiDomain\s*=\s*'([^']+)'", text)
    if not target:
        return None
    ids = set(re.findall(r"'((?:NW-)[^']+)'", text))
    return ids, target.group(1)


def build(root: Path, output: Path) -> dict:
    meta_text = (root / "questions-meta.js").read_text(encoding="utf-8")
    content_version = extract_content_version(meta_text)
    source_urls = extract_json_assignment(meta_text, "NW_SOURCE_URLS")
    answer_urls = extract_json_assignment(meta_text, "NW_ANSWER_URLS")
    unique_ids = extract_json_assignment(meta_text, "NW_UNIQUE_IDS")

    questions = []
    for path in sorted(root.glob("questions-20??-*.js"), reverse=True):
        questions.extend(extract_question_array(path.read_text(encoding="utf-8"), path))

    fix = read_ui_fix(root / "questions-ui-fixes.js")
    if fix:
        ids, target = fix
        for question in questions:
            if question.get("id") in ids:
                question["uiDomain"] = target

    for question in questions:
        question["sourceAttribution"] = "IPA公開問題を基に改変。解説は独自制作。"

    # The current #7 canonical sources do not define a sourceCheckedAt or
    # lawBaselineDate value. Preserve the schema without inventing dates.
    source_checked_at = ""

    payload = {
        "schemaVersion": 1,
        "contentVersion": content_version,
        "lawBaselineDate": None,
        "sourceCheckedAt": source_checked_at,
        "sourceURLs": source_urls,
        "answerURLs": answer_urls,
        "uniqueIDs": unique_ids,
        "questions": questions,
    }
    validate(payload)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    return payload


def validate(payload: dict) -> None:
    questions = payload["questions"]
    unique_ids = payload["uniqueIDs"]
    if len(questions) != EXPECTED_OCCURRENCES:
        raise ValueError(f"occurrences={len(questions)}, expected {EXPECTED_OCCURRENCES}")
    if len(unique_ids) != EXPECTED_UNIQUE or len(set(unique_ids)) != EXPECTED_UNIQUE:
        raise ValueError(f"unique={len(unique_ids)}, expected {EXPECTED_UNIQUE}")
    ids = [q["id"] for q in questions]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate question IDs")
    missing = sorted(set(unique_ids) - set(ids))
    if missing:
        raise ValueError(f"unique IDs missing from occurrences: {missing}")
    for year in EXPECTED_YEARS:
        count = sum(1 for q in questions if q["examYear"] == year)
        if count != 25:
            raise ValueError(f"{year} count={count}, expected 25")
    required = (
        "id", "examYear", "questionNo", "domain", "topic", "question", "choices",
        "answerIndex", "memoryLine", "shortExplanation", "detailExplanation",
        "canonicalConceptId", "isHistoricalRepeatOrVariant", "uiDomain",
    )
    for question in questions:
        for key in required:
            if key not in question:
                raise ValueError(f"{question.get('id', '?')} missing {key}")
        if len(question["choices"]) != 4:
            raise ValueError(f"{question['id']} choices != 4")
        if not 0 <= int(question["answerIndex"]) < 4:
            raise ValueError(f"{question['id']} invalid answerIndex")
        for key in ("question", "memoryLine", "shortExplanation", "detailExplanation"):
            if not str(question[key]).strip():
                raise ValueError(f"{question['id']} empty {key}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ios" / "NetworkSpecialist" / "Resources" / "questions.native.json",
    )
    args = parser.parse_args()
    payload = build(args.root, args.output)
    print(
        "PASS native question payload",
        {"occurrences": len(payload["questions"]), "unique": len(payload["uniqueIDs"]), "output": str(args.output)},
    )


if __name__ == "__main__":
    main()
