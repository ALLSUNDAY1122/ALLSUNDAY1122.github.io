#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATED_DIR="$SCRIPT_DIR/Generated"
ICON_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"

cd "$REPO_ROOT"
node tools/otsu4-build-content-v2.mjs
mkdir -p "$GENERATED_DIR" "$ICON_DIR"
cp kikenbutsu-otsu4-sprint/questions.generated.json "$GENERATED_DIR/questions.generated.json"

python3 - "$GENERATED_DIR/questions.generated.json" "$ICON_DIR/Icon-1024.png" <<'PY'
import binascii,json,struct,sys,zlib
from pathlib import Path

questions_path=Path(sys.argv[1])
icon_path=Path(sys.argv[2])

data=json.loads(questions_path.read_text(encoding='utf-8'))
assert data['contentVersion']=='otsu4-2026-08-product-v2'
assert len(data['questions'])==360
print('prepared native questions:',len(data['questions']))

W=H=1024
PAPER=(247,243,234); INDIGO=(47,74,109); SHU=(216,69,44); GOLD=(181,135,43); CREAM=(255,253,249)

def in_round_rect(x,y,l,t,r,b,rad):
    if l+rad <= x <= r-rad and t <= y <= b: return True
    if l <= x <= r and t+rad <= y <= b-rad: return True
    cx=l+rad if x < l+rad else r-rad
    cy=t+rad if y < t+rad else b-rad
    return (x-cx)*(x-cx)+(y-cy)*(y-cy) <= rad*rad

def in_ellipse(x,y,cx,cy,rx,ry):
    return ((x-cx)*(x-cx))/(rx*rx)+((y-cy)*(y-cy))/(ry*ry) <= 1.0

def in_triangle(x,y,ax,ay,bx,by,cx,cy):
    d=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
    if d == 0: return False
    u=((by-cy)*(x-cx)+(cx-bx)*(y-cy))/d
    v=((cy-ay)*(x-cx)+(ax-cx)*(y-cy))/d
    w=1-u-v
    return u>=0 and v>=0 and w>=0

rows=[]
for y in range(H):
    row=bytearray()
    for x in range(W):
        c=PAPER
        if in_round_rect(x,y,92,92,932,932,220): c=INDIGO
        if in_round_rect(x,y,148,148,876,876,174) and not in_round_rect(x,y,174,174,850,850,148): c=GOLD

        flame = in_ellipse(x,y,512,650,205,215) or in_triangle(x,y,512,190,350,620,674,620)
        flame = flame or in_ellipse(x,y,382,660,82,150) or in_ellipse(x,y,642,660,82,150)
        if flame: c=SHU

        inner = in_ellipse(x,y,512,635,72,112) or in_triangle(x,y,512,414,452,635,572,635)
        if inner: c=GOLD

        four = (535<=x<=592 and 530<=y<=790) or (426<=x<=625 and 650<=y<=706)
        if 535<=y<=660:
            center=442 + int((660-y)*0.58)
            if abs(x-center)<=25: four=True
        if four: c=CREAM
        row.extend(c)
    rows.append(b'\x00'+bytes(row))

def chunk(kind,payload):
    return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',binascii.crc32(kind+payload)&0xffffffff)

raw=b''.join(rows)
png=(b'\x89PNG\r\n\x1a\n'+
     chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+
     chunk(b'IDAT',zlib.compress(raw,9))+
     chunk(b'IEND',b''))
icon_path.write_bytes(png)

sig=png[:26]
assert sig[:8]==b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II',sig[16:24])
assert (w,h)==(1024,1024), (w,h)
assert sig[25]==2, f'App Store icon must be RGB without alpha; PNG color type={sig[25]}'
print('prepared app icon:',w,'x',h,'RGB/no-alpha',len(png),'bytes')
PY
