#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATED_DIR="$SCRIPT_DIR/Generated"
ICON_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"

cd "$REPO_ROOT"
node tools/otsu4-build-content-v2.mjs
mkdir -p "$GENERATED_DIR"
cp kikenbutsu-otsu4-sprint/questions.generated.json "$GENERATED_DIR/questions.generated.json"

python3 - "$GENERATED_DIR/questions.generated.json" <<'PY'
import json,sys
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert data['contentVersion']=='otsu4-2026-08-product-v2'
assert len(data['questions'])==360
print('prepared native questions:',len(data['questions']))
PY

base64 --decode "$ICON_DIR/Icon-1024.png.b64" > "$ICON_DIR/Icon-1024.png" 2>/dev/null || \
base64 -D "$ICON_DIR/Icon-1024.png.b64" > "$ICON_DIR/Icon-1024.png"

python3 - "$ICON_DIR/Icon-1024.png" <<'PY'
import struct,sys
p=sys.argv[1]
with open(p,'rb') as f:
    sig=f.read(24)
assert sig[:8]==b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II',sig[16:24])
assert (w,h)==(1024,1024), (w,h)
print('prepared app icon:',w,'x',h)
PY
