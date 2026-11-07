#!/usr/bin/env python3
"""Static acceptance checks for the S7-M2 msplat memory patch."""

from __future__ import annotations

import sys
from pathlib import Path


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test_m2_msplat_memory_patch.py <patched-msplat-root>")

    root = Path(sys.argv[1]).resolve()
    tensor = (root / "Sources/MsplatCore/internal/include/metal_tensor.hpp").read_text(encoding="utf-8")
    model_h = (root / "Sources/MsplatCore/internal/include/model.hpp").read_text(encoding="utf-8")
    model = (root / "Sources/MsplatCore/src/model.cpp").read_text(encoding="utf-8")

    require(tensor, "#include <memory>", "shared ownership include")
    require(tensor, "std::shared_ptr<void> _buffer", "shared Metal owner")
    require(tensor, "_buffer.reset();", "shared owner reset")
    require(tensor, "_buffer.get()", "Metal buffer bridge through shared owner")
    if "CFRelease(_buffer)" in tensor:
        raise AssertionError("legacy unconditional view CFRelease remains")

    for declaration in (
        "void detachCapacityViews();",
        "void prepareDensifyScratch();",
        "void releaseDensifyScratch();",
    ):
        require(model_h, declaration, "Model memory lifecycle declaration")

    if model.count("buf_capacity = std::max(num_active * 3, 1);") != 2:
        raise AssertionError("expected both setup and checkpoint restore to use 3N capacity")
    if "buf_capacity = num_active * 4;" in model:
        raise AssertionError("legacy 4N trainer capacity remains")

    require(model, "param.reset();", "initial active parameter early release")
    require(model, "MTensor *param_bufs[]", "Adam shape source from capacity buffers")

    require(model, "void Model::prepareDensifyScratch()", "lazy scratch preparation")
    require(model, "const int worst_case = 3 * num_active;", "densifier 3N worst case")
    require(model, "densify_split_flag = gpu_zeros({num_active}", "N-sized split flag")
    require(model, "densify_keep_flag = gpu_zeros({worst_case}", "3N-sized keep flag")
    require(model, "densify_compact_scratch = gpu_zeros({(int64_t)worst_case * fr_stride}", "3N compact scratch")
    require(model, "densify_random_samples = gpu_zeros({2 * num_active, 3}", "2N split random samples")

    require(model, "msplat_gpu_sync();\n    releaseDensifyScratch();\n    detachCapacityViews();", "safe grow boundary")
    require(model, "int growth_cap = buf_capacity + std::max(buf_capacity / 2, 1);", "1.5x capacity growth")
    require(model, "prepareDensifyScratch();", "scratch preparation at densification")
    require(model, "releaseDensifyScratch();\n            num_active = new_count;", "scratch release after synchronized densify")

    setup_start = model.index("void Model::setupOptimizers()")
    setup_end = model.index("void Model::releaseOptimizers()")
    setup = model[setup_start:setup_end]
    forbidden_persistent = (
        "densify_split_flag = gpu_zeros",
        "densify_compact_scratch = gpu_zeros",
        "densify_random_samples = gpu_zeros",
    )
    for needle in forbidden_persistent:
        if needle in setup:
            raise AssertionError(f"densification scratch still persistent in setupOptimizers: {needle}")

    checkpoint_start = model.index("int Model::loadCheckpoint")
    checkpoint_end = model.index("Model::CamSetup Model::prepareCam")
    checkpoint = model[checkpoint_start:checkpoint_end]
    require(checkpoint, "msplat_gpu_sync();\n    detachCapacityViews();\n    releaseOptimizers();", "checkpoint old trainer release")
    require(checkpoint, "buf_capacity = std::max(num_active * 3, 1);", "checkpoint 3N capacity")
    require(checkpoint, "adam_exp_avg[g].reset();", "checkpoint loaded Adam temporary release")
    require(checkpoint, "adam_exp_avg_sq[g].reset();", "checkpoint loaded Adam square temporary release")
    require(checkpoint, "releaseDensifyScratch();", "checkpoint lazy densify scratch")
    for needle in forbidden_persistent:
        if needle in checkpoint:
            raise AssertionError(f"densification scratch still persistent after checkpoint restore: {needle}")

    # Source-grounded SH3 memory arithmetic. These are trainer capacity/scratch
    # bytes only; renderer/image caches and process overhead are intentionally excluded.
    sh_bases = 16
    features_rest_floats = (sh_bases - 1) * 3
    parameter_floats = 3 + 3 + 4 + 3 + features_rest_floats + 1
    parameter_bytes = parameter_floats * 4
    adam_bytes = parameter_bytes * 2
    persistent_per_capacity = parameter_bytes + adam_bytes

    before_steady_per_active = persistent_per_capacity * 4 + (6 * 4 + features_rest_floats * 4 + 3 * 4) * 4
    after_steady_per_active = persistent_per_capacity * 3
    exact_densify_scratch_per_active = 4 * 4 + 2 * 3 * 4 + 3 * features_rest_floats * 4 + 2 * 3 * 4
    after_densify_per_active = after_steady_per_active + exact_densify_scratch_per_active

    assert parameter_bytes == 236
    assert persistent_per_capacity == 708
    assert before_steady_per_active == 3696
    assert after_steady_per_active == 2124
    assert exact_densify_scratch_per_active == 604
    assert after_densify_per_active == 2728

    steady_reduction = 1.0 - after_steady_per_active / before_steady_per_active
    densify_reduction = 1.0 - after_densify_per_active / before_steady_per_active
    print(
        "PASS: S7-M2 memory contract; "
        f"SH3 parameter={parameter_bytes} B/G, persistent-capacity={persistent_per_capacity} B/G, "
        f"capacity-backed initial/checkpoint steady subtotal {before_steady_per_active}->{after_steady_per_active} B/active-G "
        f"({steady_reduction:.1%} reduction), 3N densify subtotal={after_densify_per_active} B/active-G "
        f"({densify_reduction:.1%} below old steady subtotal)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
