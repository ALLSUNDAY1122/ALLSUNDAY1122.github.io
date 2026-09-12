#!/usr/bin/env python3
"""Fail-closed FP3 product bank schema audit.

This audit protects the learning shell from answer-index drift and accidental
reintroduction of archived-law questions into the normal learning pool.
"""
from __future__ import annotations
import json, pathlib, sys

EXPECTED_TOTAL = 180
EXPECTED_ACTIVE = 178
EXPECTED_ARCHIVED = 2
EXPECTED_DOMAINS = {
    "ライフプランニング", "リスク管理", "金融資産運用",
    "タックスプランニング", "不動産", "相続・事業承継",
}


def fail(msg: str) -> None:
    raise SystemExit(f"FAIL: {msg}")


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "fp3-manabi-sprint/question_bank_180.payload.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    qs = data.get("questions")
    if not isinstance(qs, list) or len(qs) != EXPECTED_TOTAL:
        fail(f"question_count={len(qs) if isinstance(qs, list) else 'invalid'}")
    if data.get("metadata", {}).get("question_count") != EXPECTED_TOTAL:
        fail("metadata.question_count")

    ids = [q.get("id") for q in qs]
    if any(not isinstance(x, str) or not x for x in ids) or len(set(ids)) != len(ids):
        fail("question ids must be non-empty and unique")

    domains = {q.get("domain") for q in qs}
    if domains != EXPECTED_DOMAINS:
        fail(f"domains={sorted(map(str, domains))}")

    active = [q for q in qs if q.get("status") == "active_core"]
    archived = [q for q in qs if q.get("status") == "archived_law_changed"]
    if len(active) != EXPECTED_ACTIVE or len(archived) != EXPECTED_ARCHIVED:
        fail(f"status counts active={len(active)} archived={len(archived)}")
    if len(active) + len(archived) != len(qs):
        fail("unexpected status exists")

    tf = mc = 0
    for q in qs:
        qid = q["id"]
        qtype = q.get("type")
        answer = q.get("answer")
        choices = q.get("choices")
        if qtype == "true_false":
            tf += 1
            if type(answer) is not bool:
                fail(f"{qid}: true_false answer must be bool")
            if choices not in ([], None):
                fail(f"{qid}: true_false choices must be empty")
        elif qtype == "multiple_choice":
            mc += 1
            if not isinstance(choices, list) or len(choices) < 2:
                fail(f"{qid}: multiple_choice choices invalid")
            # Canonical FP3 payload stores MC answers as 1-based choice numbers.
            if type(answer) is not int or not (1 <= answer <= len(choices)):
                fail(f"{qid}: answer must be 1..{len(choices)}, got {answer!r}")
        else:
            fail(f"{qid}: unsupported type={qtype!r}")

        for field in ("question", "explanation", "domain", "topic"):
            if not isinstance(q.get(field), str) or not q[field].strip():
                fail(f"{qid}: missing {field}")

    if tf != 90 or mc != 90:
        fail(f"type counts true_false={tf} multiple_choice={mc}")

    print(json.dumps({
        "status": "PASS",
        "total": len(qs),
        "active_core": len(active),
        "archived_law_changed": len(archived),
        "true_false": tf,
        "multiple_choice": mc,
        "answer_indexing": "multiple_choice=1-based; UI button value=0-based",
        "domains": sorted(domains),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
