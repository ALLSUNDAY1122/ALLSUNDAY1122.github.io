#!/bin/bash
# ビルド前準備: シリーズ版アイコンのデコード、図表JSONの配置、データ検証。
set -euo pipefail
cd "$(dirname "$0")"
python3 - << 'PYEOF'
import base64, json, pathlib, shutil

icon_b64 = pathlib.Path("AppIcon1024.png.b64").read_text().strip()
icon_path = pathlib.Path("Assets.xcassets/AppIcon.appiconset/AppIcon1024.png")
icon_path.write_bytes(base64.b64decode(icon_b64))
print("icon decoded:", icon_path.stat().st_size, "bytes")

for name in ("figures-1.json", "figures-2.json"):
    shutil.copyfile(f"../data/{name}", f"GeneratedResources/{name}")

bundle = json.load(open("GeneratedResources/questions.generated.json"))
assert bundle["totalQuestions"] == 546, bundle["totalQuestions"]
assert len(bundle["questions"]) == 546
assert len(bundle["freeSampleQuestionIds"]) == 30
sessions = {}
for q in bundle["questions"]:
    sessions[q["sourceExam"]] = sessions.get(q["sourceExam"], 0) + 1
assert sessions == {108: 108, 109: 109, 110: 109, 111: 110, 112: 110}, sessions
figs = {}
for name in ("figures-1.json", "figures-2.json"):
    figs.update(json.load(open(f"GeneratedResources/{name}")))
assert len(figs) == 36, len(figs)
print("prepare-ios: OK (546 questions, 30 free, 36 figures)")
PYEOF
