#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DST="$SCRIPT_DIR/Web"

rm -rf "$WEB_DST"
mkdir -p "$WEB_DST"

for file in index.html question_bank_180.payload.json; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

# The native app is fully offline for learning. Only the audited payload is bundled.
test "$(wc -c < "$WEB_DST/question_bank_180.payload.json" | tr -d ' ')" = "234369"

# WKWebView loaded from file:// can reject fetch() for another local file even when
# read access is granted. Keep the web product fetch-based, but turn the iOS copy
# into a self-contained offline document so the audited bank is available without
# network or file-origin fetch semantics.
python3 - "$WEB_DST/index.html" "$WEB_DST/question_bank_180.payload.json" <<'PY'
from pathlib import Path
import json
import sys

html_path = Path(sys.argv[1])
bank_path = Path(sys.argv[2])
html = html_path.read_text(encoding='utf-8')
data = json.loads(bank_path.read_text(encoding='utf-8'))

# Re-serialize deterministically, and escape a possible closing script sequence.
payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
marker = '<script>\nconst LS='
if marker not in html:
    raise SystemExit('FP3 iOS prepare: product script marker missing')
html = html.replace(
    marker,
    f'<script type="application/json" id="fp3-bundled-bank">{payload}</script>\n{marker}',
    1,
)
old = "async function init(){try{const r=await fetch('./question_bank_180.payload.json',{cache:'no-store'});if(!r.ok)throw Error('教材を取得できません');const data=await r.json();"
new = "async function init(){try{const bundled=document.getElementById('fp3-bundled-bank');const data=bundled?JSON.parse(bundled.textContent):await (async()=>{const r=await fetch('./question_bank_180.payload.json',{cache:'no-store'});if(!r.ok)throw Error('教材を取得できません');return r.json()})();"
if old not in html:
    raise SystemExit('FP3 iOS prepare: init fetch marker missing')
html = html.replace(old, new, 1)
html_path.write_text(html, encoding='utf-8')

# Fail closed: the native bundle must no longer depend on file:// fetch for its bank.
out = html_path.read_text(encoding='utf-8')
if 'id="fp3-bundled-bank"' not in out or "const bundled=document.getElementById('fp3-bundled-bank')" not in out:
    raise SystemExit('FP3 iOS prepare: bundled bank injection failed')
print('Embedded audited FP3 bank into native offline HTML.')
PY

echo "Prepared FP3ManabiSprint audited web bundle."
