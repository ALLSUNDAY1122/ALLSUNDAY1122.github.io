#!/usr/bin/env bash
# 保健師アプリのビルド前準備:
# アプリアイコン（Base64）を復元し、問題データと図表データを Resources/ へ
# コピーして内容を検証する。
set -euo pipefail
cd "$(dirname "$0")"

# アイコン: リポジトリには Base64 テキストで保管し、ここで PNG に戻す。
python3 - <<'PY'
import base64
from pathlib import Path
src = Path("AppIcon1024.png.b64")
dst = Path("Assets.xcassets/AppIcon.appiconset/AppIcon1024.png")
data = base64.b64decode(src.read_text(encoding="utf-8"))
assert data[:8] == b"\x89PNG\r\n\x1a\n", "FAIL: icon is not a PNG"
dst.write_bytes(data)
print(f"PASS: app icon restored ({len(data)} bytes)")
PY

mkdir -p Resources
cp ../data/questions-546.json Resources/questions-546.json
cp ../data/figures-1.json Resources/figures-1.json
cp ../data/figures-2.json Resources/figures-2.json
test -s Resources/questions-546.json
test -s Resources/figures-1.json
test -s Resources/figures-2.json

python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path

questions = json.loads(Path("Resources/questions-546.json").read_text(encoding="utf-8"))
assert len(questions) == 546, f"FAIL: expected 546 questions, got {len(questions)}"
assert len({q["id"] for q in questions}) == 546, "FAIL: duplicate question ids"

counts = Counter(q["session"] for q in questions)
expected = {108: 108, 109: 109, 110: 109, 111: 110, 112: 110}
assert dict(counts) == expected, f"FAIL: session counts {dict(counts)} != {expected}"

types = Counter(q["type"] for q in questions)
assert types["numeric"] == 8, f"FAIL: numeric count {types['numeric']} != 8"
assert all(q["explanation"].strip() for q in questions), "FAIL: empty explanation found"

figures = {}
for name in ("figures-1.json", "figures-2.json"):
    figures.update(json.loads(Path("Resources", name).read_text(encoding="utf-8")))
figure_ids = {q["id"] for q in questions if q["figure"]}
assert len(figure_ids) == 36, f"FAIL: figure questions {len(figure_ids)} != 36"
assert set(figures.keys()) == figure_ids, "FAIL: figures.json keys do not match figure questions"

free = [q for q in questions if q["session"] == 112 and q["number"] <= 15]
assert len(free) == 30, f"FAIL: free questions {len(free)} != 30"

print("PASS: 546 questions (108:108 109:109 110:109 111:110 112:110), numeric 8, figures 36, free 30")
PY
