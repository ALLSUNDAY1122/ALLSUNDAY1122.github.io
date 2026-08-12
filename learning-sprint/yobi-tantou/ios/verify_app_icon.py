#!/usr/bin/env python3
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LOCK = json.loads((HERE / "app-icon-lock.json").read_text(encoding="utf-8"))
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(data: bytes):
    if len(data) < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise ValueError("not a PNG/IHDR file")
    return struct.unpack(">II", data[16:24])


def verify(path: Path):
    data = path.read_bytes()
    actual_sha = hashlib.sha256(data).hexdigest()
    width, height = png_size(data)
    errors = []
    if len(data) != LOCK["sizeBytes"]:
        errors.append(f"size {len(data)} != {LOCK['sizeBytes']}")
    if actual_sha != LOCK["sha256"]:
        errors.append(f"sha256 {actual_sha} != {LOCK['sha256']}")
    if width != LOCK["width"] or height != LOCK["height"]:
        errors.append(f"dimensions {width}x{height} != {LOCK['width']}x{LOCK['height']}")
    if errors:
        print("FAIL: canonical AppIcon mismatch")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"PASS: {LOCK['canonicalFileName']} / {width}x{height} / SHA-256 {actual_sha}")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    args = parser.parse_args()
    return verify(args.file)


if __name__ == "__main__":
    sys.exit(main())
