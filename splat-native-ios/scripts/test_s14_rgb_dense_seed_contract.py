#!/usr/bin/env python3
"""S14 RGB multi-view dense-seed source + camera-geometry contract."""
from __future__ import annotations

import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOFTWARE = (ROOT / "SplatNative" / "SplatSoftwareDepthSeedBuilder.swift").read_text()
SEED = (ROOT / "SplatNative" / "SplatDepthSeedBuilder.swift").read_text()
MESH = (ROOT / "SplatNative" / "MeshDenseMVS.swift").read_text()
POLICY = (ROOT / "SplatNative" / "SplatReconstructionPolicy.swift").read_text()
RESOURCE = (ROOT / "SplatNative" / "SplatResourceGuard.swift").read_text()

for token in (
    "maximumSelectedFrames = 18",
    "maximumReferenceFrames = 8",
    "maximumNeighborFrames = 4",
    "hypothesisCount = 30",
    "refinementHypothesisCount = 7",
    "refinementRadiusInCoarseSteps: Float = 0.55",
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
    "sampleBilinear",
    "refinedDepth(",
    "depth: coarseDepth",
    "useBilinearNeighborSampling: true",
    "let neighborCount = min(neighborIndices.count, maximumNeighborFrames)",
    "var differences = SIMD64<Float>(repeating: 0)",
    "var differenceTotals = SIMD4<Float>(repeating: 0)",
    "var sampleCounts = SIMD4<Int32>(repeating: 0)",
    "let world = backproject(u: u + dx, v: v + dy, depth: depth, frame: reference)",
    "for neighborSlot in 0..<neighborCount",
    "differences[neighborSlot * 16 + sampleIndex] = difference",
    "let meanDifference = differenceTotals[neighborSlot] / Float(samples)",
    "guard neighborCostCount >= 2 else { return nil }",
    "return (total - minimum - maximum) / Float(neighborCostCount - 2)",
):
    assert token in SOFTWARE, f"missing S14 software-depth contract: {token}"

for forbidden in (
    "var neighborCosts: [Float] = []",
    "var referenceValues: [Float] = []",
    "var neighborValues: [Float] = []",
    "var differences = SIMD16<Float>(repeating: 0)",
):
    assert forbidden not in SOFTWARE, f"inner plane-sweep allocation/reprojection regressed: {forbidden}"

# The patch point must be backprojected before entering the neighbor loop, not once per neighbor.
backproject_token = "let world = backproject(u: u + dx, v: v + dy, depth: depth, frame: reference)"
neighbor_loop_token = "for neighborSlot in 0..<neighborCount"
assert SOFTWARE.index(backproject_token, SOFTWARE.index("private static func patchCost")) < SOFTWARE.index(
    neighbor_loop_token, SOFTWARE.index("private static func patchCost")
)

for token in (
    'legacyMetadataFileName = "s13-seed-recipe.json"',
    'metadataFileName = "s14-seed-recipe.json"',
    "static let recipeVersion = 6",
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

# The S14 software seed intentionally inherits the already-shipped MeshPlaneSweepMVS camera/image
# convention. Guard this explicitly: an isolated vertical flip or optical-axis rewrite in only one
# implementation would make the same ARKit intrinsics/poses describe different pixels.
for token in (
    "kCGImageSourceCreateThumbnailWithTransform: false",
    "let y = -(v - frame.cy) / frame.fy * depth",
    "let cameraPoint = SIMD4<Float>(x, y, -depth, 1)",
    "let depth = -camera.z",
    "let y = frame.cy - frame.fy * camera.y / depth",
):
    assert token in SOFTWARE, f"S14 camera/image convention drift: {token}"
    assert token in MESH, f"Mesh MVS camera/image convention drift: {token}"
assert "grayContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))" in SOFTWARE
assert "context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))" in MESH
assert "translateBy(x: 0, y:" not in SOFTWARE, "S14 image orientation changed independently"

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


def matmul4(a, b):
    return tuple(sum(a[r][k] * b[k] for k in range(4)) for r in range(4))


def rigid_inverse(m):
    r = tuple(tuple(m[row][col] for col in range(3)) for row in range(3))
    rt = tuple(tuple(r[col][row] for col in range(3)) for row in range(3))
    t = (m[0][3], m[1][3], m[2][3])
    inv_t = tuple(-sum(rt[row][k] * t[k] for k in range(3)) for row in range(3))
    return (
        (rt[0][0], rt[0][1], rt[0][2], inv_t[0]),
        (rt[1][0], rt[1][1], rt[1][2], inv_t[1]),
        (rt[2][0], rt[2][1], rt[2][2], inv_t[2]),
        (0.0, 0.0, 0.0, 1.0),
    )


def backproject_world(u, v, depth, fx, fy, cx, cy, camera_to_world):
    x = (u - cx) / fx * depth
    y = -(v - cy) / fy * depth
    return matmul4(camera_to_world, (x, y, -depth, 1.0))


def project_world(point, fx, fy, cx, cy, camera_to_world):
    camera = matmul4(rigid_inverse(camera_to_world), point)
    depth = -camera[2]
    assert depth > 0.05
    return (
        cx + fx * camera[0] / depth,
        cy - fy * camera[1] / depth,
        depth,
    )


def centered_patch_cost(reference_values, neighbor_values):
    assert len(reference_values) == len(neighbor_values)
    mean_difference = sum(n - r for r, n in zip(reference_values, neighbor_values)) / len(reference_values)
    return sum(
        abs((n - r) - mean_difference)
        for r, n in zip(reference_values, neighbor_values)
    ) / len(reference_values)


identity = (
    (1.0, 0.0, 0.0, 0.0),
    (0.0, 1.0, 0.0, 0.0),
    (0.0, 0.0, 1.0, 0.0),
    (0.0, 0.0, 0.0, 1.0),
)
center = backproject_world(10.0, 10.0, 1.0, 10.0, 10.0, 10.0, 10.0, identity)
assert all(math.isclose(a, b, abs_tol=1e-8) for a, b in zip(center, (0.0, 0.0, -1.0, 1.0)))

theta = math.radians(20.0)
c, s = math.cos(theta), math.sin(theta)
pose = (
    (c, 0.0, s, 0.18),
    (0.0, 1.0, 0.0, -0.04),
    (-s, 0.0, c, 0.11),
    (0.0, 0.0, 0.0, 1.0),
)
fx, fy, cx, cy = 182.0, 179.0, 96.0, 72.0
for u, v, depth in (
    (96.0, 72.0, 0.35),
    (51.5, 38.0, 0.8),
    (142.0, 103.0, 1.65),
    (80.25, 91.75, 2.4),
):
    world = backproject_world(u, v, depth, fx, fy, cx, cy, pose)
    ru, rv, rd = project_world(world, fx, fy, cx, cy, pose)
    assert math.isclose(ru, u, abs_tol=1e-5), (u, ru)
    assert math.isclose(rv, v, abs_tol=1e-5), (v, rv)
    assert math.isclose(rd, depth, abs_tol=1e-5), (depth, rd)

reference = identity
neighbor = (
    (1.0, 0.0, 0.0, 0.12),
    (0.0, 1.0, 0.0, 0.0),
    (0.0, 0.0, 1.0, 0.0),
    (0.0, 0.0, 0.0, 1.0),
)
world = backproject_world(cx, cy, 1.0, fx, fy, cx, cy, reference)
nu, nv, nd = project_world(world, fx, fy, cx, cy, neighbor)
expected_u = cx - fx * 0.12 / 1.0
assert math.isclose(nu, expected_u, abs_tol=1e-5), (expected_u, nu)
assert math.isclose(nv, cy, abs_tol=1e-5)
assert math.isclose(nd, 1.0, abs_tol=1e-5)

# The local inverse-depth search must materially reduce the quantization floor introduced by
# the 30-value coarse sweep. Evaluate the worst-case midpoint between adjacent coarse hypotheses;
# it is exactly where the old seed was forced furthest onto the wrong front/back layer.
near_depth, far_depth = 0.12, 2.8
coarse_count = 30
fine_count = 7
radius_steps = 0.55
inv_near, inv_far = 1.0 / near_depth, 1.0 / far_depth
coarse_step = (inv_near - inv_far) / (coarse_count - 1)
coarse_inverse = [inv_near - i * coarse_step for i in range(coarse_count)]

for index in (5, 12, 20, 27):
    true_inverse = (coarse_inverse[index] + coarse_inverse[index + 1]) / 2.0
    true_depth = 1.0 / true_inverse
    coarse_center = coarse_inverse[index]
    coarse_depth = 1.0 / coarse_center
    coarse_error = abs(coarse_depth - true_depth)
    radius = coarse_step * radius_steps
    refined_inverse = [
        min(inv_near, max(inv_far, coarse_center - radius + (2.0 * radius * j / (fine_count - 1))))
        for j in range(fine_count)
    ]
    refined_error = min(abs((1.0 / inv) - true_depth) for inv in refined_inverse)
    assert refined_error < coarse_error * 0.25, (index, coarse_error, refined_error)

# Additive auto-exposure changes must not turn the same local structure into a high-cost mismatch.
reference_patch = [20.0, 35.0, 55.0, 30.0, 60.0, 90.0, 25.0, 50.0, 80.0]
bright_patch = [value + 45.0 for value in reference_patch]
raw_exposure_cost = sum(abs(a - b) for a, b in zip(reference_patch, bright_patch)) / len(reference_patch)
assert raw_exposure_cost > 34.0
assert math.isclose(centered_patch_cost(reference_patch, bright_patch), 0.0, abs_tol=1e-6)
wrong_structure = [80.0, 50.0, 25.0, 90.0, 60.0, 30.0, 55.0, 35.0, 20.0]
assert centered_patch_cost(reference_patch, wrong_structure) > 20.0

# Multi-view cost must remain on the same per-pixel intensity scale while resisting one bad view.
def robust_multiview_cost(costs):
    costs = sorted(costs)
    if len(costs) < 2:
        return None
    if len(costs) == 2:
        return (costs[0] + costs[1]) * 0.5
    total = sum(costs)
    if len(costs) == 3:
        return total - min(costs) - max(costs)
    return (total - min(costs) - max(costs)) / (len(costs) - 2)

assert math.isclose(robust_multiview_cost([8.0, 10.0]), 9.0)
assert math.isclose(robust_multiview_cost([8.0, 10.0, 9.0]), 9.0)
assert math.isclose(robust_multiview_cost([8.0, 9.0, 10.0, 120.0]), 9.5)
assert sum([8.0, 9.0, 10.0, 120.0]) / 4.0 > 34.0
assert robust_multiview_cost([8.0, 9.0, 10.0, 120.0]) < 34.0
assert robust_multiview_cost([8.0]) is None

# 1 cm voxelization must collapse sub-centimetre duplicates but retain distinct geometry.
def voxel(p):
    return tuple(math.floor(v * 100.0) for v in p)

assert voxel((0.001, 0.001, -1.001)) == voxel((0.009, 0.009, -1.009))
assert voxel((0.001, 0.001, -1.001)) != voxel((0.021, 0.001, -1.001))

print("PASS: S14 RGB dense-seed + shared-backprojection exposure-normalized robust refined depth contract")
