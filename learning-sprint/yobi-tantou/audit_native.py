#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IOS = ROOT / "ios"
errors = []

swift = "\n".join(p.read_text(encoding="utf-8") for p in IOS.glob("*.swift"))
views = (IOS / "Views.swift").read_text(encoding="utf-8")
project = (IOS / "project.yml").read_text(encoding="utf-8")
questions = json.loads((IOS / "Resources" / "questions.preview.json").read_text(encoding="utf-8"))
privacy = (IOS / "PrivacyInfo.xcprivacy").read_text(encoding="utf-8")

for forbidden in ("import WebKit", "WKWebView", "SFSafariViewController"):
    if forbidden in swift:
        errors.append(f"native-only violation: {forbidden}")

required_ui = [
    "ホーム", "模試", "記録", "設定", "今日の学習", "今日のスプリント",
    "苦手をつぶす", "分野から解く", "ここだけ覚える", "わからない記録",
    "5週間", "学習データを書き出す", "学習データを読み込む"
]
for text in required_ui:
    if text not in views:
        errors.append(f"missing Golden Master UI contract: {text}")

if len(questions) != 8:
    errors.append(f"preview bank must contain exactly 8 questions, got {len(questions)}")
ids = [q.get("id") for q in questions]
if len(ids) != len(set(ids)):
    errors.append("duplicate preview question IDs")
for q in questions:
    if q.get("originType") != "original_preview" or q.get("releaseEligible") is not False:
        errors.append(f"preview question must be non-release original_preview: {q.get('id')}")
    for key in ("stem", "choices", "correctIndices", "explanation", "memory", "sourceURL", "evidenceCheckedDate"):
        if not q.get(key):
            errors.append(f"missing preview field {key}: {q.get('id')}")

for production_value in ("jp.allsunday1122.yobi", "jp.allsunday1122.yobi.premium"):
    if production_value in project or production_value in swift:
        errors.append(f"guessed production identifier found: {production_value}")
if "UNSET.YOBI.BUNDLE.ID" not in project or "YOBI_IAP_PRODUCT_ID" not in project:
    errors.append("identifier placeholders/injection contract missing")

if "NSPrivacyAccessedAPICategoryUserDefaults" not in privacy or "CA92.1" not in privacy:
    errors.append("Privacy Manifest UserDefaults reason missing")

if errors:
    print("FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: native source contract, v2.1 UI markers, preview release gate, identifiers and privacy manifest")
