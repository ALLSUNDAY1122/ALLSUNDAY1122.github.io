#!/usr/bin/env python3
"""S13 depth-seeded reconstruction contract.

This gate is intentionally source/determinism oriented. The normal Native iOS workflow performs the
actual Swift compile after XcodeGen runs the canonical materializer, which composes S13 before the
existing S7-S12 Msplat patches.
"""
from __future__ import annotations

import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILDER = (ROOT / "SplatNative" / "SplatDepthSeedBuilder.swift").read_text()
PATCHER = (ROOT / "scripts" / "apply_s13_depth_seed.py").read_text()
MATERIALIZER = (ROOT / "scripts" / "materialize_msplat_s7_wave1.sh").read_text()
PROJECT = (ROOT / "project.yml").read_text()
POLICY = (ROOT / "SplatNative" / "SplatReconstructionPolicy.swift").read_text()
RESOURCE = (ROOT / "SplatNative" / "SplatResourceGuard.swift").read_text()

for token in (
    "recipeVersion = 1",
    "targetSamplesPerFrame = 900",
    "voxelDensity: Float = 100",
    "minimumDepth: Float = 0.18",
    "maximumDepth: Float = 5.0",
    "minimumGeometryPointCount = 64",
    "maximumDepthSeedPointCount = 120_000",
    "case depth",
    "case rawFeaturePoints",
    "SplatSeedColorizer.colorize",
    "SplatSkySeeder.makeSeeds",
    "requiresFreshTrainer: true",
    "requiresFreshTrainer: false",
    "s13-seed-recipe.json",
):
    assert token in BUILDER, f"missing S13 builder contract: {token}"

# The reference iOS geometry convention is ARKit camera-to-world with the optical axis on -Z.
for token in (
    "let cameraX = (imageX - frame.cx) * z / frame.flX",
    "let cameraY = (frame.cy - imageY) * z / frame.flY",
    "cameraToWorld * SIMD4<Float>(cameraX, cameraY, -z, 1)",
):
    assert token in BUILDER, f"missing depth back-projection contract: {token}"

# Future captures prefer smoothed depth while retaining sceneDepth fallback. The first S13 recipe
# transition must invalidate a Build-8-era checkpoint; subsequent S13 resumes must reuse it.
for token in (
    "frame.smoothedSceneDepth ?? frame.sceneDepth",
    "SplatDepthSeedBuilder.preparePointCloudPLY",
    "seedOutcome.requiresFreshTrainer",
    "FileManager.default.removeItem(at: checkpoint)",
    "running-preflight-seed-",
    "seedOutcome.source.rawValue",
):
    assert token in PATCHER, f"missing S13 materializer contract: {token}"

# The physical A/B test must reuse the exact finished raw capture rather than requiring a recapture.
# Protect the currently trusted Build-8 result before switching only the in-memory model to captured;
# the on-disk manifest stays finished until train() enters the existing atomic processing transition.
for token in (
    "restoreFinishedProjectForS13Reprocess",
    "SplatProjectTrustRecovery.trustedResultURL",
    "SplatPreviousResultEvidence.preserveBeforeReprocess",
    "projectStore.reprocessRequest",
    "restoreCaptureCheckpoint(checkpoint)",
    "datasetReady = true",
    "phase = .captured",
    "同じ撮影raw",
    "同じ撮影から再生成",
    "canReprocessTrusted",
):
    assert token in PATCHER, f"missing same-raw S13 A/B contract: {token}"

# The screen recording must state which branch of the seed experiment actually ran. Without this,
# a non-LiDAR/rawFeature fallback could be mistaken for a failed depth-seed experiment.
for token in (
    "reconstructionSeedEvidenceText",
    "S13 seed:",
    "seedOutcome.depthFrameCount",
    "seedOutcome.geometryPointCount",
    "training evidence UI",
    "result evidence UI",
):
    assert token in PATCHER, f"missing visible S13 seed telemetry contract: {token}"

# Preserve the historical XcodeGen entrypoint so S7-S12 composition contracts remain stable.
assert "preGenCommand: bash scripts/materialize_msplat_s7_wave1.sh" in PROJECT
assert 'python3 "$ROOT/scripts/apply_s13_depth_seed.py"' in MATERIALIZER

# Quality/resource invariants must not move in the geometry experiment.
for token in (
    "standardIterations = 7_000",
    "datasetDownscale: Float = 4.0",
    "config.shDegree = 3",
    "config.densifyGradThresh = 0.0002",
    "config.densifySizeThresh = 0.01",
):
    assert token in POLICY, f"S13 must preserve reconstruction quality contract: {token}"
for token in (
    "residentMemoryBudgetBytes",
    "minimumAvailableMemoryReserveBytes",
    "peakResidentMemoryBytes",
):
    assert token in RESOURCE, f"S13 must preserve resource safety contract: {token}"

# Mirror a center-pixel depth sample through the identity ARKit pose: it must remain one metre
# forward on camera -Z. This catches accidental axis flips in future edits.
def backproject(image_x, image_y, z, fx, fy, cx, cy):
    camera_x = (image_x - cx) * z / fx
    camera_y = (cy - image_y) * z / fy
    return camera_x, camera_y, -z

x, y, z = backproject(10.0, 10.0, 1.0, 10.0, 10.0, 10.0, 10.0)
assert math.isclose(x, 0.0) and math.isclose(y, 0.0) and math.isclose(z, -1.0)

# 1 cm voxel density should merge sub-centimetre duplicates but preserve a clearly separate surface.
def voxel(point):
    return tuple(math.floor(v * 100.0) for v in point)

assert voxel((0.001, 0.001, -1.001)) == voxel((0.009, 0.009, -1.009))
assert voxel((0.001, 0.001, -1.001)) != voxel((0.021, 0.001, -1.001))

print("PASS: S13 depth-seed geometry + same-raw A/B + visible seed telemetry contract")
