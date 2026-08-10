#!/usr/bin/env python3
"""Materialize the exact canonical #7 AppIcon into the Xcode asset catalog.

The canonical source is the approved Google Drive file. This script never
re-renders or transforms the image. It only copies/downloads the original
bytes and refuses them unless every canonical invariant matches.
"""
from __future__ import annotations

import hashlib
import os
import struct
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
DRIVE_FILE_ID = "1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8"
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
        raise ValueError(f"{label}: PNG must be 8-bit RGB without alpha; got bitDepth={bit_depth}, colorType={color_type}")


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


def download() -> bytes:
    urls = [
        f"https://drive.usercontent.google.com/download?id={DRIVE_FILE_ID}&export=download&confirm=t",
        f"https://drive.google.com/uc?export=download&id={DRIVE_FILE_ID}&confirm=t",
    ]
    errors: list[str] = []
    for url in urls:
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=45) as response:
                data = response.read(EXPECTED_BYTES + 1024 * 1024)
            validate(data, url)
            print(f"Downloaded canonical AppIcon from Google Drive file {DRIVE_FILE_ID}")
            return data
        except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
            errors.append(f"{url}: {exc}")
    raise RuntimeError("Canonical AppIcon download failed; " + " | ".join(errors))


def main() -> int:
    data = read_local()
    if data is None:
        data = download()
    validate(data, "final AppIcon")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_bytes(data)
    print(
        "PASS canonical AppIcon",
        {"bytes": len(data), "size": "1024x1024", "mode": "RGB", "sha256": EXPECTED_SHA256, "dest": str(DEST)},
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # release gate should fail closed
        print(f"FAIL canonical AppIcon: {exc}", file=sys.stderr)
        raise SystemExit(1)
