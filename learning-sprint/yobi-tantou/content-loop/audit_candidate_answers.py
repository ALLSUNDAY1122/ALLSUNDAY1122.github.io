#!/usr/bin/env python3
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BANK = json.loads((HERE / "questions.candidates.v1.json").read_text(encoding="utf-8"))
AUDIT = json.loads((HERE / "candidate-answer-audit.v1.json").read_text(encoding="utf-8"))
LOCKS = json.loads((HERE / "candidate-source-locks.v1.json").read_text(encoding="utf-8"))


def main() -> int:
    errors = []
    bank = {q["id"]: q for q in BANK}
    audit = {item["id"]: item for item in AUDIT.get("items", [])}
    locked = {item["id"] for item in LOCKS.get("candidates", [])}

    if AUDIT.get("status") != "PASS":
        errors.append("candidate answer audit overall status is not PASS")
    if set(bank) != set(audit):
        errors.append(f"answer audit coverage mismatch missing={sorted(set(bank)-set(audit))} extra={sorted(set(audit)-set(bank))}")
    if set(bank) != locked:
        errors.append(f"source lock coverage mismatch missing={sorted(set(bank)-locked)} extra={sorted(locked-set(bank))}")

    for qid, question in bank.items():
        item = audit.get(qid)
        if not item:
            continue
        if item.get("verdict") != "PASS":
            errors.append(f"{qid}: answer audit verdict not PASS")
        if item.get("risk") != "low":
            errors.append(f"{qid}: only direct low-risk statutory candidates may pass v1 answer audit")
        if question.get("answer_type") != "singleChoice":
            errors.append(f"{qid}: v1 answer audit only supports singleChoice")
            continue
        if question.get("answer") != item.get("expectedAnswer"):
            errors.append(f"{qid}: bank answer {question.get('answer')} != audited {item.get('expectedAnswer')}")
        if len(str(item.get("note", "")).strip()) < 18:
            errors.append(f"{qid}: answer audit note too short")
        if question.get("release_eligible") is not False:
            errors.append(f"{qid}: answer-checked candidate must remain non-release")

    if errors:
        print("FAIL: candidate answer/content audit")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"PASS: {len(bank)} candidate answers/explanations reviewed; all remain release_eligible=false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
