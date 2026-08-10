#!/usr/bin/env bash
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$NATIVE_DIR/../.." && pwd)"
APP_DIR="$ROOT_DIR/tsukanshi-sprint"
RESOURCE_DIR="$NATIVE_DIR/Resources"

cd "$APP_DIR"
node validate-content.mjs
node validate-editorial-final.mjs
mkdir -p "$RESOURCE_DIR"
node export-native-content.mjs "$RESOURCE_DIR/tsukanshi-questions.json"

python3 - "$RESOURCE_DIR/tsukanshi-questions.json" <<'PY'
import json,sys
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert data['studyQuestionCount']==480
assert data['declarationCount']==12
assert len(data['questions'])==492
assert data['lawBaselineDate']=='2026-07-01'
assert all(q['contentVersion']==data['contentVersion'] for q in data['questions'])
assert all(q['sourceCheckedAt'] and q['lawBaselineDate'] for q in data['questions'])
assert not any(q.get('rightsBasis')=='officialPastExam' for q in data['questions'])
print('PASS: native JSON 480 study + 12 declaration / metadata preserved')
PY

plutil -lint "$NATIVE_DIR/PrivacyInfo.xcprivacy" >/dev/null 2>&1 || true

grep -q 'jp.allsunday1122.tsukanshi' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q '6799753744' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q 'tsukanshi_appstore' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
grep -q 'MN3D2ZM44N' "$NATIVE_DIR/TsukanshiNativeConfig.swift"
! grep -R -n -E 'WKWebView|import WebKit|UIViewRepresentable' "$NATIVE_DIR" --include='*.swift'

echo 'PASS: Tsukanshi native preparation and no-WebView gate'
