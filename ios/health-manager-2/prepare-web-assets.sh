#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_SRC="$REPO_ROOT/apps/sanitary-manager-2"
WEB_DST="$SCRIPT_DIR/HealthManager2/Web"
ASSET_DIR="$SCRIPT_DIR/HealthManager2/Assets.xcassets/AppIcon.appiconset"

rm -rf "$WEB_DST"
rm -rf "$SCRIPT_DIR/HealthManager2/Assets.xcassets"
mkdir -p "$WEB_DST" "$ASSET_DIR"

files=(
  index.html
  gm-style.css
  q1.js q2.js q3.js q4.js q5.js q6.js q7.js q8.js q9.js
  audit-patch-v2.js audit-fixes.js question-order-v1.js
  gm1.js gm2.js gm3.js gm4.js
  manifest.json icon.svg
)

for file in "${files[@]}"; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

# WKWebView loads bundled assets from file://, so the website service worker is
# intentionally omitted. All required learning assets are already inside the app.

if command -v magick >/dev/null 2>&1; then
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 1024x1024 "$ASSET_DIR/AppIcon-1024.png"
else
  echo "ImageMagick is required to generate AppIcon-1024.png" >&2
  exit 1
fi

python3 - "$ASSET_DIR/AppIcon-1024.png" <<'PY'
from pathlib import Path
import struct, sys
p = Path(sys.argv[1])
b = p.read_bytes()
assert b[:8] == b'\x89PNG\r\n\x1a\n', 'AppIcon must be PNG'
assert b[12:16] == b'IHDR', 'invalid PNG header'
w, h = struct.unpack('>II', b[16:24])
assert (w, h) == (1024, 1024), (w, h)
print('PASS: AppIcon source is 1024x1024 PNG')
PY

# Match the known-good learning-sprint Xcode 15/16 single-size AppIcon catalog.
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

echo "Prepared HealthManager2 bundled web assets and compiled AppIcon catalog inputs."
