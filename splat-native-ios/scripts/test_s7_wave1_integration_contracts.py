#!/usr/bin/env python3
"""Fail-closed static contracts for the S7-S12 HQ Msplat composition."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"forbidden {label}: {needle}")


project = read("project.yml")
policy = read("SplatNative/SplatReconstructionPolicy.swift")
model = read("SplatNative/ScanModel.swift")
guard = read("SplatNative/SplatResourceGuard.swift")
facade = read("SplatNative/SH3PreservingGaussianTrainer.swift")
exporter = read("SplatNative/SplatExportService.swift")
durability = read("SplatNative/SplatCanonicalSHAsset+ProjectDurability.swift")
materializer = read("scripts/materialize_msplat_s7_wave1.sh")

# One local Msplat package and one composition entrypoint only.
require(project, "preGenCommand: bash scripts/materialize_msplat_s7_wave1.sh", "combined preGen")
require(project, "path: Packages/MsplatMemory", "combined Msplat path")
if ".generated/msplat-m2" in project:
    raise AssertionError("standalone M2 package path leaked into combined project")
if "prepare_msplat_m2.sh" in project:
    raise AssertionError("standalone M2 preGen leaked into combined project")
require(project, "- path: SplatNative/SplatCanonicalSHAsset+ProjectDurability.swift", "SH durability test source")

# Quality contracts must not be traded for completion.
for needle, label in (
    ("static let standardIterations = 7_000", "7000 standard iterations"),
    ("static let datasetDownscale: Float = 4.0", "dataset downscale 4"),
    ("config.shDegree = 3", "SH degree 3"),
    ("config.iterations = Int32(trainingHorizon)", "training horizon"),
    ("config.densifyGradThresh = 0.0002", "canonical densify gradient threshold"),
    ("config.densifySizeThresh = 0.01", "canonical densify size threshold"),
):
    require(policy, needle, label)
require(model, "jpegData(compressionQuality: 0.90)", "capture JPEG quality 0.90")

# Resident/available safety lines and the legacy Gaussian-budget formula remain exact.
for needle, label in (
    ("let minimumBudget = 700 * mib", "minimum resident budget"),
    ("let maximumBudget = 1_536 * mib", "maximum resident budget"),
    ("let minimumReserve = 256 * mib", "minimum available reserve"),
    ("let maximumReserve = 512 * mib", "maximum available reserve"),
    ("let splatBudget = min(900_000, max(300_000, rawCount))", "Gaussian budget formula"),
    ("var densificationBudgetCount: Int { maxSplatCount }", "S12 Gaussian admission alias"),
):
    require(guard, needle, label)
require(policy, "config.maxGaussianCount = Int32(clamping: limits.densificationBudgetCount)", "shared device budget source")

# Keep historical splatBudget decode/report compatibility, but count itself is no longer terminal.
require(guard, "case splatBudget", "historical splatBudget decode")
reject(guard, "else if splatCount >= limits.maxSplatCount", "terminal splat-count pause")

# M3 telemetry/retry/resume invariants.
for needle in (
    "schemaVersion: 3", "SplatTrainingRunGate", "case memoryWarning",
    "case availableMemoryReserve", "case residentMemoryBudget",
    "case checkpointLoad", "case checkpointSave",
):
    require(guard, needle, f"M3 contract {needle}")
for needle in (
    "trainingRunGate", "trainer.loadCheckpoint(from: checkpoint.path)",
    "guard trainer.saveCheckpoint(to: checkpoint.path) else", '"running-training-step"',
):
    require(model, needle, f"M3 orchestration {needle}")

# SH facade/durability remain exact.
for needle in (
    "typealias GaussianTrainer = SH3PreservingGaussianTrainer",
    "func saveCheckpoint(to path: String) -> Bool",
    "func loadCheckpoint(from path: String) -> Int?",
    "SplatCanonicalSHAsset.persistCollisionSafe",
    "SplatCanonicalSHAsset.registerDurableProjectOutput",
):
    require(facade, needle, f"SH facade {needle}")
for needle in ("static let requiredSHDegree: UInt = 3", "higherOrderPropertyCount", "SPZSceneWriter"):
    require(exporter, needle, f"SH export {needle}")
require(durability, "case lossyFingerprintCollision", "SH collision protection")

# Deterministic composition: M1 -> M2 -> S10 -> S12, exact generated dirty inventory.
for needle in (
    "materialize_msplat_memory.sh",
    "apply_msplat_m2_to_existing.sh",
    "test_m2_msplat_memory_patch.py",
    "apply_msplat_s10_patch.py",
    "test_s10_bounded_memory_patch.py",
    "apply_msplat_s12_patch.py",
    "test_s12_bounded_densification_patch.py",
    "MSPLAT_S10_COMPOSED",
    "source_files=11",
    "dirty_paths=12",
):
    require(materializer, needle, f"combined materializer {needle}")

print("PASS: S7-S12 integration contracts preserve M1/M2/S10 memory work, M3 telemetry, SH3, safety lines and quality invariants")
