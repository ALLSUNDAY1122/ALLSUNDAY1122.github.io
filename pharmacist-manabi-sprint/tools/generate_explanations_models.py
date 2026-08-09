#!/usr/bin/env python3
"""Generate per-question learning explanations with GitHub Models.

The script is resumable. It never overwrites manual review files and only processes
questions from the text-only review queue. Generated content remains blocked from
release until the independent audit workflow marks it PASS.
"""
from __future__ import annotations

import csv
import glob
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "content" / "review"
REVIEWED = ROOT / "content" / "reviewed"
AUTO = REVIEWED / "auto"
LOG = ROOT / "content" / "model-loop"
AUTO.mkdir(parents=True, exist_ok=True)
LOG.mkdir(parents=True, exist_ok=True)

TOKEN = os.environ.get("GITHUB_TOKEN", "")
MODEL = os.environ.get("EXPLANATION_MODEL", "openai/gpt-4.1")
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "20"))
MAX_BATCHES = int(os.environ.get("MAX_BATCHES", "999"))
API = "https://models.github.ai/inference/chat/completions"


def load_existing_ids():
    ids = set()
    for path in glob.glob(str(REVIEWED / "**" / "*.json"), recursive=True):
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
        except Exception:
            continue
        items = data if isinstance(data, list) else data.get("items", []) if isinstance(data, dict) else []
        for item in items:
            if isinstance(item, dict) and item.get("id"):
                ids.add(item["id"])
    return ids


def load_text_queue():
    rows = []
    for exam in (111, 110, 109):
        path = REVIEW / f"text-{exam}.tsv"
        if not path.exists():
            continue
        with path.open(encoding="utf-8", newline="") as f:
            rows.extend(csv.DictReader(f, delimiter="\t"))
    return rows


def labels_from_row(row):
    choices = json.loads(row["choices_json"])
    answer = json.loads(row["answer_json"])
    accepted = json.loads(row["accepted_answers_json"])
    def n(i): return int(i) + 1
    if row["scoring_status"] == "excluded":
        correct = "公式解なし（通常採点から除外）"
    elif row["scoring_status"] == "multiple_accepted":
        correct = " / ".join("・".join(str(n(i)) for i in combo) for combo in accepted)
    elif isinstance(answer, list):
        correct = "・".join(str(n(i)) for i in answer)
    else:
        correct = str(n(answer))
    return choices, correct


def make_prompt(batch):
    payload = []
    for row in batch:
        choices, correct = labels_from_row(row)
        payload.append({
            "id": row["id"],
            "exam": int(row["sourceExam"]),
            "questionNo": int(row["questionNo"]),
            "section": row["subject"],
            "domain": row["domain"],
            "question": row["question"],
            "choices": choices,
            "officialCorrectChoiceNumbers": correct,
            "correctionStatus": json.loads(row["correctionStatus_json"]),
            "effectiveDate": row["effective_date"],
        })
    return (
        "あなたは薬剤師国家試験の問題監査者です。以下は厚生労働省公式問題から抽出し、公式正答を別監査済みの問題です。"
        "各問について、公式正答を変更せず、受験学習用の短い『ここだけ覚える』と、正答根拠が分かる簡潔な解説を日本語で作成してください。"
        "誤答選択肢を網羅的に解説する必要はありませんが、正解理由は具体的にしてください。臨床判断の個別助言ではなく試験学習として記述します。"
        "根拠が設問だけから特定できない場合は推測せず reviewRequired=true とし、reason に不足点を書いてください。"
        "公式正答と矛盾する説明、架空の法令名・数値・薬効は作らないでください。"
        "出力はJSONオブジェクトのみで、形式は {\"items\":[{\"id\":...,\"memoryPoint\":...,\"explanation\":...,\"reviewRequired\":false,\"reason\":\"\"}]}。"
        "入力IDを全件1回ずつ返し、順序を維持してください。\nINPUT:\n" + json.dumps(payload, ensure_ascii=False)
    )


def call_model(prompt):
    body = {
        "model": MODEL,
        "temperature": 0.1,
        "max_tokens": 8000,
        "messages": [
            {"role": "system", "content": "Be conservative, factual, and output valid JSON only."},
            {"role": "user", "content": prompt},
        ],
    }
    req = urllib.request.Request(
        API,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
        },
        method="POST",
    )
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                result = json.loads(r.read().decode("utf-8"))
            content = result["choices"][0]["message"]["content"].strip()
            content = re.sub(r"^```(?:json)?\s*|\s*```$", "", content, flags=re.S)
            return json.loads(content), result.get("usage", {})
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", errors="replace")
            last = RuntimeError(f"HTTP {e.code}: {msg[:1000]}")
            if e.code not in (429, 500, 502, 503, 504):
                raise last
        except Exception as e:
            last = e
        time.sleep(min(60, 2 ** attempt * 3))
    raise last or RuntimeError("model call failed")


def validate_response(batch, obj):
    items = obj.get("items") if isinstance(obj, dict) else None
    if not isinstance(items, list):
        raise ValueError("response items missing")
    expected = [r["id"] for r in batch]
    got = [x.get("id") for x in items if isinstance(x, dict)]
    if got != expected:
        raise ValueError(f"ID mismatch expected={expected} got={got}")
    for item in items:
        if not isinstance(item.get("memoryPoint"), str) or len(item["memoryPoint"].strip()) < 8:
            raise ValueError(f"{item.get('id')}: memoryPoint too short")
        if not isinstance(item.get("explanation"), str) or len(item["explanation"].strip()) < 20:
            raise ValueError(f"{item.get('id')}: explanation too short")
        item["generatorModel"] = MODEL
        item["generationStatus"] = "pending_independent_audit"
    return items


def main():
    if not TOKEN:
        raise SystemExit("GITHUB_TOKEN missing")
    existing = load_existing_ids()
    queue = [r for r in load_text_queue() if r["id"] not in existing]
    print(f"existing={len(existing)} remaining_text={len(queue)} batch={BATCH_SIZE}")
    usage_total = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
    processed = []
    failed = []
    batches = 0
    for pos in range(0, len(queue), BATCH_SIZE):
        if batches >= MAX_BATCHES:
            break
        batch = queue[pos:pos+BATCH_SIZE]
        if not batch:
            break
        batch_key = f"{batch[0]['id']}-{batch[-1]['id']}"
        try:
            obj, usage = call_model(make_prompt(batch))
            items = validate_response(batch, obj)
            out = AUTO / f"explanations-{batch_key}.json"
            out.write_text(json.dumps(items, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
            processed.extend(x["id"] for x in items)
            for k in usage_total:
                usage_total[k] += int(usage.get(k, 0) or 0)
            print(f"OK {batch_key}: {len(items)}")
        except Exception as e:
            failed.append({"batch": batch_key, "ids": [r["id"] for r in batch], "error": repr(e)})
            print(f"FAIL {batch_key}: {e}")
        batches += 1
        time.sleep(1)
    report = {
        "model": MODEL,
        "existingBefore": len(existing),
        "remainingBefore": len(queue),
        "processed": len(processed),
        "processedIds": processed,
        "failed": failed,
        "usage": usage_total,
        "complete": not failed and len(processed) == len(queue),
    }
    (LOG/"generation-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    if failed:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
