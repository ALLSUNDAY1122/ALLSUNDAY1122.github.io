#!/usr/bin/env python3
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "Sources"
PRODUCT = ROOT.parent / "product-content"
swift_files = list(SOURCES.glob("*.swift"))
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
    "第58〜60回ベース模試",
    "分野から解く",
    "これまで",
    "LearningSprintProgressRing",
    "LearningSprintHeatmap",
    "監査済み問題",
    "試験日を設定",
    "月額プラン",
    "無料版では8分野から選んだ60問",
)
for token in required_ui:
    if token not in all_swift:
        errors.append(f"Golden Master/課金UI要素欠損: {token}")

required_native = (
    "RigakuRootViewV2",
    "LearningEngine.selectSprint",
    "LearningEngine.selectWeak",
    "LearningEngine.record",
    "LearningSessionSnapshot",
    "fileExporter",
    "fileImporter",
    "LearningBackupDocument",
    "RigakuQuestionMediaRepository",
    "isMockReady",
    "availableQuestionCount(forSubject:",
    "RigakuExamScoringRepository",
    "runtimePremiumProductID",
    "PurchaseController(productID:",
    "purchasePremium()",
    "restorePurchases()",
    "purchaseDisplayPrice",
    "RigakuAccessPolicy.freeQuestionIDs",
    "canAccessBaseMocks",
    "canAccessFullWeakReview",
    "premiumLockedView",
)
for token in required_native:
    if token not in all_swift:
        errors.append(f"共通ネイティブ機能接続欠損: {token}")

app_entry = texts.get("RigakuSprintApp.swift", "")
root_v2 = texts.get("RigakuRootViewV2.swift", "")
if "RigakuRootViewV2()" not in app_entry:
    errors.append("実行入口が現行正本UI RigakuRootViewV2 ではありません")
for token in ("RigakuPurchaseSettingsSection()", "RigakuLegalSettingsSection()"):
    if token not in root_v2:
        errors.append(f"設定画面へのリリースSection接続欠損: {token}")

legacy_files = (
    SOURCES / "RootTabView.swift",
    SOURCES / "RigakuRootView.swift",
    SOURCES / "RigakuRootTabView.swift",
)
for legacy in legacy_files:
    if legacy.exists():
        errors.append(f"旧UIソースが残っています: {legacy.name}")
if "struct StudyPlaceholderView" in all_swift:
    errors.append("旧プレースホルダー画面 StudyPlaceholderView が残っています")

unknown_patterns = (
    "answer: .unknown",
    "AnswerPayload.unknown",
    "AnswerPayload(isUnknown: true)",
)
if not any(pattern in all_swift for pattern in unknown_patterns):
    errors.append("共通ネイティブ機能接続欠損: わからない回答")

canonical_bundle = "jp.allsunday1122.rigakuryouhoushi"
canonical_product = "jp.allsunday1122.rigakuryouhoushi.monthly"
if f"PRODUCT_BUNDLE_IDENTIFIER: {canonical_bundle}" not in project:
    errors.append("Bundle IDが#15正本値と不一致")
if f"RigakuPremiumProductID: {canonical_product}" not in project:
    errors.append("月額Product IDが#15正本値と不一致")
if "MARKETING_VERSION: 1.0.0" not in project:
    errors.append("初回公開Versionが1.0.0ではありません")

for required_resource in (
    "questions.json",
    "question-batches",
    "media-manifest.json",
    "exam-config.json",
    "official-answers.json",
    "scoring-adjustments.json",
    "Assets.xcassets",
    "PrivacyInfo.xcprivacy",
):
    if required_resource not in project:
        errors.append(f"ネイティブresource未登録: {required_resource}")

asset_contents = ROOT / "Assets.xcassets" / "Contents.json"
app_icon_contents = ROOT / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"
if not asset_contents.exists():
    errors.append("Asset Catalog欠損: Assets.xcassets/Contents.json")
if not app_icon_contents.exists():
    errors.append("AppIcon asset metadata欠損: AppIcon.appiconset/Contents.json")
else:
    try:
        icon_doc = json.loads(app_icon_contents.read_text(encoding="utf-8"))
        images = icon_doc.get("images", [])
        if not any(item.get("size") == "1024x1024" and item.get("platform") == "ios" for item in images):
            errors.append("AppIcon 1024x1024 iOS slot欠損")
    except json.JSONDecodeError as exc:
        errors.append(f"AppIcon Contents.json不正: {exc}")

privacy_manifest = ROOT / "PrivacyInfo.xcprivacy"
if not privacy_manifest.exists():
    errors.append("PrivacyInfo.xcprivacy欠損")

config = texts.get("AppConfiguration.swift", "")
if f'static let canonicalBundleIdentifier = "{canonical_bundle}"' not in config:
    errors.append("AppConfigurationのBundle ID正本値欠損")
if f'static let canonicalMonthlyProductID = "{canonical_product}"' not in config:
    errors.append("AppConfigurationの月額Product ID正本値欠損")
if 'static let contentVersion = "1.0.0"' not in config:
    errors.append("contentVersionが1.0.0ではありません")

access = texts.get("RigakuAccessPolicy.swift", "")
if "static let freeQuestionLimit = 60" not in access:
    errors.append("無料60問上限が固定されていません")
for subject, quota in {
    "理学療法": 16,
    "臨床医学大要": 14,
    "生理学": 7,
    "解剖学": 6,
    "リハビリテーション医学": 5,
    "臨床心理学": 5,
    "運動学": 5,
    "病理学概論": 2,
}.items():
    if f'"{subject}": {quota}' not in access:
        errors.append(f"無料問題配分欠損: {subject}={quota}")

round_matches = re.findall(r"\.init\(round: (\d+), officialQuestionCount: (\d+), publicationStatus: \.verifiedPublished\)", config)
verified = {int(round_no): int(count) for round_no, count in round_matches}
expected = {60: 200, 59: 200, 58: 200}
if verified != expected:
    errors.append(f"公式PDF確認済み枠が不一致: actual={verified}, expected={expected}")
if "static let totalOfficialQuestionSlots = examRounds.compactMap(\\.officialQuestionCount).reduce(0, +)" not in config:
    errors.append("3回分総枠の導出が欠損")
if "normalizedExternalIdentifier" not in config:
    errors.append("外部識別子の未展開プレースホルダー拒否処理が欠損")
for legal_url_token in ("supportURL", "privacyURL", "termsURL"):
    if legal_url_token not in config:
        errors.append(f"アプリ内法務URL欠損: {legal_url_token}")

for json_name in (
    "questions.json",
    "media-manifest.json",
    "exam-frame.json",
    "exam-config.json",
    "official-answers.json",
    "scoring-adjustments.json",
):
    path = PRODUCT / json_name
    if not path.exists():
        errors.append(f"product-content欠損: {json_name}")
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"JSON不正 {json_name}: {exc}")

questions_path = PRODUCT / "questions.json"
if questions_path.exists():
    questions = json.loads(questions_path.read_text(encoding="utf-8"))
    if questions != []:
        required_question_keys = {
            "id", "subject", "topic", "answerType", "prompt", "memoryPoint",
            "explanation", "sourceCheckedAt", "lawBaselineDate", "contentVersion", "rightsBasis"
        }
        for index, question in enumerate(questions):
            missing = required_question_keys - set(question)
            if missing:
                errors.append(f"question[{index}] 必須キー欠損: {sorted(missing)}")
            if not question.get("rightsBasis"):
                errors.append(f"question[{index}] rightsBasis欠損")

if errors:
    print("STATIC AUDIT: FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STATIC AUDIT: PASS")
print(f"Swift files: {len(swift_files)}")
print("WebView ban: PASS")
print("Golden Master signature elements: PASS")
print("Active root route gate: PASS")
print("Legacy root/source gate: PASS")
print("Mock completeness gate: PASS")
print("Shared native learning features: PASS")
print("Monthly StoreKit2 access gate: PASS")
print("Free 60 balanced-sample policy: PASS")
print("Canonical Bundle/Product IDs: PASS")
print("In-app legal/support links: PASS")
print("JSON backup/import: PASS")
print("Rights-gated media manifest: PASS")
print("Asset catalog metadata: PASS")
print("Privacy manifest presence: PASS")
print("Official frame: R60/R59/R58 = 200 each, total 600: PASS")
print("Product JSON syntax/schema gate: PASS")
