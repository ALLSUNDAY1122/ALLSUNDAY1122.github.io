#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHOSHI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUESTIONS_SRC="$SHOSHI_ROOT/content-loop/questions.generated.json"
RESOURCES="$SCRIPT_DIR/Resources"
ICON="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
ICON_SHA256="c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506"

mkdir -p "$RESOURCES"
cp "$QUESTIONS_SRC" "$RESOURCES/questions.generated.json"

test -f "$ICON"
actual_icon_sha="$(shasum -a 256 "$ICON" | awk '{print $1}')"
test "$actual_icon_sha" = "$ICON_SHA256"

python3 - "$RESOURCES/questions.generated.json" <<'PY'
import json,sys,hashlib
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert isinstance(data,list) and len(data)==210
assert len({q['id'] for q in data})==210
q=next(x for x in data if x['id']=='SHOSHI-R7-PM-33')
assert q.get('scoring_status')=='all_correct' and q.get('official_answer_no') is None
print('PASS: pure-native bundle has audited 210 questions and R7-PM-33 all_correct')
print('QuestionsSHA256:',hashlib.sha256(open(p,'rb').read()).hexdigest())
PY

if grep -R -nE 'import[[:space:]]+WebKit|WKWebView|UIViewRepresentable' "$SCRIPT_DIR" --include='*.swift'; then
  echo 'ERROR: WebView/WebKit implementation is forbidden for ShoshiSprint' >&2
  exit 1
fi

echo "PASS: canonical AppIcon SHA256=$actual_icon_sha"
echo 'PASS: ShoshiSprint native resources prepared; no WebKit/WKWebView source.'
