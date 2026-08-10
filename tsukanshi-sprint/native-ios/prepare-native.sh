#!/usr/bin/env bash
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$NATIVE_DIR/../.." && pwd)"
APP_DIR="$ROOT_DIR/tsukanshi-sprint"
RESOURCE_DIR="$NATIVE_DIR/Resources"

cd "$APP_DIR"
node validate-content.mjs
node validate-editorial-final.mjs
test -f native-source-audit-legacy.json
mkdir -p "$RESOURCE_DIR"
node export-native-content.mjs "$RESOURCE_DIR/tsukanshi-questions.json"

python3 - "$RESOURCE_DIR/tsukanshi-questions.json" <<'PY'
import json,re,sys
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
questions=data['questions']
assert data['studyQuestionCount']==480
assert data['declarationCount']==12
assert len(questions)==492
assert data['lawBaselineDate']=='2026-07-01'
assert all(q['contentVersion']==data['contentVersion'] for q in questions)
assert all(re.fullmatch(r'\d{4}-\d{2}-\d{2}',q['sourceCheckedAt']) for q in questions)
assert all(re.fullmatch(r'\d{4}-\d{2}-\d{2}',q['lawBaselineDate']) for q in questions)
assert all(q.get('rightsBasis') for q in questions)
assert all('officialPastExam' not in q.get('rightsBasis','') for q in questions)
assert all(q['sourceRefs'] or 'sourceType=appMetadata' in q['rightsBasis'] for q in questions)
print('PASS: native JSON 480 study + 12 declaration / evidence metadata preserved')
print('INFO: structured metadata warnings =',len(data.get('auditWarnings',[])))
for warning in data.get('auditWarnings',[])[:5]: print('WARN:',warning)
PY

plutil -lint "$NATIVE_DIR/PrivacyInfo.xcprivacy"

grep -q 'jp.allsunday1122.tsukanshi' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q '6799753744' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q 'tsukanshi_appstore' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q 'MN3D2ZM44N' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
! grep -R -n -E 'WKWebView|import WebKit|UIViewRepresentable' "$NATIVE_DIR" --include='*.swift'
! grep -q "'2026-08-09'" export-native-content.mjs

echo 'PASS: Tsukanshi native preparation and no-WebView gate'
