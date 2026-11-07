#!/usr/bin/env python3
"""Checkpoint-aware wrapper for the S7-M2 pinned-msplat memory patch.

The upstream model.cpp contains two intentionally similar 4N/scratch allocation
sites (fresh optimizer setup and checkpoint restore). This wrapper first makes
the checkpoint site unambiguous, then runs the base fail-closed patcher, then
finishes checkpoint-specific lifecycle changes.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count} in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_msplat_m2_patch_v3.py <msplat-root>")

    root = Path(sys.argv[1]).resolve()
    script_dir = Path(__file__).resolve().parent
    base_patcher = script_dir / "apply_msplat_m2_patch.py"
    model = root / "Sources/MsplatCore/src/model.cpp"

    if not model.is_file():
        raise RuntimeError(f"missing pinned msplat model source: {model}")

    replace_once(
        model,
        "    num_active = (int)numPts;\n    buf_capacity = num_active * 4;\n",
        "    num_active = (int)numPts;\n    buf_capacity = std::max(num_active * 3, 1);\n",
        "checkpoint trainer capacity",
    )

    checkpoint_scratch = (
        "    // Allocate densification scratch buffers\n"
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
    # This block exists twice upstream. Restrict the checkpoint replacement by
    # anchoring it after the checkpoint optimizer-copy loop.
    text = model.read_text(encoding="utf-8")
    checkpoint_start = text.index("int Model::loadCheckpoint")
    before = text[:checkpoint_start]
    checkpoint_tail = text[checkpoint_start:]
    count = checkpoint_tail.count(checkpoint_scratch)
    if count != 1:
        raise RuntimeError(f"checkpoint scratch disambiguation: expected one checkpoint match, found {count}")
    checkpoint_tail = checkpoint_tail.replace(checkpoint_scratch, "    // M2_CHECKPOINT_SCRATCH_PLACEHOLDER\n\n", 1)
    model.write_text(before + checkpoint_tail, encoding="utf-8")

    subprocess.run([sys.executable, str(base_patcher), str(root)], check=True)

    replace_once(
        model,
        "    // Gaussian parameters — read into fresh tensors\n"
        "    means = readTensor(f);\n",
        "    // Gaussian parameters — read into fresh tensors. Release any existing\n"
        "    // trainer backing only after the checkpoint header/scalars were validated.\n"
        "    msplat_gpu_sync();\n"
        "    detachCapacityViews();\n"
        "    releaseOptimizers();\n"
        "    means = readTensor(f);\n",
        "checkpoint previous trainer release",
    )

    replace_once(
        model,
        "    // Copy gaussian params into oversized backing buffers\n"
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
        "    allocBuf(opacities_buf, opacities);\n",
        "    // Copy gaussian params into 3N backing buffers and release each loaded\n"
        "    // temporary as soon as its copy is complete.\n"
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
        "    allocBuf(opacities, opacities_buf);\n",
        "checkpoint parameter handoff",
    )

    replace_once(
        model,
        "        memcpy(avg_buf.data_ptr(), adam_exp_avg[g].data_ptr(), adam_exp_avg[g].nbytes());\n"
        "        memcpy(sq_buf.data_ptr(), adam_exp_avg_sq[g].data_ptr(), adam_exp_avg_sq[g].nbytes());\n"
        "        adam_exp_avg_buf[g] = avg_buf;\n"
        "        adam_exp_avg_sq_buf[g] = sq_buf;\n",
        "        memcpy(avg_buf.data_ptr(), adam_exp_avg[g].data_ptr(), adam_exp_avg[g].nbytes());\n"
        "        memcpy(sq_buf.data_ptr(), adam_exp_avg_sq[g].data_ptr(), adam_exp_avg_sq[g].nbytes());\n"
        "        adam_exp_avg[g].reset();\n"
        "        adam_exp_avg_sq[g].reset();\n"
        "        adam_exp_avg_buf[g] = avg_buf;\n"
        "        adam_exp_avg_sq_buf[g] = sq_buf;\n",
        "checkpoint optimizer handoff",
    )

    replace_once(
        model,
        "    // M2_CHECKPOINT_SCRATCH_PLACEHOLDER\n\n",
        "    // Densification scratch remains lazy after checkpoint restore as well.\n"
        "    releaseDensifyScratch();\n\n",
        "checkpoint lazy densify scratch",
    )

    print("PASS: applied S7-M2 checkpoint memory patch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
