#!/usr/bin/env python3
"""Fail-closed provenance and integrity check for the exact FP2 Apple AppIcon PNG."""
import hashlib
import json
import struct
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
record = json.loads((repo / "fp2-manabi-sprint/ios/appicon-provenance.json").read_text())
asset = repo / record["current_icon_path"]
data = asset.read_bytes()
sha = hashlib.sha256(data).hexdigest()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("FAIL: not a PNG")
width, height = struct.unpack(">II", data[16:24])
color_type = data[25]
assert (width, height) == (1024, 1024), "AppIcon must be 1024x1024"
assert color_type == 2, "AppIcon must be opaque RGB (no alpha)"
assert sha == record["current_icon_sha256"], "Current AppIcon SHA-256 drift"
print("Current icon PNG 1024x1024 RGB / SHA256 pinned:", sha)
expected = record.get("canonical_sha256")
if not expected:
    raise SystemExit("BLOCKED: official FP2 AppIcon and recorded SHA256 not found in source-of-truth. No substitution allowed.")
assert sha == expected, "FAIL: current AppIcon != canonical AppIcon"
print("PASS: source-of-truth AppIcon SHA256 matched")
