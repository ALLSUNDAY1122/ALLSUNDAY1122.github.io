#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

LEGAL_SUBJECTS = {"憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法"}
OFFICIAL_SUBJECTS = LEGAL_SUBJECTS | {"一般教養"}


class ReleaseBuildError(ValueError):
    pass


def convert_question(q):
    qid = q.get("id", "<no-id>")
    if q.get("audit_status") != "release_passed" or q.get("release_eligible") is not True:
        raise ReleaseBuildError(f"{qid}: release監査PASS前はnative releaseへ変換できない")
    if q.get("subject") not in OFFICIAL_SUBJECTS:
        raise ReleaseBuildError(f"{qid}: subject不正")
    if not isinstance(q.get("exam_year"), int):
        raise ReleaseBuildError(f"{qid}: exam_year未確定")
    if q.get("subject") in LEGAL_SUBJECTS and not q.get("reference_date"):
        raise ReleaseBuildError(f"{qid}: 法律科目のreference_date未確定")
    if not q.get("rights_basis") or not q.get("source_url") or not q.get("evidence_checked_date"):
        raise ReleaseBuildError(f"{qid}: 根拠・権利監査情報不足")

    answer_type = q.get("answer_type")
    answer = q.get("answer")
    if answer_type == "singleChoice":
        indices = [answer]
    elif answer_type == "multiChoice":
        indices = answer
    else:
        raise ReleaseBuildError(f"{qid}: native未対応answer_type {answer_type}")

    if not isinstance(indices, list) or not indices or any(not isinstance(i, int) for i in indices):
        raise ReleaseBuildError(f"{qid}: answer不正")

    return {
        "id": qid,
        "examYear": q["exam_year"],
        "subject": q["subject"],
        "topic": q["topic"],
        "stem": q["question"],
        "choices": q["choices"],
        "correctIndices": indices,
        "explanation": q["explanation"],
        "memory": q["memory"],
        "sourceTitle": q["source_title"],
        "sourceURL": q["source_url"],
        "evidenceCheckedDate": q["evidence_checked_date"],
        "lawBasisDate": q.get("reference_date") if q["subject"] in LEGAL_SUBJECTS else None,
        "originType": q["origin_type"],
        "releaseEligible": True
    }


def build(bank):
    if not isinstance(bank, list) or not bank:
        raise ReleaseBuildError("release bankは1問以上必要")
    native = [convert_question(q) for q in bank]
    ids = [q["id"] for q in native]
    if len(ids) != len(set(ids)):
        raise ReleaseBuildError("release bankに問題ID重複")
    return native


def fixture(status="release_passed", release=True, subject="憲法", reference_date="2026-01-01"):
    return {
        "id": "YOBI-SELFTEST-001",
        "round": 1,
        "exam_year": 2026,
        "subject": subject,
        "topic": "release builder test",
        "question": "構造テスト問題",
        "choices": ["A", "B"],
        "answer_type": "singleChoice",
        "answer": 0,
        "explanation": "release builderの構造テスト説明。",
        "memory": "構造テスト",
        "source_title": "一次資料",
        "source_url": "https://example.invalid/primary",
        "evidence_checked_date": "2026-08-13",
        "reference_date": reference_date,
        "origin_type": "original_from_primary_source",
        "rights_basis": "自作fixture。第三者本文なし。",
        "audit_status": status,
        "release_eligible": release
    }


def self_test():
    legal = build([fixture()])
    assert legal[0]["releaseEligible"] is True
    assert legal[0]["lawBasisDate"] == "2026-01-01"

    general = build([fixture(subject="一般教養", reference_date=None)])
    assert general[0]["lawBasisDate"] is None

    try:
        build([fixture(status="candidate", release=False)])
    except ReleaseBuildError:
        pass
    else:
        raise AssertionError("candidateがreleaseへ変換された")

    print("SELFTEST PASS: release_passed only / legal date / general-ed policy")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not args.input or not args.output:
        parser.error("input output または --self-test が必要")

    bank = json.loads(args.input.read_text(encoding="utf-8"))
    native = build(bank)
    args.output.write_text(json.dumps(native, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: native release bank {len(native)}問を生成")
    return 0


if __name__ == "__main__":
    sys.exit(main())
