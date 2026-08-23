#!/usr/bin/env python3
import json
import re
from difflib import SequenceMatcher
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = ROOT / "data" / "authored-batches"


def normalize(text: str) -> str:
    value = str(text).lower()
    value = re.sub(r"\s+", "", value)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", value)


plan = build_plan()
plan_by_intent = {q["intentId"]: q for q in plan["questions"]}
authored = {}
for path in sorted(BATCH_DIR.glob("*.json")):
    payload = json.loads(path.read_text(encoding="utf-8"))
    for q in payload.get("questions", []):
        authored[q["intentId"]] = {**q, "batch": path.name}

records = []
for intent_id, q in authored.items():
    planned = plan_by_intent[intent_id]
    records.append({
        "id": planned["id"],
        "topicId": planned["topicId"],
        "intentId": intent_id,
        "intentFocus": planned["intentFocus"],
        "prompt": q["prompt"],
        "batch": q["batch"],
        "normalized": normalize(q["prompt"]),
    })
records.sort(key=lambda r: r["id"])

warnings = []
for i in range(len(records)):
    for j in range(i + 1, len(records)):
        a, b = records[i], records[j]
        if a["topicId"] != b["topicId"]:
            continue
        ratio = SequenceMatcher(None, a["normalized"], b["normalized"]).ratio()
        if 0.75 <= ratio < 0.90:
            warnings.append((ratio, a, b))

print(f"SIMILARITY REVIEW PAIRS: {len(warnings)}")
for ratio, a, b in warnings:
    print(f"\n{ratio:.2f} | {a['id']} <-> {b['id']} | topic={a['topicId']}")
    print(f"  A: {a['intentId']} | {a['intentFocus']} | {a['batch']}")
    print(f"     {a['prompt']}")
    print(f"  B: {b['intentId']} | {b['intentFocus']} | {b['batch']}")
    print(f"     {b['prompt']}")
