#!/usr/bin/env python3
import json
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = ROOT / "data" / "authored-batches"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


plan = build_plan()
plan_by_intent = {question["intentId"]: question for question in plan["questions"]}
if len(plan_by_intent) != 330:
    fail(f"generation plan must contain 330 unique intents, found {len(plan_by_intent)}")

authored_locations: dict[str, str] = {}
for path in sorted(BATCH_DIR.glob("*.json")):
    payload = json.loads(path.read_text(encoding="utf-8"))
    for question in payload.get("questions", []):
        intent_id = question.get("intentId")
        if not intent_id:
            fail(f"{path.name}: question missing intentId")
        if intent_id not in plan_by_intent:
            fail(f"{path.name}: unknown intentId {intent_id}")
        if intent_id in authored_locations:
            fail(
                f"duplicate authored intentId {intent_id}: "
                f"{authored_locations[intent_id]} and {path.name}"
            )
        authored_locations[intent_id] = path.name

remaining = [
    question for question in plan["questions"]
    if question["intentId"] not in authored_locations
]

print(f"AUTHORED: {len(authored_locations)}/330")
print(f"REMAINING: {len(remaining)}/330")
if not remaining:
    print("FULL: all 330 planned semantic intents are authored exactly once")
else:
    print("REMAINING INTENTS (canonical generation-plan order):")
    for question in remaining:
        print(
            f"  {question['id']} | {question['intentId']} | {question['topicId']} | "
            f"{question['intentFocus']} | R{question['mockRound']} {question['session']} "
            f"Q{question['slotNumber']:02d} | {question['questionType']}"
        )
