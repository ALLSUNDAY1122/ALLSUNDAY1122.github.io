#!/usr/bin/env bash
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$NATIVE_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
TMP="${TMPDIR:-/tmp}/tsukanshi-canonical-appicon.png"
FILE_ID="1fVipxbpieTaTW81ZlXYklWXqsViDcVw3"
EXPECTED_SHA256="ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa"
EXPECTED_BYTES="556001"

rm -f "$TMP"
URL1="https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"
URL2="https://drive.google.com/uc?export=download&id=${FILE_ID}"

if ! curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$URL1" -o "$TMP"; then
  curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$URL2" -o "$TMP"
fi

ACTUAL_BYTES="$(wc -c < "$TMP" | tr -d ' ')"
ACTUAL_SHA256="$(shasum -a 256 "$TMP" | awk '{print $1}')"

if [[ "$ACTUAL_BYTES" != "$EXPECTED_BYTES" ]]; then
  echo "FAIL: canonical AppIcon size drift: expected=$EXPECTED_BYTES actual=$ACTUAL_BYTES" >&2
  exit 1
fi
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "FAIL: canonical AppIcon SHA-256 drift: expected=$EXPECTED_SHA256 actual=$ACTUAL_SHA256" >&2
  exit 1
fi

python3 - "$TMP" <<'PY'
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
cp "$TMP" "$OUTPUT"
echo "PASS: canonical Drive AppIcon copied with SHA-256 $EXPECTED_SHA256"
