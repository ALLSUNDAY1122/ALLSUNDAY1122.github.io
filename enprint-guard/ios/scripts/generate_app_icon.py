#!/usr/bin/env python3
"""Generate a deterministic 1024px opaque RGB app icon using Python stdlib."""
from pathlib import Path
import struct, zlib
SIZE, SCALE = 1024, 3
W = SIZE * SCALE
BG=(232,243,236); PAPER=(255,255,255); GREEN=(34,103,78)
FOLD=(211,232,218); LINE=(194,211,200); ORANGE=(239,157,72); WHITE=(255,255,255)
canvas=bytearray(bytes(BG)*(W*W))
def put(x,y,c):
    if 0<=x<W and 0<=y<W:
        i=(y*W+x)*3; canvas[i:i+3]=bytes(c)
def rr(x0,y0,x1,y1,r,c):
    x0,y0,x1,y1,r=(v*SCALE for v in (x0,y0,x1,y1,r)); r2=r*r
    for y in range(y0,y1):
        cy=y+.5; qy=min(max(cy,y0+r),y1-r); dy=(cy-qy)**2
        for x in range(x0,x1):
            cx=x+.5; qx=min(max(cx,x0+r),x1-r)
            if (cx-qx)**2+dy<=r2: put(x,y,c)
def circle(cx,cy,r,c):
    cx,cy,r=cx*SCALE,cy*SCALE,r*SCALE; r2=r*r
    for y in range(max(0,int(cy-r)),min(W,int(cy+r+1))):
        dy=(y+.5-cy)**2
        for x in range(max(0,int(cx-r)),min(W,int(cx+r+1))):
            if (x+.5-cx)**2+dy<=r2: put(x,y,c)
def poly(points,c):
    pts=[(x*SCALE,y*SCALE) for x,y in points]; a,b,d=pts
    def cross(p,q,x,y): return (q[0]-p[0])*(y-p[1])-(q[1]-p[1])*(x-p[0])
    for y in range(max(0,int(min(p[1] for p in pts))),min(W,int(max(p[1] for p in pts)+1))):
        for x in range(max(0,int(min(p[0] for p in pts))),min(W,int(max(p[0] for p in pts)+1))):
            v=[cross(a,b,x+.5,y+.5),cross(b,d,x+.5,y+.5),cross(d,a,x+.5,y+.5)]
            if all(t>=0 for t in v) or all(t<=0 for t in v): put(x,y,c)
def line(x1,y1,x2,y2,width,c):
    x1,y1,x2,y2,width=(v*SCALE for v in (x1,y1,x2,y2,width))
    vx,vy=x2-x1,y2-y1; length=vx*vx+vy*vy; r2=(width/2)**2; m=width/2+1
    for y in range(max(0,int(min(y1,y2)-m)),min(W,int(max(y1,y2)+m+1))):
        py=y+.5
        for x in range(max(0,int(min(x1,x2)-m)),min(W,int(max(x1,x2)+m+1))):
            px=x+.5; t=0 if not length else max(0,min(1,((px-x1)*vx+(py-y1)*vy)/length))
            dx,dy=px-x1-t*vx,py-y1-t*vy
            if dx*dx+dy*dy<=r2: put(x,y,c)
rr(164,108,860,916,88,PAPER)
poly([(650,108),(860,108),(860,318)],FOLD)
rr(270,270,594,330,26,GREEN)
rr(270,420,710,460,18,LINE); rr(270,530,670,570,18,LINE); rr(270,640,560,680,18,LINE)
circle(345,790,40,ORANGE); circle(700,758,150,GREEN)
line(625,760,680,818,34,WHITE); line(680,818,788,686,34,WHITE)
raw=bytearray()
for y in range(SIZE):
    raw.append(0); sy=y*SCALE
    for x in range(SIZE):
        sx=x*SCALE; sums=[0,0,0]
        for oy in range(SCALE):
            for ox in range(SCALE):
                i=((sy+oy)*W+sx+ox)*3
                sums[0]+=canvas[i]; sums[1]+=canvas[i+1]; sums[2]+=canvas[i+2]
        raw.extend(v//(SCALE*SCALE) for v in sums)
def chunk(k,d): return struct.pack(">I",len(d))+k+d+struct.pack(">I",zlib.crc32(k+d)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",SIZE,SIZE,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(bytes(raw),9))+chunk(b"IEND",b"")
out=Path(__file__).parent/"EnprintGuard"/"Assets.xcassets"/"AppIcon.appiconset"/"AppIcon.png"
out.parent.mkdir(parents=True,exist_ok=True); out.write_bytes(png)
print(f"PASS: {out} (1024x1024 opaque RGB)")
