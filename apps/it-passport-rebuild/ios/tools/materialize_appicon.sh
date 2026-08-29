#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/Assets.xcassets/AppIcon.appiconset"
OUT="$ICON_DIR/AppIcon-1024.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/ITPassport-canonical.png"
VENV="$TMP/venv"
FILE_ID="1Cej-mIkRG1NVjajSK8PI1xCE4vI17cXl"
EXPECTED_SOURCE_SHA="a1c5fc063d443de17c8a498c132ccaad961dfa353a372756cd4e79ce4023f288"
EXPECTED_PIXEL_SHA="7ecad6e7e195da9be52b2b75f2afd3dbfd199c1134fb737207abdd808ebc0403"

mkdir -p "$ICON_DIR"
rm -f "$OUT"

ensure_pillow() {
  if [[ ! -x "$VENV/bin/python" ]]; then
    python3 -m venv "$VENV"
    "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check Pillow
  fi
}

verify_source() {
  local byte_sha pixel_sha
  [[ -s "$SRC" ]] || { echo "FAIL: canonical AppIcon source is empty" >&2; return 1; }
  byte_sha="$(shasum -a 256 "$SRC" | awk '{print $1}')"
  ensure_pillow
  pixel_sha="$(SRC_PATH="$SRC" "$VENV/bin/python" - <<'PY'
from PIL import Image
from pathlib import Path
import hashlib, os, sys
p = Path(os.environ['SRC_PATH'])
try:
    im = Image.open(p).convert('RGB')
except Exception as exc:
    print(f'INVALID:{exc}')
    sys.exit(0)
print(hashlib.sha256(im.tobytes()).hexdigest())
PY
)"
  if [[ "$pixel_sha" != "$EXPECTED_PIXEL_SHA" ]]; then
    echo "FAIL: canonical AppIcon pixel mismatch expected=$EXPECTED_PIXEL_SHA actual=$pixel_sha byte_sha=$byte_sha" >&2
    return 1
  fi
  if [[ "$byte_sha" != "$EXPECTED_SOURCE_SHA" ]]; then
    echo "INFO: source metadata/container differs but decoded RGB pixels match canonical; byte_sha=$byte_sha" >&2
  fi
}

fetch_icon() {
  local url="$1"
  rm -f "$SRC"
  echo "INFO: fetching canonical AppIcon source" >&2
  if ! curl --fail --location --silent --show-error --retry 2 --connect-timeout 20 --max-time 120 "$url" -o "$SRC"; then
    echo "WARN: canonical AppIcon download request failed" >&2
    return 1
  fi
  verify_source
}

# When a byte-preserving source is injected, exact bytes are preferred. Google
# Drive direct-download may rewrite PNG metadata/C2PA blocks, so remote sources
# are accepted only when the decoded RGB pixels match the Drive canonical file.
if [[ -n "${APPICON_SOURCE_PATH:-}" ]]; then
  [[ -f "$APPICON_SOURCE_PATH" ]] || { echo "FAIL: APPICON_SOURCE_PATH not found" >&2; exit 1; }
  cp "$APPICON_SOURCE_PATH" "$SRC"
  verify_source
elif ! fetch_icon "https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"; then
  echo "INFO: trying alternate Google Drive download endpoint" >&2
  if ! fetch_icon "https://drive.google.com/uc?export=download&id=${FILE_ID}"; then
    echo "FAIL: could not materialize pixel-identical canonical AppIcon from Google Drive; refusing fallback icon" >&2
    exit 1
  fi
fi

SOURCE_WIDTH="$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')"
SOURCE_HEIGHT="$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ {print $2}')"
SOURCE_ALPHA="$(sips -g hasAlpha "$SRC" | awk '/hasAlpha/ {print $2}')"
[[ "$SOURCE_WIDTH" == "1254" && "$SOURCE_HEIGHT" == "1254" ]] || { echo "FAIL: source dimensions ${SOURCE_WIDTH}x${SOURCE_HEIGHT}" >&2; exit 1; }
[[ "$SOURCE_ALPHA" == "no" ]] || { echo "FAIL: source must not contain alpha" >&2; exit 1; }

cp "$SRC" "$OUT"
sips -z 1024 1024 "$OUT" >/dev/null

WIDTH="$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/ {print $2}')"
ALPHA="$(sips -g hasAlpha "$OUT" | awk '/hasAlpha/ {print $2}')"
[[ "$WIDTH" == "1024" && "$HEIGHT" == "1024" ]] || { echo "FAIL: output dimensions ${WIDTH}x${HEIGHT}" >&2; exit 1; }
[[ "$ALPHA" == "no" ]] || { echo "FAIL: output must not contain alpha" >&2; exit 1; }

printf 'PASS AppIcon canonical_pixel_sha=%s output_sha=%s size=%sx%s alpha=%s\n' \
  "$EXPECTED_PIXEL_SHA" "$(shasum -a 256 "$OUT" | awk '{print $1}')" "$WIDTH" "$HEIGHT" "$ALPHA"
