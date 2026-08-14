#!/usr/bin/env python3
"""Generate a deterministic 1024px PoC AppIcon without external dependencies."""
from __future__ import annotations
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "SplatNative/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

def pixel(x: int, y: int) -> tuple[int, int, int]:
    cx = cy = SIZE / 2
    dx, dy = x - cx, y - cy
    d = min(1.0, math.hypot(dx, dy) / (SIZE * 0.72))
    base = (int(10 + 8 * (1-d)), int(15 + 17 * (1-d)), int(27 + 24 * (1-d)))
    r, g, b = base
    # Gaussian-splat-like points distributed on a spiral around the center.
    for i in range(42):
        a = i * 2.399963229728653
        rr = (i / 41) ** 0.60 * 302
        px = cx + math.cos(a) * rr
        py = cy + math.sin(a) * rr * 0.78
        radius = 8 + 12 * (1 - rr / 315)
        dist = math.hypot(x-px, y-py)
        if dist < radius:
            t = 1 - dist / radius
            r = min(255, int(r + (115-r) * 0.72 * t))
            g = min(255, int(g + (238-g) * 0.85 * t))
            b = min(255, int(b + (220-b) * 0.82 * t))
    # Minimal wireframe cube at center.
    lines = [((425,468),(512,418)),((512,418),(599,468)),((599,468),(512,518)),((512,518),(425,468)),
             ((425,468),(425,566)),((425,566),(512,618)),((512,618),(599,566)),((599,566),(599,468)),((512,518),(512,618))]
    for (x1,y1),(x2,y2) in lines:
        vx, vy = x2-x1, y2-y1
        wx, wy = x-x1, y-y1
        denom = vx*vx + vy*vy
        t = 0 if denom == 0 else max(0.0, min(1.0, (wx*vx + wy*vy) / denom))
        dd = math.hypot(x-(x1+t*vx), y-(y1+t*vy))
        if dd <= 5.5:
            r, g, b = 244, 249, 255
    return r, g, b

def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # PNG filter: None
        for x in range(SIZE):
            raw.extend(pixel(x, y))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    OUT.write_bytes(png)
    print(f"Generated {OUT} ({len(png)} bytes)")

if __name__ == "__main__":
    main()
