#!/usr/bin/env python3
"""Materialize the exact canonical #7 AppIcon into the Xcode asset catalog.

The approved PNG is stored byte-for-byte inside the repository. No network
fetch, image rendering, conversion, or derived transport is permitted. Every
source is rejected unless the canonical byte count, SHA-256, PNG dimensions,
bit depth and RGB color type all match.
"""
from __future__ import annotations

import hashlib
import os
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
REPO_CANONICAL = ROOT / "07_ネットワークスペシャリスト試験.png"
EXPECTED_SHA256 = "5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729"
EXPECTED_BYTES = 678_310
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


def read_repo_canonical() -> bytes:
    if not REPO_CANONICAL.is_file():
        raise FileNotFoundError(f"Repository canonical AppIcon missing: {REPO_CANONICAL}")
    data = REPO_CANONICAL.read_bytes()
    validate(data, str(REPO_CANONICAL))
    print(f"Using repository canonical AppIcon: {REPO_CANONICAL}")
    return data


def read_override() -> bytes | None:
    raw = os.environ.get("CANONICAL_APPICON_PATH")
    if not raw:
        return None
    path = Path(raw).expanduser()
    if not path.is_file():
        raise FileNotFoundError(f"CANONICAL_APPICON_PATH does not exist: {path}")
    data = path.read_bytes()
    validate(data, str(path))
    print(f"Using explicitly supplied canonical AppIcon: {path}")
    return data


def main() -> int:
    data = read_override()
    if data is None:
        data = read_repo_canonical()
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
