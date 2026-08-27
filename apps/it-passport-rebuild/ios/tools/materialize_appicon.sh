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

fetch_icon() {
  local url="$1"
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 120 "$url" -o "$SRC"
  [[ -s "$SRC" ]]
  [[ "$(shasum -a 256 "$SRC" | awk '{print $1}')" == "$EXPECTED_SOURCE_SHA" ]]
}

if ! fetch_icon "https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"; then
  rm -f "$SRC"
  fetch_icon "https://drive.google.com/uc?export=download&id=${FILE_ID}"
fi

SOURCE_WIDTH="$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')"
SOURCE_HEIGHT="$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ {print $2}')"
SOURCE_ALPHA="$(sips -g hasAlpha "$SRC" | awk '/hasAlpha/ {print $2}')"
[[ "$SOURCE_WIDTH" == "1254" && "$SOURCE_HEIGHT" == "1254" ]]
[[ "$SOURCE_ALPHA" == "no" ]]

cp "$SRC" "$OUT"
sips -z 1024 1024 "$OUT" >/dev/null

WIDTH="$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/ {print $2}')"
ALPHA="$(sips -g hasAlpha "$OUT" | awk '/hasAlpha/ {print $2}')"
[[ "$WIDTH" == "1024" && "$HEIGHT" == "1024" ]]
[[ "$ALPHA" == "no" ]]

printf 'PASS AppIcon source_sha=%s output_sha=%s size=%sx%s alpha=%s\n' \
  "$EXPECTED_SOURCE_SHA" "$(shasum -a 256 "$OUT" | awk '{print $1}')" "$WIDTH" "$HEIGHT" "$ALPHA"
