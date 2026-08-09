#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"; WEB="$IOS/Web"; ICON="$IOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
rm -rf "$WEB"; mkdir -p "$WEB/content/product" "$WEB/content/media"
for f in index.html style.css heatmap-fix.css product-v06.css app-v06.js record-fix-v061.js; do cp "$ROOT/$f" "$WEB/$f"; done
cp "$IOS/product-loader-ios.js" "$WEB/product-loader-ios.js"; cp "$IOS/native-store-ui.js" "$WEB/native-store-ui.js"; cp "$IOS/native-store.css" "$WEB/native-store.css"
cp -R "$ROOT/content/media/." "$WEB/content/media/"
python3 - "$ROOT/content/product/questions.json" "$WEB/questions-data.js" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8')); assert len(d.get('questions',[]))==1035
open(sys.argv[2],'w',encoding='utf-8').write('window.PHARM_PRODUCT_RAW='+json.dumps(d,ensure_ascii=False,separators=(',',':'))+';\n')
PY
python3 - "$WEB/index.html" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8').replace('<link rel="manifest" href="./manifest.json">','').replace('<link rel="stylesheet" href="./product-v06.css">','<link rel="stylesheet" href="./product-v06.css"><link rel="stylesheet" href="./native-store.css">').replace('<script src="./product-loader-v06.js"></script>','<script src="./questions-data.js"></script><script src="./product-loader-ios.js"></script>')
assert 'product-loader-ios.js' in s and 'product-loader-v06.js' not in s;p.write_text(s,encoding='utf-8')
PY
if [[ ! -f "$ICON" && "${PREFLIGHT_PLACEHOLDER_ICON:-0}" == "1" ]]; then
python3 - "$ICON" <<'PY'
import struct,zlib,binascii,sys
w=h=1024; row=b'\x00'+bytes((47,74,109))*w; raw=row*h
def c(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',binascii.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+c(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+c(b'IDAT',zlib.compress(raw,9))+c(b'IEND',b'')
open(sys.argv[1],'wb').write(png)
print('PREFLIGHT ONLY: generated non-release placeholder icon')
PY
fi
if [[ ! -f "$ICON" ]]; then echo "ERROR: canonical AppIcon missing. Materialize Drive file 1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu as $ICON" >&2; exit 2; fi
python3 - "$ICON" "${PREFLIGHT_PLACEHOLDER_ICON:-0}" <<'PY'
import hashlib,struct,sys
b=open(sys.argv[1],'rb').read(); pre=sys.argv[2]=='1'; expect='dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
assert b[:8]==b'\x89PNG\r\n\x1a\n' and b[12:16]==b'IHDR' and struct.unpack('>II',b[16:24])==(1024,1024) and b[25]==2
if not pre: assert hashlib.sha256(b).hexdigest()==expect,'AppIcon SHA-256 mismatch'
print('PASS: '+('simulator placeholder' if pre else 'canonical AppIcon'))
PY
echo "PASS: prepared PharmacistSprint offline web bundle"
