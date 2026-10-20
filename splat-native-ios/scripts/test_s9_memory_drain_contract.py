#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
trainer = (root / "SplatNative" / "SH3PreservingGaussianTrainer.swift").read_text(encoding="utf-8")
policy = (root / "SplatNative" / "SplatReconstructionPolicy.swift").read_text(encoding="utf-8")
guard = (root / "SplatNative" / "SplatResourceGuard.swift").read_text(encoding="utf-8")
scan_model = (root / "SplatNative" / "ScanModel.swift").read_text(encoding="utf-8")
root_view = (root / "SplatNative" / "RootScanView.swift").read_text(encoding="utf-8")

required_trainer = [
    "applyThermalPacingBeforeStep()",
    "return autoreleasepool {",
    "let stats = base.step()",
    "stats.iteration % 20 == 0",
    "msplatSync()",
]
for token in required_trainer:
    assert token in trainer, f"missing S9 drain invariant: {token}"

# The sync must happen inside the per-step autorelease scope and after the step has produced stats.
pool = trainer.index("return autoreleasepool {")
step = trainer.index("let stats = base.step()", pool)
sync = trainer.index("msplatSync()", step)
return_stats = trainer.index("return stats", sync)
assert pool < step < sync < return_stats

# ScanModel samples resources every 20 iterations, matching the settled-footprint sync cadence.
assert "iteration % 20 == 0" in scan_model
assert "passResourceGuard.evaluate(splatCount: stats.splatCount)" in scan_model

# Dismantling the ARSCNView is insufficient if ScanModel itself strongly retains ARSession.
# Keep the capture session weak so removing the capture view can actually release the ARKit graph.
assert "private(set) weak var session: ARSession?" in scan_model, "ScanModel still retains ARSession strongly"
assert "private(set) var session: ARSession?" not in scan_model, "strong ARSession retention regressed"

# Retry progress must represent the absolute training target, not reset to a remaining-pass percentage.
assert "Double(resumedIteration) / Double(max(1, effectiveTarget))" in scan_model
assert "Double(iteration) / Double(max(1, effectiveTarget))" in scan_model
assert "Double(iteration - passStart) / Double(passSpan)" not in scan_model
assert "resumedIteration >= effectiveTarget ? 1 : 0" not in scan_model

# The live ARKit/SceneKit renderer is useful for ready/capture/resume, but must not stay resident
# through reconstruction, finished, or failure screens.
for token in [
    "private var needsCaptureRenderer: Bool",
    "case .ready, .capturing, .captured:",
    "case .training, .finished, .failed:",
    "if needsCaptureRenderer {",
    "static func dismantleUIView",
    "uiView.session.pause()",
    "uiView.scene = SCNScene()",
    "coordinator.prepareForDismantle()",
]:
    assert token in root_view, f"missing S9 capture-renderer teardown invariant: {token}"

# Build 6 quality and safety contracts must not be weakened to get past memory pressure.
for token in [
    "static let standardIterations = 7_000",
    "static let datasetDownscale: Float = 4.0",
    "config.shDegree = 3",
]:
    assert token in policy, f"quality contract changed: {token}"

for token in [
    "let maximumBudget = 1_536 * mib",
    "let minimumReserve = 256 * mib",
    "let maximumReserve = 512 * mib",
]:
    assert token in guard, f"resource safety limit changed: {token}"

assert "jpegData(compressionQuality: 0.90)" in scan_model, "capture JPEG quality changed"
print("PASS: S9 drains training temporaries, releases capture ownership, preserves absolute resume progress, and keeps quality/safety limits")
