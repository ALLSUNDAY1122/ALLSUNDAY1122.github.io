#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"{label}: expected {expected} matches, found {count}")
    return text.replace(old, new)


def capacity_helper() -> str:
    return '''namespace {\n\n// S10: reserve modest burst slack instead of the old 3N worst-case backing.\n// Densification classification now tells us the population that will actually\n// be written before model/Adam capacity grows.\nint capacityWithSlack(int required) {\n    int64_t base = std::max<int64_t>(required, 1);\n    int64_t slack = std::max<int64_t>(base / 4, 4096);\n    int64_t capacity = base + slack;\n    return static_cast<int>(std::min<int64_t>(capacity, std::numeric_limits<int>::max()));\n}\n\n} // namespace\n\n'''


def patch_model(root: Path) -> None:
    h = root / "Sources/MsplatCore/internal/include/model.hpp"
    cpp = root / "Sources/MsplatCore/src/model.cpp"
    ht = h.read_text(encoding="utf-8")
    ct = cpp.read_text(encoding="utf-8")

    ht = replace_exact(
        ht,
        "  void refreshViews();\n  void detachCapacityViews();\n  void prepareDensifyScratch();\n  void releaseDensifyScratch();\n  void ensureCapacity(int needed);\n",
        "  void refreshViews();\n  void detachCapacityViews();\n  void prepareDensifyClassificationScratch();\n  void prepareDensifyOutputScratch(int population);\n  void releaseDensifyScratch();\n  void ensureCapacity(int needed);\n",
        "model.hpp S10 scratch API",
    )

    ct = replace_exact(ct, "#include <iostream>\n", "#include <iostream>\n#include <algorithm>\n#include <limits>\n", "model includes")
    ct = replace_exact(
        ct,
        "namespace fs = std::filesystem;\n\nstatic const double C0",
        "namespace fs = std::filesystem;\n\n" + capacity_helper() + "static const double C0",
        "capacity helper",
    )

    # M2 leaves exactly two 3N allocations: fresh setup and checkpoint restore.
    ct = replace_exact(
        ct,
        "    buf_capacity = std::max(num_active * 3, 1);\n",
        "    buf_capacity = capacityWithSlack(num_active);\n",
        "fresh/checkpoint backing capacity",
        expected=2,
    )

    old_scratch = '''void Model::prepareDensifyScratch(){
    releaseDensifyScratch();
    const int worst_case = 3 * num_active;
    densify_split_flag = gpu_zeros({num_active}, DType::Int32);
    densify_dup_flag = gpu_zeros({num_active}, DType::Int32);
    densify_split_prefix = gpu_zeros({num_active}, DType::Int32);
    densify_dup_prefix = gpu_zeros({num_active}, DType::Int32);
    densify_keep_flag = gpu_zeros({worst_case}, DType::Int32);
    densify_keep_prefix = gpu_zeros({worst_case}, DType::Int32);
    int max_blocks = (worst_case + 1023) / 1024;
    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);
    int64_t fr_stride = featuresRest_buf.stride0();
    densify_compact_scratch = gpu_zeros({(int64_t)worst_case * fr_stride}, DType::Float32);
    densify_random_samples = gpu_zeros({2 * num_active, 3}, DType::Float32);
}
'''
    new_scratch = '''void Model::prepareDensifyClassificationScratch(){
    releaseDensifyScratch();
    densify_split_flag = gpu_zeros({num_active}, DType::Int32);
    densify_dup_flag = gpu_zeros({num_active}, DType::Int32);
    densify_split_prefix = gpu_zeros({num_active}, DType::Int32);
    densify_dup_prefix = gpu_zeros({num_active}, DType::Int32);
    int max_blocks = std::max((num_active + 1023) / 1024, 1);
    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);
}

void Model::prepareDensifyOutputScratch(int population){
    // Classification buffers/prefixes must survive a model-capacity grow because
    // they describe this exact refinement pass. Everything below is written only
    // after the actual post-split/dup population is known.
    densify_keep_flag.reset();
    densify_keep_prefix.reset();
    densify_block_totals.reset();
    densify_compact_scratch.reset();
    densify_random_samples.reset();

    int logicalPopulation = std::max(population, 1);
    densify_keep_flag = gpu_zeros({logicalPopulation}, DType::Int32);
    densify_keep_prefix = gpu_zeros({logicalPopulation}, DType::Int32);
    int max_blocks = std::max((logicalPopulation + 1023) / 1024, 1);
    densify_block_totals = gpu_zeros({max_blocks}, DType::Int32);
    int64_t fr_stride = featuresRest_buf.stride0();
    densify_compact_scratch = gpu_zeros({(int64_t)logicalPopulation * fr_stride}, DType::Float32);
    // Preserve the original split-sampling semantics; only backing capacity is reduced.
    densify_random_samples = gpu_zeros({2 * num_active, 3}, DType::Float32);
}
'''
    ct = replace_exact(ct, old_scratch, new_scratch, "two-phase densify scratch")

    ct = replace_exact(
        ct,
        "    msplat_gpu_sync();\n    releaseDensifyScratch();\n    detachCapacityViews();\n",
        "    msplat_gpu_sync();\n    // Keep this pass' split/dup classification buffers alive across backing growth.\n    detachCapacityViews();\n",
        "preserve classification across capacity grow",
    )
    ct = replace_exact(
        ct,
        "    int growth_cap = buf_capacity + std::max(buf_capacity / 2, 1);\n",
        "    int growth_cap = capacityWithSlack(buf_capacity);\n",
        "modest growth slack",
    )

    start = ct.index("        if (doDensification){\n")
    end = ct.index("\n        if (step < stopSplitAt && step % resetInterval == refineEvery){", start)
    old_block = ct[start:end]
    if old_block.count("ensureCapacity(3 * num_active)") != 1 or old_block.count("prepareDensifyScratch()") != 1:
        raise RuntimeError("afterTrain densification block is not the expected M2-composed source")

    new_block = '''        if (doDensification){
            int numPointsBefore = num_active;
            float half_max_dim = 0.5f * static_cast<float>((std::max)(lastWidth, lastHeight));
            int check_screen = (step < stopScreenSizeAt) ? 1 : 0;
            bool checkHuge = step > refineEvery * resetAlphaEvery;

            // Classify first. The old path allocated parameter + Adam backing for
            // a theoretical 3N population before knowing how many points would
            // actually split/duplicate.
            prepareDensifyClassificationScratch();
            int numSplits = 0;
            int numDups = 0;
            msplat_prepare_densify(
                num_active,
                densifyGradThresh, densifySizeThresh, splitScreenSize, check_screen,
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
            int population = static_cast<int>(population64);

            ensureCapacity(population);
            prepareDensifyOutputScratch(population);

            // Fill the same random split samples as the pinned path.
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

            releaseDensifyScratch();
            num_active = new_count;
            refreshViews();
            std::cout << "Densified: " << numPointsBefore << " -> " << num_active
                      << " gaussians (prepared " << population << ")" << std::endl;
        }
'''
    ct = ct[:start] + new_block + ct[end:]

    h.write_text(ht, encoding="utf-8")
    cpp.write_text(ct, encoding="utf-8")


def patch_bindings(root: Path) -> None:
    path = root / "Sources/MsplatCore/metal/bindings.h"
    text = path.read_text(encoding="utf-8")
    start = text.index("int msplat_densify(\n")
    end = text.index("\n);", start) + len("\n);")
    old = text[start:end]
    if "int N, int buf_capacity" not in old or "float grad_thresh" not in old:
        raise RuntimeError("bindings densify declaration does not match pinned API")
    new = '''void msplat_prepare_densify(
    int N,
    float grad_thresh, float size_thresh, float screen_thresh, int check_screen,
    MTensor &xys_grad_norm, MTensor &vis_counts, MTensor &max_2d_size,
    float half_max_dim,
    MTensor &scales_buf,
    MTensor &split_flag, MTensor &dup_flag,
    MTensor &split_prefix, MTensor &dup_prefix,
    MTensor &block_totals,
    int &num_splits, int &num_dups
);

int msplat_densify(
    int N, int population,
    float cull_alpha_thresh, float cull_scale_thresh, float cull_screen_size,
    int check_screen, int check_huge,
    MTensor &max_2d_size,
    MTensor &means_buf, MTensor &scales_buf, MTensor &quats_buf,
    MTensor &featuresDc_buf, MTensor &featuresRest_buf, MTensor &opacities_buf,
    int fr_stride,
    MTensor adam_exp_avg_buf[], MTensor adam_exp_avg_sq_buf[],
    MTensor &split_flag, MTensor &dup_flag,
    MTensor &split_prefix, MTensor &dup_prefix,
    MTensor &keep_flag, MTensor &keep_prefix,
    MTensor &block_totals, MTensor &compact_scratch,
    MTensor &random_samples
);'''
    path.write_text(text[:start] + new + text[end:], encoding="utf-8")


def patch_metal(root: Path) -> None:
    path = root / "Sources/MsplatCore/metal/msplat_metal.mm"
    text = path.read_text(encoding="utf-8")

    # Quality-neutral transient lifecycle: hand back chunk buffers when a later
    # resolution no longer uses chunked rasterization, and release old generation
    # before allocating a replacement generation.
    old_chunks = '''    void ensure_chunks(int K, int ih, int iw, id<MTLDevice> dev) {
        if (K <= chunk_K_max && ih == chunk_img_height && iw == chunk_img_width) return;
        chunk_K_max = K;
        chunk_img_height = ih;
        chunk_img_width = iw;
        chunk_T = mtensor_empty(dev, {K, ih, iw}, DType::Float32);
        chunk_C = mtensor_empty(dev, {K, ih, iw, 3}, DType::Float32);
        chunk_final_idx = mtensor_empty(dev, {K, ih, iw}, DType::Int32);
        prefix_T = mtensor_empty(dev, {K, ih, iw}, DType::Float32);
        after_C = mtensor_empty(dev, {K, ih, iw, 3}, DType::Float32);
    }
'''
    new_chunks = '''    void ensure_chunks(int K, int ih, int iw, id<MTLDevice> dev) {
        if (K <= 1) {
            // A coarse-resolution chunk generation cannot be reused once the
            // training resolution changes and chunking becomes unnecessary.
            if (chunk_T.defined() && (ih != chunk_img_height || iw != chunk_img_width)) {
                chunk_K_max = 0;
                chunk_img_height = ih;
                chunk_img_width = iw;
                chunk_T.reset(); chunk_C.reset(); chunk_final_idx.reset();
                prefix_T.reset(); after_C.reset();
            }
            return;
        }
        if (K <= chunk_K_max && ih == chunk_img_height && iw == chunk_img_width) return;

        // Drop the previous generation first so a resolution transition does
        // not require old + new large chunk buffers to coexist.
        chunk_K_max = 0;
        chunk_T.reset(); chunk_C.reset(); chunk_final_idx.reset();
        prefix_T.reset(); after_C.reset();

        chunk_T = mtensor_empty(dev, {K, ih, iw}, DType::Float32);
        chunk_C = mtensor_empty(dev, {K, ih, iw, 3}, DType::Float32);
        chunk_final_idx = mtensor_empty(dev, {K, ih, iw}, DType::Int32);
        prefix_T = mtensor_empty(dev, {K, ih, iw}, DType::Float32);
        after_C = mtensor_empty(dev, {K, ih, iw, 3}, DType::Float32);
        chunk_K_max = K;
        chunk_img_height = ih;
        chunk_img_width = iw;
    }
'''
    text = replace_exact(text, old_chunks, new_chunks, "depth chunk lifecycle")

    # Both training paths previously skipped ensure_chunks when K_max <= 1,
    # preventing it from releasing a stale prior-resolution generation.
    old_call = "        if (K_max > 1) g_tcache.ensure_chunks(K_max, img_height, img_width, ctx->device);\n"
    call_count = text.count(old_call)
    if call_count < 1:
        raise RuntimeError("expected at least one guarded ensure_chunks call")
    text = text.replace(old_call, "        g_tcache.ensure_chunks(K_max, img_height, img_width, ctx->device);\n")

    # Split the monolithic densifier after its classify/prefix phase. This keeps
    # Metal kernels and thresholds unchanged; only allocation order changes.
    fn = text.index("int msplat_densify(\n")
    stage1 = text.index("        // ---- Stage 1: Classify (split/dup) ----", fn)
    stage4 = text.index("        // ---- Stage 4: Append split children ----", stage1)
    trailing = text[text.rfind("}", fn) + 1:]
    if trailing.strip():
        raise RuntimeError("expected msplat_densify to be the final function in msplat_metal.mm")
    original = text[fn:]
    stage123 = text[stage1:stage4]
    stage48 = text[stage4:]
    if "int worst_case = 3 * N;" not in original or "return new_count;" not in stage48:
        raise RuntimeError("pinned densify body markers changed")

    prepare = '''void msplat_prepare_densify(
    int N,
    float grad_thresh, float size_thresh, float screen_thresh, int check_screen,
    MTensor &xys_grad_norm, MTensor &vis_counts, MTensor &max_2d_size,
    float half_max_dim,
    MTensor &scales_buf,
    MTensor &split_flag, MTensor &dup_flag,
    MTensor &split_prefix, MTensor &dup_prefix,
    MTensor &block_totals,
    int &num_splits, int &num_dups
) {
    MetalContext* ctx = get_global_context();
    uint32_t N_u32 = (uint32_t)N;
    uint32_t K = (uint32_t)((N + 1023) / 1024);
    int check_screen_int = check_screen;
    id<MTLCommandBuffer> command_buffer = ctx->getCommandBuffer();
    assert(command_buffer && "Failed to retrieve command buffer reference");

    dispatch_sync(ctx->d_queue, ^(){
        id<MTLComputeCommandEncoder> enc = [command_buffer computeCommandEncoder];
        assert(enc && "Failed to create compute command encoder");

'''
    prepare += stage123
    prepare += '''        [enc endEncoding];
    });

    ctx->syncCB();
    num_splits = N > 0 ? split_prefix.data<int32_t>()[N - 1] : 0;
    num_dups = N > 0 ? dup_prefix.data<int32_t>()[N - 1] : 0;
}

'''

    densify = '''int msplat_densify(
    int N, int population,
    float cull_alpha_thresh, float cull_scale_thresh, float cull_screen_size,
    int check_screen, int check_huge,
    MTensor &max_2d_size,
    MTensor &means_buf, MTensor &scales_buf, MTensor &quats_buf,
    MTensor &featuresDc_buf, MTensor &featuresRest_buf, MTensor &opacities_buf,
    int fr_stride,
    MTensor adam_exp_avg_buf[], MTensor adam_exp_avg_sq_buf[],
    MTensor &split_flag, MTensor &dup_flag,
    MTensor &split_prefix, MTensor &dup_prefix,
    MTensor &keep_flag, MTensor &keep_prefix,
    MTensor &block_totals, MTensor &compact_scratch,
    MTensor &random_samples
) {
    MetalContext* ctx = get_global_context();
    int worst_case = population;
    float log_size_fac = std::log(1.6f);

    int strides[6] = {3, 3, 4, 3, fr_stride, 1};
    int max_stride = fr_stride;
    std::array<MTensor*, 18> all_bufs = {{
        &means_buf, &scales_buf, &quats_buf, &featuresDc_buf, &featuresRest_buf, &opacities_buf,
        &adam_exp_avg_buf[0], &adam_exp_avg_buf[1], &adam_exp_avg_buf[2],
        &adam_exp_avg_buf[3], &adam_exp_avg_buf[4], &adam_exp_avg_buf[5],
        &adam_exp_avg_sq_buf[0], &adam_exp_avg_sq_buf[1], &adam_exp_avg_sq_buf[2],
        &adam_exp_avg_sq_buf[3], &adam_exp_avg_sq_buf[4], &adam_exp_avg_sq_buf[5]
    }};
    std::array<int, 18> all_strides = {{
        3, 3, 4, 3, fr_stride, 1,
        3, 3, 4, 3, fr_stride, 1,
        3, 3, 4, 3, fr_stride, 1
    }};

    uint32_t N_u32 = (uint32_t)N;
    int check_screen_int = check_screen;
    int check_huge_int = check_huge;
    id<MTLCommandBuffer> command_buffer = ctx->getCommandBuffer();
    assert(command_buffer && "Failed to retrieve command buffer reference");

    dispatch_sync(ctx->d_queue, ^(){
        id<MTLComputeCommandEncoder> enc = [command_buffer computeCommandEncoder];
        assert(enc && "Failed to create compute command encoder");

'''
    densify += stage48
    text = text[:fn] + prepare + densify

    # The pinned July iOS source already passes an explicit packed-intersection
    # capacity plus overflow flag to the tile sorter. Keep this safety behavior
    # and fail closed if a future pin regresses it; S10 does not blindly port an
    # older fork's num_points*16 overflow fix on top of already-bounded code.
    required_intersection_contracts = [
        "int64_t capacity_multiplier = 64;",
        "ENC_SCALAR(enc, capacity_u32, 13);",
        "ENC_BUF(enc, g_tcache.overflow_flag, 14);",
    ]
    for marker in required_intersection_contracts:
        if marker not in text:
            raise RuntimeError(f"intersection safety contract missing: {marker}")

    path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_msplat_s10_patch.py <M1+M2-composed-msplat-root>")
    root = Path(sys.argv[1]).resolve()
    patch_model(root)
    patch_bindings(root)
    patch_metal(root)
    print("PASS: applied S10 bounded-memory msplat patch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
