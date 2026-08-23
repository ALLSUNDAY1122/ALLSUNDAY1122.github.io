#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX="$SCRIPT_DIR/Resources/index.html"
QUESTIONS="$SCRIPT_DIR/Resources/questions.json"
ICON_DIR="$SCRIPT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

# Expand the canonical 132 HM1 bank with 132 already-audited common-scope
# questions from the HealthManager2 five-year expansion. The augmentation script
# rejects unpublished/unaudited items and near-duplicate stems.
node "$SCRIPT_DIR/augment-to-264.cjs"

# Difficulty gate: do not ship questions that can be solved by obvious dummy
# choices, answer-length cues, or extreme wording without domain knowledge.
node "$SCRIPT_DIR/audit/difficulty-audit-2026-08-21.cjs"

python3 - "$INDEX" "$QUESTIONS" <<'PY'
from pathlib import Path
import collections, json, re, sys
index=Path(sys.argv[1]); qpath=Path(sys.argv[2])
questions=json.loads(qpath.read_text(encoding='utf-8'))
assert len(questions)==264, f'question count={len(questions)}'
assert len({q['id'] for q in questions})==264, 'duplicate ids'
rounds=collections.Counter(q['round'] for q in questions)
expected_rounds={'2026-04':44,'2025-10':44,'2025-04':44,'practice-A':44,'practice-B':44,'practice-C':44}
assert rounds==expected_rounds, rounds
for r in ['2026-04','2025-10','2025-04']:
    labels=collections.Counter(q['label'] for q in questions if q['round']==r)
    assert labels=={'関係法令':17,'労働衛生':17,'労働生理':10}, (r,labels)
for r in ['practice-A','practice-B','practice-C']:
    labels=collections.Counter(q['label'] for q in questions if q['round']==r)
    assert sum(labels.values())==44 and set(labels)=={'関係法令','労働衛生','労働生理'}, (r,labels)

compact=json.dumps(questions,ensure_ascii=False,separators=(',',':'))
assert '</script>' not in compact.lower()
text=index.read_text(encoding='utf-8')
updated,count=re.subn(r'const QUESTIONS=\[.*?\];\nconst DOMAINS=', 'const QUESTIONS='+compact+';\nconst DOMAINS=', text, count=1, flags=re.S)
assert count==1, f'QUESTIONS replacement count={count}'

round_defs=[
 {'id':'2026-04','title':'2026年4月公表回対応','period':'2025年7〜12月実施分'},
 {'id':'2025-10','title':'2025年10月公表回対応','period':'2025年1〜6月実施分'},
 {'id':'2025-04','title':'2025年4月公表回対応','period':'2024年7〜12月実施分'},
 {'id':'practice-A','title':'追加演習A','period':'監査済み共通範囲・44問'},
 {'id':'practice-B','title':'追加演習B','period':'監査済み共通範囲・44問'},
 {'id':'practice-C','title':'追加演習C','period':'監査済み共通範囲・44問'},
]
round_js='const ROUNDS='+json.dumps(round_defs,ensure_ascii=False,separators=(',',':'))+';'
updated,n=re.subn(r'const ROUNDS\s*=\s*\[.*?\];',round_js,updated,count=1,flags=re.S)
if n==0:
    marker="const DOMAINS=['関係法令','労働衛生','労働生理'];"
    assert marker in updated, 'DOMAINS insertion marker missing'
    updated=updated.replace(marker,marker+'\n'+round_js,1)
else:
    assert n==1, f'ROUNDS replacement count={n}'

# Release UI must match the final 264-question product and current Japan-only
# StoreKit price points. TestFlight previously surfaced stale USD metadata even
# though the Apple purchase sheet showed the canonical JPY 800 price.
updated=updated.replace('3回分・科目別に9セット','公表回3＋追加演習3・合計264問')
updated=updated.replace('3回分を科目ごとに。1科目ずつでも通しでも解けます。','公表回3回分＋追加演習3セット。1科目ずつでも44問通しでも解けます。')
updated=updated.replace("monthlyPrice:'月額200円',lifetimePrice:'980円'", "monthlyPrice:'¥200',lifetimePrice:'¥800'")
updated=updated.replace('全132問','全264問')
updated=updated.replace('独自問題132問を収録しています。','公表回対応132問＋追加演習132問、合計264問を収録しています。')

assert 'const ROUNDS=' in updated
assert 'practice-C-Q44' in updated
assert '合計264問' in updated
assert '全132問' not in updated
assert '980円' not in updated
assert "monthlyPrice:'¥200',lifetimePrice:'¥800'" in updated
index.write_text(updated,encoding='utf-8')
print(f'PASS: bundled audited HM1 questions={len(questions)} rounds={dict(rounds)} JPY paywall=200/800')
PY

# The approved unified Learning Sprint AppIcon PNGs are versioned assets.
# Do not re-render them during release builds: SVG text rendering depends on
# host fonts and can change/fail across macOS images. Validate the committed
# approved files and dimensions instead.
python3 - "$ICON_DIR" <<'PY'
from pathlib import Path
import json, struct, sys, hashlib
root=Path(sys.argv[1])
expected={
 'icon-20@2x.png':40,'icon-20@3x.png':60,
 'icon-29@2x.png':58,'icon-29@3x.png':87,
 'icon-40@2x.png':80,'icon-40@3x.png':120,
 'icon-60@2x.png':120,'icon-60@3x.png':180,
 'icon-1024.png':1024,
}
contents=json.loads((root/'Contents.json').read_text(encoding='utf-8'))
listed={x.get('filename') for x in contents.get('images',[]) if x.get('filename')}
assert listed==set(expected), (listed,set(expected))
for name,px in expected.items():
    b=(root/name).read_bytes()
    assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR', name
    w,h=struct.unpack('>II',b[16:24])
    assert (w,h)==(px,px),(name,w,h,px)
print('PASS: approved unified Learning Sprint HM1 AppIcon assets verified; canonical sha256='+hashlib.sha256((root/'icon-1024.png').read_bytes()).hexdigest())
PY
