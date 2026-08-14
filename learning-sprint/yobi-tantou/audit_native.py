#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IOS = ROOT / "ios"
CONTENT_LOOP = ROOT / "content-loop"
errors = []

swift = "\n".join(p.read_text(encoding="utf-8") for p in IOS.glob("*.swift"))
views = (IOS / "Views.swift").read_text(encoding="utf-8")
app_model = (IOS / "AppModel.swift").read_text(encoding="utf-8")
question_repository = (IOS / "QuestionRepository.swift").read_text(encoding="utf-8")
scoring_repository = (IOS / "OfficialScoringRepository.swift").read_text(encoding="utf-8")
storekit = (IOS / "StoreKitManager.swift").read_text(encoding="utf-8")
release_builder = (CONTENT_LOOP / "build_native_release.py").read_text(encoding="utf-8")
combiner = (CONTENT_LOOP / "combine_practice_release.py").read_text(encoding="utf-8")
project = (IOS / "project.yml").read_text(encoding="utf-8")
preview_questions = json.loads((IOS / "Resources" / "questions.preview.json").read_text(encoding="utf-8"))
release_path = IOS / "Resources" / "questions.release.json"
privacy = (IOS / "PrivacyInfo.xcprivacy").read_text(encoding="utf-8")
icon_lock = json.loads((IOS / "app-icon-lock.json").read_text(encoding="utf-8"))

legal_subjects = {"憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法"}
valid_release_subjects = legal_subjects | {"一般教養"}
valid_difficulties = {"foundation", "standard", "applied"}

for forbidden in ("import WebKit", "WKWebView", "SFSafariViewController"):
    if forbidden in swift:
        errors.append(f"native-only violation: {forbidden}")

required_ui = [
    "ホーム", "模試", "記録", "設定", "今日の学習", "今日のスプリント",
    "苦手をつぶす", "分野から解く", "ここだけ覚える", "わからない記録",
    "5週間", "学習データを書き出す", "学習データを読み込む",
    "確認済みの公式採点構造", "採点確認済み", "公式合格点",
    "正式教材問題の権利・内容監査が完了するまで、年度模試の開始だけをロックしています。"
]
for text in required_ui:
    if text not in views:
        errors.append(f"missing Golden Master/qualification UI contract: {text}")

required_mock = [
    "generalEducationSubject = \"一般教養\"",
    "generalEducationAnswerLimit = 20",
    "MockSelectionPolicy.select(from: yearQuestions)",
    "OfficialScoringRepository.load(bundle: bundle)",
    "officialScoringYears",
    "officialScoring(year:",
]
for marker in required_mock:
    if marker not in swift:
        errors.append(f"missing preliminary-exam mock contract: {marker}")

required_use_separation = [
    "enum QuestionContentUse",
    "case officialMock = \"official_mock\"",
    "enum QuestionDifficulty",
    "$0.releaseEligible && $0.isOfficialMockQuestion && $0.examYear == year",
    "releasedPractice = questions.filter { $0.releaseEligible && $0.isPracticeQuestion }",
]
for marker in required_use_separation:
    if marker not in swift:
        errors.append(f"missing practice/official-mock/tier separation: {marker}")

for marker in (
    "officialMockRequiresDedicatedBank",
    "question.examYear == nil",
    "question.contentUse",
    "question.difficulty != nil",
):
    if marker not in question_repository:
        errors.append(f"missing repository formal release gate: {marker}")

for marker in (
    'PRACTICE_USE = "practice"',
    'OFFICIAL_MOCK_USE = "official_mock"',
    'DIFFICULTIES = {"foundation", "standard", "applied"}',
    'practice問題にexam_yearを付与できない',
    '公式年度模試は通常練習バンクへ変換できない',
    '"contentUse": PRACTICE_USE',
    '"difficulty": difficulty',
):
    if marker not in release_builder:
        errors.append(f"missing tiered practice-only release builder gate: {marker}")

for marker in (
    "duplicate question id across tiers",
    "only practice content may enter combined bank",
    "practice item cannot carry official exam year",
    "difficulty does not match declared tier",
):
    if marker not in combiner:
        errors.append(f"missing fail-closed practice tier combiner gate: {marker}")

required_scoring = [
    "static let supportedYears = [2024, 2025]",
    "legal.questionCount == 95",
    "legal.maxPoints == 210",
    "general.select == 20",
    "general.maxPoints == 60",
    "yearData.totalMaxPoints == 270",
]
for marker in required_scoring:
    if marker not in scoring_repository:
        errors.append(f"missing verified official scoring contract: {marker}")

if "officialScoringCanonical = try OfficialScoringRepository.load(bundle: bundle)" not in app_model:
    errors.append("AppModel does not fail-closed load bundled official scoring canonical")

required_storekit = [
    "Product.products(for:", "product.purchase()", "AppStore.sync()",
    "Transaction.currentEntitlements", "Transaction.updates",
    "transaction.revocationDate == nil", "StoreProductIDPolicy.normalized",
]
for marker in required_storekit:
    if marker not in storekit:
        errors.append(f"missing StoreKit lifecycle contract: {marker}")

if len(preview_questions) != 8:
    errors.append(f"preview bank must contain exactly 8 questions, got {len(preview_questions)}")
preview_ids = [q.get("id") for q in preview_questions]
if len(preview_ids) != len(set(preview_ids)):
    errors.append("duplicate preview question IDs")
for q in preview_questions:
    if q.get("originType") != "original_preview" or q.get("releaseEligible") is not False:
        errors.append(f"preview question must be non-release original_preview: {q.get('id')}")
    if q.get("contentUse") is not None or q.get("difficulty") is not None:
        errors.append(f"preview question must not declare production contentUse/difficulty: {q.get('id')}")
    for key in ("stem", "choices", "correctIndices", "explanation", "memory", "sourceURL", "evidenceCheckedDate"):
        if not q.get(key):
            errors.append(f"missing preview field {key}: {q.get('id')}")

# Formal practice bank has three independently audited tiers: 14 foundation,
# 14 standard and 14 applied. Each tier contains exactly two items for each of
# the seven legal subjects. Official exam reproductions remain in a separate,
# still-locked official-mock pipeline.
if not release_path.exists():
    errors.append("formal practice questions.release.json missing")
else:
    release_questions = json.loads(release_path.read_text(encoding="utf-8"))
    if not isinstance(release_questions, list) or len(release_questions) != 42:
        count = len(release_questions) if isinstance(release_questions, list) else "non-list"
        errors.append(f"formal practice bank must contain exactly 42 audited questions, got {count}")
        release_questions = release_questions if isinstance(release_questions, list) else []
    release_ids = [q.get("id") for q in release_questions]
    if any(not qid for qid in release_ids) or len(release_ids) != len(set(release_ids)):
        errors.append("formal practice bank has missing/duplicate IDs")

    expected_difficulties = Counter({"foundation": 14, "standard": 14, "applied": 14})
    difficulty_counts = Counter(q.get("difficulty") for q in release_questions)
    if difficulty_counts != expected_difficulties:
        errors.append(f"formal practice difficulty coverage mismatch: {dict(difficulty_counts)}")
    for difficulty in ("foundation", "standard", "applied"):
        tier_subject_counts = Counter(
            q.get("subject") for q in release_questions if q.get("difficulty") == difficulty
        )
        for subject in legal_subjects:
            if tier_subject_counts.get(subject, 0) != 2:
                errors.append(f"{difficulty} practice coverage must be exactly 2 questions: {subject}")

    for q in release_questions:
        qid = q.get("id", "<no-id>")
        if q.get("releaseEligible") is not True:
            errors.append(f"formal practice item is not releaseEligible: {qid}")
        if q.get("contentUse") != "practice":
            errors.append(f"ordinary release bank contains non-practice contentUse: {qid}")
        if q.get("examYear") is not None:
            errors.append(f"practice item falsely carries official exam year: {qid}")
        if q.get("difficulty") not in valid_difficulties:
            errors.append(f"formal practice difficulty invalid: {qid}")
        if q.get("originType") in (None, "original_preview", "official_exam_reproduced"):
            errors.append(f"formal practice originType invalid: {qid}")
        if q.get("subject") not in valid_release_subjects:
            errors.append(f"formal practice subject invalid: {qid}")
        if q.get("subject") in legal_subjects and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(q.get("lawBasisDate", ""))):
            errors.append(f"formal legal practice lawBasisDate invalid: {qid}")
        for key in ("stem", "choices", "correctIndices", "explanation", "memory", "sourceURL", "evidenceCheckedDate"):
            if not q.get(key):
                errors.append(f"formal practice field missing {key}: {qid}")

for production_value in ("jp.allsunday1122.yobi", "jp.allsunday1122.yobi.premium"):
    if production_value in project or production_value in swift:
        errors.append(f"guessed production identifier found: {production_value}")
if "UNSET.YOBI.BUNDLE.ID" not in project or "YOBI_IAP_PRODUCT_ID" not in project:
    errors.append("identifier placeholders/injection contract missing")

if "NSPrivacyTracking" not in privacy or "<false/>" not in privacy:
    errors.append("Privacy Manifest tracking=false missing")
if "NSPrivacyCollectedDataTypes" not in privacy:
    errors.append("Privacy Manifest collected-data declaration missing")
if "NSPrivacyAccessedAPICategoryUserDefaults" not in privacy or "CA92.1" not in privacy:
    errors.append("Privacy Manifest UserDefaults reason missing")

expected_icon = {
    "developmentSequence": 11,
    "canonicalFileName": "11_司法試験予備試験_短答式.png",
    "canonicalDriveFileId": "1EyeJxBN2WPEjEw9TUszhmyhuk3_3Lu6K",
    "width": 1024,
    "height": 1024,
    "mimeType": "image/png",
    "sizeBytes": 721851,
    "sha256": "c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9",
}
for key, expected in expected_icon.items():
    if icon_lock.get(key) != expected:
        errors.append(f"canonical AppIcon lock mismatch {key}: {icon_lock.get(key)!r} != {expected!r}")
if not re.fullmatch(r"[0-9a-f]{64}", str(icon_lock.get("sha256", ""))):
    errors.append("canonical AppIcon SHA-256 format invalid")

if errors:
    print("FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: native source contract, v2.1 UI, 42-question three-tier formal practice bank, practice/official-mock isolation, verified scoring, preview/release gates, StoreKit lifecycle, identifiers, privacy and canonical AppIcon lock")
