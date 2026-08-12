#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(name: str):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def slot_id(round_no: int, session: str, number: int) -> str:
    return f"RIGAKU-R{round_no}-{session}-{number:03d}"


def main() -> int:
    errors: list[str] = []
    frame = load("exam-frame.json")
    sources = load("official-sources.json")
    adjustments = load("scoring-adjustments.json")
    classification = load("classification.json")
    questions = load("questions.json")

    frame_rounds = {int(item["round"]): item for item in frame["rounds"]}
    source_rounds = {int(item["round"]): item for item in sources["rounds"]}
    expected_rounds = {58, 59, 60}
    if set(frame_rounds) != expected_rounds:
        errors.append(f"exam-frame rounds mismatch: {sorted(frame_rounds)}")
    if set(source_rounds) != expected_rounds:
        errors.append(f"official-sources rounds mismatch: {sorted(source_rounds)}")

    slots: dict[str, dict] = {}
    for round_no in sorted(expected_rounds, reverse=True):
        frame_round = frame_rounds.get(round_no, {})
        source_round = source_rounds.get(round_no, {})
        if frame_round.get("morning_questions") != 100:
            errors.append(f"R{round_no} AM count must be 100")
        if frame_round.get("afternoon_questions") != 100:
            errors.append(f"R{round_no} PM count must be 100")
        if frame_round.get("total_questions") != 200:
            errors.append(f"R{round_no} total must be 200")
        counts = source_round.get("questionCount", {})
        if counts != {"AM": 100, "PM": 100, "total": 200}:
            errors.append(f"R{round_no} source question counts mismatch: {counts}")

        for session in ("AM", "PM"):
            for number in range(1, 101):
                sid = slot_id(round_no, session, number)
                slots[sid] = {
                    "round": round_no,
                    "session": session,
                    "number": number,
                    "category": "practical" if number <= 20 else "general",
                    "basePoints": 3 if number <= 20 else 1,
                    "treatment": "normal",
                }

    if len(slots) != 600:
        errors.append(f"structural slot count must be 600, got {len(slots)}")

    adjustment_ids: set[str] = set()
    for item in adjustments["adjustments"]:
        sid = item["id"]
        expected_id = slot_id(int(item["round"]), item["session"], int(item["questionNumber"]))
        if sid != expected_id:
            errors.append(f"adjustment id mismatch: {sid} != {expected_id}")
        if sid not in slots:
            errors.append(f"adjustment references missing slot: {sid}")
            continue
        if sid in adjustment_ids:
            errors.append(f"duplicate adjustment: {sid}")
        adjustment_ids.add(sid)
        treatment = item.get("treatment")
        codes = item.get("acceptedResponseCodes", [])
        if treatment not in {"excluded", "multiple_accepted"}:
            errors.append(f"unsupported treatment: {sid} {treatment}")
        if treatment == "excluded" and codes:
            errors.append(f"excluded question must have no accepted response codes: {sid}")
        if treatment == "multiple_accepted" and len(codes) < 2:
            errors.append(f"multiple_accepted needs >=2 official codes: {sid}")
        if not item.get("officialAdjustmentURL") or not item.get("officialFinalAnswerURL"):
            errors.append(f"official scoring evidence missing: {sid}")
        slots[sid]["treatment"] = treatment

    if len(adjustment_ids) != 20:
        errors.append(f"expected 20 official scoring adjustments, got {len(adjustment_ids)}")

    # Position rule (1-20 practical, 21-100 general) is accepted only because
    # its score totals reproduce MHLW's published maxima for all three rounds
    # after the official excluded questions are removed.
    calculated = defaultdict(lambda: {"general": 0, "practical": 0})
    for slot in slots.values():
        if slot["treatment"] == "excluded":
            continue
        calculated[slot["round"]][slot["category"]] += slot["basePoints"]

    for round_no in expected_rounds:
        scoring = source_rounds[round_no]["scoring"]
        general = calculated[round_no]["general"]
        practical = calculated[round_no]["practical"]
        if general != scoring["general_max"]:
            errors.append(f"R{round_no} general max mismatch: {general} != {scoring['general_max']}")
        if practical != scoring["practical_max"]:
            errors.append(f"R{round_no} practical max mismatch: {practical} != {scoring['practical_max']}")
        if general + practical != scoring["total_max"]:
            errors.append(f"R{round_no} total max mismatch: {general + practical} != {scoring['total_max']}")

    class_ids: set[str] = set()
    allowed_subjects = {
        "解剖学", "生理学", "運動学", "病理学概論", "臨床心理学",
        "リハビリテーション医学", "臨床医学大要", "理学療法"
    }
    for record in classification.get("records", []):
        sid = record.get("id")
        if sid not in slots:
            errors.append(f"classification references missing slot: {sid}")
            continue
        if sid in class_ids:
            errors.append(f"duplicate classification: {sid}")
        class_ids.add(sid)
        if record.get("subject") not in allowed_subjects:
            errors.append(f"invalid subject: {sid} {record.get('subject')}")
        if not record.get("topic"):
            errors.append(f"topic missing: {sid}")
        if record.get("classificationStatus") != "verified":
            errors.append(f"classification must be verified before ledger inclusion: {sid}")
        if record.get("rightsStatus") not in {"pdl_mhlw_confirmed", "originalized_from_primary_sources", "excluded_third_party_rights"}:
            errors.append(f"invalid rightsStatus: {sid}")
        if record.get("mediaStatus") not in {"none", "rights_cleared_local", "excluded_unresolved_rights"}:
            errors.append(f"invalid mediaStatus: {sid}")

    question_ids: list[str] = []
    for question in questions:
        sid = question.get("id")
        question_ids.append(sid)
        if sid not in slots:
            errors.append(f"product question references missing slot: {sid}")
        if sid not in class_ids:
            errors.append(f"product question lacks verified classification/rights ledger: {sid}")
        if not question.get("rightsBasis"):
            errors.append(f"product question rightsBasis missing: {sid}")
        if not question.get("sourceURL"):
            errors.append(f"product question sourceURL missing: {sid}")
        if not question.get("explanation") or not question.get("memoryPoint"):
            errors.append(f"product question L3 explanation/memory missing: {sid}")

    duplicates = [key for key, count in Counter(question_ids).items() if count > 1]
    if duplicates:
        errors.append(f"duplicate product question ids: {duplicates[:10]}")

    if errors:
        print("RIGAKU EXAM STRUCTURE: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RIGAKU EXAM STRUCTURE: PASS")
    print("official structural slots: 600")
    print(f"official scoring adjustments: {len(adjustment_ids)}")
    for round_no in sorted(expected_rounds, reverse=True):
        print(
            f"R{round_no}: general={calculated[round_no]['general']} / "
            f"practical={calculated[round_no]['practical']} / "
            f"total={calculated[round_no]['general'] + calculated[round_no]['practical']}"
        )
    print(f"verified classified slots: {len(class_ids)} / 600")
    print(f"release question records: {len(questions)} / 600")
    print("release gate remains closed until audited product questions are populated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
