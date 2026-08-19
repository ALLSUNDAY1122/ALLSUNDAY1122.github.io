#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
EXPECTED_SHA256="c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03"

test -f "$ICON"
ACTUAL_SHA256="$(shasum -a 256 "$ICON" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "FAIL: AppIcon SHA-256 mismatch: $ACTUAL_SHA256" >&2
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

echo "PASS: canonical AppIcon SHA-256 $ACTUAL_SHA256"
