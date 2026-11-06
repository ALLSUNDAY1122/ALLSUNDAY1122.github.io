#!/usr/bin/env python3
import argparse
import difflib
import json
import re
from pathlib import Path

CATEGORIES = {"quantitative_logic", "natural_science_reasoning", "social_data_reasoning", "language_reading"}


def norm(text: str) -> str:
    return re.sub(r"[\s、。・『』「」（）()\[\]!?！？:：;；]+", "", text or "")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bank", type=Path)
    args = ap.parse_args()
    data = json.loads(args.bank.read_text(encoding="utf-8"))
    if not isinstance(data, list) or not data:
        raise SystemExit("FAIL: general candidate bank must be a non-empty JSON array")

    failures = []
    ids = []
    for q in data:
        qid = q.get("id")
        ids.append(qid)
        if not isinstance(qid, str) or not qid:
            failures.append("missing id")
            continue
        if q.get("practice_mock_id") not in {"practice-mock-1", "practice-mock-2", "practice-mock-3"}:
            failures.append(f"{qid}: invalid practice_mock_id")
        if q.get("subject") != "一般教養":
            failures.append(f"{qid}: subject must be 一般教養")
        if q.get("general_category") not in CATEGORIES:
            failures.append(f"{qid}: invalid general_category")
        if q.get("origin_type") != "self_authored_original":
            failures.append(f"{qid}: origin_type must be self_authored_original")
        if q.get("content_use") != "practice" or q.get("exam_year") is not None:
            failures.append(f"{qid}: must be practice with exam_year=null")
        if q.get("audit_status") != "candidate" or q.get("release_eligible") is not False:
            failures.append(f"{qid}: candidate must remain non-release")
        choices = q.get("choices")
        answer = q.get("answer")
        if not isinstance(choices, list) or len(choices) != 4 or any(not isinstance(c, str) or not c.strip() for c in choices):
            failures.append(f"{qid}: exactly four non-empty choices required")
        if not isinstance(answer, int) or not 0 <= answer < 4:
            failures.append(f"{qid}: answer must be index 0..3")
        for field, minimum in (("question", 18), ("explanation", 60), ("memory", 8), ("rights_basis", 25)):
            value = q.get(field)
            if not isinstance(value, str) or len(norm(value)) < minimum:
                failures.append(f"{qid}: {field} too shallow")
        verification = q.get("verification")
        if not isinstance(verification, dict) or not verification.get("kind"):
            failures.append(f"{qid}: verification required")
        if q.get("source_title") != "Self-authored deterministic fixture":
            failures.append(f"{qid}: source_title must identify self-authored fixture")
        if q.get("source_url") != "internal://self-authored-general-education":
            failures.append(f"{qid}: source_url must use internal self-authored source")

    if len(ids) != len(set(ids)):
        failures.append("duplicate IDs within general candidate bank")

    for i, a in enumerate(data):
        for b in data[i + 1:]:
            ratio = difflib.SequenceMatcher(None, norm(a.get("question", "")), norm(b.get("question", ""))).ratio()
            if ratio >= 0.84:
                failures.append(f"near duplicate {ratio:.3f}: {a.get('id')} <-> {b.get('id')}")

    if failures:
        print("FAIL: general candidate validation")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"PASS: general candidate validation ({len(data)} items)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
