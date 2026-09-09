#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path
from urllib.request import Request, urlopen

FILE_ID = "1Ni3r5iu3M2lgDBqSSlNPtNflX-o2UJUK"
EXPECTED_SHA256 = "0da95e08cbc366cc17ced44aaf28d46a08cd4219d328be389e31666d32d7c45c"
URL = f"https://drive.usercontent.google.com/download?id={FILE_ID}&export=download&confirm=t"

ROOT = Path(__file__).resolve().parents[1]
APPICON_SET = ROOT / "Sources" / "Assets.xcassets" / "AppIcon.appiconset"
PNG_PATH = APPICON_SET / "AppIcon-1024.png"
CONTENTS_PATH = APPICON_SET / "Contents.json"

request = Request(URL, headers={"User-Agent": "Mozilla/5.0"})
with urlopen(request, timeout=30) as response:
    data = response.read()

actual_sha256 = hashlib.sha256(data).hexdigest()
if actual_sha256 != EXPECTED_SHA256:
    raise SystemExit(
        f"OT_APPICON_SHA_MISMATCH expected={EXPECTED_SHA256} actual={actual_sha256} size={len(data)}"
    )

if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 24:
    raise SystemExit("OT_APPICON_INVALID_PNG")
width, height = struct.unpack(">II", data[16:24])
if (width, height) != (1024, 1024):
    raise SystemExit(f"OT_APPICON_DIMENSION_MISMATCH actual={width}x{height}")

APPICON_SET.mkdir(parents=True, exist_ok=True)
PNG_PATH.write_bytes(data)
CONTENTS_PATH.write_text(
    json.dumps(
        {
            "images": [
                {
                    "filename": "AppIcon-1024.png",
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)

print(
    "OT_APPICON_CANONICAL_PASS "
    f"size={len(data)} sha256={actual_sha256} dimensions={width}x{height}"
)
