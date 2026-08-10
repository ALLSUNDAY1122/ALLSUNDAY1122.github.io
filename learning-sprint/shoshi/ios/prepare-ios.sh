#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHOSHI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUESTIONS_SRC="$SHOSHI_ROOT/content-loop/questions.generated.json"
RESOURCES="$SCRIPT_DIR/Resources"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON="$ASSET_DIR/AppIcon.png"
ICON_DRIVE_ID="1lALyLGEVFvdWvMZVsQqdRnEJmJzUOFu7"
ICON_SHA256="c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506"
ICON_MODE="${SHOSHI_ICON_MODE:-canonical}"

mkdir -p "$RESOURCES" "$ASSET_DIR"
cp "$QUESTIONS_SRC" "$RESOURCES/questions.generated.json"

cat > "$ASSET_DIR/Contents.json" <<'JSON'
{
  "images" : [{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],
  "info" : {"author":"xcode","version":1}
}
JSON

fetch_canonical_icon() {
  local tmp url sha
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  for url in \
    "https://drive.usercontent.google.com/download?id=${ICON_DRIVE_ID}&export=download&confirm=t" \
    "https://drive.google.com/uc?export=download&id=${ICON_DRIVE_ID}&confirm=t" \
    "https://drive.google.com/uc?id=${ICON_DRIVE_ID}&export=download&confirm=t"; do
    rm -f "$tmp"
    if curl --fail --location --silent --show-error --connect-timeout 15 --max-time 60 "$url" --output "$tmp"; then
      sha="$(shasum -a 256 "$tmp" | awk '{print $1}')"
      echo "INFO: canonical AppIcon candidate SHA256=$sha"
      if [ "$sha" = "$ICON_SHA256" ]; then
        mv "$tmp" "$ICON"
        trap - RETURN
        echo "PASS: retrieved exact canonical AppIcon bytes from Drive"
        return 0
      fi
    fi
  done
  return 1
}

case "$ICON_MODE" in
  canonical)
    if [ ! -f "$ICON" ]; then
      fetch_canonical_icon || {
        echo "ERROR: canonical AppIcon is missing and no exact-byte Drive endpoint reproduced SHA256=$ICON_SHA256" >&2
        exit 1
      }
    fi
    actual_icon_sha="$(shasum -a 256 "$ICON" | awk '{print $1}')"
    if [ "$actual_icon_sha" != "$ICON_SHA256" ]; then
      echo "ERROR: canonical AppIcon SHA mismatch: $actual_icon_sha" >&2
      exit 1
    fi
    echo "PASS: canonical AppIcon SHA256=$actual_icon_sha"
    ;;
  simulator-placeholder)
    python3 - "$ICON" <<'PY'
import struct,sys,zlib
p=sys.argv[1]; w=h=1024
row=b'\x00'+bytes((47,74,109))*w
raw=row*h
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
open(p,'wb').write(png)
print('INFO: generated compile-only placeholder icon; Release/TestFlight use forbidden')
PY
    ;;
  *) echo "ERROR: unknown SHOSHI_ICON_MODE=$ICON_MODE" >&2; exit 1 ;;
esac

python3 - "$RESOURCES/questions.generated.json" <<'PY'
import json,sys,hashlib
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert isinstance(data,list) and len(data)==210
assert len({q['id'] for q in data})==210
q=next(x for x in data if x['id']=='SHOSHI-R7-PM-33')
assert q.get('scoring_status')=='all_correct' and q.get('official_answer_no') is None
print('PASS: pure-native bundle has audited 210 questions and R7-PM-33 all_correct')
print('QuestionsSHA256:',hashlib.sha256(open(p,'rb').read()).hexdigest())
PY

if grep -R -nE 'import[[:space:]]+WebKit|WKWebView|UIViewRepresentable' "$SCRIPT_DIR" --include='*.swift'; then
  echo 'ERROR: WebView/WebKit implementation is forbidden for ShoshiSprint' >&2
  exit 1
fi

echo "PASS: ShoshiSprint native resources prepared (icon mode: $ICON_MODE); no WebKit/WKWebView source."
