#!/usr/bin/env python3
from pathlib import Path
import re
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
round_matches = re.findall(r"\.init\(round: (\d+), officialQuestionCount: (\d+), publicationStatus: \.verifiedPublished\)", config)
verified = {int(round_no): int(count) for round_no, count in round_matches}
expected = {60: 200, 59: 200, 58: 200}
if verified != expected:
    errors.append(f"公式PDF確認済み枠が不一致: actual={verified}, expected={expected}")
if "static let totalOfficialQuestionSlots = examRounds.reduce" not in config:
    errors.append("3回分総枠の導出が欠損")

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
print("Official frame: R60/R59/R58 = 200 each, total 600: PASS")
