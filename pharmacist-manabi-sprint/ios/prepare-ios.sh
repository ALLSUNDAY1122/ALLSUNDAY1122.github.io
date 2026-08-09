#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
WEB="$IOS/Web"
ICON="$IOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
rm -rf "$WEB"
mkdir -p "$WEB/content/product" "$WEB/content/media"
for f in index.html style.css heatmap-fix.css product-v06.css app-v06.js record-fix-v061.js; do cp "$ROOT/$f" "$WEB/$f"; done
cp "$IOS/product-loader-ios.js" "$WEB/product-loader-ios.js"
cp "$IOS/native-store-ui.js" "$WEB/native-store-ui.js"
cp "$IOS/native-store.css" "$WEB/native-store.css"
cp -R "$ROOT/content/media/." "$WEB/content/media/"
python3 - "$ROOT/content/product/questions.json" "$WEB/questions-data.js" <<'PY'
import json,sys
src,out=sys.argv[1:]
d=json.load(open(src,encoding='utf-8'))
assert len(d.get('questions',[]))==1035
open(out,'w',encoding='utf-8').write('window.PHARM_PRODUCT_RAW='+json.dumps(d,ensure_ascii=False,separators=(',',':'))+';\n')
PY
python3 - "$WEB/index.html" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
s=s.replace('<link rel="manifest" href="./manifest.json">','')
s=s.replace('<link rel="stylesheet" href="./product-v06.css">','<link rel="stylesheet" href="./product-v06.css"><link rel="stylesheet" href="./native-store.css">')
s=s.replace('<script src="./product-loader-v06.js"></script>','<script src="./questions-data.js"></script><script src="./product-loader-ios.js"></script>')
assert 'product-loader-ios.js' in s and 'product-loader-v06.js' not in s
p.write_text(s,encoding='utf-8')
PY
if [[ ! -f "$ICON" ]]; then
  echo "ERROR: canonical AppIcon missing: $ICON" >&2
  echo "Use Google Drive file 1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu (05_薬剤師国家試験.png)." >&2
  exit 2
fi
python3 - "$ICON" <<'PY'
import hashlib,struct,sys
p=sys.argv[1]; b=open(p,'rb').read(); expect='dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
assert hashlib.sha256(b).hexdigest()==expect, 'AppIcon SHA-256 mismatch'
assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR'
w,h=struct.unpack('>II',b[16:24]); assert (w,h)==(1024,1024)
assert b[25]==2, 'AppIcon must be RGB without alpha'
print('PASS: canonical 1024x1024 RGB AppIcon')
PY
echo "PASS: prepared PharmacistSprint offline web bundle"
