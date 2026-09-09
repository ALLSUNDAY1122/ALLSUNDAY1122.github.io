#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
OUT = ROOT / "ios" / "GeneratedResources" / "questions.generated.json"
ROUNDS = [DATA / f"questions-r{i}.json" for i in (1, 2, 3)]
CONTENT_VERSION = "ot-600-v1"


def convert(q):
    if q.get("answer_type") not in {"singleChoice", "multiChoice"}:
        raise ValueError(f"unsupported answer_type: {q.get('id')} {q.get('answer_type')}")
    raw_answers = q.get("answer") or []
    if not raw_answers:
        raise ValueError(f"missing answer: {q.get('id')}")
    correct = sorted({int(v) - 1 for v in raw_answers})
    if any(i < 0 or i >= len(q.get("choices", [])) for i in correct):
        raise ValueError(f"answer index out of range: {q.get('id')}")

    return {
        "id": q["id"],
        "subject": q["subject"],
        "topic": q.get("topic") or q["subject"],
        "answerType": q["answer_type"],
        "prompt": q["text"],
        "choices": q.get("choices", []),
        "correctIndices": correct,
        "correctNumber": None,
        "acceptedRange": None,
        "unit": None,
        "roundingRule": None,
        "blanks": [],
        "declarationFields": [],
        "sourceText": q.get("source"),
        "memoryPoint": q.get("topic") or q["subject"],
        "explanation": q["explanation"],
        "sourceTitle": q.get("source"),
        "sourceURL": q.get("source_url"),
        "sourceRefs": [u for u in [q.get("source_page_url"), q.get("answer_source_url")] if u],
        "sourceCheckedAt": q.get("source_checked_at", "2026-08-19"),
        "lawBaselineDate": q.get("baseline_date", "2026-02-23"),
        "contentVersion": CONTENT_VERSION,
        "premium": q.get("round") != "R1",
        "examRound": str(q.get("reference_exam_round")) if q.get("reference_exam_round") else None,
        "questionNumber": q.get("source_id"),
        "rightsBasis": q.get("rights_basis"),
    }


def main():
    items = []
    seen = set()
    for path in ROUNDS:
        bank = json.loads(path.read_text(encoding="utf-8"))
        for q in bank:
            if q["id"] in seen:
                raise ValueError(f"duplicate id: {q['id']}")
            seen.add(q["id"])
            items.append(convert(q))

    if len(items) != 600:
        raise ValueError(f"expected 600 questions, got {len(items)}")
    if sum(not q["premium"] for q in items) != 200:
        raise ValueError("R1 free-set contract must contain exactly 200 questions")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"OT_NATIVE_PAYLOAD_PASS total={len(items)} free=200 premium=400 output={OUT}")


if __name__ == "__main__":
    main()
