#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON_SRC="${JOSANSHI_APPICON_PATH:-$SCRIPT_DIR/AppIcon.png}"
ICON_DRIVE_ID="134DG19Lknp2p1AFvDAkLPA2zocyj2nOP"
ICON_EXPECTED_SIZE="590870"
ICON_SHA256="07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579"

if [ ! -f "$ICON_SRC" ]; then
  echo "ERROR: exact canonical #14 AppIcon is not staged. Source Drive ID=${ICON_DRIVE_ID}" >&2
  echo "Set JOSANSHI_APPICON_PATH to the authenticated canonical PNG before release preparation." >&2
  exit 1
fi

actual_size="$(wc -c < "$ICON_SRC" | tr -d ' ')"
actual_sha="$(shasum -a 256 "$ICON_SRC" | awk '{print $1}')"
if [ "$actual_size" != "$ICON_EXPECTED_SIZE" ] || [ "$actual_sha" != "$ICON_SHA256" ]; then
  echo "ERROR: canonical #14 AppIcon mismatch: size=$actual_size sha=$actual_sha" >&2
  exit 1
fi

python3 - "$ICON_SRC" <<'PY'
from pathlib import Path
import struct, sys
b = Path(sys.argv[1]).read_bytes()
assert b[:8] == b'\x89PNG\r\n\x1a\n'
w, h = struct.unpack('>II', b[16:24])
assert (w, h) == (1024, 1024), (w, h)
print('PASS: #14 canonical AppIcon dimensions 1024x1024')
PY

rm -rf "$SCRIPT_DIR/Assets.xcassets"
mkdir -p "$ASSET_DIR"
cp "$ICON_SRC" "$ASSET_DIR/AppIcon.png"
cat > "$ASSET_DIR/Contents.json" <<'JSON'
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
JSON

echo "PASS: #14 authenticated canonical AppIcon materialized: ${ICON_DRIVE_ID} SHA256=${ICON_SHA256}"
