#!/usr/bin/env python3
"""Materialize the exact canonical #7 AppIcon into the Xcode asset catalog.

No image rendering or conversion is permitted. The script reconstructs the
approved PNG byte-for-byte from repository Base64 transport parts (preferred),
or copies a supplied local canonical file. Every source is rejected unless the
canonical byte count, SHA-256, PNG dimensions, bit depth and RGB color type all
match.
"""
from __future__ import annotations

import base64
import hashlib
import os
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
TRANSPORT_DIR = ROOT / "ios/appicon-source"
EXPECTED_SHA256 = "5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729"
EXPECTED_BYTES = 678_310
EXPECTED_BASE64_CHARS = 904_416
EXPECTED_SIZE = (1024, 1024)


def validate(data: bytes, label: str) -> None:
    if len(data) != EXPECTED_BYTES:
        raise ValueError(f"{label}: byte size {len(data)} != {EXPECTED_BYTES}")
    actual = hashlib.sha256(data).hexdigest()
    if actual != EXPECTED_SHA256:
        raise ValueError(f"{label}: SHA-256 {actual} != canonical {EXPECTED_SHA256}")
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"{label}: not a canonical PNG IHDR stream")
    width, height = struct.unpack(">II", data[16:24])
    bit_depth, color_type = data[24], data[25]
    if (width, height) != EXPECTED_SIZE:
        raise ValueError(f"{label}: PNG size {(width, height)} != {EXPECTED_SIZE}")
    if bit_depth != 8 or color_type != 2:
        raise ValueError(
            f"{label}: PNG must be 8-bit RGB without alpha; "
            f"got bitDepth={bit_depth}, colorType={color_type}"
        )


def read_transport_parts() -> bytes | None:
    parts = sorted(TRANSPORT_DIR.glob("AppIcon-1024.png.b64.part*"))
    if not parts:
        return None
    expected_names = [f"AppIcon-1024.png.b64.part{i:02d}" for i in range(len(parts))]
    actual_names = [p.name for p in parts]
    if actual_names != expected_names:
        raise ValueError(f"AppIcon transport parts are not contiguous: {actual_names[:3]} ... {actual_names[-3:]}")
    encoded = "".join(p.read_text(encoding="ascii").strip() for p in parts)
    if len(encoded) != EXPECTED_BASE64_CHARS:
        raise ValueError(
            f"AppIcon Base64 transport length {len(encoded)} != canonical {EXPECTED_BASE64_CHARS}"
        )
    data = base64.b64decode(encoded, validate=True)
    validate(data, f"{len(parts)} repository transport parts")
    print(f"Using canonical AppIcon reconstructed from {len(parts)} repository transport parts")
    return data


def read_local() -> bytes | None:
    candidates = [
        os.environ.get("CANONICAL_APPICON_PATH"),
        str(ROOT / "07_ネットワークスペシャリスト試験.png"),
        str(ROOT.parent / "07_ネットワークスペシャリスト試験.png"),
    ]
    for raw in candidates:
        if not raw:
            continue
        path = Path(raw).expanduser()
        if path.is_file():
            data = path.read_bytes()
            validate(data, str(path))
            print(f"Using canonical local AppIcon: {path}")
            return data
    return None


def main() -> int:
    data = read_transport_parts()
    if data is None:
        data = read_local()
    if data is None:
        raise RuntimeError(
            "Canonical AppIcon unavailable. Add the approved Base64 transport parts "
            "or provide CANONICAL_APPICON_PATH."
        )
    validate(data, "final AppIcon")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_bytes(data)
    print(
        "PASS canonical AppIcon",
        {
            "bytes": len(data),
            "size": "1024x1024",
            "mode": "RGB",
            "sha256": EXPECTED_SHA256,
            "dest": str(DEST),
        },
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # release gate must fail closed
        print(f"FAIL canonical AppIcon: {exc}", file=sys.stderr)
        raise SystemExit(1)
