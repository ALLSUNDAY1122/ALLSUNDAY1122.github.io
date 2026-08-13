#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"

bank = json.loads(BANK.read_text(encoding="utf-8"))
questions = bank.get("questions", [])
if len(questions) != 70:
    raise SystemExit(f"FAIL: checkpoint requires 70 authored questions, found {len(questions)}")

pending = [q.get("intentId") for q in questions if q.get("auditStatus") != "pass"]
if pending:
    raise SystemExit(f"FAIL: independently unaudited questions: {pending}")

by_subject = Counter(q.get("subject") for q in questions)
expected = {
    "基礎助産学": 25,
    "地域母子保健": 20,
    "助産管理": 25,
    "助産診断・技術学": 0,
}
for subject, expected_count in expected.items():
    actual = by_subject.get(subject, 0)
    if actual != expected_count:
        raise SystemExit(f"FAIL: {subject} expected {expected_count}, found {actual}")

intent_ids = [q.get("intentId") for q in questions]
if len(intent_ids) != len(set(intent_ids)):
    raise SystemExit("FAIL: duplicate intentId in 70-question checkpoint")

print("PASS: #14 audited 70-question checkpoint")
print("  total: 70 / 330")
print("  基礎助産学: 25 / 100")
print("  地域母子保健: 20 / 20 COMPLETE")
print("  助産管理: 25 / 25 COMPLETE")
print("  助産診断・技術学: 0 / 185")
print("  independent audit status: 70 / 70 PASS")
