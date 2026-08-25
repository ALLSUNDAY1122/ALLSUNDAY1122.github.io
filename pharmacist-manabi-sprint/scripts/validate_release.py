#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, plistlib, struct, subprocess, sys

R = Path(__file__).resolve().parents[1]
ROOT = R.parent
errors = []
warnings = []

def need(path):
    if not (R / path).exists():
        errors.append('missing: ' + path)

required = [
    'content/product/questions.json', 'content/product/final-audit-v2.json', 'content/product/web-static-audit.json',
    'support.html', 'privacy.html', 'terms.html',
    'ios/project.yml', 'ios/App.swift', 'ios/Models.swift', 'ios/LearningStore.swift', 'ios/LearningStoreResultActions.swift',
    'ios/Theme.swift', 'ios/RootAndHomeViews.swift', 'ios/QuizViews.swift', 'ios/HistorySettingsViews.swift',
    'ios/MockPaywallViews.swift', 'ios/Tests/QuestionModelTests.swift', 'ios/Info.plist', 'ios/PrivacyInfo.xcprivacy',
    'ios/prepare-ios.sh', 'ios/Assets.xcassets/AppIcon.appiconset/Contents.json',
    'ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md', 'metadata/APP_STORE_METADATA_JA.md',
    'metadata/RELEASE_STATUS.md', 'metadata/RELEASE_CHECKLIST.md', 'metadata/APP_PRIVACY_AND_RIGHTS.md'
]
for path in required:
    need(path)
if not (ROOT / 'codemagic.yaml').exists():
    errors.append('missing: root codemagic.yaml')
if (R / 'ios/StoreKitManager.swift').exists():
    errors.append('StoreKitManager.swift must not ship in no-IAP release source')
if errors:
    print('FAIL\n' + '\n'.join('- ' + e for e in errors))
    sys.exit(1)

try:
    subprocess.run([sys.executable, str(R / 'tools/final_product_audit_v2.py')], cwd=R, check=True)
except subprocess.CalledProcessError:
    errors.append('fresh final question audit failed')

audit = json.load(open(R / 'content/product/final-audit-v2.json', encoding='utf-8'))
bank = json.load(open(R / 'content/product/questions.json', encoding='utf-8'))
web_audit = json.load(open(R / 'content/product/web-static-audit.json', encoding='utf-8'))

if not audit.get('finalPass') or audit.get('questionCount') != 1035 or audit.get('blockedCount') != 0 or audit.get('explanationCoverage') != 1035:
    errors.append('final question audit not PASS')
integrity = audit.get('difficultyIntegrity') or {}
if integrity.get('policy') != 'official_exam_only' or integrity.get('sourceExams') != [109, 110, 111]:
    errors.append('difficulty integrity policy mismatch')
if audit.get('generatedSupplementQuestionCount') != 0 or integrity.get('officialQuestionCount') != 1035:
    errors.append('generated/non-official question detected')
if any(integrity.get(k) for k in ('generatedSupplementQuestionIds', 'unexpectedExamQuestionIds', 'nonOfficialQuestionIds', 'nonMhlwSourceQuestionIds', 'answerLeakQuestionIds')):
    errors.append('difficulty/source integrity findings remain')

questions = bank.get('questions', [])
active = [q for q in questions if q.get('scoring_status') != 'excluded']
excluded = [q for q in questions if q.get('scoring_status') == 'excluded']
flexible = [q for q in questions if q.get('scoring_status') == 'multiple_accepted']
if (len(questions), len(active), len(excluded), len(flexible)) != (1035, 1031, 4, 3):
    errors.append(f'bank counts invalid {(len(questions), len(active), len(excluded), len(flexible))}')
if web_audit.get('pass') is not True:
    errors.append('web/source audit not PASS')

with open(R / 'ios/Info.plist', 'rb') as f:
    info = plistlib.load(f)
if info.get('ITSAppUsesNonExemptEncryption') is not False:
    errors.append('encryption plist mismatch')
with open(R / 'ios/PrivacyInfo.xcprivacy', 'rb') as f:
    privacy = plistlib.load(f)
if privacy.get('NSPrivacyTracking') is not False or privacy.get('NSPrivacyCollectedDataTypes') != [] or privacy.get('NSPrivacyAccessedAPITypes') != []:
    errors.append('privacy manifest mismatch')

compiled_files = [
    'App.swift', 'Models.swift', 'LearningStore.swift', 'LearningStoreResultActions.swift', 'Theme.swift',
    'RootAndHomeViews.swift', 'QuizViews.swift', 'HistorySettingsViews.swift', 'MockPaywallViews.swift'
]
swift = '\n'.join((R / 'ios' / p).read_text(encoding='utf-8') for p in compiled_files)
compact = ''.join(swift.split())
app = (R / 'ios/App.swift').read_text(encoding='utf-8')
project = (R / 'ios/project.yml').read_text(encoding='utf-8')
root_home = (R / 'ios/RootAndHomeViews.swift').read_text(encoding='utf-8')
mock = (R / 'ios/MockPaywallViews.swift').read_text(encoding='utf-8')
settings = (R / 'ios/HistorySettingsViews.swift').read_text(encoding='utf-8')
tests = (R / 'ios/Tests/QuestionModelTests.swift').read_text(encoding='utf-8')
theme = (R / 'ios/Theme.swift').read_text(encoding='utf-8')
metadata = (R / 'metadata/APP_STORE_METADATA_JA.md').read_text(encoding='utf-8')

for forbidden in ['import WebKit', 'WKWebView', 'UIViewRepresentable']:
    if forbidden in swift:
        errors.append('WebView/native violation: ' + forbidden)

# No-IAP release contract. The binary must not include StoreKit code, purchase UI, paywalls, or premium locks.
for forbidden in [
    'import StoreKit', 'StoreKitManager', 'PaywallView', 'Product.purchase', 'AppStore.sync',
    'Transaction.currentEntitlements', 'showManageSubscriptions', '購入を復元', 'サブスクリプション管理',
    '7日間無料', 'プレミアム'
]:
    if forbidden in swift:
        errors.append('no-IAP release contains billing token: ' + forbidden)
if 'StoreKitManager.swift' in project:
    errors.append('StoreKitManager remains in Xcode target')
for token in ['storeKit', 'paywallPresented', 'lock.fill']:
    if token in root_home or token in mock:
        errors.append('full-access UI still contains purchase/lock path: ' + token)
if 'premium: true' not in root_home or 'premium: true' not in mock:
    errors.append('full-access study routes are not explicitly unlocked')
if '追加購入なし' not in root_home:
    errors.append('full-access disclosure missing from home')
if 'アプリ内課金' not in settings or '追加購入なし' not in settings:
    errors.append('no-IAP disclosure missing from settings')

for required_token in ['RootView()', 'LearningStore()']:
    if required_token not in app:
        errors.append('native app root missing: ' + required_token)
if 'StoreKitManager()' in app:
    errors.append('StoreKit object still initialized')
for token in ['PharmacistSprintTests', 'Generated/questions.native.json']:
    if token not in project:
        errors.append('project native/test token missing: ' + token)
if 'path: Web' in project:
    errors.append('Web folder is still bundled by Xcode target')

for token in ['case home = "ホーム"', 'case mock = "模試"', 'case history = "記録"', 'case settings = "設定"', 'var goal = 8', 'var fontSize = 16']:
    if token not in swift:
        errors.append('Golden Master state token missing: ' + token)
if '[4,8,16]' not in compact:
    errors.append('Golden Master behavior token missing: 4/8/16 goals')
for token in ['3回連続正解', 'わからない（答えを見る）', '5週間の学習', 'JSONを書き出す', 'JSONを読み込む']:
    if token not in swift:
        errors.append('Golden Master behavior token missing: ' + token)
if 'daily.answered += 1' not in swift:
    errors.append('daily answered-count update missing')
if 'learningProgress' not in swift or 'seen.filter' not in swift:
    errors.append('achievement progress must be based on seen questions')
if 'accessibilityReduceMotion' not in theme or 'reduceMotion ? nil' not in theme:
    errors.append('Reduce Motion handling missing')

settings_tokens = [
    'settingBlock("文字サイズ")', 'settingBlock("1日の目標")', 'toggleRow("出題順をシャッフル"',
    'toggleRow("選択肢もシャッフル"', 'examDateBlock', 'backupBlock', 'title: "覚えかたのルール"',
    'title: "この教材について"', 'Text("学習記録をリセット")'
]
positions = [settings.find(token) for token in settings_tokens]
if any(p < 0 for p in positions) or positions != sorted(positions):
    errors.append('Golden Master mandatory settings order mismatch')

for token in ['testWrongOrUnknownAnswerStillAdvancesDailyHeatmapAndAchievement', 'testFieldBatchesCoverEveryQuestionWithoutEightQuestionLimit']:
    if token not in tests:
        errors.append('required regression XCTest missing: ' + token)

source = (R / 'ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md').read_text(encoding='utf-8')
expected_icon = 'dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
if '1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu' not in source or expected_icon not in source:
    errors.append('canonical icon source mismatch')
icon = R / 'ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
materialized = icon.exists()
if materialized:
    raw = icon.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected_icon:
        errors.append('AppIcon hash mismatch')
    elif raw[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', raw[16:24]) != (1024, 1024) or raw[25] != 2:
        errors.append('AppIcon must be canonical 1024 RGB')
else:
    warnings.append('canonical AppIcon materialization pending before signed build')

for p in ['support.html', 'privacy.html', 'terms.html']:
    if 'http://' in (R / p).read_text(encoding='utf-8'):
        errors.append(p + ' has insecure link')
for token in ['価格：無料', '1,031', '追加購入なし', 'アプリ内課金：なし', '16+']:
    if token not in metadata:
        errors.append('metadata missing no-IAP release token: ' + token)
for forbidden in ['jp.allsunday1122.yakuzaishi.monthly', 'jp.allsunday1122.yakuzaishi.lifetime', 'displayPrice', '無料90問', '月額', '買い切り']:
    if forbidden in metadata:
        errors.append('metadata still contains IAP/free-tier token: ' + forbidden)

cm = (ROOT / 'codemagic.yaml').read_text(encoding='utf-8')
for token in [
    'pharmacist-ios:', 'bundle_identifier: jp.allsunday1122.yakuzaishi', 'APP_STORE_CONNECT_APP_ID: "6799753724"',
    'CODEMAGIC_PROFILE_REF: yakuzaishi_appstore', 'submit_to_testflight: true', 'submit_to_app_store: false'
]:
    if token not in cm:
        errors.append('Codemagic token missing: ' + token)

report = {
    'pass': not errors,
    'architecture': 'SwiftUI-native',
    'monetization': 'none',
    'allScoredQuestionsUnlocked': True,
    'webViewRuntime': False,
    'errors': errors,
    'warnings': warnings,
    'questions': len(questions),
    'active': len(active),
    'excluded': len(excluded),
    'flexible': len(flexible),
    'iconMaterialized': materialized,
    'bundleId': 'jp.allsunday1122.yakuzaishi',
    'appStoreConnectAppId': '6799753724'
}
(R / 'content/product/release-preflight-static.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
sys.exit(1 if errors else 0)
