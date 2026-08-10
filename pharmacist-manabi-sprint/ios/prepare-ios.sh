#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
GEN="$IOS/Generated"
ICON="$IOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

rm -rf "$GEN"
mkdir -p "$GEN"

python3 - "$ROOT/content/product/questions.json" "$GEN/questions.native.json" "$ROOT" "$GEN" <<'PY'
from pathlib import Path
import json, shutil, sys

src = Path(sys.argv[1])
out = Path(sys.argv[2])
root = Path(sys.argv[3])
gen = Path(sys.argv[4])
data = json.loads(src.read_text(encoding='utf-8'))
raw = data.get('questions', [])
assert len(raw) == 1035, len(raw)

questions = []
active = excluded = flexible = free = 0
media_copied = set()
for q in raw:
    scoring = q.get('scoring_status', 'normal')
    if scoring == 'excluded': excluded += 1
    else: active += 1
    if scoring == 'multiple_accepted': flexible += 1
    exam = int(q.get('sourceExam') or 0)
    section = str(q.get('subject') or '')
    if scoring != 'excluded' and exam == 111 and section == '必須': free += 1

    answer = q.get('answer')
    if isinstance(answer, int): answer = [answer]
    elif not isinstance(answer, list): answer = []
    accepted = q.get('accepted_answers')
    if not isinstance(accepted, list): accepted = []

    mode = str(q.get('displayMode') or 'textChoices')
    choices = q.get('choices') if isinstance(q.get('choices'), list) else []
    # Official-image questions use the numbered native answer controls and do not trust
    # partially extracted text choices as the visible source of truth.
    if mode == 'officialQuestionImage': choices = []

    media_assets = []
    for rel in q.get('mediaAssets') or []:
        rel = str(rel).replace('\\', '/')
        source = root / rel
        assert source.exists() and source.stat().st_size > 1000, f'media missing: {rel}'
        target = gen / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if rel not in media_copied:
            shutil.copy2(source, target)
            media_copied.add(rel)
        media_assets.append(rel)

    questions.append({
        'id': str(q['id']),
        'exam': exam,
        'questionNo': int(q.get('questionNo') or 0),
        'section': section,
        'field': str(q.get('domain') or ''),
        'question': str(q.get('question') or ''),
        'choices': [str(x) for x in choices],
        'answer': [int(x) for x in answer],
        'acceptedAnswers': [[int(v) for v in x] for x in accepted if isinstance(x, list)],
        'scoringStatus': scoring,
        'memoryPoint': str(q.get('memoryPoint') or ''),
        'explanation': str(q.get('explanation') or ''),
        'sharedStem': str(q.get('sharedStem') or ''),
        'displayMode': mode,
        'mediaAssets': media_assets,
        'numberedChoiceCount': int(q.get('numberedChoiceCount') or 0),
        'attribution': str(q.get('attributionDisplay') or f"出典：厚生労働省『第{exam}回薬剤師国家試験問題及び解答』"),
        'modificationDisclosure': str(q.get('modificationDisclosureDisplay') or '厚生労働省公開問題をもとに、学習表示・解説を加工して作成'),
        'canonicalId': str(q.get('dailySprintCanonicalId') or q['id']),
    })

assert (active, excluded, flexible, free) == (1031, 4, 3, 90), (active, excluded, flexible, free)
assert all(q['id'] and q['exam'] in (109,110,111) and q['section'] in ('必須','理論','実践') for q in questions)
assert all(q['memoryPoint'] and q['explanation'] for q in questions)

bundle = {
    'schemaVersion': 1,
    'contentVersion': str(data.get('contentVersion') or 'pharmacist-native-111-110-109-v1'),
    'questions': questions,
}
out.write_text(json.dumps(bundle, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
print(json.dumps({'questions':len(questions),'active':active,'excluded':excluded,'flexible':flexible,'free':free,'mediaAssets':len(media_copied)}, ensure_ascii=False))
PY

if [[ ! -f "$ICON" && "${PREFLIGHT_PLACEHOLDER_ICON:-0}" == "1" ]]; then
python3 - "$ICON" <<'PY'
import struct,zlib,binascii,sys
w=h=1024; row=b'\x00'+bytes((47,74,109))*w; raw=row*h
def c(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',binascii.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+c(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+c(b'IDAT',zlib.compress(raw,9))+c(b'IEND',b'')
open(sys.argv[1],'wb').write(png)
print('PREFLIGHT ONLY: generated non-release placeholder icon')
PY
fi

if [[ ! -f "$ICON" ]]; then
  echo "ERROR: canonical AppIcon missing. Materialize Drive file 1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu as $ICON" >&2
  exit 2
fi
python3 - "$ICON" "${PREFLIGHT_PLACEHOLDER_ICON:-0}" <<'PY'
import hashlib,struct,sys
b=open(sys.argv[1],'rb').read(); pre=sys.argv[2]=='1'; expect='dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR' and struct.unpack('>II',b[16:24])==(1024,1024) and b[25]==2
if not pre: assert hashlib.sha256(b).hexdigest()==expect,'AppIcon SHA-256 mismatch'
print('PASS: '+('simulator placeholder' if pre else 'canonical AppIcon'))
PY

echo "PASS: prepared PharmacistSprint native SwiftUI resources"
