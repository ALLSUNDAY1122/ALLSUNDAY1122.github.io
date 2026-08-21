#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATED_DIR="$SCRIPT_DIR/Generated"
ICON_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON_PATH="$ICON_DIR/Icon-1024.png"
EXPECTED_ICON_SHA="d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d"

cd "$REPO_ROOT"
node tools/otsu4-build-content-v2.mjs
node tools/otsu4-apply-difficulty-hardening.mjs
node tools/otsu4-difficulty-audit.mjs
mkdir -p "$GENERATED_DIR" "$ICON_DIR"
cp kikenbutsu-otsu4-sprint/questions.generated.json "$GENERATED_DIR/questions.generated.json"

test -f "$ICON_PATH" || {
  echo "FAIL: canonical AppIcon is missing: $ICON_PATH" >&2
  exit 1
}

python3 - "$GENERATED_DIR/questions.generated.json" "$ICON_PATH" "$EXPECTED_ICON_SHA" <<'PY'
import hashlib,json,struct,sys
from pathlib import Path

questions_path=Path(sys.argv[1])
icon_path=Path(sys.argv[2])
expected_sha=sys.argv[3]

data=json.loads(questions_path.read_text(encoding='utf-8'))
assert data['contentVersion']=='otsu4-2026-08-product-v2'
assert len(data['questions'])==360
assert data.get('difficultyAudit',{}).get('policy')=='2026-08 exam-level v1'
print('prepared native questions:',len(data['questions']))

png=icon_path.read_bytes()
actual_sha=hashlib.sha256(png).hexdigest()
assert actual_sha==expected_sha, f'canonical AppIcon SHA mismatch: {actual_sha}'
assert png[:8]==b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II',png[16:24])
assert (w,h)==(1024,1024), (w,h)
assert png[25]==2, f'App Store icon must be RGB without alpha; PNG color type={png[25]}'
print('verified canonical app icon:',w,'x',h,'RGB/no-alpha',len(png),'bytes',actual_sha)
PY
