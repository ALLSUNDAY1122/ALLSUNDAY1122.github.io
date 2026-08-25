#!/bin/bash
# Canonical First-class Health Manager AppIcon materialization.
# Source: user-approved artwork transported in approved-icon-v1/part01..04.b64.
# The reconstructed WebP must match the exact approved byte count and SHA.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARTS_DIR="$SCRIPT_DIR/approved-icon-v1"
ICONSET="$SCRIPT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
EXPECTED_BYTES=43200
EXPECTED_SHA="ac8f0c2c050801ed2121bdd50494fdcafcec8af89a1d7811cd044b8977dd2d59"
TMP_WEBP="$(mktemp -t hm1-approved.XXXXXX.webp)"
TMP_PNG="$(mktemp -t hm1-approved.XXXXXX.png)"
trap 'rm -f "$TMP_WEBP" "$TMP_PNG"' EXIT

for n in 01 02 03 04; do
  test -f "$PARTS_DIR/part${n}.b64" || { echo "Missing approved icon part${n}.b64" >&2; exit 1; }
done
COUNT=$(find "$PARTS_DIR" -maxdepth 1 -type f -name 'part*.b64' | wc -l | tr -d ' ')
test "$COUNT" = "4" || { echo "Approved icon transport must contain exactly 4 parts" >&2; exit 1; }

python3 - "$PARTS_DIR" "$TMP_WEBP" <<'PY'
from pathlib import Path
import base64,sys
root=Path(sys.argv[1]); out=Path(sys.argv[2])
alphabet=set('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/')
chunks=[]
for n in ('01','02','03','04'):
    raw=(root/f'part{n}.b64').read_text(encoding='utf-8')
    payload=''.join(c for c in raw if c in alphabet)
    payload += '=' * ((-len(payload)) % 4)
    chunks.append(base64.b64decode(payload,validate=True))
out.write_bytes(b''.join(chunks))
PY

python3 - "$TMP_WEBP" "$EXPECTED_BYTES" "$EXPECTED_SHA" <<'PY'
from pathlib import Path
import hashlib,struct,sys
p=Path(sys.argv[1]); expected_bytes=int(sys.argv[2]); expected_sha=sys.argv[3]
b=p.read_bytes()
assert len(b)==expected_bytes, f'approved icon bytes {len(b)}/{expected_bytes}'
assert b[:4]==b'RIFF' and b[8:12]==b'WEBP', 'approved icon transport is not a WebP RIFF container'
assert struct.unpack('<I',b[4:8])[0]+8==len(b), 'WebP RIFF length mismatch'
sha=hashlib.sha256(b).hexdigest()
assert sha==expected_sha, f'approved icon SHA mismatch: {sha}'
print(f'PASS: approved HM1 artwork verified ({len(b)} bytes, {sha})')
PY

if ! command -v dwebp >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install webp
  else
    echo "dwebp is required to materialize the approved HM1 icon" >&2
    exit 1
  fi
fi
dwebp "$TMP_WEBP" -o "$TMP_PNG" >/dev/null 2>&1
mkdir -p "$ICONSET"

# Codemagic runs on macOS, where sips is deterministic enough for asset-catalog
# resizing and does not require a Python imaging package. Linux CI falls back to
# Pillow, which is installed by the icon verification workflow.
if command -v sips >/dev/null 2>&1; then
  while read -r name px; do
    sips -z "$px" "$px" "$TMP_PNG" --out "$ICONSET/$name" >/dev/null
  done <<'SIZES'
icon-20@2x.png 40
icon-20@3x.png 60
icon-29@2x.png 58
icon-29@3x.png 87
icon-40@2x.png 80
icon-40@3x.png 120
icon-60@2x.png 120
icon-60@3x.png 180
icon-1024.png 1024
SIZES
else
  python3 - "$TMP_PNG" "$ICONSET" <<'PY'
from pathlib import Path
from PIL import Image
import sys
src=Path(sys.argv[1]); root=Path(sys.argv[2])
with Image.open(src) as opened:
    rgb=opened.convert('RGB')
resampling=getattr(Image,'Resampling',Image).LANCZOS
sizes={'icon-20@2x.png':40,'icon-20@3x.png':60,'icon-29@2x.png':58,'icon-29@3x.png':87,'icon-40@2x.png':80,'icon-40@3x.png':120,'icon-60@2x.png':120,'icon-60@3x.png':180,'icon-1024.png':1024}
for name,px in sizes.items():
    rgb.resize((px,px),resampling).save(root/name,format='PNG',optimize=True)
PY
fi

python3 - "$ICONSET" <<'PY'
from pathlib import Path
import hashlib,json,struct,sys
root=Path(sys.argv[1])
sizes={'icon-20@2x.png':40,'icon-20@3x.png':60,'icon-29@2x.png':58,'icon-29@3x.png':87,'icon-40@2x.png':80,'icon-40@3x.png':120,'icon-60@2x.png':120,'icon-60@3x.png':180,'icon-1024.png':1024}
manifest=[]
for name,px in sizes.items():
    p=root/name; b=p.read_bytes()
    assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR', name
    w,h=struct.unpack('>II',b[16:24]); color_type=b[25]
    assert (w,h)==(px,px), f'{name}: {(w,h)}/{px}'
    assert color_type not in (4,6), f'{name}: alpha channel is not allowed'
    manifest.append({'filename':name,'pixels':px,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
print(json.dumps({'approvedSourceSha256':'ac8f0c2c050801ed2121bdd50494fdcafcec8af89a1d7811cd044b8977dd2d59','count':len(manifest),'files':manifest},ensure_ascii=False,indent=2))
PY

echo "Prepared all 9 AppIcon slots from the checksum-verified user-approved HM1 artwork."
