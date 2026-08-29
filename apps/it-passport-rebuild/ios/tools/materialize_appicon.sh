#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/Assets.xcassets/AppIcon.appiconset"
OUT="$ICON_DIR/AppIcon-1024.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/ITPassport-canonical.png"
FILE_ID="1Cej-mIkRG1NVjajSK8PI1xCE4vI17cXl"
EXPECTED_SOURCE_SHA="a1c5fc063d443de17c8a498c132ccaad961dfa353a372756cd4e79ce4023f288"

mkdir -p "$ICON_DIR"
rm -f "$OUT"

verify_source() {
  local actual
  [[ -s "$SRC" ]] || { echo "FAIL: canonical AppIcon source is empty" >&2; return 1; }
  actual="$(shasum -a 256 "$SRC" | awk '{print $1}')"
  if [[ "$actual" != "$EXPECTED_SOURCE_SHA" ]]; then
    echo "FAIL: canonical AppIcon SHA mismatch expected=$EXPECTED_SOURCE_SHA actual=$actual" >&2
    return 1
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

# CI may provide a byte-preserving local canonical source in the future. It is
# accepted only when its SHA-256 exactly matches the Notion/Drive source-of-truth.
if [[ -n "${APPICON_SOURCE_PATH:-}" ]]; then
  [[ -f "$APPICON_SOURCE_PATH" ]] || { echo "FAIL: APPICON_SOURCE_PATH not found" >&2; exit 1; }
  cp "$APPICON_SOURCE_PATH" "$SRC"
  verify_source
elif ! fetch_icon "https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"; then
  echo "INFO: trying alternate Google Drive download endpoint" >&2
  if ! fetch_icon "https://drive.google.com/uc?export=download&id=${FILE_ID}"; then
    echo "FAIL: could not materialize exact canonical AppIcon from Google Drive; refusing fallback icon" >&2
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

printf 'PASS AppIcon source_sha=%s output_sha=%s size=%sx%s alpha=%s\n' \
  "$EXPECTED_SOURCE_SHA" "$(shasum -a 256 "$OUT" | awk '{print $1}')" "$WIDTH" "$HEIGHT" "$ALPHA"
