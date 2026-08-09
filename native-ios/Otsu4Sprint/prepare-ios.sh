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

python3 - "$GENERATED_DIR/questions.generated.json" "$ICON_DIR/Icon-1024.png.b64" "$ICON_DIR/Icon-1024.png" <<'PY'
import base64,json,struct,sys
from pathlib import Path

questions_path=Path(sys.argv[1])
icon_b64_path=Path(sys.argv[2])
icon_path=Path(sys.argv[3])

data=json.loads(questions_path.read_text(encoding='utf-8'))
assert data['contentVersion']=='otsu4-2026-08-product-v2'
assert len(data['questions'])==360
print('prepared native questions:',len(data['questions']))

raw=base64.b64decode(icon_b64_path.read_text(encoding='ascii'), validate=True)
icon_path.write_bytes(raw)
sig=raw[:26]
assert sig[:8]==b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II',sig[16:24])
assert (w,h)==(1024,1024), (w,h)
color_type=sig[25]
assert color_type==2, f'App Store icon must be RGB without alpha; PNG color type={color_type}'
print('prepared app icon:',w,'x',h,'RGB/no-alpha')
PY
