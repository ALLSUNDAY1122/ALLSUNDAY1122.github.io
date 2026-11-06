#!/usr/bin/env python3
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
APP_STORE = ROOT / "app-store"
IOS = ROOT / "ios"
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

config_path = APP_STORE / "monetization-config.v1.json"
if not config_path.exists():
    errors.append("missing app-store asset: app-store/monetization-config.v1.json")
    monetization = {}
else:
    monetization = json.loads(config_path.read_text(encoding="utf-8"))

all_text = "\n".join(texts.values())
swift_text = "\n".join(path.read_text(encoding="utf-8") for path in IOS.glob("*.swift"))

required_shared = [
    "法務省", "公式アプリではありません", "StoreKit",
    "jp.allsunday1122.yobishikentantou",
    "jp.allsunday1122.yobishikentantou.monthly",
    "Auto-Renewable Subscription",
    "https://allsunday1122.github.io/learning-sprint/yobi-tantou/support/",
    "https://allsunday1122.github.io/learning-sprint/yobi-tantou/privacy/",
]
for marker in required_shared:
    if marker not in all_text:
        errors.append(f"missing app-store marker: {marker}")

# v2.4 migration must not leave the old buyout design in submission assets.
for forbidden in [
    "Non-Consumable買い切り",
    "IAP商品種別Non-Consumable",
    "プレミアム機能は、アプリ内課金（買い切り）で解放",
    "Bundle ID: `要確認`",
    "法務省公式アプリ",
]:
    if forbidden in all_text:
        errors.append(f"obsolete/misleading release value found: {forbidden}")

# 200 JPY/month is a canonical App Store Connect reference price in v2.4,
# but user-facing app code must obtain the localized price from StoreKit.
if "Product.displayPrice" not in all_text and "product.displayPrice" not in all_text:
    errors.append("StoreKit displayPrice disclosure missing")
if re.search(r"(?:200\s*円|￥\s*200|¥\s*200)", swift_text):
    errors.append("hard-coded 200 JPY price found in Swift source")
if "product.displayPrice" not in swift_text:
    errors.append("Premium UI must render StoreKit product.displayPrice")

metadata = texts.get("metadata", "")
review = texts.get("review", "")
privacy = texts.get("privacy", "")
support = texts.get("support", "")
packet = texts.get("packet", "")
storekit = texts.get("storekit", "")

for marker in [
    "自動更新サブスクリプション（月額）",
    "最初の1スプリント最大8問",
    "StoreKit `Product.displayPrice`",
]:
    if marker not in metadata + review + storekit + packet:
        errors.append(f"StoreKit disclosure missing: {marker}")

for marker in [
    "最初の1スプリントは最大8問まで無料",
    "プレミアム機能は、自動更新サブスクリプションで解放します",
    "App Storeから取得したローカライズ済み価格を表示します",
]:
    if marker not in metadata:
        errors.append(f"metadata subscription disclosure missing: {marker}")

plan = monetization.get("monetization") or {}
iap = monetization.get("iap") or {}
if monetization.get("standardProcedureVersion") != "2.4":
    errors.append("monetization config is not on standard procedure v2.4")
if monetization.get("bundleID") != "jp.allsunday1122.yobishikentantou":
    errors.append("canonical Bundle ID mismatch")
if plan.get("model") != "auto_renewable_subscription" or plan.get("period") != "P1M":
    errors.append("monthly auto-renewable monetization model mismatch")
if plan.get("japanReferencePriceJPY") != 200:
    errors.append("Japan reference price must be 200 JPY/month")
if plan.get("priceDisplayPolicy") != "StoreKit Product.displayPrice only":
    errors.append("displayPrice-only policy mismatch")
if iap.get("plannedProductID") != "jp.allsunday1122.yobishikentantou.monthly":
    errors.append("planned IAP Product ID mismatch")
if iap.get("productType") != "autoRenewable":
    errors.append("IAP product type must be autoRenewable")
if iap.get("appStoreConnectRegistrationStatus") != "pending":
    errors.append("IAP registration must remain pending until App Store Connect confirms it")
if iap.get("runtimeConfigurationStatus") != "unset_until_registered":
    errors.append("runtime IAP must remain unset until registered")

# Public privacy text should describe behavior in user-facing terms. The exact
# required-reason code CA92.1 is validated separately in audit_native.py.
for marker in ["トラッキングを行いません", "分析SDK", "端末内", "UserDefaults"]:
    if marker not in privacy:
        errors.append(f"privacy disclosure missing: {marker}")

for marker in ["GitHub Issues", "購入資格そのものはバックアップファイルには含まれません"]:
    if marker not in support:
        errors.append(f"support disclosure missing: {marker}")

if "WebView" in privacy or "WebView" in metadata or "WebView" in review:
    errors.append("native app submission assets must not claim WebView storage/implementation")

if re.search(r"(?:収録|全)[^\n]{0,12}\d+問", metadata):
    errors.append("metadata contains fixed official question-count marketing claim before canonical release")

if "External Beta App Review／App Store本審査をユーザー承認前に実行しない" not in packet:
    errors.append("external review approval gate missing")

if errors:
    print("FAIL: App Store draft consistency")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PASS: App Store draft assets are v2.4 monthly-subscription/native/privacy consistent; Bundle ID canonical; ASC-issued values remain blocked")
