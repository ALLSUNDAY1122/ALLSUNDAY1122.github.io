#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON_SRC="$SCRIPT_DIR/AppIcon.png"
ICON_EXPECTED_SIZE="726223"
ICON_SHA256="294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f"
ICON_MODE="${KANRI_ICON_MODE:-canonical}"

python3 "$ROOT/scripts/build_native_questions.py"
test -f "$SCRIPT_DIR/Resources/questions.native.json"
rm -rf "$SCRIPT_DIR/Assets.xcassets"
mkdir -p "$ASSET_DIR"

case "$ICON_MODE" in
  skip)
    echo "INFO: AppIcon skipped for static audit."
    ;;
  simulator-placeholder)
    python3 - "$ASSET_DIR/AppIcon.png" <<'PY'
import struct,sys,zlib
p=sys.argv[1];w=h=1024;row=b'\x00'+bytes((47,74,109))*w;raw=row*h
def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
open(p,'wb').write(png)
print('INFO: compile-only placeholder icon; Archive/TestFlight use prohibited')
PY
    ;;
  canonical)
    if [ ! -f "$ICON_SRC" ] && [ -n "${KANRI_APPICON_BASE64:-}" ]; then
      printf '%s' "$KANRI_APPICON_BASE64" | base64 --decode > "$ICON_SRC"
      echo "INFO: canonical AppIcon materialized from KANRI_APPICON_BASE64"
    fi
    if [ ! -f "$ICON_SRC" ] && [ -n "${KANRI_APPICON_FILE_URL:-}" ]; then
      curl --fail --location --silent --show-error "$KANRI_APPICON_FILE_URL" --output "$ICON_SRC"
      echo "INFO: canonical AppIcon downloaded from explicit KANRI_APPICON_FILE_URL"
    fi
    if [ ! -f "$ICON_SRC" ]; then
      echo "ERROR: canonical AppIcon is not materialized. Set Codemagic secret KANRI_APPICON_BASE64 (preferred) or KANRI_APPICON_FILE_URL. Anonymous Google Drive fallback is intentionally disabled because it previously returned non-canonical bytes." >&2
      exit 1
    fi
    actual_size="$(wc -c < "$ICON_SRC" | tr -d ' ')"
    actual_sha="$(shasum -a 256 "$ICON_SRC" | awk '{print $1}')"
    if [ "$actual_size" != "$ICON_EXPECTED_SIZE" ] || [ "$actual_sha" != "$ICON_SHA256" ]; then
      echo "ERROR: canonical AppIcon mismatch: size=$actual_size sha=$actual_sha" >&2
      rm -f "$ICON_SRC"
      exit 1
    fi
    cp "$ICON_SRC" "$ASSET_DIR/AppIcon.png"
    echo "PASS: canonical AppIcon SHA256=${ICON_SHA256}"
    ;;
  *)
    echo "ERROR: unknown KANRI_ICON_MODE=$ICON_MODE" >&2
    exit 1
    ;;
esac

if [ "$ICON_MODE" != "skip" ]; then
cat > "$ASSET_DIR/Contents.json" <<'JSON'
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
JSON
fi

echo "PASS: prepared pure SwiftUI native resources (600 questions, icon mode: $ICON_MODE)"
