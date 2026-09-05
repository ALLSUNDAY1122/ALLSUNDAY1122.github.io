#!/usr/bin/env python3
"""Generate a deterministic 1024px PoC AppIcon without external dependencies."""
import math, struct, zlib
from pathlib import Path
SIZE=1024
OUT=Path(__file__).resolve().parents[1]/"SplatNative/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
def chunk(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
def main():
    OUT.parent.mkdir(parents=True,exist_ok=True)
    raw=bytearray(); c=SIZE/2
    for y in range(SIZE):
        raw.append(0)
        dy=(y-c)/SIZE
        for x in range(SIZE):
            dx=(x-c)/SIZE; d=min(1.0,math.hypot(dx,dy)/.72)
            r,g,b=int(10+8*(1-d)),int(15+17*(1-d)),int(27+24*(1-d))
            # Analytic dotted Gaussian field: no per-point inner loop.
            ring=abs(math.hypot(dx,dy)-.27)
            wave=math.sin((math.atan2(dy,dx)+math.hypot(dx,dy)*24)*10)
            if ring<.045 and wave>.55:
                t=(.045-ring)/.045
                r=int(r+(120-r)*t); g=int(g+(238-g)*t); b=int(b+(220-b)*t)
            # Bright center cube approximation.
            if 420<x<604 and 420<y<620:
                edge=min(abs(x-420),abs(x-604),abs(y-420),abs(y-620))
                diag=min(abs((y-470)-.55*(x-420)),abs((y-470)+.55*(x-604)))
                if edge<5 or diag<4: r,g,b=244,249,255
            raw.extend((r,g,b))
    png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",SIZE,SIZE,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(bytes(raw),9))+chunk(b"IEND",b"")
    OUT.write_bytes(png); print(f"Generated {OUT} ({len(png)} bytes)")
if __name__=="__main__": main()
