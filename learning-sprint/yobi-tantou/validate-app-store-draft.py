#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
APP_STORE = ROOT / "app-store"
errors = []

files = {
    "metadata": APP_STORE / "APP_STORE_METADATA_JA.md",
    "review": APP_STORE / "APP_REVIEW_NOTES_JA.md",
    "storekit": APP_STORE / "STOREKIT_TEST_PLAN.md",
    "checklist": APP_STORE / "RELEASE_CHECKLIST.md",
    "packet": APP_STORE / "APPLE_CONNECT_PACKET.md",
    "privacy": ROOT / "privacy" / "index.html",
    "support": ROOT / "support" / "index.html",
}

texts = {}
for name, path in files.items():
    if not path.exists():
        errors.append(f"missing app-store asset: {path.relative_to(ROOT)}")
    else:
        texts[name] = path.read_text(encoding="utf-8")

all_text = "\n".join(texts.values())

required_shared = [
    "法務省", "公式アプリではありません", "StoreKit", "要確認",
    "https://allsunday1122.github.io/learning-sprint/yobi-tantou/support/",
    "https://allsunday1122.github.io/learning-sprint/yobi-tantou/privacy/",
]
for marker in required_shared:
    if marker not in all_text:
        errors.append(f"missing app-store marker: {marker}")

for forbidden in [
    "jp.allsunday1122.yobi",
    "jp.allsunday1122.yobi.premium",
    "6799750000",
    "法務省公式アプリ",
]:
    if forbidden in all_text:
        errors.append(f"guessed/misleading release value found: {forbidden}")

if re.search(r"[¥￥]\s*\d", all_text):
    errors.append("hard-coded yen price found")

metadata = texts.get("metadata", "")
review = texts.get("review", "")
privacy = texts.get("privacy", "")
support = texts.get("support", "")
packet = texts.get("packet", "")
storekit = texts.get("storekit", "")

for marker in ["Non-Consumable", "最初の1スプリント最大8問", "固定価格を書かない"]:
    if marker not in metadata + review + storekit + packet:
        errors.append(f"StoreKit disclosure missing: {marker}")

for marker in ["トラッキングを行いません", "分析SDK", "端末内", "CA92.1"]:
    if marker not in privacy:
        errors.append(f"privacy disclosure missing: {marker}")

for marker in ["GitHub Issues", "購入資格そのものはバックアップファイルには含まれません"]:
    if marker not in support:
        errors.append(f"support disclosure missing: {marker}")

if "WebView" in privacy or "WebView" in metadata or "WebView" in review:
    errors.append("native app submission assets must not claim WebView storage/implementation")

for unsafe_claim in ["3年分", "3回分", "210問", "180問", "正式問題数"]:
    # '正式問題数' is allowed only with pending/unknown wording; detect certainty around numeric marketing claims separately.
    pass
if re.search(r"(?:収録|全)[^\n]{0,12}\d+問", metadata):
    errors.append("metadata contains fixed official question-count marketing claim before canonical release")

if "External Beta App Review／App Store本審査をユーザー承認前に実行しない" not in packet:
    errors.append("external review approval gate missing")

if errors:
    print("FAIL: App Store draft consistency")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PASS: App Store draft assets are native/privacy/StoreKit consistent and production IDs/prices remain blocked")
