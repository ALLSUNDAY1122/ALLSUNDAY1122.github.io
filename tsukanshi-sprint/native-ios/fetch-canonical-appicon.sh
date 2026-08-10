#!/usr/bin/env bash
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$NATIVE_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
STAGED="$NATIVE_DIR/CanonicalAssets/02_通関士.png"
EXPECTED_SHA256="ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa"
EXPECTED_BYTES="556001"

# The Notion-canonical Drive file is private. CI must never curl the Drive
# share URL anonymously because Google can return an HTML/interstitial payload.
# Use an explicitly staged copy of the exact canonical PNG, or an already
# installed AppIcon with the same byte hash. A caller may also provide an
# absolute source path via TSUKANSHI_CANONICAL_APPICON_SOURCE.
SOURCE="${TSUKANSHI_CANONICAL_APPICON_SOURCE:-}"
if [[ -z "$SOURCE" ]]; then
  if [[ -f "$STAGED" ]]; then
    SOURCE="$STAGED"
  elif [[ -f "$OUTPUT" ]]; then
    SOURCE="$OUTPUT"
  else
    echo "FAIL: canonical AppIcon is not staged." >&2
    echo "Place exact Notion/Drive asset 02_通関士.png at: $STAGED" >&2
    echo "Expected SHA-256: $EXPECTED_SHA256" >&2
    exit 1
  fi
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "FAIL: canonical AppIcon source not found: $SOURCE" >&2
  exit 1
fi

ACTUAL_BYTES="$(wc -c < "$SOURCE" | tr -d ' ')"
ACTUAL_SHA256="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"

if [[ "$ACTUAL_BYTES" != "$EXPECTED_BYTES" ]]; then
  echo "FAIL: canonical AppIcon size drift: expected=$EXPECTED_BYTES actual=$ACTUAL_BYTES" >&2
  exit 1
fi
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "FAIL: canonical AppIcon SHA-256 drift: expected=$EXPECTED_SHA256 actual=$ACTUAL_SHA256" >&2
  exit 1
fi

python3 - "$SOURCE" <<'PY'
import struct,sys
p=sys.argv[1]
data=open(p,'rb').read(32)
assert data[:8]==b'\x89PNG\r\n\x1a\n', 'not PNG'
assert data[12:16]==b'IHDR', 'missing IHDR'
w,h=struct.unpack('>II',data[16:24])
bit_depth=data[24]
color_type=data[25]
assert (w,h)==(1024,1024), f'wrong dimensions: {w}x{h}'
assert bit_depth==8, f'wrong bit depth: {bit_depth}'
assert color_type==2, f'expected RGB/no alpha PNG, color type={color_type}'
print('PASS: canonical AppIcon is 1024x1024 8-bit RGB/no-alpha')
PY

mkdir -p "$(dirname "$OUTPUT")"
if [[ "$SOURCE" != "$OUTPUT" ]]; then
  cp "$SOURCE" "$OUTPUT"
fi
echo "PASS: canonical AppIcon installed with SHA-256 $EXPECTED_SHA256"