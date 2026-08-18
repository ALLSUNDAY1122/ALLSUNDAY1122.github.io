#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_SRC="$REPO_ROOT/apps/sanitary-manager-2"
WEB_DST="$SCRIPT_DIR/HealthManager2/Web"
ASSET_DIR="$SCRIPT_DIR/HealthManager2/Assets.xcassets/AppIcon.appiconset"
APP_ICON_SOURCE="$WEB_SRC/approved-app-icon.png"

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
  q1.js q2.js q3.js q4.js q5.js q6.js q7.js q8.js q9.js
  q10.js q11.js q12.js q13.js q14.js q15.js q16.js
  audit-patch-v2.js audit-fixes.js question-order-v1.js
  gm1.js gm2.js gm3.js gm4.js
  manifest.json icon.svg
)

for file in "${files[@]}"; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

test -f "$APP_ICON_SOURCE" || { echo "Missing approved AppIcon: $APP_ICON_SOURCE" >&2; exit 1; }

# WKWebView loads bundled assets from file://, so the website service worker is
# intentionally omitted. All required learning assets are already inside the app.

if command -v magick >/dev/null 2>&1; then
  # Always derive release icons from the user-approved canonical PNG. Never
  # regenerate the artwork from the old placeholder icon.svg.
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
