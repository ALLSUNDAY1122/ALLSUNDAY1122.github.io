#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX="$SCRIPT_DIR/Resources/index.html"
QUESTIONS="$SCRIPT_DIR/Resources/questions.json"
ICON_SRC="$SCRIPT_DIR/learning-sprint-hm1.svg"
ICON_DIR="$SCRIPT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

python3 - "$INDEX" "$QUESTIONS" <<'PY'
from pathlib import Path
import collections, json, re, sys
index=Path(sys.argv[1]); qpath=Path(sys.argv[2])
questions=json.loads(qpath.read_text(encoding='utf-8'))
assert len(questions)==132, f'question count={len(questions)}'
assert len({q['id'] for q in questions})==132, 'duplicate ids'
rounds=collections.Counter(q['round'] for q in questions)
assert rounds=={'2026-04':44,'2025-10':44,'2025-04':44}, rounds
for r in rounds:
    labels=collections.Counter(q['label'] for q in questions if q['round']==r)
    assert labels=={'関係法令':17,'労働衛生':17,'労働生理':10}, (r,labels)
compact=json.dumps(questions,ensure_ascii=False,separators=(',',':'))
assert '</script>' not in compact.lower()
text=index.read_text(encoding='utf-8')
updated,count=re.subn(r'const QUESTIONS=\[.*?\];\nconst DOMAINS=', 'const QUESTIONS='+compact+';\nconst DOMAINS=', text, count=1, flags=re.S)
assert count==1, f'QUESTIONS replacement count={count}'
assert '2025-10-Q44' in updated and '2025-04-Q44' in updated
assert '3回分・科目別に9セット' in updated
index.write_text(updated,encoding='utf-8')
print(f'PASS: bundled audited HM1 questions={len(questions)} rounds={dict(rounds)}')
PY

if ! command -v magick >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install imagemagick
fi

test -f "$ICON_SRC"
mkdir -p "$ICON_DIR"
render() {
  local px="$1" out="$2"
  magick "$ICON_SRC" -background white -alpha remove -alpha off -resize "${px}x${px}!" "$ICON_DIR/$out"
}
render 40 icon-20@2x.png
render 60 icon-20@3x.png
render 58 icon-29@2x.png
render 87 icon-29@3x.png
render 80 icon-40@2x.png
render 120 icon-40@3x.png
render 120 icon-60@2x.png
render 180 icon-60@3x.png
render 1024 icon-1024.png

python3 - "$ICON_DIR" <<'PY'
from pathlib import Path
import struct,sys,hashlib
root=Path(sys.argv[1])
expected={'icon-20@2x.png':40,'icon-20@3x.png':60,'icon-29@2x.png':58,'icon-29@3x.png':87,'icon-40@2x.png':80,'icon-40@3x.png':120,'icon-60@2x.png':120,'icon-60@3x.png':180,'icon-1024.png':1024}
for name,px in expected.items():
    b=(root/name).read_bytes()
    assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR', name
    w,h=struct.unpack('>II',b[16:24]); assert (w,h)==(px,px),(name,w,h)
print('PASS: unified Learning Sprint HM1 AppIcon rendered; canonical sha256='+hashlib.sha256((root/'icon-1024.png').read_bytes()).hexdigest())
PY
