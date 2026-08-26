#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"{label}: expected {expected} matches, found {count}")
    return text.replace(old, new)


def patch_training_config(root: Path) -> None:
    path = root / "Sources/Msplat/TrainingConfig.swift"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        "    public var splitScreenSize: Float = 0.05\n    public var keepCrs: Bool = false\n",
        '''    public var splitScreenSize: Float = 0.05
    /// S12: transient pre-cull population ceiling for densification admission.
    /// Zero preserves upstream/unbounded behavior.
    public var maxGaussianCount: Int32 = 0
    public var keepCrs: Bool = false
''',
        "TrainingConfig maxGaussianCount property",
    )
    text = replace_exact(
        text,
        "        c.splitScreenSize = splitScreenSize\n        c.keepCrs = keepCrs\n",
        '''        c.splitScreenSize = splitScreenSize
        c.maxGaussianCount = maxGaussianCount
        c.keepCrs = keepCrs
''',
        "TrainingConfig C bridge",
    )
    path.write_text(text, encoding="utf-8")


def patch_c_api(root: Path) -> None:
    path = root / "Sources/MsplatCore/include/msplat_c_api.h"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        "    float splitScreenSize;\n    bool keepCrs;\n",
        "    float splitScreenSize;\n    int maxGaussianCount;\n    bool keepCrs;\n",
        "C config maxGaussianCount field",
    )
    text = replace_exact(
        text,
        "    c.splitScreenSize = 0.05f;\n    c.keepCrs = false;\n",
        "    c.splitScreenSize = 0.05f;\n    c.maxGaussianCount = 0;\n    c.keepCrs = false;\n",
        "C config default",
    )
    path.write_text(text, encoding="utf-8")


def patch_cpp_api_header(root: Path) -> None:
    path = root / "Sources/MsplatCore/internal/include/msplat_api.hpp"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        "    float splitScreenSize = 0.05f;\n    bool keepCrs = false;\n",
        "    float splitScreenSize = 0.05f;\n    int maxGaussianCount = 0;\n    bool keepCrs = false;\n",
        "C++ config maxGaussianCount field",
    )
    path.write_text(text, encoding="utf-8")


def patch_cpp_api(root: Path) -> None:
    path = root / "Sources/MsplatCore/src/msplat_api.mm"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        '''        config.densifyGradThresh, config.densifySizeThresh,
        config.stopScreenSizeAt, config.splitScreenSize,
        config.iterations, config.keepCrs,
''',
        '''        config.densifyGradThresh, config.densifySizeThresh,
        config.stopScreenSizeAt, config.splitScreenSize, config.maxGaussianCount,
        config.iterations, config.keepCrs,
''',
        "Trainer forwards maxGaussianCount to Model",
    )
    text = replace_exact(
        text,
        "    cfg.splitScreenSize = c.splitScreenSize;\n    cfg.keepCrs = c.keepCrs;\n",
        "    cfg.splitScreenSize = c.splitScreenSize;\n    cfg.maxGaussianCount = c.maxGaussianCount;\n    cfg.keepCrs = c.keepCrs;\n",
        "C config conversion",
    )
    path.write_text(text, encoding="utf-8")


def patch_model_header(root: Path) -> None:
    path = root / "Sources/MsplatCore/internal/include/model.hpp"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        '''        int refineEvery, int warmupLength, int resetAlphaEvery, float densifyGradThresh, float densifySizeThresh, int stopScreenSizeAt, float splitScreenSize,
        int maxSteps, bool keepCrs,
''',
        '''        int refineEvery, int warmupLength, int resetAlphaEvery, float densifyGradThresh, float densifySizeThresh, int stopScreenSizeAt, float splitScreenSize, int maxGaussianCount,
        int maxSteps, bool keepCrs,
''',
        "Model constructor budget parameter",
    )
    text = replace_exact(
        text,
        "  float splitScreenSize;\n  int maxSteps;\n",
        "  float splitScreenSize;\n  int maxGaussianCount;\n  int maxSteps;\n",
        "Model budget field",
    )
    path.write_text(text, encoding="utf-8")


def patch_model_cpp(root: Path) -> None:
    path = root / "Sources/MsplatCore/src/model.cpp"
    text = path.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        "#include <limits>\n",
        "#include <limits>\n#include <vector>\n",
        "model vector include",
    )
    text = replace_exact(
        text,
        '''    int refineEvery, int warmupLength, int resetAlphaEvery, float densifyGradThresh, float densifySizeThresh, int stopScreenSizeAt, float splitScreenSize,
    int maxSteps, bool keepCrs,
''',
        '''    int refineEvery, int warmupLength, int resetAlphaEvery, float densifyGradThresh, float densifySizeThresh, int stopScreenSizeAt, float splitScreenSize, int maxGaussianCount,
    int maxSteps, bool keepCrs,
''',
        "Model implementation budget parameter",
    )
    text = replace_exact(
        text,
        '''      stopScreenSizeAt(stopScreenSizeAt), splitScreenSize(splitScreenSize),
      maxSteps(maxSteps), keepCrs(keepCrs) {
''',
        '''      stopScreenSizeAt(stopScreenSizeAt), splitScreenSize(splitScreenSize),
      maxGaussianCount(maxGaussianCount),
      maxSteps(maxSteps), keepCrs(keepCrs) {
''',
        "Model budget initializer",
    )

    start = text.index("        if (doDensification){\n")
    end = text.index("\n        if (step < stopSplitAt && step % resetInterval == refineEvery){", start)
    old = text[start:end]
    required = [
        "prepareDensifyClassificationScratch();",
        "msplat_prepare_densify(",
        "ensureCapacity(population);",
        "prepareDensifyOutputScratch(population);",
        "int new_count = msplat_densify(",
    ]
    for marker in required:
        if marker not in old:
            raise RuntimeError(f"S10 densification block missing before S12: {marker}")

    new = r'''        if (doDensification){
            int numPointsBefore = num_active;
            float half_max_dim = 0.5f * static_cast<float>((std::max)(lastWidth, lastHeight));
            int check_screen = (step < stopScreenSizeAt) ? 1 : 0;
            bool checkHuge = step > refineEvery * resetAlphaEvery;

            // S12: the legacy device Gaussian limit becomes a transient
            // pre-cull densification admission budget, not a terminal training
            // result. Preserve one-count headroom on fresh runs so the Swift
            // ResourceGuard keeps its normal 20-iteration sampling cadence
            // instead of being forced into an every-step >= maxSplatCount path.
            prepareDensifyClassificationScratch();
            int numSplits = 0;
            int numDups = 0;
            int population = num_active;
            float effectiveGradThresh = densifyGradThresh;

            auto classifyAt = [&](float threshold) {
                msplat_prepare_densify(
                    num_active,
                    threshold, densifySizeThresh, splitScreenSize, check_screen,
                    xysGradNorm, visCounts, max2DSize, half_max_dim,
                    scales_buf,
                    densify_split_flag, densify_dup_flag,
                    densify_split_prefix, densify_dup_prefix,
                    densify_block_totals,
                    numSplits, numDups
                );
                int64_t population64 = static_cast<int64_t>(num_active) +
                    2LL * numSplits + numDups;
                if (population64 > std::numeric_limits<int>::max())
                    throw std::runtime_error("Densified population exceeds supported size");
                population = static_cast<int>(population64);
            };

            classifyAt(effectiveGradThresh);
            const int unrestrictedPopulation = population;
            const int unrestrictedSplits = numSplits;
            const int unrestrictedDups = numDups;
            const int configuredCeiling = maxGaussianCount > 0
                ? std::max(maxGaussianCount - 1, 0)
                : std::numeric_limits<int>::max();
            const int admissionCeiling = std::max(configuredCeiling, num_active);
            const int growthHeadroom = std::max(admissionCeiling - num_active, 0);
            bool budgetLimited = population > admissionCeiling;

            if (budgetLimited) {
                if (growthHeadroom == 0) {
                    effectiveGradThresh = std::numeric_limits<float>::infinity();
                    classifyAt(effectiveGradThresh);
                } else {
                    // Reuse the exact avg-gradient signal already consumed by
                    // the Metal classifier. Encode transient growth cost in a
                    // weighted score multiset: split contributes two slots,
                    // duplicate contributes one. nth_element finds the first
                    // rejected quality score in average O(N), avoiding a full
                    // sort on every budget-limited refinement.
                    std::vector<float> weightedScores;
                    weightedScores.reserve(static_cast<size_t>(2 * numSplits + numDups));

                    const float *grad = xysGradNorm.data<float>();
                    const float *visible = visCounts.data<float>();
                    const int32_t *split = densify_split_flag.data<int32_t>();
                    const int32_t *dup = densify_dup_flag.data<int32_t>();

                    for (int i = 0; i < num_active; ++i) {
                        if (split[i] == 0 && dup[i] == 0) continue;
                        float vc = visible[i];
                        if (vc <= 0.0f) continue;
                        float score = (grad[i] / vc) * half_max_dim;
                        if (split[i] != 0) {
                            weightedScores.push_back(score);
                            weightedScores.push_back(score);
                        } else {
                            weightedScores.push_back(score);
                        }
                    }

                    if (weightedScores.size() <= static_cast<size_t>(growthHeadroom)) {
                        // Unrestricted population said there was too much
                        // growth, so a smaller weighted set means malformed or
                        // non-finite readback. Fail closed on growth.
                        effectiveGradThresh = std::numeric_limits<float>::infinity();
                    } else {
                        auto cutoff = weightedScores.begin() + growthHeadroom;
                        std::nth_element(
                            weightedScores.begin(), cutoff, weightedScores.end(),
                            std::greater<float>()
                        );
                        // Metal uses avg_grad > threshold, so every candidate
                        // tied at the boundary is rejected as one quality group.
                        // This is deterministic and never first-K/random.
                        effectiveGradThresh = *cutoff;
                    }
                    classifyAt(effectiveGradThresh);

                    // One fail-closed precision fallback. Never binary-search
                    // or loop GPU classification while the device is hot.
                    if (population > admissionCeiling) {
                        effectiveGradThresh = std::numeric_limits<float>::infinity();
                        classifyAt(effectiveGradThresh);
                    }
                }

                if (population > admissionCeiling)
                    throw std::runtime_error("S12 densification admission exceeded Gaussian budget");

                fprintf(stderr,
                    "S12 densify budget step=%d active=%d unrestricted=%d admitted=%d limit=%d "
                    "splits=%d->%d dups=%d->%d grad=%.9g\n",
                    step, num_active, unrestrictedPopulation, population, admissionCeiling,
                    unrestrictedSplits, numSplits, unrestrictedDups, numDups, effectiveGradThresh);
            }

            ensureCapacity(population);
            prepareDensifyOutputScratch(population);

            // Preserve the exact deterministic split sampling of S10/pinned msplat.
            {
                std::mt19937 rng(step);
                std::normal_distribution<float> dist(0.0f, 1.0f);
                float *p = densify_random_samples.data<float>();
                for (int64_t i = 0; i < 2LL * num_active * 3; i++) p[i] = dist(rng);
            }

            int fr_stride = (int)featuresRest_buf.stride0();
            int new_count = msplat_densify(
                num_active, population,
                0.1f, 0.5f, 0.15f, check_screen, checkHuge ? 1 : 0,
                max2DSize,
                means_buf, scales_buf, quats_buf,
                featuresDc_buf, featuresRest_buf, opacities_buf, fr_stride,
                adam_exp_avg_buf, adam_exp_avg_sq_buf,
                densify_split_flag, densify_dup_flag,
                densify_split_prefix, densify_dup_prefix,
                densify_keep_flag, densify_keep_prefix,
                densify_block_totals, densify_compact_scratch,
                densify_random_samples
            );

            // Zero admitted growth still enters existing Stage 6 cull/compact.
            // Pruning can therefore reopen headroom while optimizer steps keep
            // running toward the full requested iteration target.
            releaseDensifyScratch();
            num_active = new_count;
            refreshViews();
            std::cout << "Densified: " << numPointsBefore << " -> " << num_active
                      << " gaussians (prepared " << population
                      << (budgetLimited ? ", S12 budget-limited" : "") << ")" << std::endl;
        }
'''
    text = text[:start] + new + text[end:]
    path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_msplat_s12_patch.py <M1+M2+S10-composed-msplat-root>")
    root = Path(sys.argv[1]).resolve()
    patch_training_config(root)
    patch_c_api(root)
    patch_cpp_api_header(root)
    patch_cpp_api(root)
    patch_model_header(root)
    patch_model_cpp(root)
    print("PASS: applied S12 quality-aware bounded densification patch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
