#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"
STAGE = ROOT / "data" / "content-stage.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


bank = json.loads(BANK.read_text(encoding="utf-8"))
stage = json.loads(STAGE.read_text(encoding="utf-8"))
questions = bank.get("questions", [])

minimum = int(stage.get("minimumAuthoredQuestions", 0))
target = int(stage.get("targetQuestions", 0))
if len(questions) < minimum:
    fail(f"stage requires at least {minimum} authored questions, found {len(questions)}")
if target and len(questions) > target:
    fail(f"authored questions exceed target {target}: {len(questions)}")

intent_ids = [q.get("intentId") for q in questions]
if None in intent_ids or len(intent_ids) != len(set(intent_ids)):
    fail("missing or duplicate intentId in current bank")

if stage.get("requireAllAuthoredIndependentlyAudited"):
    pending = [q.get("intentId") for q in questions if q.get("auditStatus") != "pass"]
    if pending:
        preview = pending[:20]
        suffix = "..." if len(pending) > len(preview) else ""
        fail(f"independently unaudited authored questions: {preview}{suffix}")

by_subject = Counter(q.get("subject") for q in questions)
minimums = stage.get("subjectMinimums", {})
targets = stage.get("subjectTargets", {})
for subject, minimum_count in minimums.items():
    actual = by_subject.get(subject, 0)
    if actual < int(minimum_count):
        fail(f"{subject}: expected at least {minimum_count}, found {actual}")
for subject, target_count in targets.items():
    actual = by_subject.get(subject, 0)
    if actual > int(target_count):
        fail(f"{subject}: exceeds designed target {target_count}, found {actual}")

print(f"PASS: #14 monotonic content stage '{stage.get('stage')}'")
print(f"  independently audited authored questions: {len(questions)} / {target}")
for subject in ["基礎助産学", "助産診断・技術学", "地域母子保健", "助産管理"]:
    print(f"  {subject}: {by_subject.get(subject, 0)} / {targets.get(subject, '?')}")
