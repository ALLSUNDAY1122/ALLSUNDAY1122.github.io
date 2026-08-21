#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import struct
import subprocess
import sys
import zlib
from pathlib import Path

NAVY = (17, 43, 70)
BLUE = (49, 87, 213)
MINT = (34, 211, 197)
WHITE = (248, 251, 255)


def blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: Path, size: int, *, mark_scale: float = 1.0, transparent: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = 4 if transparent else 3
    rows: list[bytes] = []
    for y in range(size):
        row = bytearray([0])
        v = y / max(1, size - 1)
        for x in range(size):
            u = x / max(1, size - 1)
            if transparent:
                color = (0, 0, 0)
                alpha = 0
            else:
                color = blend(NAVY, BLUE, 0.55 * u + 0.45 * v)
                glow = max(0.0, 1.0 - math.hypot(u - 0.78, v - 0.16) / 0.55)
                color = blend(color, (84, 118, 238), glow * 0.28)
                alpha = 255

            su = (u - 0.5) / mark_scale + 0.5
            sv = (v - 0.5) / mark_scale + 0.5
            if rounded_rect(su, sv, 0.30, 0.18, 0.72, 0.80, 0.055):
                color, alpha = composite(color, alpha, (13, 30, 56), 95)
            if rounded_rect(su, sv, 0.25, 0.15, 0.67, 0.77, 0.055):
                color, alpha = composite(color, alpha, WHITE, 255)
            for yy in (0.26, 0.38, 0.50, 0.62):
                if (su - 0.29) ** 2 + (sv - yy) ** 2 <= 0.013 ** 2:
                    color, alpha = composite(color, alpha, BLUE, 255)
            for yy, x2 in ((0.31, 0.58), (0.42, 0.60), (0.53, 0.52)):
                if distance_to_segment(su, sv, 0.36, yy, x2, yy) < 0.012:
                    color, alpha = composite(color, alpha, (184, 197, 225), 255)
            route = min(
                distance_to_segment(su, sv, 0.30, 0.68, 0.47, 0.56),
                distance_to_segment(su, sv, 0.47, 0.56, 0.63, 0.37),
                distance_to_segment(su, sv, 0.63, 0.37, 0.75, 0.27),
            )
            if route < 0.022:
                color, alpha = composite(color, alpha, MINT, 255)
            for px, py, radius in ((0.30, 0.68, 0.042), (0.47, 0.56, 0.033), (0.63, 0.37, 0.033)):
                if (su - px) ** 2 + (sv - py) ** 2 <= radius ** 2:
                    color, alpha = composite(color, alpha, MINT, 255)
            if point_in_triangle((su, sv), (0.70, 0.22), (0.80, 0.25), (0.76, 0.34)):
                color, alpha = composite(color, alpha, MINT, 255)
            row.extend((*color, alpha) if channels == 4 else color)
        rows.append(bytes(row))

    color_type = 6 if channels == 4 else 2
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, color_type, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(rows), 9))
    png += chunk(b'IEND', b'')
    path.write_bytes(png)


def composite(base: tuple[int, int, int], base_alpha: int, top: tuple[int, int, int], top_alpha: int):
    if base_alpha == 0:
        return top, top_alpha
    return blend(base, top, top_alpha / 255.0), max(base_alpha, top_alpha)


def rounded_rect(x: float, y: float, x1: float, y1: float, x2: float, y2: float, r: float) -> bool:
    if x1 + r <= x <= x2 - r and y1 <= y <= y2:
        return True
    if x1 <= x <= x2 and y1 + r <= y <= y2 - r:
        return True
    return any((x - cx) ** 2 + (y - cy) ** 2 <= r ** 2 for cx, cy in (
        (x1 + r, y1 + r), (x2 - r, y1 + r), (x1 + r, y2 - r), (x2 - r, y2 - r)
    ))


def distance_to_segment(px, py, x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    if dx == dy == 0:
        return math.hypot(px - x1, py - y1)
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))


def point_in_triangle(p, a, b, c):
    def sign(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = sign(p, a, b), sign(p, b, c), sign(p, c, a)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


def ios_icons(root: Path) -> None:
    appicon = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    data = json.loads((appicon / 'Contents.json').read_text())
    for image in data['images']:
        filename = image.get('filename')
        if filename:
            points = float(image['size'].split('x')[0])
            scale = int(image['scale'].rstrip('x'))
            write_png(appicon / filename, round(points * scale))
    launch = root / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    for filename, size in (('LaunchImage.png', 168), ('LaunchImage@2x.png', 336), ('LaunchImage@3x.png', 504)):
        write_png(launch / filename, size, mark_scale=0.88, transparent=True)
    storyboard = root / 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
    storyboard.write_text(storyboard.read_text().replace(
        'red="1" green="1" blue="1"',
        'red="0.0667" green="0.1686" blue="0.2745"',
    ))


def android_icons(root: Path) -> None:
    for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        write_png(root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
    for rel in ('android/app/src/main/res/drawable/launch_background.xml', 'android/app/src/main/res/drawable-v21/launch_background.xml'):
        path = root / rel
        path.write_text(path.read_text().replace(
            '<item android:drawable="@android:color/white" />',
            '<item android:drawable="#112B46" />',
        ))


def web_icons(root: Path) -> None:
    write_png(root / 'web/favicon.png', 32)
    for filename, size, scale in (
        ('Icon-192.png', 192, 1.0), ('Icon-512.png', 512, 1.0),
        ('Icon-maskable-192.png', 192, 0.78), ('Icon-maskable-512.png', 512, 0.78),
    ):
        write_png(root / 'web/icons' / filename, size, mark_scale=scale)
    path = root / 'web/manifest.json'
    manifest = json.loads(path.read_text())
    manifest['background_color'] = '#112B46'
    manifest['theme_color'] = '#3157D5'
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


def harden_v06_submission(root: Path) -> None:
    pubspec = root / 'pubspec.yaml'
    hardener = Path(__file__).with_name('harden_v06_ios_submission.py')
    if not pubspec.exists() or 'version: 0.6.0+6' not in pubspec.read_text():
        return
    if not hardener.exists():
        raise FileNotFoundError(f'missing v0.6 hardener: {hardener}')
    subprocess.run([sys.executable, str(hardener), str(root)], check=True)


def main() -> None:
    root = Path(sys.argv[1]).resolve()
    if (root / 'ios').exists():
        ios_icons(root)
        harden_v06_submission(root)
    if (root / 'android').exists():
        android_icons(root)
    if (root / 'web').exists():
        web_icons(root)
    preview = root / 'docs/brand'
    write_png(preview / 'AI_Handover_Log_AppIcon_1024.png', 1024)
    write_png(preview / 'AI_Handover_Log_LaunchMark_504.png', 504, mark_scale=0.88, transparent=True)
    print('generated v0.5 brand assets')


if __name__ == '__main__':
    main()
