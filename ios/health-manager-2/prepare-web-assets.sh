#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_SRC="$REPO_ROOT/apps/sanitary-manager-2"
WEB_DST="$SCRIPT_DIR/HealthManager2/Web"
ASSET_DIR="$SCRIPT_DIR/HealthManager2/Assets.xcassets/AppIcon.appiconset"

rm -rf "$WEB_DST"
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
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 1024x1024 "$ASSET_DIR/AppIcon.png"
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 120x120 "$ASSET_DIR/AppIcon-120.png"
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 180x180 "$ASSET_DIR/AppIcon-180.png"
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 152x152 "$ASSET_DIR/AppIcon-152.png"
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 167x167 "$ASSET_DIR/AppIcon-167.png"
  cp "$ASSET_DIR/AppIcon-120.png" "$SCRIPT_DIR/HealthManager2/AppIcon-120.png"
  cp "$ASSET_DIR/AppIcon-152.png" "$SCRIPT_DIR/HealthManager2/AppIcon-152.png"
  cp "$ASSET_DIR/AppIcon-167.png" "$SCRIPT_DIR/HealthManager2/AppIcon-167.png"
  cp "$ASSET_DIR/AppIcon-180.png" "$SCRIPT_DIR/HealthManager2/AppIcon-180.png"
else
  echo "ImageMagick is required to generate AppIcon.png" >&2
  exit 1
fi

cat > "$ASSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "AppIcon-120.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-180.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-152.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "AppIcon-167.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Prepared HealthManager2 bundled web assets (audited content set)."
