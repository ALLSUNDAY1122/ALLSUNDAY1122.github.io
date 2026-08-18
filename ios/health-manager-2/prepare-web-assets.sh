#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_SRC="$REPO_ROOT/apps/sanitary-manager-2"
WEB_DST="$SCRIPT_DIR/HealthManager2/Web"
ASSET_DIR="$SCRIPT_DIR/HealthManager2/Assets.xcassets/AppIcon.appiconset"
APP_ICON_SOURCE="$WEB_SRC/approved-app-icon.png"
ICON_PARTS_DIR="$WEB_SRC/approved-icon-v4"
ICON_TRANSPORT_SHA256="4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c"

# Every Apple upload needs a unique CFBundleVersion. Codemagic supplies a
# monotonically increasing build number; apply it before XcodeGen runs.
if [ -n "${CM_BUILD_NUMBER:-}" ]; then
  python3 - "$SCRIPT_DIR/project.yml" "$CM_BUILD_NUMBER" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
build_number = sys.argv[2]
text = p.read_text(encoding='utf-8')
updated, count = re.subn(r'(?m)^(\s*CURRENT_PROJECT_VERSION:\s*)\d+\s*$', rf'\g<1>{build_number}', text, count=1)
if count != 1:
    raise SystemExit('CURRENT_PROJECT_VERSION was not updated exactly once')
p.write_text(updated, encoding='utf-8')
print(f'PASS: HealthManager2 CURRENT_PROJECT_VERSION={build_number}')
PY
fi

rm -rf "$WEB_DST"
rm -rf "$SCRIPT_DIR/HealthManager2/Assets.xcassets"
mkdir -p "$WEB_DST" "$ASSET_DIR"

files=(
  index.html
  gm-style.css
  q1.js q2.js q3.js q4.js q5.js q6.js q7.js q8.js q9.js q10.js q11.js q12.js
  audit-patch-v2.js audit-patch-v3.js audit-patch-v4.js audit-fixes.js question-order-v1.js
  gm1.js gm2.js gm3.js gm4.js
  manifest.json icon.svg
)

for file in "${files[@]}"; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

# The artwork was explicitly user-approved. v4 stores a compression-only WebP
# derivative of the exact approved Drive PNG in four deterministic chunks.
# Reconstruct only that verified payload; never redraw/relabel the icon and never
# fall back to the historical placeholder icon.svg.
if [ ! -f "$APP_ICON_SOURCE" ]; then
  test -d "$ICON_PARTS_DIR" || { echo "Missing approved AppIcon transport: $ICON_PARTS_DIR" >&2; exit 1; }
  PART_COUNT=$(find "$ICON_PARTS_DIR" -maxdepth 1 -type f -name 'part*.b64' | wc -l | tr -d ' ')
  test "$PART_COUNT" = "4" || { echo "Approved AppIcon transport must contain exactly 4 parts, got $PART_COUNT" >&2; exit 1; }
  TMP_WEBP="$(mktemp -t sm2-approved-icon.XXXXXX.webp)"
  cat "$ICON_PARTS_DIR"/part01.b64 "$ICON_PARTS_DIR"/part02.b64 "$ICON_PARTS_DIR"/part03.b64 "$ICON_PARTS_DIR"/part04.b64 | tr -d '\r\n' | base64 --decode > "$TMP_WEBP"
  python3 - "$TMP_WEBP" "$ICON_TRANSPORT_SHA256" <<'PY'
from pathlib import Path
import hashlib, struct, sys
p=Path(sys.argv[1]); expected_sha=sys.argv[2]
b=p.read_bytes()
assert len(b)==28904, f'approved icon bytes {len(b)}/28904'
assert b[:4]==b'RIFF' and b[8:12]==b'WEBP', 'approved icon transport is not WebP RIFF'
assert struct.unpack('<I', b[4:8])[0]+8 == len(b), 'approved icon RIFF length mismatch'
sha=hashlib.sha256(b).hexdigest()
assert sha==expected_sha, f'approved icon SHA mismatch: {sha}'
print(f'PASS: approved icon transport v4 verified ({len(b)} bytes, {sha})')
PY
  if command -v magick >/dev/null 2>&1; then
    magick "$TMP_WEBP" -alpha off "$APP_ICON_SOURCE"
  else
    echo "ImageMagick is required to reconstruct approved AppIcon transport" >&2
    exit 1
  fi
  rm -f "$TMP_WEBP"
fi

test -f "$APP_ICON_SOURCE" || { echo "Missing approved AppIcon: $APP_ICON_SOURCE" >&2; exit 1; }

# WKWebView loads bundled assets from file://, so the website service worker is
# intentionally omitted. All required learning assets are already inside the app.

if command -v magick >/dev/null 2>&1; then
  # Always derive release icon sizes from the approved canonical artwork. Never
  # regenerate the artwork itself from icon.svg.
  magick "$APP_ICON_SOURCE" -background '#f7f3ea' -alpha remove -alpha off -resize 1024x1024 "$ASSET_DIR/AppIcon-1024.png"
  cp "$ASSET_DIR/AppIcon-1024.png" "$ASSET_DIR/AppIcon.png"

  magick "$APP_ICON_SOURCE" -background '#f7f3ea' -alpha remove -alpha off -resize 120x120 "$SCRIPT_DIR/HealthManager2/AppIcon-120.png"
  magick "$APP_ICON_SOURCE" -background '#f7f3ea' -alpha remove -alpha off -resize 152x152 "$SCRIPT_DIR/HealthManager2/AppIcon-152.png"
  magick "$APP_ICON_SOURCE" -background '#f7f3ea' -alpha remove -alpha off -resize 167x167 "$SCRIPT_DIR/HealthManager2/AppIcon-167.png"
  magick "$APP_ICON_SOURCE" -background '#f7f3ea' -alpha remove -alpha off -resize 180x180 "$SCRIPT_DIR/HealthManager2/AppIcon-180.png"
else
  echo "ImageMagick is required to generate AppIcon assets" >&2
  exit 1
fi

python3 - "$ASSET_DIR/AppIcon-1024.png" "$SCRIPT_DIR/HealthManager2" <<'PY'
from pathlib import Path
import struct, sys
expected = {
    'AppIcon-1024.png': (1024, 1024),
    'AppIcon-120.png': (120, 120),
    'AppIcon-152.png': (152, 152),
    'AppIcon-167.png': (167, 167),
    'AppIcon-180.png': (180, 180),
}
paths = {'AppIcon-1024.png': Path(sys.argv[1])}
root = Path(sys.argv[2])
for name in expected:
    if name != 'AppIcon-1024.png':
        paths[name] = root / name
for name, p in paths.items():
    b = p.read_bytes()
    assert b[:8] == b'\x89PNG\r\n\x1a\n', f'{name}: must be PNG'
    assert b[12:16] == b'IHDR', f'{name}: invalid PNG header'
    w, h = struct.unpack('>II', b[16:24])
    assert (w, h) == expected[name], (name, w, h)
print('PASS: approved AppIcon source and legacy icon dimensions verified')
PY

cat > "$ASSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
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

echo "Prepared HealthManager2 300-question web assets and approved AppIcon resources."
