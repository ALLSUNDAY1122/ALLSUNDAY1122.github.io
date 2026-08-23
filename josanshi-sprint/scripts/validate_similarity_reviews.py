#!/usr/bin/env python3
import hashlib
import json
import re
from difflib import SequenceMatcher
from pathlib import Path

from build_generation_plan import build_plan

ROOT = Path(__file__).resolve().parents[1]
BATCH_DIR = ROOT / "data" / "authored-batches"
REVIEW_FILE = ROOT / "data" / "similarity-review.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def normalize(text: str) -> str:
    value = str(text).lower()
    value = re.sub(r"\s+", "", value)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", value)


def prompt_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def pair_key(id_a: str, id_b: str) -> tuple[str, str]:
    return tuple(sorted((id_a, id_b)))


plan = build_plan()
plan_by_intent = {q["intentId"]: q for q in plan["questions"]}
authored = {}
for path in sorted(BATCH_DIR.glob("*.json")):
    payload = json.loads(path.read_text(encoding="utf-8"))
    for question in payload.get("questions", []):
        intent_id = question.get("intentId")
        if intent_id in authored:
            fail(f"duplicate authored intentId: {intent_id}")
        authored[intent_id] = question

records = []
for intent_id, question in authored.items():
    planned = plan_by_intent.get(intent_id)
    if planned is None:
        fail(f"unknown intentId: {intent_id}")
    prompt = question.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        fail(f"{intent_id}: prompt missing")
    records.append({
        "id": planned["id"],
        "topicId": planned["topicId"],
        "prompt": prompt,
        "normalized": normalize(prompt),
    })
records.sort(key=lambda r: r["id"])

current_warnings = {}
for i in range(len(records)):
    for j in range(i + 1, len(records)):
        a, b = records[i], records[j]
        if a["topicId"] != b["topicId"]:
            continue
        ratio = SequenceMatcher(None, a["normalized"], b["normalized"]).ratio()
        if 0.75 <= ratio < 0.90:
            current_warnings[pair_key(a["id"], b["id"])] = {
                "ratio": ratio,
                "prompts": {a["id"]: a["prompt"], b["id"]: b["prompt"]},
            }

if not REVIEW_FILE.is_file():
    fail("similarity-review.json missing")
review_doc = json.loads(REVIEW_FILE.read_text(encoding="utf-8"))
if review_doc.get("qualification") != "助産師国家試験":
    fail("similarity review qualification mismatch")

reviews = {}
for entry in review_doc.get("reviews", []):
    id_a = entry.get("idA")
    id_b = entry.get("idB")
    if not id_a or not id_b or id_a == id_b:
        fail("similarity review has invalid pair IDs")
    key = pair_key(id_a, id_b)
    if key in reviews:
        fail(f"duplicate similarity review pair: {key}")
    if entry.get("decision") != "distinct":
        fail(f"{key}: only explicit 'distinct' decision can clear a warning")
    if not str(entry.get("reason", "")).strip():
        fail(f"{key}: semantic review reason missing")
    reviews[key] = entry

missing = sorted(set(current_warnings) - set(reviews))
if missing:
    fail(f"unreviewed same-topic similarity warnings: {missing}")

stale = sorted(set(reviews) - set(current_warnings))
if stale:
    fail(f"stale similarity reviews no longer matching current warning set: {stale}")

for key, warning in current_warnings.items():
    entry = reviews[key]
    for suffix in ("A", "B"):
        qid = entry[f"id{suffix}"]
        prompt = warning["prompts"].get(qid)
        if prompt is None:
            fail(f"{key}: review ID {qid} is not part of current warning pair")
        expected = prompt_hash(prompt)
        actual = entry.get(f"promptHash{suffix}")
        if actual != expected:
            fail(f"{key}: prompt changed after semantic review for {qid}; re-review required")

print(f"PASS: {len(current_warnings)} same-topic similarity warnings independently reviewed")
for key, warning in sorted(current_warnings.items()):
    print(f"  {warning['ratio']:.2f}: {key[0]} <-> {key[1]} — distinct semantic intent confirmed")
