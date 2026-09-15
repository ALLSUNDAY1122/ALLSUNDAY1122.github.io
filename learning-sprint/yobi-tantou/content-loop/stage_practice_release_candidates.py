#!/usr/bin/env python3
"""Create a non-release staging bank for independently authored practice items.

This stage is deliberately not a release promotion. It proves that candidate,
source-lock and answer-audit evidence refer to exactly the same items, assigns
the production usage class `practice`, removes any official exam-year
association, and keeps every item release_eligible=false.
"""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_CANDIDATES = ROOT / "questions.candidates.v1.json"
DEFAULT_LOCKS = ROOT / "candidate-source-locks.v1.json"
DEFAULT_ANSWERS = ROOT / "candidate-answer-audit.v1.json"
DEFAULT_OUTPUT = ROOT / "practice-release-staging.v1.json"

ALLOWED_ORIGINS = {"original_from_primary_source", "public_domain_or_law"}
ALLOWED_INPUT_STATUS = {"candidate", "source_checked", "answer_checked", "pending_release_audit"}


class StagingError(ValueError):
    pass


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def item_ids(items, label: str) -> list[str]:
    if not isinstance(items, list) or not items:
        raise StagingError(f"{label}: 1件以上の配列が必要")
    ids = [item.get("id") for item in items]
    if any(not value for value in ids):
        raise StagingError(f"{label}: id欠損")
    if len(ids) != len(set(ids)):
        raise StagingError(f"{label}: id重複")
    return ids


def build(candidates, locks_document, answer_document):
    candidate_ids = item_ids(candidates, "candidates")

    locks = locks_document.get("candidates")
    lock_ids = item_ids(locks, "source locks")

    if answer_document.get("status") != "PASS":
        raise StagingError("answer audit全体がPASSではない")
    answers = answer_document.get("items")
    answer_ids = item_ids(answers, "answer audit")

    candidate_set = set(candidate_ids)
    if set(lock_ids) != candidate_set:
        raise StagingError("candidateとsource lockのID集合が一致しない")
    if set(answer_ids) != candidate_set:
        raise StagingError("candidateとanswer auditのID集合が一致しない")

    answer_by_id = {item["id"]: item for item in answers}
    staged = []
    for source in candidates:
        qid = source["id"]
        if source.get("origin_type") not in ALLOWED_ORIGINS:
            raise StagingError(f"{qid}: practice staging非対応origin_type")
        if source.get("audit_status") not in ALLOWED_INPUT_STATUS:
            raise StagingError(f"{qid}: input audit_status不正")
        if source.get("release_eligible") is not False:
            raise StagingError(f"{qid}: staging前候補がrelease済み")
        if source.get("exam_year") is not None:
            raise StagingError(f"{qid}: 独自practice候補にexam_yearを付与できない")
        if source.get("content_use") not in (None, "practice"):
            raise StagingError(f"{qid}: content_useはpractice以外にできない")

        answer = answer_by_id[qid]
        if answer.get("verdict") != "PASS" or answer.get("risk") != "low":
            raise StagingError(f"{qid}: answer auditがlow-risk PASSではない")
        if answer.get("expectedAnswer") != source.get("answer"):
            raise StagingError(f"{qid}: answer auditと候補正答が不一致")

        item = dict(source)
        item.pop("exam_year", None)
        item["content_use"] = "practice"
        item["audit_status"] = "pending_release_audit"
        item["release_eligible"] = False
        item["staging_evidence"] = {
            "source_lock_version": locks_document.get("version"),
            "source_lock_as_of": locks_document.get("asOf"),
            "answer_audit_version": answer_document.get("version"),
            "answer_audit_checked_at": answer_document.get("checkedAt"),
            "answer_audit_verdict": answer.get("verdict"),
            "answer_audit_risk": answer.get("risk"),
        }
        staged.append(item)

    if len(staged) != len(candidates):
        raise StagingError("staging件数不整合")
    if any(item.get("release_eligible") is not False for item in staged):
        raise StagingError("stagingでrelease_eligible=trueは禁止")
    if any(item.get("content_use") != "practice" for item in staged):
        raise StagingError("staging用途は全件practice必須")
    if any(item.get("exam_year") is not None for item in staged):
        raise StagingError("stagingへofficial exam yearを持ち込めない")
    return staged


def fixture():
    candidate = {
        "id": "YOBI-STAGE-001",
        "subject": "憲法",
        "topic": "構造テスト",
        "question": "構造テスト問題",
        "choices": ["A", "B"],
        "answer_type": "singleChoice",
        "answer": 0,
        "explanation": "十分な長さの構造テスト用説明である。",
        "memory": "構造テスト要点",
        "source_title": "日本国憲法",
        "source_url": "https://example.invalid/primary",
        "evidence_checked_date": "2026-08-13",
        "reference_date": "2026-01-01",
        "origin_type": "original_from_primary_source",
        "rights_basis": "一次資料を根拠に独自作成した構造テスト。",
        "audit_status": "candidate",
        "release_eligible": False,
    }
    locks = {
        "version": "1.0",
        "asOf": "2026-01-01",
        "candidates": [{"id": "YOBI-STAGE-001", "law_id": "x", "marker": "x"}],
    }
    answers = {
        "version": "1.0",
        "checkedAt": "2026-08-13",
        "status": "PASS",
        "items": [{"id": "YOBI-STAGE-001", "expectedAnswer": 0, "verdict": "PASS", "risk": "low"}],
    }
    return candidate, locks, answers


def self_test():
    candidate, locks, answers = fixture()
    staged = build([candidate], locks, answers)
    assert staged[0]["content_use"] == "practice"
    assert staged[0]["audit_status"] == "pending_release_audit"
    assert staged[0]["release_eligible"] is False
    assert "exam_year" not in staged[0]

    bad = dict(candidate, exam_year=2026)
    try:
        build([bad], locks, answers)
    except StagingError:
        pass
    else:
        raise AssertionError("fake official exam year was not rejected")

    bad_answers = json.loads(json.dumps(answers))
    bad_answers["items"][0]["expectedAnswer"] = 1
    try:
        build([candidate], locks, bad_answers)
    except StagingError:
        pass
    else:
        raise AssertionError("answer mismatch was not rejected")

    print("SELFTEST PASS: practice staging is non-release, no official year, evidence-aligned")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--locks", type=Path, default=DEFAULT_LOCKS)
    parser.add_argument("--answers", type=Path, default=DEFAULT_ANSWERS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    staged = build(load(args.candidates), load(args.locks), load(args.answers))
    args.output.write_text(json.dumps(staged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: staged {len(staged)} independently-authored practice candidates; releaseEligible=0")
    print(f"WROTE {args.output}")


if __name__ == "__main__":
    main()
