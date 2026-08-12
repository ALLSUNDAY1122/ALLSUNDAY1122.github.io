#!/usr/bin/env python3
import argparse
import json
import re
import sys
import tempfile
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

SUBJECTS = {
    "憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法", "一般教養"
}
LEGAL_SUBJECTS = SUBJECTS - {"一般教養"}
ALLOWED_ORIGINS = {"original_from_primary_source", "public_domain_or_law"}
ALLOWED_AUDIT = {"candidate", "source_checked", "answer_checked", "pending_release_audit"}
REQUIRED = {
    "id", "subject", "topic", "question", "choices", "answer_type", "answer",
    "explanation", "memory", "source_title", "source_url", "evidence_checked_date",
    "reference_date", "origin_type", "rights_basis", "audit_status", "release_eligible"
}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def normalize(value: str) -> str:
    value = str(value).lower()
    value = re.sub(r"\s+", "", value)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", value)


def validate_question(q, errors):
    qid = q.get("id", "<no-id>")
    missing = [key for key in REQUIRED if q.get(key) in (None, "", []) and key != "answer"]
    if missing:
        errors.append(f"{qid}: 必須フィールド欠損 {sorted(missing)}")
        return

    if q.get("subject") not in SUBJECTS:
        errors.append(f"{qid}: subject不正 {q.get('subject')}")
    if q.get("origin_type") not in ALLOWED_ORIGINS:
        errors.append(f"{qid}: origin_type不正 {q.get('origin_type')}")
    if q.get("audit_status") not in ALLOWED_AUDIT:
        errors.append(f"{qid}: audit_status不正 {q.get('audit_status')}")
    if q.get("release_eligible") is not False:
        errors.append(f"{qid}: 候補バンクでrelease_eligible=trueは禁止")
    if not str(q.get("source_url", "")).startswith("https://"):
        errors.append(f"{qid}: source_urlはhttps必須")
    if not DATE_RE.match(str(q.get("evidence_checked_date", ""))):
        errors.append(f"{qid}: evidence_checked_date形式不正")
    if q.get("subject") in LEGAL_SUBJECTS and not DATE_RE.match(str(q.get("reference_date", ""))):
        errors.append(f"{qid}: 法律科目はreference_date必須")
    if len(str(q.get("rights_basis", "")).strip()) < 8:
        errors.append(f"{qid}: rights_basisが具体性不足")
    if len(str(q.get("explanation", "")).strip()) < 20:
        errors.append(f"{qid}: explanationが短すぎる")
    if len(str(q.get("memory", "")).strip()) < 6:
        errors.append(f"{qid}: memoryが短すぎる")

    choices = q.get("choices")
    if not isinstance(choices, list) or len(choices) < 2:
        errors.append(f"{qid}: choices不正")
        return

    answer_type = q.get("answer_type")
    answer = q.get("answer")
    if answer_type == "singleChoice":
        if not isinstance(answer, int) or isinstance(answer, bool) or not 0 <= answer < len(choices):
            errors.append(f"{qid}: singleChoice answer不正 {answer}")
    elif answer_type == "multiChoice":
        if not isinstance(answer, list) or len(answer) < 2 or len(set(answer)) != len(answer):
            errors.append(f"{qid}: multiChoice answer不正 {answer}")
        elif any(not isinstance(i, int) or isinstance(i, bool) or not 0 <= i < len(choices) for i in answer):
            errors.append(f"{qid}: multiChoice index範囲外")
    else:
        errors.append(f"{qid}: answer_type不正 {answer_type}")


def validate(data, similarity_threshold=0.90):
    errors = []
    warnings = []
    if not isinstance(data, list) or not data:
        return ["候補問題バンクは1問以上のJSON配列が必要"], warnings

    ids = [q.get("id") for q in data]
    duplicates = [qid for qid, count in Counter(ids).items() if qid and count > 1]
    if duplicates:
        errors.append(f"問題ID重複: {duplicates}")

    for q in data:
        validate_question(q, errors)

    normalized = [(q.get("id", "?"), q.get("topic", ""), normalize(q.get("question", ""))) for q in data]
    for i in range(len(normalized)):
        id_a, topic_a, text_a = normalized[i]
        for j in range(i + 1, len(normalized)):
            id_b, topic_b, text_b = normalized[j]
            if not text_a or not text_b:
                continue
            ratio = SequenceMatcher(None, text_a, text_b).ratio()
            if ratio >= similarity_threshold:
                errors.append(f"高類似候補 {ratio:.2f}: {id_a} <-> {id_b}")
            elif topic_a and topic_a == topic_b and ratio >= 0.72:
                warnings.append(f"同一論点類似 要確認 {ratio:.2f}: {id_a} <-> {id_b}")

    return errors, warnings


def sample_question(qid="YOBI-CAND-001", release=False):
    return {
        "id": qid,
        "subject": "憲法",
        "topic": "構造テスト",
        "question": "候補問題preflightの構造を確認するためのテスト問題はどれか。",
        "choices": ["選択肢A", "選択肢B"],
        "answer_type": "singleChoice",
        "answer": 0,
        "explanation": "これは候補問題preflight validator自体を検証するための構造テスト用説明である。",
        "memory": "候補はRelease不可。",
        "source_title": "テスト一次資料",
        "source_url": "https://example.invalid/primary",
        "evidence_checked_date": "2026-08-13",
        "reference_date": "2026-01-01",
        "origin_type": "original_from_primary_source",
        "rights_basis": "構造テスト専用の自作データで第三者本文を含まない。",
        "audit_status": "candidate",
        "release_eligible": release
    }


def self_test():
    valid_errors, _ = validate([sample_question()])
    if valid_errors:
        print("SELFTEST FAIL: valid fixture rejected", valid_errors)
        return 1

    bad_release, _ = validate([sample_question(release=True)])
    if not any("release_eligible=true" in item for item in bad_release):
        print("SELFTEST FAIL: release gate did not fire")
        return 1

    duplicate, _ = validate([sample_question(), sample_question()])
    if not any("問題ID重複" in item for item in duplicate):
        print("SELFTEST FAIL: duplicate gate did not fire")
        return 1

    print("SELFTEST PASS: candidate schema, release gate, duplicate/similarity checks")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not args.file:
        parser.error("file または --self-test が必要")

    data = json.loads(args.file.read_text(encoding="utf-8"))
    errors, warnings = validate(data)
    print(f"候補問題数: {len(data) if isinstance(data, list) else 0}")
    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print("PASS: 候補問題preflight監査")
    return 0


if __name__ == "__main__":
    sys.exit(main())
