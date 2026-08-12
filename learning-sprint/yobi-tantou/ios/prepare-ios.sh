#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK="$SCRIPT_DIR/app-icon-lock.json"
ASSETS="$SCRIPT_DIR/Assets.xcassets"
APPICON="$ASSETS/AppIcon.appiconset"
MODE="${YOBI_ICON_MODE:-canonical}"

read_lock() {
  python3 - "$LOCK" "$1" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1],encoding='utf-8'))
print(obj[sys.argv[2]])
PY
}

ICON_ID="$(read_lock canonicalDriveFileId)"
ICON_NAME="$(read_lock canonicalFileName)"

rm -rf "$ASSETS"
mkdir -p "$APPICON"
cat > "$ASSETS/Contents.json" <<'JSON'
{"info":{"author":"xcode","version":1}}
JSON

case "$MODE" in
  simulator-placeholder)
    python3 - "$APPICON/AppIcon.png" <<'PY'
import struct,sys,zlib
p=sys.argv[1]; w=h=1024
row=b'\x00'+bytes((35,57,93))*w
raw=row*h
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
open(p,'wb').write(png)
print('INFO: generated simulator-only AppIcon placeholder')
PY
    ;;
  canonical)
    TMP="$(mktemp -t yobi-appicon.XXXXXX).png"
    trap 'rm -f "$TMP"' EXIT
    curl --fail --location --silent --show-error \
      "https://drive.usercontent.google.com/download?id=${ICON_ID}&export=download&confirm=t" \
      --output "$TMP"
    python3 "$SCRIPT_DIR/verify_app_icon.py" "$TMP"
    cp "$TMP" "$APPICON/AppIcon.png"
    echo "PASS: installed canonical AppIcon $ICON_NAME"
    ;;
  *)
    echo "ERROR: unknown YOBI_ICON_MODE=$MODE" >&2
    exit 1
    ;;
esac

cat > "$APPICON/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {"author" : "xcode", "version" : 1}
}
JSON

if [ "$MODE" = "canonical" ]; then
  python3 "$SCRIPT_DIR/verify_app_icon.py" "$APPICON/AppIcon.png"
fi

echo "Prepared YobiTantouSprint AppIcon (mode: $MODE)."
