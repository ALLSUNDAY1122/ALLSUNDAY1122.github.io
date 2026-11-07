#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise RuntimeError(f"missing {label}: {marker}")


def reject(text: str, marker: str, label: str) -> None:
    if marker in text:
        raise RuntimeError(f"forbidden {label}: {marker}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test_s12_bounded_densification_patch.py <msplat-root>")
    root = Path(sys.argv[1]).resolve()

    swift = (root / "Sources/Msplat/TrainingConfig.swift").read_text(encoding="utf-8")
    c_api = (root / "Sources/MsplatCore/include/msplat_c_api.h").read_text(encoding="utf-8")
    cpp_api_h = (root / "Sources/MsplatCore/internal/include/msplat_api.hpp").read_text(encoding="utf-8")
    cpp_api = (root / "Sources/MsplatCore/src/msplat_api.mm").read_text(encoding="utf-8")
    model_h = (root / "Sources/MsplatCore/internal/include/model.hpp").read_text(encoding="utf-8")
    model = (root / "Sources/MsplatCore/src/model.cpp").read_text(encoding="utf-8")

    # One explicit device budget crosses Swift -> C -> C++ -> Model.
    require(swift, "public var maxGaussianCount: Int32 = 0", "Swift budget config")
    require(swift, "c.maxGaussianCount = maxGaussianCount", "Swift/C budget bridge")
    require(c_api, "int maxGaussianCount;", "C budget field")
    require(c_api, "c.maxGaussianCount = 0;", "C unbounded default")
    require(cpp_api_h, "int maxGaussianCount = 0;", "C++ budget field")
    require(cpp_api, "config.splitScreenSize, config.maxGaussianCount", "Trainer/Model budget forwarding")
    require(cpp_api, "cfg.maxGaussianCount = c.maxGaussianCount;", "C/C++ budget conversion")
    require(model_h, "float splitScreenSize, int maxGaussianCount", "Model constructor budget")
    require(model_h, "int maxGaussianCount;", "Model budget storage")

    # S12 uses the existing quality signal and weighted transient growth cost.
    require(model, "float effectiveGradThresh = densifyGradThresh;", "adaptive per-pass threshold")
    require(model, "const int configuredCeiling = maxGaussianCount > 0", "configured admission ceiling")
    require(model, "? maxGaussianCount", "full configured Gaussian budget")
    reject(model, "maxGaussianCount - 1", "stale one-count ResourceGuard coupling")
    require(model, "float score = (grad[i] / vc) * half_max_dim;", "same avg-gradient quality signal")
    require(model, "std::isfinite(score)", "finite quality-score guard")
    require(model, "bool invalidScore = false;", "invalid score fail-closed state")
    require(model, "weightedScores.push_back(score);", "weighted quality score admission")
    require(model, "weightedScores.push_back(score);\n                            weightedScores.push_back(score);", "split cost two")
    require(model, "std::nth_element(", "linear-average quality cutoff")
    require(model, "std::greater<float>()", "highest-quality-first cutoff")
    require(model, "effectiveGradThresh = *cutoff;", "quality cutoff threshold")
    require(model, "std::numeric_limits<float>::infinity()", "zero-growth fail-closed fallback")
    require(model, "if (population > admissionCeiling)", "post-reclassification budget assertion")

    reject(model, "std::shuffle", "random admission")
    reject(model, "std::sort(", "full-sort admission")
    reject(model, "firstK", "first-K admission")
    reject(model, "for (int attempt", "iterative GPU threshold search")
    reject(model, "while (population > admissionCeiling)", "iterative GPU threshold search")

    # Growth may be zero, but existing culling/compaction still runs.
    require(model, "int new_count = msplat_densify(", "existing densify/cull execution")
    require(model, "num_active = new_count;", "post-cull active population")
    require(model, "Pruning can therefore reopen headroom", "resume-after-prune contract")

    print("PASS: S12 deterministic quality-aware bounded densification contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
