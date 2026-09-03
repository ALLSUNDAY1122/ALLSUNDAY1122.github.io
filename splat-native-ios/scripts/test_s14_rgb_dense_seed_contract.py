#!/usr/bin/env python3
"""S14 RGB multi-view dense-seed source contract."""
from __future__ import annotations

import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOFTWARE = (ROOT / "SplatNative" / "SplatSoftwareDepthSeedBuilder.swift").read_text()
SEED = (ROOT / "SplatNative" / "SplatDepthSeedBuilder.swift").read_text()
POLICY = (ROOT / "SplatNative" / "SplatReconstructionPolicy.swift").read_text()
RESOURCE = (ROOT / "SplatNative" / "SplatResourceGuard.swift").read_text()

for token in (
    "maximumSelectedFrames = 18",
    "maximumReferenceFrames = 8",
    "maximumNeighborFrames = 4",
    "hypothesisCount = 30",
    "pixelStride = 2",
    "bestCostThreshold: Float = 34",
    "uniquenessMargin: Float = 3.5",
    "minimumBaseline: Float = 0.025",
    "maximumBaseline: Float = 0.75",
    "minimumDirectionDot: Float = 0.50",
    "nearDepth: Float = 0.12",
    "farDepth: Float = 2.8",
    "voxelDensity: Float = 100",
    "maximumPointCount = 120_000",
    "minimumUsablePointCount = 2_000",
    "secondCost - bestCost > uniquenessMargin",
    "simd_dot(reference.forward, frames[index].forward)",
    "SIMD4<Float>(x, y, -depth, 1)",
    "reference.rgb.sample(u, v)",
):
    assert token in SOFTWARE, f"missing S14 software-depth contract: {token}"

for token in (
    'legacyMetadataFileName = "s13-seed-recipe.json"',
    'metadataFileName = "s14-seed-recipe.json"',
    "case planeSweep",
    "SplatSoftwareDepthSeedBuilder.makeSeedPoints",
    "softwareResult.points.count >= SplatSoftwareDepthSeedBuilder.minimumUsablePointCount",
    "source = .planeSweep",
    "geometryColors = softwareResult.colors",
    "source = .rawFeaturePoints",
    "SplatSeedColorizer.colorize",
    "requiresFreshTrainer: true",
):
    assert token in SEED, f"missing S14 seed-routing contract: {token}"

# S14 changes initialization only. Training and safety policy must remain frozen.
for token in (
    "standardIterations = 7_000",
    "datasetDownscale: Float = 4.0",
    "config.shDegree = 3",
    "config.densifyGradThresh = 0.0002",
    "config.densifySizeThresh = 0.01",
):
    assert token in POLICY, f"S14 must preserve reconstruction contract: {token}"
for token in (
    "residentMemoryBudgetBytes",
    "minimumAvailableMemoryReserveBytes",
    "peakResidentMemoryBytes",
):
    assert token in RESOURCE, f"S14 must preserve resource safety contract: {token}"

# Mirror the optical-axis convention used by current MeshPlaneSweepMVS and S13 hardware depth.
def backproject(u, v, depth, fx, fy, cx, cy):
    x = (u - cx) / fx * depth
    y = -(v - cy) / fy * depth
    return x, y, -depth

x, y, z = backproject(10.0, 10.0, 1.0, 10.0, 10.0, 10.0, 10.0)
assert math.isclose(x, 0.0) and math.isclose(y, 0.0) and math.isclose(z, -1.0)

# 1 cm voxelization must collapse sub-centimetre duplicates.
def voxel(p):
    return tuple(math.floor(v * 100.0) for v in p)

assert voxel((0.001, 0.001, -1.001)) == voxel((0.009, 0.009, -1.009))
assert voxel((0.001, 0.001, -1.001)) != voxel((0.021, 0.001, -1.001))

print("PASS: S14 RGB multi-view software-depth dense-seed contract")
