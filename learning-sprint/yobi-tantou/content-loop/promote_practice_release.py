#!/usr/bin/env python3
"""Promote practice staging items only after all release-quality gates PASS.

The promotion is intentionally separate from staging. It never accepts official
mock content, never creates an exam-year label, and refuses partial promotion:
all staged IDs must have a matching PASS result in the quality audit.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_STAGING = ROOT / "practice-release-staging.v1.json"
DEFAULT_QUALITY = ROOT / "practice-release-quality-audit.v1.json"
DEFAULT_OUTPUT = ROOT / "questions.practice.release.v1.json"


class PromotionError(ValueError):
    pass


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def promote(staging: list[dict], quality: dict) -> list[dict]:
    if not isinstance(staging, list) or not staging:
        raise PromotionError("staging bank must be non-empty")
    if quality.get("overallVerdict") != "PASS":
        raise PromotionError("quality audit must be PASS")
    summary = quality.get("summary") or {}
    if summary.get("total") != len(staging) or summary.get("pass") != len(staging) or summary.get("hold") != 0:
        raise PromotionError("quality audit summary does not authorize full promotion")

    staged_ids = [item.get("id") for item in staging]
    if any(not qid for qid in staged_ids) or len(staged_ids) != len(set(staged_ids)):
        raise PromotionError("staging IDs missing or duplicated")

    quality_items = quality.get("items") or []
    quality_by_id = {item.get("id"): item for item in quality_items if item.get("id")}
    if set(quality_by_id) != set(staged_ids):
        raise PromotionError("staging and quality-audit ID sets differ")

    promoted = []
    for source in staging:
        qid = source["id"]
        audit = quality_by_id[qid]
        if audit.get("verdict") != "PASS" or audit.get("failures"):
            raise PromotionError(f"{qid}: quality audit is not clean PASS")
        if source.get("content_use") != "practice":
            raise PromotionError(f"{qid}: only practice content can be promoted here")
        if source.get("exam_year") is not None:
            raise PromotionError(f"{qid}: practice content cannot carry official exam year")
        if source.get("audit_status") != "pending_release_audit" or source.get("release_eligible") is not False:
            raise PromotionError(f"{qid}: invalid staging state")

        evidence = source.get("staging_evidence") or {}
        if evidence.get("answer_audit_verdict") != "PASS" or evidence.get("answer_audit_risk") != "low":
            raise PromotionError(f"{qid}: upstream answer evidence not low-risk PASS")

        item = dict(source)
        item["audit_status"] = "release_passed"
        item["release_eligible"] = True
        item["release_evidence"] = {
            "quality_audit_schema_version": quality.get("schemaVersion"),
            "quality_checked_at": quality.get("checkedAt"),
            "quality_verdict": audit.get("verdict"),
            "source_lock_version": evidence.get("source_lock_version"),
            "source_lock_as_of": evidence.get("source_lock_as_of"),
            "answer_audit_version": evidence.get("answer_audit_version"),
            "answer_audit_checked_at": evidence.get("answer_audit_checked_at"),
        }
        promoted.append(item)

    if any(item.get("release_eligible") is not True for item in promoted):
        raise PromotionError("promotion invariant violated")
    if any(item.get("content_use") != "practice" or item.get("exam_year") is not None for item in promoted):
        raise PromotionError("practice/official-mock isolation invariant violated")
    return promoted


def fixture():
    staging = [{
        "id": "YOBI-PROMOTE-001",
        "content_use": "practice",
        "audit_status": "pending_release_audit",
        "release_eligible": False,
        "staging_evidence": {
            "source_lock_version": "1.0",
            "source_lock_as_of": "2026-01-01",
            "answer_audit_version": "1.0",
            "answer_audit_checked_at": "2026-08-13",
            "answer_audit_verdict": "PASS",
            "answer_audit_risk": "low",
        },
    }]
    quality = {
        "schemaVersion": 1,
        "checkedAt": "2026-08-13",
        "overallVerdict": "PASS",
        "summary": {"total": 1, "pass": 1, "hold": 0},
        "items": [{"id": "YOBI-PROMOTE-001", "verdict": "PASS", "failures": []}],
    }
    return staging, quality


def self_test() -> None:
    staging, quality = fixture()
    result = promote(staging, quality)
    assert result[0]["release_eligible"] is True
    assert result[0]["audit_status"] == "release_passed"
    assert result[0]["content_use"] == "practice"
    assert result[0].get("exam_year") is None

    blocked = json.loads(json.dumps(quality))
    blocked["overallVerdict"] = "HOLD"
    try:
        promote(staging, blocked)
    except PromotionError:
        pass
    else:
        raise AssertionError("HOLD audit was promoted")

    official = json.loads(json.dumps(staging))
    official[0]["content_use"] = "official_mock"
    official[0]["exam_year"] = 2024
    try:
        promote(official, quality)
    except PromotionError:
        pass
    else:
        raise AssertionError("official mock content was promoted as practice")

    print("SELFTEST PASS: full quality PASS required; official mock isolation enforced")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--quality", type=Path, default=DEFAULT_QUALITY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    promoted = promote(load(args.staging), load(args.quality))
    args.output.write_text(json.dumps(promoted, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: promoted {len(promoted)} independently-authored practice items to release_passed")
    print(f"WROTE {args.output}")


if __name__ == "__main__":
    main()
