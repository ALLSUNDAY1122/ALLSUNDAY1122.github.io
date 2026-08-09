#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DST="$SCRIPT_DIR/Web"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"

rm -rf "$WEB_DST" "$SCRIPT_DIR/Assets.xcassets"
mkdir -p "$WEB_DST" "$ASSET_DIR"

files=(
  index.html
  style-v21.css
  questions.js
  sources-v02.js
  questions-v02-tb.js
  questions-v02-ks1.js
  questions-v02-ks2.js
  questions-v02-ks3.js
  questions-v02-ks4.js
  questions-v02-jm1.js
  questions-v02-jm2.js
  questions-v02-jm3.js
  questions-v02-jm4.js
  sources-v03.js
  questions-v03-tb.js
  questions-v03-audit1.js
  questions-v03-audit1-order.js
  questions-v03-audit1-polish.js
  questions-editorial-audit2-7.js
  questions-editorial-final-polish.js
  official-past-exam-links.js
  bootstrap-v21.js
  app-v21.js
  manifest.json
  icon.svg
)

for file in "${files[@]}"; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

# WKWebView uses bundled file:// resources. The website service worker is not
# bundled because all learning assets required by the native app are local.

if command -v magick >/dev/null 2>&1; then
  magick "$WEB_SRC/icon.svg" -background '#f7f3ea' -alpha remove -alpha off -resize 1024x1024 "$ASSET_DIR/AppIcon.png"
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
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Prepared TsukanshiSprint audited web bundle and App Store icon."
