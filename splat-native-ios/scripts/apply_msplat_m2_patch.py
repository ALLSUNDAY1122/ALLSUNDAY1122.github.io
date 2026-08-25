#!/usr/bin/env python3
"""Apply the Scaniverse S7-M2 memory patch to the pinned msplat source tree.

This patcher is intentionally fail-closed: every replacement must match the
known upstream revision exactly once. prepare_msplat_m2.sh verifies the git SHA
before invoking this script.
"""

from __future__ import annotations

import sys
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one upstream match, found {count} in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_msplat_m2_patch.py <msplat-root>")

    root = Path(sys.argv[1]).resolve()
    tensor = root / "Sources/MsplatCore/internal/include/metal_tensor.hpp"
    model_h = root / "Sources/MsplatCore/internal/include/model.hpp"
    model_cpp = root / "Sources/MsplatCore/src/model.cpp"

    for path in (tensor, model_h, model_cpp):
        if not path.is_file():
            raise RuntimeError(f"missing pinned msplat source: {path}")

    # MTensor: make Metal buffer ownership explicit and shared across views.
    replace_once(
        tensor,
        "#include <cstring>\n",
        "#include <cstring>\n#include <memory>\n",
        "MTensor include <memory>",
    )
    replace_once(
        tensor,
        "        _buffer = (__bridge_retained void*)buf;\n        _data = [buf contents];  // cache CPU-accessible pointer for C++ access\n",
        "        void* retained = (__bridge_retained void*)buf;\n"
        "        _buffer = std::shared_ptr<void>(retained, [](void* p) {\n"
        "            if (p) CFRelease(p);\n"
        "        });\n"
        "        _data = [buf contents];  // cache CPU-accessible pointer for C++ access\n",
        "MTensor retained Metal owner",
    )
    replace_once(
        tensor,
        "    id<MTLBuffer> buffer() const { return (__bridge id<MTLBuffer>)_buffer; }\n",
        "    id<MTLBuffer> buffer() const { return (__bridge id<MTLBuffer>)_buffer.get(); }\n",
        "MTensor buffer getter",
    )
    replace_once(
        tensor,
        "    bool defined() const { return _buffer != nullptr || !_cpu_data.empty(); }\n    bool isGpu() const { return _buffer != nullptr; }\n",
        "    bool defined() const { return static_cast<bool>(_buffer) || !_cpu_data.empty(); }\n"
        "    bool isGpu() const { return static_cast<bool>(_buffer); }\n",
        "MTensor defined/isGpu",
    )
    replace_once(
        tensor,
        "    void reset() {\n#ifdef __OBJC__\n        if (_buffer) { CFRelease(_buffer); }\n#endif\n        _buffer = nullptr;\n        _data = nullptr;\n",
        "    void reset() {\n        _buffer.reset();\n        _data = nullptr;\n",
        "MTensor reset ownership",
    )
    replace_once(
        tensor,
        "    // Create a view of the first `n` elements along dim 0.\n"
        "    // WARNING: Non-owning — shares the underlying MTLBuffer without retaining it.\n"
        "    // The caller MUST ensure the parent MTensor outlives all views.\n"
        "    // Use-after-free if the parent is destroyed while a view exists.\n",
        "    // Create a view of the first `n` elements along dim 0.\n"
        "    // Views share ownership of the underlying MTLBuffer. This does not duplicate\n"
        "    // GPU storage, but it prevents a parent resize/reset from invalidating a live view.\n",
        "MTensor view ownership comment",
    )
    replace_once(
        tensor,
        "    void* _buffer = nullptr;  // retained id<MTLBuffer> as void*\n",
        "    std::shared_ptr<void> _buffer;  // retained id<MTLBuffer>; shared by zero-copy views\n",
        "MTensor shared owner member",
    )

    # Model interface: explicit capacity-view and densification-scratch lifecycle.
    replace_once(
        model_h,
        "  void refreshViews();\n  void ensureCapacity(int needed);\n",
        "  void refreshViews();\n"
        "  void detachCapacityViews();\n"
        "  void prepareDensifyScratch();\n"
        "  void releaseDensifyScratch();\n"
        "  void ensureCapacity(int needed);\n",
        "Model memory lifecycle declarations",
    )

    # Initial capacity only needs to satisfy the densifier's documented 3*N worst case.
    replace_once(
        model_cpp,
        "    buf_capacity = num_active * 4;\n",
        "    buf_capacity = std::max(num_active * 3, 1);\n",
        "initial trainer capacity",
    )

    # Release each temporary active tensor as soon as it has been copied into its
    # capacity-backed buffer; Adam shapes are then derived from the backing buffers.
    replace_once(
        model_cpp,
        "    auto allocBuf = [&](MTensor &buf, const MTensor &param) {\n"
        "        auto shape = param.shape();\n"
        "        shape[0] = buf_capacity;\n"
        "        buf = gpu_zeros(shape, DType::Float32);\n"
        "        memcpy(buf.data_ptr(), param.data_ptr(), param.nbytes());\n"
        "    };\n"
        "    allocBuf(means_buf, means);\n"
        "    allocBuf(scales_buf, scales);\n"
        "    allocBuf(quats_buf, quats);\n"
        "    allocBuf(featuresDc_buf, featuresDc);\n"
        "    allocBuf(featuresRest_buf, featuresRest);\n"
        "    allocBuf(opacities_buf, opacities);\n\n"
        "    static constexpr float lr_init[] = {0.00016f, 0.005f, 0.001f, 0.0025f, 0.000125f, 0.05f};\n"
        "    MTensor *params[] = {&means, &scales, &quats, &featuresDc, &featuresRest, &opacities};\n"
        "    for (int g = 0; g < N_ADAM_GROUPS; g++) {\n"
        "        auto shape = params[g]->shape();\n",
        "    auto allocBuf = [&](MTensor &param, MTensor &buf) {\n"
        "        auto shape = param.shape();\n"
        "        shape[0] = buf_capacity;\n"
        "        buf = gpu_zeros(shape, DType::Float32);\n"
        "        memcpy(buf.data_ptr(), param.data_ptr(), param.nbytes());\n"
        "        param.reset();\n"
        "    };\n"
        "    allocBuf(means, means_buf);\n"
        "    allocBuf(scales, scales_buf);\n"
        "    allocBuf(quats, quats_buf);\n"
        "    allocBuf(featuresDc, featuresDc_buf);\n"
        "    allocBuf(featuresRest, featuresRest_buf);\n"
        "    allocBuf(opacities, opacities_buf);\n\n"
        "    static constexpr float lr_init[] = {0.00016f, 0.005f, 0.001f, 0.0025f, 0.000125f, 0.05f};\n"
        "    MTensor *param_bufs[] = {&means_buf, &scales_buf, &quats_buf, &featuresDc_buf, &featuresRest_buf, &opacities_buf};\n"
        "    for (int g = 0; g < N_ADAM_GROUPS; g++) {\n"
        "        auto shape = param_bufs[g]->shape();\n",
        "setup optimizer buffer handoff",
    )

    # Densification scratch is no longer resident for the full training run.
    old_scratch_setup = (
        "    densify_split_flag = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    densify_dup_flag = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    densify_split_prefix = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    densify_dup_prefix = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    densify_keep_flag = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    densify_keep_prefix = gpu_zeros({buf_capacity}, DType::Int32);\n"
        "    int max_blocks = (buf_capacity + 1023) / 1024;\n"
        "    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);\n"
        "    int64_t fr_stride = featuresRest.numel() / featuresRest.size(0);\n"
        "    densify_compact_scratch = gpu_zeros({(int64_t)buf_capacity * fr_stride}, DType::Float32);\n"
        "    densify_random_samples = gpu_zeros({buf_capacity, 3}, DType::Float32);\n\n"
    )
    replace_once(model_cpp, old_scratch_setup, "    releaseDensifyScratch();\n\n", "remove persistent densify scratch")

    replace_once(
        model_cpp,
        "    densify_split_flag.reset(); densify_dup_flag.reset();\n"
        "    densify_split_prefix.reset(); densify_dup_prefix.reset();\n"
        "    densify_keep_flag.reset(); densify_keep_prefix.reset();\n"
        "    densify_block_totals.reset(); densify_compact_scratch.reset(); densify_random_samples.reset();\n"
        "}\n\nvoid Model::schedulersStep(int step){\n",
        "    releaseDensifyScratch();\n"
        "}\n\n"
        "void Model::detachCapacityViews(){\n"
        "    means.reset(); scales.reset(); quats.reset();\n"
        "    featuresDc.reset(); featuresRest.reset(); opacities.reset();\n"
        "    for (int g = 0; g < N_ADAM_GROUPS; g++) {\n"
        "        adam_exp_avg[g].reset();\n"
        "        adam_exp_avg_sq[g].reset();\n"
        "    }\n"
        "}\n\n"
        "void Model::releaseDensifyScratch(){\n"
        "    densify_split_flag.reset(); densify_dup_flag.reset();\n"
        "    densify_split_prefix.reset(); densify_dup_prefix.reset();\n"
        "    densify_keep_flag.reset(); densify_keep_prefix.reset();\n"
        "    densify_block_totals.reset(); densify_compact_scratch.reset(); densify_random_samples.reset();\n"
        "}\n\n"
        "void Model::prepareDensifyScratch(){\n"
        "    releaseDensifyScratch();\n"
        "    const int worst_case = 3 * num_active;\n"
        "    densify_split_flag = gpu_zeros({num_active}, DType::Int32);\n"
        "    densify_dup_flag = gpu_zeros({num_active}, DType::Int32);\n"
        "    densify_split_prefix = gpu_zeros({num_active}, DType::Int32);\n"
        "    densify_dup_prefix = gpu_zeros({num_active}, DType::Int32);\n"
        "    densify_keep_flag = gpu_zeros({worst_case}, DType::Int32);\n"
        "    densify_keep_prefix = gpu_zeros({worst_case}, DType::Int32);\n"
        "    int max_blocks = (worst_case + 1023) / 1024;\n"
        "    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);\n"
        "    int64_t fr_stride = featuresRest_buf.stride0();\n"
        "    densify_compact_scratch = gpu_zeros({(int64_t)worst_case * fr_stride}, DType::Float32);\n"
        "    densify_random_samples = gpu_zeros({2 * num_active, 3}, DType::Float32);\n"
        "}\n\n"
        "void Model::schedulersStep(int step){\n",
        "trainer memory lifecycle helpers",
    )

    old_ensure = (
        "void Model::ensureCapacity(int needed){\n"
        "    if (needed <= buf_capacity) return;\n"
        "    int new_cap = std::max(needed, buf_capacity * 2);\n\n"
        "    auto grow = [&](MTensor &buf) {\n"
        "        auto shape = buf.shape();\n"
        "        shape[0] = new_cap;\n"
        "        MTensor new_buf = gpu_zeros(shape, DType::Float32);\n"
        "        size_t copy_bytes = num_active * buf.stride0() * sizeof(float);\n"
        "        memcpy(new_buf.data_ptr(), buf.data_ptr(), copy_bytes);\n"
        "        buf = new_buf;\n"
        "    };\n"
        "    grow(means_buf); grow(scales_buf); grow(quats_buf);\n"
        "    grow(featuresDc_buf); grow(featuresRest_buf); grow(opacities_buf);\n"
        "    for (int g = 0; g < N_ADAM_GROUPS; g++) {\n"
        "        grow(adam_exp_avg_buf[g]);\n"
        "        grow(adam_exp_avg_sq_buf[g]);\n"
        "    }\n"
        "    densify_split_flag = gpu_zeros({new_cap}, DType::Int32);\n"
        "    densify_dup_flag = gpu_zeros({new_cap}, DType::Int32);\n"
        "    densify_split_prefix = gpu_zeros({new_cap}, DType::Int32);\n"
        "    densify_dup_prefix = gpu_zeros({new_cap}, DType::Int32);\n"
        "    densify_keep_flag = gpu_zeros({new_cap}, DType::Int32);\n"
        "    densify_keep_prefix = gpu_zeros({new_cap}, DType::Int32);\n"
        "    int max_blocks = (new_cap + 1023) / 1024;\n"
        "    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);\n"
        "    int64_t fr_stride = featuresRest_buf.stride0();\n"
        "    densify_compact_scratch = gpu_zeros({(int64_t)new_cap * fr_stride}, DType::Float32);\n"
        "    densify_random_samples = gpu_zeros({new_cap, 3}, DType::Float32);\n\n"
        "    buf_capacity = new_cap;\n"
        "    refreshViews();\n"
        "}\n"
    )
    new_ensure = (
        "void Model::ensureCapacity(int needed){\n"
        "    if (needed <= buf_capacity) return;\n\n"
        "    // A grow happens at a densification boundary. Finish outstanding GPU reads\n"
        "    // before detaching views so replaced buffers can be released immediately.\n"
        "    msplat_gpu_sync();\n"
        "    releaseDensifyScratch();\n"
        "    detachCapacityViews();\n\n"
        "    int growth_cap = buf_capacity + std::max(buf_capacity / 2, 1);\n"
        "    int new_cap = std::max(needed, growth_cap);\n\n"
        "    auto grow = [&](MTensor &buf) {\n"
        "        auto shape = buf.shape();\n"
        "        shape[0] = new_cap;\n"
        "        MTensor new_buf = gpu_zeros(shape, DType::Float32);\n"
        "        size_t copy_bytes = num_active * buf.stride0() * sizeof(float);\n"
        "        memcpy(new_buf.data_ptr(), buf.data_ptr(), copy_bytes);\n"
        "        buf = new_buf;\n"
        "    };\n"
        "    grow(means_buf); grow(scales_buf); grow(quats_buf);\n"
        "    grow(featuresDc_buf); grow(featuresRest_buf); grow(opacities_buf);\n"
        "    for (int g = 0; g < N_ADAM_GROUPS; g++) {\n"
        "        grow(adam_exp_avg_buf[g]);\n"
        "        grow(adam_exp_avg_sq_buf[g]);\n"
        "    }\n\n"
        "    buf_capacity = new_cap;\n"
        "    refreshViews();\n"
        "}\n"
    )
    replace_once(model_cpp, old_ensure, new_ensure, "capacity growth lifecycle")

    replace_once(
        model_cpp,
        "            ensureCapacity(3 * num_active);  // worst case: every gaussian splits\n\n"
        "            // Fill random samples for splits (CPU randn, shared memory)\n",
        "            ensureCapacity(3 * num_active);  // worst case: every gaussian splits\n"
        "            prepareDensifyScratch();\n\n"
        "            // Fill random samples for splits (CPU randn, shared memory)\n",
        "lazy densify scratch prepare",
    )
    replace_once(
        model_cpp,
        "            );\n\n            num_active = new_count;\n",
        "            );\n\n            // msplat_densify synchronizes before returning new_count, so all temporary\n"
        "            // scratch buffers can be released before the next training iteration.\n"
        "            releaseDensifyScratch();\n"
        "            num_active = new_count;\n",
        "densify scratch release",
    )

    print("PASS: applied S7-M2 trainer memory patch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
