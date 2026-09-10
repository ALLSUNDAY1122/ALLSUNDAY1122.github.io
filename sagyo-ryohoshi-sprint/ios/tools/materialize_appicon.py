#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import json
import struct
from pathlib import Path

EXPECTED_SHA256 = "0da95e08cbc366cc17ced44aaf28d46a08cd4219d328be389e31666d32d7c45c"
ROOT = Path(__file__).resolve().parents[1]
TRANSPORT_DIR = ROOT / "CanonicalAssets" / "AppIcon.transport"
PARTS = [TRANSPORT_DIR / f"part-{i:02d}.b64" for i in range(1, 5)]
APPICON_SET = ROOT / "Sources" / "Assets.xcassets" / "AppIcon.appiconset"
PNG_PATH = APPICON_SET / "AppIcon-1024.png"
CONTENTS_PATH = APPICON_SET / "Contents.json"

missing = [str(path) for path in PARTS if not path.is_file()]
if missing:
    raise SystemExit(f"OT_APPICON_TRANSPORT_MISSING parts={missing}")

encoded = "".join(path.read_text(encoding="ascii").strip() for path in PARTS)
try:
    data = base64.b64decode(encoded, validate=True)
except Exception as exc:
    raise SystemExit(f"OT_APPICON_TRANSPORT_INVALID_BASE64 error={exc}") from exc

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
    f"size={len(data)} sha256={actual_sha256} dimensions={width}x{height} transport_parts={len(PARTS)}"
)
