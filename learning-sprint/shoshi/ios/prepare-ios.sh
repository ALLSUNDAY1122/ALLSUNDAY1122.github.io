#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHOSHI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_SRC="$SHOSHI_ROOT/mvp"
QUESTIONS_SRC="$SHOSHI_ROOT/content-loop/questions.generated.json"
WEB_DST="$SCRIPT_DIR/Web"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON_SRC="$SCRIPT_DIR/AppIcon.png"

rm -rf "$WEB_DST" "$SCRIPT_DIR/Assets.xcassets"
mkdir -p "$WEB_DST" "$ASSET_DIR"

for file in index.html styles.css polish.css app.js manifest.webmanifest; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

test -f "$QUESTIONS_SRC"
cp "$QUESTIONS_SRC" "$WEB_DST/questions.generated.json"
test -f "$SCRIPT_DIR/native-storekit.js"
cp "$SCRIPT_DIR/native-storekit.js" "$WEB_DST/native-storekit.js"

python3 - "$WEB_DST/index.html" "$WEB_DST/app.js" <<'PY'
from pathlib import Path
import sys
index=Path(sys.argv[1])
app=Path(sys.argv[2])
html=index.read_text(encoding='utf-8')
needle='  <script src="app.js" defer></script>'
if needle not in html:
    raise SystemExit('ERROR: app.js script marker not found')
html=html.replace(needle, '  <script src="native-storekit.js" defer></script>\n'+needle, 1)
index.write_text(html, encoding='utf-8')
js=app.read_text(encoding='utf-8')
old="const DATA_URL = '../content-loop/questions.generated.json';"
if old not in js:
    raise SystemExit('ERROR: question data URL marker not found')
js=js.replace(old, "const DATA_URL = './questions.generated.json';", 1)
old_call='    setupServiceWorker();'
new_call="    if (location.protocol !== 'file:') setupServiceWorker();"
if old_call not in js:
    raise SystemExit('ERROR: service-worker init marker not found')
js=js.replace(old_call, new_call, 1)
app.write_text(js, encoding='utf-8')
PY

# The adopted series icon is a canonical individual PNG from Google Drive.
# It must be checked into AppIcon.png without regeneration or list-image cropping.
test -f "$ICON_SRC"
cp "$ICON_SRC" "$ASSET_DIR/AppIcon.png"

cat > "$ASSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

python3 - "$WEB_DST/questions.generated.json" <<'PY'
import json,sys,hashlib
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert isinstance(data,list) and len(data)==210
assert len({q['id'] for q in data})==210
q=next(x for x in data if x['id']=='SHOSHI-R7-PM-33')
assert q.get('scoring_status')=='all_correct' and q.get('official_answer_no') is None
print('PASS: bundled 210-question dataset, unique IDs, and R7-PM-33 all_correct')
print('SHA256:', hashlib.sha256(open(p,'rb').read()).hexdigest())
PY

echo "Prepared ShoshiSprint local audited web bundle and canonical AppIcon."
