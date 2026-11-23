#!/usr/bin/env python3
"""Verify FP2 AppIcon matches the legacy FP2 source byte-for-byte; ASC verification is HUMAN-REQUIRED."""
import hashlib
import json
import struct
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
record = json.loads((repo / "fp2-manabi-sprint/ios/appicon-provenance.json").read_text())
current = repo / record["current_icon_path"]
data = current.read_bytes()
sha = hashlib.sha256(data).hexdigest()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("FAIL: current AppIcon is not PNG")
width, height = struct.unpack(">II", data[16:24])
assert (width, height) == (1024, 1024), "FAIL: AppIcon must be 1024x1024"
assert data[25] == 2, "FAIL: AppIcon must be opaque RGB PNG"
assert sha == record["current_icon_sha256"], "FAIL: current icon hash drift"
assert sha == record["internal_reference_sha256"], "FAIL: current icon does not match FP2 legacy reference SHA-256"
assert record["current_icon_git_blob_sha"] == record["internal_reference_git_blob_sha"], "FAIL: Git blob identity mismatch"

# If the reference is checked out in the current branch, compare actual bytes as well.
reference = repo / record["internal_reference_path"]
if reference.is_file():
    assert reference.read_bytes() == data, "FAIL: source reference bytes differ"

assert record["asc_verified"] is False, "ASC readback was not performed"
assert record["asc_comparison"] == "HUMAN_REQUIRED"
print("PASS: internal FP2 AppIcon 1024x1024 RGB / SHA-256:", sha)
print("PASS: legacy reference Git blob SHA:", record["internal_reference_git_blob_sha"])
print("HUMAN-REQUIRED: App Store Connect-side icon comparison was NOT performed")
