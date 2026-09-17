#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


class StageError(ValueError):
    pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bank", type=Path, required=True)
    parser.add_argument("--answer-audit", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    items = json.loads(args.bank.read_text(encoding="utf-8"))
    audit = json.loads(args.answer_audit.read_text(encoding="utf-8"))
    if audit.get("status") != "PASS":
        raise StageError("answer audit must be PASS")
    by_id = {item.get("id"): item for item in audit.get("items", [])}
    ids = [item.get("id") for item in items]
    if set(ids) != set(by_id):
        raise StageError("candidate and answer-audit ID sets differ")

    staged = []
    for source in items:
        qid = source["id"]
        answer = by_id[qid]
        if answer.get("verdict") != "PASS" or answer.get("risk") != "low":
            raise StageError(f"{qid}: deterministic audit is not low-risk PASS")
        if answer.get("expectedAnswer") != source.get("answer"):
            raise StageError(f"{qid}: answer index mismatch")
        if source.get("origin_type") != "self_authored_original":
            raise StageError(f"{qid}: only self-authored general items are accepted")
        if source.get("subject") != "一般教養" or source.get("content_use") != "practice":
            raise StageError(f"{qid}: invalid general practice assignment")
        if source.get("exam_year") is not None:
            raise StageError(f"{qid}: original general item cannot carry official exam year")
        if source.get("release_eligible") is not False:
            raise StageError(f"{qid}: candidate must remain non-release before staging")

        item = dict(source)
        item["audit_status"] = "pending_release_audit"
        item["release_eligible"] = False
        item["staging_evidence"] = {
            "source_lock_version": "self-authored-deterministic-v1",
            "source_lock_as_of": source.get("reference_date"),
            "answer_audit_version": audit.get("schemaVersion"),
            "answer_audit_checked_at": audit.get("checkedAt"),
            "answer_audit_verdict": answer.get("verdict"),
            "answer_audit_risk": answer.get("risk"),
            "verification_kind": answer.get("verificationKind"),
        }
        staged.append(item)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(staged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: staged {len(staged)} self-authored deterministic general items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
