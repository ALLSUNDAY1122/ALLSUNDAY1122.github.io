#!/usr/bin/env python3
"""Deterministic S2 reconstruction contracts that do not require booting iOS Simulator.

The iOS test bundle is still compiled by xcodebuild build-for-testing, which catches Swift/API/link
regressions. These contracts cover reconstruction invariants while msplat runtime execution remains a
real-device gate because the Simulator path has previously stalled in CI.
"""
from __future__ import annotations

import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
POLICY = (ROOT / "SplatNative" / "SplatReconstructionPolicy.swift").read_text()
MODEL = (ROOT / "SplatNative" / "ScanModel.swift").read_text()
COLORIZER = (ROOT / "SplatNative" / "SplatSeedColorizer.swift").read_text()
SKY = (ROOT / "SplatNative" / "SplatSkySeeder.swift").read_text()
RESOURCE = (ROOT / "SplatNative" / "SplatResourceGuard.swift").read_text()
TESTS = (ROOT / "SplatNativeTests" / "SplatReconstructionPolicyTests.swift").read_text()


def require(pattern: str, text: str, message: str) -> re.Match[str]:
    match = re.search(pattern, text, re.MULTILINE)
    assert match, message
    return match


def int_constant(name: str) -> int:
    raw = require(rf"static let {re.escape(name)}\s*=\s*([0-9_]+)", POLICY, f"missing {name}").group(1)
    return int(raw.replace("_", ""))


horizon = int_constant("trainingHorizon")
standard = int_constant("standardIterations")
enhancement = int_constant("enhancementIncrement")
checkpoint = int_constant("checkpointInterval")
thermal = int_constant("thermalCheckInterval")
assert horizon >= 30_000
assert 7_000 <= standard < horizon
assert enhancement > 0 and standard + enhancement <= horizon
assert 1 <= checkpoint <= 2_000
assert 1 <= thermal <= 250

for contract in (
    r"config\.iterations\s*=\s*Int32\(trainingHorizon\)",
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

assert "base + enhancementIncrement" in POLICY
assert "min(trainingHorizon" in POLICY
for ply_field in ("property uchar red", "property uchar green", "property uchar blue"):
    assert ply_field in MODEL, f"colored seed PLY contract missing: {ply_field}"

assert "trainer.loadCheckpoint" in MODEL
assert "trainer.saveCheckpoint" in MODEL
assert "requiresThermalPause" in MODEL
assert "func enhanceResult()" in MODEL
assert "enhancementTarget(from: trainingIteration)" in MODEL

# Checkpoint durability is part of the retry/resume contract. Msplat's pinned public API returns Bool
# from saveCheckpoint(to:), so callers must not discard that result and then claim a recoverable
# checkpoint in telemetry. Every save site must fail closed when persistence fails.
checkpoint_save_guards = re.findall(
    r"guard\s+trainer\.saveCheckpoint\(to:\s*checkpoint\.path\)\s+else",
    MODEL,
)
assert len(checkpoint_save_guards) >= 4, "all checkpoint save sites must validate the Bool result"
assert "_ = trainer.saveCheckpoint" not in MODEL, "checkpoint save success must never be ignored"
for outcome in (
    "failed-checkpoint-save-resource-pause",
    "cancelled-checkpoint-save-failed",
    "failed-checkpoint-save-training",
    "failed-checkpoint-save-final",
):
    assert outcome in MODEL, f"missing fail-closed checkpoint outcome: {outcome}"
checkpoint_failure_start = MODEL.index("let failCheckpointSave:")
checkpoint_failure_end = MODEL.index("if checkpointExists", checkpoint_failure_start)
checkpoint_failure_helper = MODEL[checkpoint_failure_start:checkpoint_failure_end]
assert ".checkpointSave" in checkpoint_failure_helper
assert ".trainerError" in checkpoint_failure_helper
require(
    r"iteration\s*,\s*count\s*,\s*nil\s*,\s*checkpointSaveFailureMessage",
    checkpoint_failure_helper,
    "checkpoint persistence failure must not claim a checkpoint iteration",
)

# Abrupt process termination cannot execute a Swift failure branch. Persist a phase breadcrumb
# before expensive/uninterruptible reconstruction work, and refresh training progress only at the existing
# checkpoint cadence so Build 5 evidence identifies the last durable phase without excessive I/O.
for outcome, phase in (
    ("running-preflight", ".preflight"),
    ("running-dataset-init", ".datasetInit"),
    ("running-trainer-init", ".trainerInit"),
    ("running-checkpoint-load", ".checkpointLoad"),
    ("running-checkpoint-save", ".checkpointSave"),
    ("running-export", ".export"),
    ("running-preview", ".preview"),
):
    require(
        rf'{re.escape(outcome)}"[\s\S]{{0,500}}{re.escape(phase)}',
        MODEL,
        f"missing durable reconstruction phase breadcrumb: {outcome} / {phase}",
    )
assert MODEL.count('"running-training-step"') >= 2, "training must persist start + checkpoint-cadence heartbeats"
require(
    r'if checkpointDue \{[\s\S]{0,500}running-training-step',
    MODEL,
    "training heartbeat must reuse checkpoint cadence rather than per-step disk writes",
)

# Expensive point-color projection and sky seeding must run after Task.detached begins, not while
# finishCapture is transitioning the UI from capture to the processing screen.
finish = MODEL.index("func finishCapture()")
train = MODEL.index("private func startTraining(")
detached = MODEL.index("Task.detached", train)
prepare = MODEL.index("Self.preparePointCloudPLY", detached)
dataset = MODEL.index("let dataset = GaussianDataset", prepare)
assert finish < train < detached < prepare < dataset
assert "preparePointCloudPLY" not in MODEL[finish:train]

# Scaniverse-style splats retain background and sky. S2 therefore must not universally replace the
# background with a foreground mask; only conservative far-field sky seeds are added.
assert "SplatForegroundIsolator" not in MODEL
assert "SplatSkySeeder.makeSeeds" in MODEL
assert "farDistance: Float = 20" in SKY
assert "borderCandidates.count >= 5" in SKY
assert "hasGeometryNear" in SKY
assert "brightOvercast" in SKY and "blueSky" in SKY
assert "prepareProjectImages" not in COLORIZER

# S8 Sev-2 #4157: training cannot densify without a bounded resource strategy. The process must
# observe iOS memory warnings and phys_footprint, maintain a device-scaled splat ceiling, checkpoint
# before pausing, and persist evidence for the eventual real-device parity run.
for token in (
    "residentMemoryBudgetBytes",
    "maxSplatCount",
    "TASK_VM_INFO",
    "phys_footprint",
    "didReceiveMemoryWarningNotification",
    "passResourceGuard.evaluate",
    "resourcePauseReason",
    "SplatReconstructionRunReport.write",
):
    assert token in (RESOURCE + MODEL), f"resource guard contract missing: {token}"

resource_pause = MODEL.index("if let reason = resourcePauseReason")
checkpoint_before_pause = MODEL.rfind("trainer.saveCheckpoint", 0, resource_pause)
assert checkpoint_before_pause >= 0, "resource pause must be preceded by a recoverable checkpoint"
assert "paused-\\(reason.rawValue)" in MODEL
require(
    r'writeRunReport\(\s*"completed"\s*,\s*\.preview',
    MODEL,
    "completed reconstruction must persist a preview-phase run report",
)
assert "peakResidentMemoryBytes" in RESOURCE
assert "peakSplatCount" in RESOURCE
assert "reconstruction-run-%05d.json" in RESOURCE

for test_name in (
    "testResourceLimitsScaleWithDeviceMemoryAndRemainBounded",
    "testSyntheticHighDensityTriggersCheckpointPauseBeforeUnboundedGrowth",
    "testSyntheticMemoryPressureRecordsPeakAndPauses",
    "testMemoryWarningOverridesOtherwiseSafeResourceSnapshot",
    "testRunReportCapturesSyntheticPeakMemory",
):
    assert test_name in TESTS, f"synthetic stress regression missing: {test_name}"

# Coordinate-contract mirror: ARKit camera looks down -Z, image y grows downward.
def project(point, fx=10.0, fy=10.0, cx=10.0, cy=10.0):
    x, y, z = point
    depth = -z
    assert depth > 0
    return fx * x / depth + cx, cy - fy * y / depth, depth

u, v, d = project((0.0, 0.0, -1.0))
assert math.isclose(u, 10.0) and math.isclose(v, 10.0) and math.isclose(d, 1.0)
_, upper_v, _ = project((0.0, 0.5, -1.0))
assert math.isclose(upper_v, 5.0)

print("PASS: deterministic S2 reconstruction contracts")
