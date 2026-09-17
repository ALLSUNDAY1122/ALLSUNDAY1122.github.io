#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_BANK = HERE / "questions.candidates.v1.json"
DEFAULT_AUDIT = HERE / "candidate-answer-audit.v1.json"
DEFAULT_LOCKS = HERE / "candidate-source-locks.v1.json"


def audit(bank_items: list[dict], audit_document: dict, locks_document: dict) -> list[str]:
    errors = []
    bank = {q["id"]: q for q in bank_items}
    audit_items = {item["id"]: item for item in audit_document.get("items", [])}
    locked = {item["id"] for item in locks_document.get("candidates", [])}

    if audit_document.get("status") != "PASS":
        errors.append("candidate answer audit overall status is not PASS")
    if set(bank) != set(audit_items):
        errors.append(f"answer audit coverage mismatch missing={sorted(set(bank)-set(audit_items))} extra={sorted(set(audit_items)-set(bank))}")
    if set(bank) != locked:
        errors.append(f"source lock coverage mismatch missing={sorted(set(bank)-locked)} extra={sorted(locked-set(bank))}")

    for qid, question in bank.items():
        item = audit_items.get(qid)
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

    if not errors:
        print(f"PASS: {len(bank)} candidate answers/explanations reviewed; all remain release_eligible=false")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bank", type=Path, default=DEFAULT_BANK)
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument("--locks", type=Path, default=DEFAULT_LOCKS)
    args = parser.parse_args()

    bank = json.loads(args.bank.read_text(encoding="utf-8"))
    audit_document = json.loads(args.audit.read_text(encoding="utf-8"))
    locks_document = json.loads(args.locks.read_text(encoding="utf-8"))
    errors = audit(bank, audit_document, locks_document)
    if errors:
        print("FAIL: candidate answer/content audit")
        for error in errors:
            print(f"- {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
