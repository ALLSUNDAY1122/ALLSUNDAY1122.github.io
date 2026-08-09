#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DST="$SCRIPT_DIR/Web"
ASSET_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
ICON_SRC="$SCRIPT_DIR/AppIcon.png"
ICON_DRIVE_ID="11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4"
ICON_EXPECTED_SIZE="726223"
ICON_SHA256="294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f"
ICON_MODE="${KANRI_ICON_MODE:-canonical}"

rm -rf "$WEB_DST" "$SCRIPT_DIR/Assets.xcassets"
mkdir -p "$WEB_DST/data" "$WEB_DST/audit/round3" "$ASSET_DIR"

for f in index.html styles.css styles-v061.css app-v061.js data-bootstrap-v061.js manifest.json questions.js questions-121-150.js questions-151-180.js questions-181-210.js questions-211-240.js; do test -f "$ROOT/$f"; cp "$ROOT/$f" "$WEB_DST/$f"; done
cp "$ROOT"/data/*.js "$WEB_DST/data/"
for f in round2-extra-121-140.json round2-extra-141-160.json round2-extra-161-170.json round2-extra-171-180.json round2-extra-181-190.json round2-extra-191-200.json round2-rebalance-201-216.json round2-rebalance-217-232.json primary-source-registry.json; do cp "$ROOT/audit/$f" "$WEB_DST/audit/$f"; done
cp "$ROOT"/audit/round3/*.json "$WEB_DST/audit/round3/"
cp "$SCRIPT_DIR/native-storekit.js" "$WEB_DST/native-storekit.js"

python3 - "$WEB_DST/index.html" "$WEB_DST/app-v061.js" <<'PY'
from pathlib import Path
import sys
index=Path(sys.argv[1]);app=Path(sys.argv[2])
html=index.read_text(encoding='utf-8');needle='<script src="data-bootstrap-v061.js?v=061"></script>'
if needle not in html: raise SystemExit('ERROR: bootstrap marker not found')
html=html.replace(needle,'<script src="native-storekit.js?v=ios1"></script>\n'+needle,1);index.write_text(html,encoding='utf-8')
js=app.read_text(encoding='utf-8');pos=js.rfind('})();')
if pos<0: raise SystemExit('ERROR: app closure marker not found')
api=r'''
function nativeFreePool(category){var counts={},out=[];Q.forEach(function(q){if(qRound(q)!==1)return;if(category&&q.c!==category)return;var n=counts[q.c]||0;if(n<6){counts[q.c]=n+1;out.push(q);}});return out;}
function nativeFreeIdMap(){var m={};nativeFreePool().forEach(function(q){m[q.id]=1;});return m;}
window.__KANRI_NATIVE_API={
  forceFreeMode:function(){if(!window.KANRI_NATIVE_STORE||window.KANRI_NATIVE_STORE.premium)return;S.selectedRound=1;save();},
  startFreeToday:function(){var a=nativeFreePool();startSession(pick(a,Number(S.goal)||8),'today','無料60問',1);},
  startFreeSubject:function(c){var a=nativeFreePool(c);startSession(pick(a,Number(S.goal)||8),'subject',c,1);},
  startFreeWeak:function(){var a=nativeFreePool().filter(function(q){return !!S.weak[q.id];});if(!a.length){toast('無料範囲の苦手問題はありません');return;}startSession(pick(a,Number(S.goal)||8),'weak','苦手',1);},
  resumeFree:function(){if(!S.ip||!Array.isArray(S.ip.ids))return false;var allowed=nativeFreeIdMap(),ok=S.ip.ids.every(function(id){return !!allowed[id];});if(!ok){S.ip=null;save();return false;}resume();return true;},
  freeCount:function(){return nativeFreePool().length;}
};
'''
js=js[:pos]+api+js[pos:];app.write_text(js,encoding='utf-8')
PY

case "$ICON_MODE" in
  skip) echo "INFO: AppIcon skipped for static/native UI audit.";;
  simulator-placeholder)
    python3 - "$ASSET_DIR/AppIcon.png" <<'PY'
import struct,sys,zlib
p=sys.argv[1];w=h=1024;row=b'\x00'+bytes((47,74,109))*w;raw=row*h
def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'');open(p,'wb').write(png)
print('INFO: compile-only placeholder icon; TestFlight/Archive use prohibited')
PY
    ;;
  canonical)
    if [ ! -f "$ICON_SRC" ]; then curl --fail --location --silent --show-error "https://drive.usercontent.google.com/download?id=${ICON_DRIVE_ID}&export=download&confirm=t" --output "$ICON_SRC"; fi
    actual_size="$(wc -c < "$ICON_SRC" | tr -d ' ')";actual_sha="$(shasum -a 256 "$ICON_SRC" | awk '{print $1}')"
    if [ "$actual_size" != "$ICON_EXPECTED_SIZE" ] || [ "$actual_sha" != "$ICON_SHA256" ]; then echo "ERROR: canonical AppIcon mismatch: size=$actual_size sha=$actual_sha" >&2;rm -f "$ICON_SRC";exit 1;fi
    python3 - "$ICON_SRC" <<'PY'
from pathlib import Path
import struct,sys
b=Path(sys.argv[1]).read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n';w,h=struct.unpack('>II',b[16:24]);assert (w,h)==(1024,1024),(w,h);print('PASS: canonical PNG dimensions 1024x1024')
PY
    cp "$ICON_SRC" "$ASSET_DIR/AppIcon.png";echo "PASS: canonical Drive AppIcon materialized: ${ICON_DRIVE_ID} SHA256=${ICON_SHA256}";;
  *) echo "ERROR: unknown KANRI_ICON_MODE=$ICON_MODE" >&2;exit 1;;
esac

if [ "$ICON_MODE" != "skip" ]; then cat > "$ASSET_DIR/Contents.json" <<'JSON'
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
JSON
fi

python3 - "$WEB_DST" <<'PY'
from pathlib import Path
import json,sys
r=Path(sys.argv[1]);assert 'native-storekit.js' in (r/'index.html').read_text(encoding='utf-8');app=(r/'app-v061.js').read_text(encoding='utf-8');assert '__KANRI_NATIVE_API' in app and 'resumeFree' in app
round3=sum(len(json.loads(p.read_text(encoding='utf-8'))) for p in (r/'audit/round3').glob('*.json'));assert round3==200,round3;assert len(list((r/'audit').glob('round2-extra-*.json')))==6
print('PASS: iOS local bundle contains StoreKit bridge, free-60 API and 600-question source set')
PY

echo "Prepared KanriEiyoushiSprint iOS local web bundle (icon mode: $ICON_MODE)."
