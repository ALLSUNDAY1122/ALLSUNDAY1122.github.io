#!/usr/bin/env python3
"""Fail-closed static contracts for the S7/S10 HQ Msplat composition."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


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

# Quality contracts must not be traded for memory headroom.
for needle, label in (
    ("static let standardIterations = 7_000", "7000 standard iterations"),
    ("static let datasetDownscale: Float = 4.0", "dataset downscale 4"),
    ("config.shDegree = 3", "SH degree 3"),
    ("config.iterations = Int32(trainingHorizon)", "training horizon"),
):
    require(policy, needle, label)
require(model, "jpegData(compressionQuality: 0.90)", "capture JPEG quality 0.90")

# ResourceGuard thresholds stay unchanged; S10 lowers allocations rather than
# moving the safety line.
for needle, label in (
    ("let minimumBudget = 700 * mib", "minimum resident budget"),
    ("let maximumBudget = 1_536 * mib", "maximum resident budget"),
    ("let minimumReserve = 256 * mib", "minimum available reserve"),
    ("let maximumReserve = 512 * mib", "maximum available reserve"),
    ("let splatBudget = min(900_000, max(300_000, rawCount))", "Gaussian guard range"),
):
    require(guard, needle, label)

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

# Deterministic composition: M1 -> M2 validation -> S10, exact dirty inventory.
for needle in (
    "materialize_msplat_memory.sh",
    "apply_msplat_m2_to_existing.sh",
    "test_m2_msplat_memory_patch.py",
    "apply_msplat_s10_patch.py",
    "test_s10_bounded_memory_patch.py",
    "source_files=8",
    "dirty_paths=9",
):
    require(materializer, needle, f"combined materializer {needle}")

print("PASS: S7/S10 integration contracts preserve M1+M2 ownership, M3 telemetry, SH3, safety thresholds and quality invariants")
