#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from validate_exam_structure import load_classification_records

ROOT = Path(__file__).resolve().parent
BATCH_DIR = ROOT / "question-batches"
AUDIT_DIR = ROOT / "content-audit-batches"

REQUIRED = {
    "id", "subject", "topic", "answerType", "prompt", "choices",
    "correctIndices", "memoryPoint", "explanation", "sourceURL", "sourceRefs",
    "sourceCheckedAt", "lawBaselineDate", "contentVersion", "rightsBasis",
    "examRound", "questionNumber", "originType", "officialScoringStatus"
}

# 表記だけが異なり、教材論点として同義であることを人手確認した組だけを許可する。
# 未知の表記差・別論点は自動許可せずFAILさせる。
TOPIC_ALIASES = {
    ("認知症の行動・心理症状", "認知症の周辺症状"),
    ("C6B1頸髄損傷の到達可能動作", "C6頸髄損傷の到達可能動作"),
    ("三次予防と社会復帰", "三次予防と職場復帰"),
    ("下腿区画と神経支配", "下腿断面の解剖"),
    ("関節唇", "関節唇を有する関節"),
    ("視覚器", "視覚器の構造"),
    ("脊髄運動ニューロン", "脊髄の運動ニューロン"),
    ("CBRマトリックス", "CBRマトリクス"),
    ("介護保険制度のケアプラン", "介護保険ケアプラン"),
    ("ICD疾病分類", "国際疾病分類ICD"),
    ("診療報酬改定の周期", "診療報酬改定周期"),
    ("二分脊椎の機能レベルと歩行", "二分脊椎の機能残存レベルと歩行"),
    ("腰椎椎間板ヘルニアの疼痛誘発", "腰椎椎間板ヘルニアの疼痛誘発テスト"),
    ("アミロイドーシス", "アミロイド沈着"),
    ("関節運動と運動軸", "関節の運動軸"),
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def accepted_sets(question: dict) -> list[list[int]]:
    values = question.get("acceptedIndexSets")
    if values:
        return values
    indices = question.get("correctIndices", [])
    return [indices] if indices else []


def load_content_audits(errors: list[str]) -> dict[str, dict]:
    result: dict[str, dict] = {}
    if not AUDIT_DIR.exists():
        return result
    for path in sorted(AUDIT_DIR.glob("audit-*.json")):
        try:
            doc = load_json(path)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: invalid audit JSON: {exc}")
            continue
        if doc.get("qualification") != "理学療法士国家試験":
            errors.append(f"{path.name}: audit qualification mismatch")
        for row in doc.get("records", []):
            if not isinstance(row, list) or len(row) < 3:
                errors.append(f"{path.name}: invalid audit row {row!r}")
                continue
            sid, status, note = row[0], row[1], row[2]
            if sid in result:
                errors.append(f"duplicate content audit: {sid}")
                continue
            result[sid] = {
                "status": status,
                "note": note,
                "checkedAt": doc.get("checkedAt"),
                "batch": doc.get("batch"),
            }
    return result


def main() -> int:
    errors: list[str] = []
    classifications, classification_errors = load_classification_records()
    errors.extend(classification_errors)
    class_by_id = {item["id"]: item for item in classifications}
    audits = load_content_audits(errors)

    adjustments = load_json(ROOT / "scoring-adjustments.json")
    official_treatment = {
        item["id"]: item["treatment"] for item in adjustments.get("adjustments", [])
    }

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

        audit = audits.get(sid)
        if audit is None:
            errors.append(f"{sid}: medical/content audit missing")
        elif not str(audit["status"]).startswith("PASS"):
            errors.append(f"{sid}: medical/content audit not PASS: {audit['status']}")

        classification = class_by_id.get(sid)
        if classification is None:
            errors.append(f"{sid}: no verified classification")
        else:
            if question["subject"] != classification["subject"]:
                errors.append(
                    f"{sid}: subject mismatch question={question['subject']} classification={classification['subject']}"
                )
            actual_topic = str(question["topic"]).strip()
            expected_topic = str(classification["topic"]).strip()
            independent_excluded_replacement = (
                question.get("officialScoringStatus") == "excluded"
                and question.get("originType") == "independent_replacement_for_excluded_official"
            )
            if (
                actual_topic != expected_topic
                and (actual_topic, expected_topic) not in TOPIC_ALIASES
                and not independent_excluded_replacement
            ):
                errors.append(
                    f"{sid}: topic mismatch question={actual_topic} classification={expected_topic}"
                )
            if (
                classification["mediaStatus"] == "excluded_unresolved_rights"
                and question["originType"] == "official_text_with_media"
            ):
                errors.append(f"{sid}: unresolved official media cannot ship")

        if not str(question["prompt"]).strip():
            errors.append(f"{sid}: empty prompt")
        if not str(question["explanation"]).strip():
            errors.append(f"{sid}: empty explanation")
        if not str(question["memoryPoint"]).strip():
            errors.append(f"{sid}: empty memoryPoint")
        if not str(question["sourceURL"]).startswith("https://"):
            errors.append(f"{sid}: sourceURL must be HTTPS")
        if not isinstance(question.get("sourceRefs"), list) or not question["sourceRefs"]:
            errors.append(f"{sid}: sourceRefs must contain evidence")
        elif any(not str(url).startswith("https://") for url in question["sourceRefs"]):
            errors.append(f"{sid}: sourceRefs must be HTTPS")
        if not str(question["rightsBasis"]).strip():
            errors.append(f"{sid}: rightsBasis missing")
        if question["officialScoringStatus"] not in {"scored", "excluded"}:
            errors.append(f"{sid}: invalid officialScoringStatus")

        expected_treatment = official_treatment.get(sid)
        if expected_treatment == "excluded":
            if question["officialScoringStatus"] != "excluded":
                errors.append(f"{sid}: official excluded slot must remain marked excluded")
            if question["originType"] != "independent_replacement_for_excluded_official":
                errors.append(f"{sid}: excluded official slot must use independent replacement")
        elif question["officialScoringStatus"] == "excluded":
            errors.append(f"{sid}: non-excluded official slot marked excluded")

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
    print(f"medical/content audits: {len([sid for sid in ids if sid in audits])} / {len(questions)}")
    print(f"remaining: {600 - len(questions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
