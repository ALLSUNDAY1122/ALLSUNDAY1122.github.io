#!/usr/bin/env python3
"""Deterministic S2 reconstruction contracts that do not require booting iOS Simulator.

The iOS test bundle is still compiled by xcodebuild build-for-testing, which catches Swift/API/link
regressions. These contracts cover the reconstruction invariants that previously tempted CI to boot
an msplat-linked Simulator test process; that runtime path is intentionally reserved for a real device.
"""
from __future__ import annotations

import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
POLICY = (ROOT / "SplatNative" / "SplatReconstructionPolicy.swift").read_text()
MODEL = (ROOT / "SplatNative" / "ScanModel.swift").read_text()
COLORIZER = (ROOT / "SplatNative" / "SplatSeedColorizer.swift").read_text()
ISOLATOR = (ROOT / "SplatNative" / "SplatForegroundIsolator.swift").read_text()


def require(pattern: str, text: str, message: str) -> re.Match[str]:
    match = re.search(pattern, text, re.MULTILINE)
    assert match, message
    return match


def int_constant(name: str) -> int:
    raw = require(rf"static let {re.escape(name)}\s*=\s*([0-9_]+)", POLICY, f"missing {name}").group(1)
    return int(raw.replace("_", ""))


standard = int_constant("standardIterations")
enhancement = int_constant("enhancementIterations")
checkpoint = int_constant("checkpointInterval")
thermal = int_constant("thermalCheckInterval")
assert standard >= 7_000, "standard reconstruction regressed below S2 quality floor"
assert enhancement > standard, "enhancement pass must extend the standard pass"
assert 1 <= checkpoint <= 2_000, "checkpoint interval is too sparse for recoverable on-device training"
assert 1 <= thermal <= 250, "thermal state must be sampled frequently enough during training"

for contract in (
    r"config\.shDegree\s*=\s*3",
    r"config\.shDegreeInterval\s*=\s*1_000",
    r"config\.numDownscales\s*=\s*1",
    r"config\.resolutionSchedule\s*=\s*2_000",
    r"config\.warmupLength\s*=\s*500",
    r"config\.resetAlphaEvery\s*=\s*30",
    r"config\.densifyGradThresh\s*=\s*0\.0002",
    r"config\.densifySizeThresh\s*=\s*0\.01",
):
    require(contract, POLICY, f"reconstruction policy contract missing: {contract}")

for ply_field in ("property uchar red", "property uchar green", "property uchar blue"):
    assert ply_field in MODEL, f"colored seed PLY contract missing: {ply_field}"

assert "trainer.loadCheckpoint" in MODEL
assert "trainer.saveCheckpoint" in MODEL
assert "requiresThermalPause" in MODEL
assert "func enhanceResult()" in MODEL

# Background suppression must happen after capture finalization, inside the detached training task,
# and before GaussianDataset reads training images. This prevents Vision preprocessing from freezing
# the capture-completion UI and guarantees the dataset observes the derived images.
train_start = MODEL.index("func train(")
detached = MODEL.index("Task.detached", train_start)
preprocess = MODEL.index("SplatForegroundIsolator.prepareProjectImages", detached)
dataset = MODEL.index("let dataset = GaussianDataset", detached)
finish = MODEL.index("func finishCapture()")
assert finish < train_start < detached < preprocess < dataset
finish_body = MODEL[finish:train_start]
assert "prepareProjectImages" not in finish_body
assert "prepareProjectImages" not in COLORIZER

# Preserve original captures and reject implausible masks. These source-level bounds mirror the
# Swift unit tests but remain runnable on CI without an iOS runtime.
assert 'rawDirectoryName = "raw-images"' in ISOLATOR
assert "0.04...0.92" in ISOLATOR
assert "centerOccupancy >= 0.10" in ISOLATOR

# Coordinate-contract mirror: ARKit camera looks down -Z, image y grows downward.
def project(point, fx=10.0, fy=10.0, cx=10.0, cy=10.0):
    x, y, z = point
    depth = -z
    assert depth > 0
    return fx * x / depth + cx, cy - fy * y / depth, depth

u, v, d = project((0.0, 0.0, -1.0))
assert math.isclose(u, 10.0) and math.isclose(v, 10.0) and math.isclose(d, 1.0)
_, upper_v, _ = project((0.0, 0.5, -1.0))
assert math.isclose(upper_v, 5.0), "positive camera Y must project upward in top-left image coordinates"

print("PASS: deterministic S2 reconstruction contracts")
