#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
swift_files = list((ROOT / "Sources").glob("*.swift"))
texts = {p.name: p.read_text(encoding="utf-8") for p in swift_files}
all_swift = "\n".join(texts.values())
project = (ROOT / "project.yml").read_text(encoding="utf-8")

errors = []

for banned in ("WKWebView", "UIWebView", "import WebKit"):
    if banned in all_swift:
        errors.append(f"WebView禁止違反: {banned}")

required_ui = (
    "今日のスプリント",
    "苦手をつぶす",
    "模擬試験",
    "分野から解く",
    "これまで",
    "LearningSprintProgressRing",
    "LearningSprintHeatmap",
)
for token in required_ui:
    if token not in all_swift:
        errors.append(f"Golden Master要素欠損: {token}")

if "$(RIGAKU_BUNDLE_ID)" not in project:
    errors.append("Bundle IDは正本値の外部注入にすること")

for guessed in ("jp.allsunday1122.rigaku", "jp.allsunday1122.rigakusprint"):
    if guessed in project or guessed in all_swift:
        errors.append(f"Bundle ID推測値を検出: {guessed}")

config = texts.get("AppConfiguration.swift", "")
if ".init(round: 59, officialQuestionCount: nil" not in config:
    errors.append("第59回問題数を未確認のまま固定している可能性")
if ".init(round: 58, officialQuestionCount: nil" not in config:
    errors.append("第58回問題数を未確認のまま固定している可能性")

if errors:
    print("STATIC AUDIT: FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STATIC AUDIT: PASS")
print(f"Swift files: {len(swift_files)}")
print("WebView ban: PASS")
print("Golden Master signature elements: PASS")
print("Identifier non-guess policy: PASS")
print("Unverified exam counts remain unset: PASS")
