#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, plistlib, struct, subprocess, sys

R = Path(__file__).resolve().parents[1]
ROOT = R.parent
errors = []
warnings = []

def need(p):
    if not (R / p).exists(): errors.append('missing: ' + p)

required = [
    'content/product/questions.json','content/product/final-audit-v2.json','content/product/web-static-audit.json',
    'support.html','privacy.html','terms.html',
    'ios/project.yml','ios/App.swift','ios/Models.swift','ios/LearningStore.swift','ios/LearningStoreResultActions.swift',
    'ios/StoreKitManager.swift','ios/Theme.swift','ios/RootAndHomeViews.swift','ios/QuizViews.swift',
    'ios/HistorySettingsViews.swift','ios/MockPaywallViews.swift','ios/Tests/QuestionModelTests.swift',
    'ios/Info.plist','ios/PrivacyInfo.xcprivacy','ios/prepare-ios.sh','ios/apply-xcode-capabilities.py',
    'ios/Assets.xcassets/AppIcon.appiconset/Contents.json','ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md',
    'metadata/APP_STORE_METADATA_JA.md','metadata/RELEASE_STATUS.md','metadata/RELEASE_CHECKLIST.md','metadata/APP_PRIVACY_AND_RIGHTS.md'
]
for p in required: need(p)
if not (ROOT / 'codemagic.yaml').exists(): errors.append('missing: root codemagic.yaml')
if errors:
    print('FAIL\n' + '\n'.join('- ' + e for e in errors)); sys.exit(1)

# Always regenerate the final question audit from the current bank. This prevents
# a stale PASS JSON from hiding generated/easier supplement questions or a source
# provenance regression introduced after the previous audit was committed.
try:
    subprocess.run([sys.executable, str(R/'tools/final_product_audit_v2.py')], cwd=R, check=True)
except subprocess.CalledProcessError:
    errors.append('fresh final question audit failed')

# Question/source audit must remain the exact audited 3-exam bank.
a = json.load(open(R/'content/product/final-audit-v2.json', encoding='utf-8'))
q = json.load(open(R/'content/product/questions.json', encoding='utf-8'))
w = json.load(open(R/'content/product/web-static-audit.json', encoding='utf-8'))
if not a.get('finalPass') or a.get('questionCount') != 1035 or a.get('blockedCount') != 0 or a.get('explanationCoverage') != 1035 or a.get('unresolvedHighSimilarityPairs'):
    errors.append('final question audit not PASS')
integrity = a.get('difficultyIntegrity') or {}
if integrity.get('policy') != 'official_exam_only' or integrity.get('sourceExams') != [109, 110, 111]:
    errors.append('difficulty integrity policy mismatch')
if a.get('generatedSupplementQuestionCount') != 0 or integrity.get('officialQuestionCount') != 1035:
    errors.append('generated/non-official question detected')
if any(integrity.get(k) for k in ('generatedSupplementQuestionIds','unexpectedExamQuestionIds','nonOfficialQuestionIds','nonMhlwSourceQuestionIds','answerLeakQuestionIds')):
    errors.append('difficulty/source integrity findings remain')
qs = q.get('questions', [])
active = [x for x in qs if x.get('scoring_status') != 'excluded']
exc = [x for x in qs if x.get('scoring_status') == 'excluded']
flex = [x for x in qs if x.get('scoring_status') == 'multiple_accepted']
free = [x for x in active if int(x.get('sourceExam', 0)) == 111 and x.get('subject') == '必須']
if (len(qs), len(active), len(exc), len(flex), len(free)) != (1035, 1031, 4, 3, 90):
    errors.append(f'bank counts invalid {(len(qs),len(active),len(exc),len(flex),len(free))}')
if w.get('pass') is not True: errors.append('web/source audit not PASS')

# Privacy / export declarations.
with open(R/'ios/Info.plist', 'rb') as f: info = plistlib.load(f)
if info.get('ITSAppUsesNonExemptEncryption') is not False: errors.append('encryption plist mismatch')
with open(R/'ios/PrivacyInfo.xcprivacy', 'rb') as f: priv = plistlib.load(f)
if priv.get('NSPrivacyTracking') is not False or priv.get('NSPrivacyCollectedDataTypes') != [] or priv.get('NSPrivacyAccessedAPITypes') != []:
    errors.append('privacy manifest mismatch')

swift_files = list((R/'ios').glob('*.swift'))
swift = '\n'.join(p.read_text(encoding='utf-8') for p in swift_files)
compact_swift = ''.join(swift.split())
app = (R/'ios/App.swift').read_text(encoding='utf-8')
project = (R/'ios/project.yml').read_text(encoding='utf-8')
prepare = (R/'ios/prepare-ios.sh').read_text(encoding='utf-8')
theme = (R/'ios/Theme.swift').read_text(encoding='utf-8')
settings = (R/'ios/HistorySettingsViews.swift').read_text(encoding='utf-8')
tests = (R/'ios/Tests/QuestionModelTests.swift').read_text(encoding='utf-8')

# Native-only gate: learning UI must not be a WKWebView shell.
for forbidden in ['import WebKit', 'WKWebView', 'UIViewRepresentable']:
    if forbidden in swift: errors.append('WebView-only/native violation: ' + forbidden)
for required_token in ['RootView()', 'LearningStore()', 'StoreKitManager()']:
    if required_token not in app: errors.append('native app root missing: ' + required_token)
for token in ['PharmacistSprintTests','Generated/questions.native.json']:
    if token not in project: errors.append('project native/test token missing: ' + token)
if 'path: Web' in project: errors.append('Web folder is still bundled by Xcode target')
if 'questions.native.json' not in prepare or '1035' not in prepare or 'free' not in prepare:
    errors.append('native audited question generator incomplete')

# Golden Master behavior/static contract.
for token in ['case home = "ホーム"','case mock = "模試"','case history = "記録"','case settings = "設定"','var goal = 8','var fontSize = 16']:
    if token not in swift: errors.append('Golden Master state token missing: ' + token)
if '[4,8,16]' not in compact_swift: errors.append('Golden Master behavior token missing: 4/8/16 goals')
for token in ['3回連続正解','わからない（答えを見る）','5週間の学習','JSONを書き出す','JSONを読み込む']:
    if token not in swift: errors.append('Golden Master behavior token missing: ' + token)
if 'daily.answered += 1' not in swift: errors.append('daily answered-count update missing; heatmap regression risk')
if 'learningProgress' not in swift or 'seen.filter' not in swift: errors.append('achievement progress must be based on seen questions, not accuracy only')
if 'accessibilityReduceMotion' not in theme or 'reduceMotion ? nil' not in theme:
    errors.append('Reduce Motion handling missing from progress animation')

# Exact mandatory settings sequence: font -> goal -> question shuffle -> choice shuffle -> exam date -> JSON -> memory -> about -> reset.
settings_tokens = [
    'settingBlock("文字サイズ")', 'settingBlock("1日の目標")', 'toggleRow("出題順をシャッフル"',
    'toggleRow("選択肢もシャッフル"', 'examDateBlock', 'backupBlock', 'title: "覚えかたのルール"',
    'title: "この教材について"', 'Text("学習記録をリセット")'
]
positions = [settings.find(token) for token in settings_tokens]
if any(p < 0 for p in positions) or positions != sorted(positions):
    errors.append('Golden Master mandatory settings order mismatch')
about_pos = settings.find('title: "この教材について"')
premium_pos = settings.find('SprintCard {\n                    premiumBlock')
if premium_pos < 0 or premium_pos < about_pos:
    errors.append('premium controls must be outside/after mandatory settings sequence')

# Regression tests for the user-reported record-screen bugs must remain in XCTest.
for token in ['testWrongOrUnknownAnswerStillAdvancesDailyHeatmapAndAchievement', 'todayRecord.answered', 'learningProgress']:
    if token not in tests: errors.append('record-screen regression XCTest missing: ' + token)

# StoreKit 2 contract.
store = (R/'ios/StoreKitManager.swift').read_text(encoding='utf-8')
paywall = (R/'ios/MockPaywallViews.swift').read_text(encoding='utf-8')
for token in ['jp.allsunday1122.yakuzaishi.monthly','jp.allsunday1122.yakuzaishi.lifetime','Transaction.currentEntitlements','AppStore.sync()','showManageSubscriptions','displayPrice','isEligibleForIntroOffer']:
    if token not in store: errors.append('StoreKit native token missing: ' + token)
if '7日間無料' not in paywall or '/ 月で自動更新' not in paywall: errors.append('subscription disclosure missing')
for forbidden in ['¥200','¥980','￥200','￥980']:
    if forbidden in swift: errors.append('hard-coded purchase price found: ' + forbidden)
if 'UserDefaults' in swift: errors.append('UserDefaults added without Privacy Manifest required-reason declaration')

# Canonical AppIcon.
source = (R/'ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md').read_text(encoding='utf-8')
expected = 'dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
if '1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu' not in source or expected not in source:
    errors.append('canonical icon source mismatch')
icon = R/'ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
materialized = icon.exists()
if materialized:
    b = icon.read_bytes()
    if hashlib.sha256(b).hexdigest() != expected: errors.append('AppIcon hash mismatch')
    elif b[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', b[16:24]) != (1024,1024) or b[25] != 2:
        errors.append('AppIcon must be canonical 1024 RGB')
else:
    warnings.append('canonical AppIcon source verified; PNG materialization pending before signed build')

# Public support/privacy/terms.
for p in ['support.html','privacy.html','terms.html']:
    s = (R/p).read_text(encoding='utf-8')
    if 'http://' in s: errors.append(p + ' has insecure link')
metadata = (R/'metadata/APP_STORE_METADATA_JA.md').read_text(encoding='utf-8')
for token in ['1,031','必須90問','displayPrice','jp.allsunday1122.yakuzaishi.monthly','jp.allsunday1122.yakuzaishi.lifetime','16+']:
    if token not in metadata: errors.append('metadata missing: ' + token)

# TestFlight-only publishing gate and fixed identifiers.
cm = (ROOT/'codemagic.yaml').read_text(encoding='utf-8')
for token in [
    'pharmacist-ios:', 'bundle_identifier: jp.allsunday1122.yakuzaishi', 'APP_STORE_CONNECT_APP_ID: "6799753724"',
    'CODEMAGIC_PROFILE_REF: yakuzaishi_appstore', 'submit_to_testflight: true', 'submit_to_app_store: false',
    'testFlightInternalTestingOnly'
]:
    if token not in cm: errors.append('Codemagic token missing: ' + token)

report = {
    'pass': not errors,
    'architecture': 'SwiftUI-native',
    'webViewRuntime': False,
    'errors': errors,
    'warnings': warnings,
    'questions': len(qs), 'active': len(active), 'excluded': len(exc), 'flexible': len(flex), 'free': len(free),
    'iconMaterialized': materialized,
    'bundleId': 'jp.allsunday1122.yakuzaishi',
    'appStoreConnectAppId': '6799753724',
    'codemagicProfileRef': 'yakuzaishi_appstore'
}
(R/'content/product/release-preflight-static.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
sys.exit(1 if errors else 0)
