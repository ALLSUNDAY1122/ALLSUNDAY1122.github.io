#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"

bank = json.loads(BANK.read_text(encoding="utf-8"))
questions = bank.get("questions", [])
if len(questions) != 47:
    raise SystemExit(f"FAIL: checkpoint requires 47 authored questions, found {len(questions)}")

if any(q.get("auditStatus") != "pass" for q in questions):
    pending = [q.get("intentId") for q in questions if q.get("auditStatus") != "pass"]
    raise SystemExit(f"FAIL: independently unaudited checkpoint questions: {pending}")

by_subject = Counter(q.get("subject") for q in questions)
expected = {
    "基礎助産学": 2,
    "地域母子保健": 20,
    "助産管理": 25,
}
for subject, count in expected.items():
    if by_subject[subject] != count:
        raise SystemExit(f"FAIL: {subject} expected {count}, found {by_subject[subject]}")
if by_subject.get("助産診断・技術学", 0) != 0:
    raise SystemExit("FAIL: clinical diagnosis questions should not be counted in this pre-clinical checkpoint")

community_intents = {q["intentId"] for q in questions if q["subject"] == "地域母子保健"}
management_intents = {q["intentId"] for q in questions if q["subject"] == "助産管理"}
if len(community_intents) != 20:
    raise SystemExit("FAIL: 地域母子保健 must have 20 unique intents")
if len(management_intents) != 25:
    raise SystemExit("FAIL: 助産管理 must have 25 unique intents")

print("PASS: #14 pre-clinical checkpoint")
print("  audited questions: 47 / 330")
print("  地域母子保健: 20 / 20 COMPLETE")
print("  助産管理: 25 / 25 COMPLETE")
print("  基礎助産学: 2 / 100")
print("  助産診断・技術学: 0 / 185")
