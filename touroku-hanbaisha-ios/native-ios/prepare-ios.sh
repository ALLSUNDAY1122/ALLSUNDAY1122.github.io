#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
SOURCE="$ICON_DIR/AppIcon.source.svg"
ICON="$ICON_DIR/AppIcon-1024.png"
EXPECTED_SHA256="c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03"

test -f "$SOURCE"
python3 - "$SOURCE" "$ICON" <<'PY'
import sys
from pathlib import Path
try:
    import cairosvg
except ImportError as exc:
    raise SystemExit('cairosvg==2.8.2 is required before prepare-ios.sh') from exc
src, out = map(Path, sys.argv[1:])
cairosvg.svg2png(url=str(src), write_to=str(out), output_width=1024, output_height=1024)
PY

ACTUAL_SHA256="$(shasum -a 256 "$ICON" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "FAIL: generated AppIcon does not match Drive canonical PNG; SHA-256=$ACTUAL_SHA256" >&2
  exit 1
fi

python3 - "$ICON" <<'PY'
import struct, sys
from pathlib import Path
p=Path(sys.argv[1])
data=p.read_bytes()
assert data[:8] == b'\x89PNG\r\n\x1a\n', 'AppIcon is not PNG'
w,h=struct.unpack('>II', data[16:24])
assert (w,h)==(1024,1024), f'AppIcon must be 1024x1024, got {w}x{h}'
print(f'PASS: canonical AppIcon {w}x{h}')
PY

echo "PASS: generated AppIcon exactly matches Drive canonical SHA-256 $ACTUAL_SHA256"
