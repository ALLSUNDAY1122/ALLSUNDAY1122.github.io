#!/usr/bin/env bash
# 小学生漢字アプリのビルド前準備:
# data/kanji-1026.json を Resources/ へコピーし、内容を検証する。
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p Resources
cp ../data/kanji-1026.json Resources/kanji-1026.json
test -s Resources/kanji-1026.json

python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path

data = json.loads(Path("Resources/kanji-1026.json").read_text(encoding="utf-8"))
items = data["kanji"]
assert len(items) == 1026, f"FAIL: expected 1026 kanji, got {len(items)}"
assert len({item["kanji"] for item in items}) == 1026, "FAIL: duplicate kanji entries"

counts = Counter(item["grade"] for item in items)
expected = {1: 80, 2: 160, 3: 200, 4: 202, 5: 193, 6: 191}
assert dict(counts) == expected, f"FAIL: grade counts {dict(counts)} != {expected}"

for item in items:
    strokes = item.get("strokes") or []
    assert strokes, f"FAIL: no strokes for {item['kanji']}"
    assert len(strokes) == item["strokeCount"], (
        f"FAIL: stroke count mismatch for {item['kanji']}: "
        f"data {item['strokeCount']} vs paths {len(strokes)}"
    )
    assert item.get("on") or item.get("kun"), f"FAIL: no readings for {item['kanji']}"

print("PASS: 1026 kanji, grade counts 80/160/200/202/193/191, all strokes and readings present")
PY
