#!/usr/bin/env python3
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
        raise SystemExit("usage: test_s10_bounded_memory_patch.py <msplat-root>")
    root = Path(sys.argv[1]).resolve()
    model = (root / "Sources/MsplatCore/src/model.cpp").read_text(encoding="utf-8")
    model_h = (root / "Sources/MsplatCore/internal/include/model.hpp").read_text(encoding="utf-8")
    bindings = (root / "Sources/MsplatCore/metal/bindings.h").read_text(encoding="utf-8")
    metal = (root / "Sources/MsplatCore/metal/msplat_metal.mm").read_text(encoding="utf-8")

    require(model, "int capacityWithSlack(int required)", "bounded capacity helper")
    require(model, "buf_capacity = capacityWithSlack(num_active);", "fresh/checkpoint slack")
    if model.count("buf_capacity = capacityWithSlack(num_active);") != 2:
        raise RuntimeError("fresh and checkpoint capacity must both use bounded slack")
    reject(model, "ensureCapacity(3 * num_active)", "3N worst-case model reservation")
    reject(model, "buf_capacity = std::max(num_active * 3, 1)", "3N steady backing")
    require(model, "prepareDensifyClassificationScratch();", "classification-before-grow")
    require(model, "population64", "actual population accounting")
    require(model, "ensureCapacity(population);", "population-based grow")
    require(model, "prepareDensifyOutputScratch(population);", "logical output scratch")
    require(model_h, "prepareDensifyClassificationScratch();", "two-phase scratch declaration")
    require(model_h, "prepareDensifyOutputScratch(int population);", "output scratch declaration")

    require(bindings, "void msplat_prepare_densify(", "split classify API")
    require(bindings, "int N, int population", "population densify API")
    reject(bindings, "int N, int buf_capacity", "monolithic 3N densify API")

    require(metal, "void msplat_prepare_densify(", "Metal classify function")
    require(metal, "int worst_case = population;", "logical cull population")
    reject(metal, "int worst_case = 3 * N;", "Metal 3N worst-case")
    require(metal, "if (K <= 1)", "chunk release path")
    require(metal, "chunk_T.reset(); chunk_C.reset(); chunk_final_idx.reset();", "chunk generation release")
    reject(metal, "if (K_max > 1) g_tcache.ensure_chunks", "guard that prevents stale-chunk release")

    # The pinned July source already has an explicit packed-intersection capacity
    # and overflow flag. S10 preserves this instead of applying an obsolete fix.
    require(metal, "int64_t capacity_multiplier = 64;", "intersection capacity policy")
    require(metal, "ENC_SCALAR(enc, capacity_u32, 13);", "sort write capacity")
    require(metal, "ENC_BUF(enc, g_tcache.overflow_flag, 14);", "sort overflow flag")

    print("PASS: S10 bounded-memory contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
