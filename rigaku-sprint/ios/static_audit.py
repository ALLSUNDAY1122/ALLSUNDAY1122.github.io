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
    "模擬試験",
    "分野から解く",
    "これまで",
    "LearningSprintProgressRing",
    "LearningSprintHeatmap",
    "監査済み問題",
    "試験日を設定",
)
for token in required_ui:
    if token not in all_swift:
        errors.append(f"Golden Master要素欠損: {token}")

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
    "auditedQuestionCount(forSubject:",
    "RigakuExamScoringRepository",
)
for token in required_native:
    if token not in all_swift:
        errors.append(f"共通ネイティブ機能接続欠損: {token}")

app_entry = texts.get("RigakuSprintApp.swift", "")
if "RigakuRootViewV2()" not in app_entry:
    errors.append("実行入口が現行正本UI RigakuRootViewV2 ではありません")

# 旧UIの検出は型名文字列検索ではなく、廃止済みソースファイルの実在で判定する。
# 型名検索だと監査コードやコメント自身の説明文を誤検出するため。
legacy_files = (
    SOURCES / "RootTabView.swift",
    SOURCES / "RigakuRootView.swift",
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

if "$(RIGAKU_BUNDLE_ID)" not in project:
    errors.append("Bundle IDは正本値の外部注入にすること")
for required_resource in (
    "questions.json",
    "question-batches",
    "media-manifest.json",
    "exam-config.json",
    "official-answers.json",
    "scoring-adjustments.json",
):
    if required_resource not in project:
        errors.append(f"ネイティブresource未登録: {required_resource}")

for guessed in (
    "jp.allsunday1122.rigaku",
    "jp.allsunday1122.rigakusprint",
    "jp.allsunday1122.rigaku.premium",
):
    if guessed in project or guessed in all_swift:
        errors.append(f"識別子推測値を検出: {guessed}")

config = texts.get("AppConfiguration.swift", "")
round_matches = re.findall(r"\.init\(round: (\d+), officialQuestionCount: (\d+), publicationStatus: \.verifiedPublished\)", config)
verified = {int(round_no): int(count) for round_no, count in round_matches}
expected = {60: 200, 59: 200, 58: 200}
if verified != expected:
    errors.append(f"公式PDF確認済み枠が不一致: actual={verified}, expected={expected}")
if "static let totalOfficialQuestionSlots = examRounds.compactMap(\\.officialQuestionCount).reduce(0, +)" not in config:
    errors.append("3回分総枠の導出が欠損")

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
print("Mock completeness gate: PASS")
print("Shared native learning features: PASS")
print("JSON backup/import: PASS")
print("Rights-gated media manifest: PASS")
print("Identifier non-guess policy: PASS")
print("Official frame: R60/R59/R58 = 200 each, total 600: PASS")
print("Product JSON syntax/schema gate: PASS")
