#!/usr/bin/env python3
"""Quantify spatial coherence of the persisted S14/S19 geometry seed without mutating it.

The S14 writer stores geometry vertices first and optional sky seeds afterwards.  This diagnostic
uses s14-seed-recipe.json's geometryPointCount to exclude sky seeds, then measures coarse 5 cm
voxel connectivity.  It is intentionally diagnostic-only: the thresholds mark only severe,
obvious fragmentation and never rewrite/reject reconstruction data.
"""
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib
import tempfile
from typing import Any, Iterable

SCHEMA = "scanlab.seed-geometry-diagnostic.v1"
CONNECTIVITY_VOXEL_METERS = 0.05
SEVERE_LARGEST_COMPONENT_RATIO = 0.35
SEVERE_COMPONENT_MIN_RATIO = 0.02
SEVERE_COMPONENT_COUNT = 4


def _read_ascii_ply_xyz(path: pathlib.Path, geometry_point_count: int | None = None) -> list[tuple[float, float, float]]:
    with path.open("r", encoding="utf-8", errors="strict") as handle:
        if handle.readline().strip() != "ply":
            raise ValueError("not a PLY file")
        vertex_count = None
        ascii_format = False
        while True:
            line = handle.readline()
            if not line:
                raise ValueError("truncated PLY header")
            stripped = line.strip()
            if stripped == "format ascii 1.0":
                ascii_format = True
            elif stripped.startswith("element vertex "):
                vertex_count = int(stripped.split()[-1])
            elif stripped == "end_header":
                break
        if not ascii_format:
            raise ValueError("only ASCII PLY is supported by this diagnostic")
        if vertex_count is None or vertex_count < 0:
            raise ValueError("missing/invalid vertex count")

        wanted = vertex_count if geometry_point_count is None else min(vertex_count, max(0, geometry_point_count))
        points: list[tuple[float, float, float]] = []
        for index in range(vertex_count):
            line = handle.readline()
            if not line:
                raise ValueError(f"truncated PLY body at vertex {index}")
            if index >= wanted:
                continue
            fields = line.split()
            if len(fields) < 3:
                raise ValueError(f"vertex {index} has fewer than 3 fields")
            point = (float(fields[0]), float(fields[1]), float(fields[2]))
            if all(math.isfinite(value) for value in point):
                points.append(point)
        return points


def _voxel(point: tuple[float, float, float], size: float) -> tuple[int, int, int]:
    return tuple(math.floor(value / size) for value in point)  # type: ignore[return-value]


def _neighbors(v: tuple[int, int, int]) -> Iterable[tuple[int, int, int]]:
    x, y, z = v
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if dx == dy == dz == 0:
                    continue
                yield (x + dx, y + dy, z + dz)


def diagnose_points(points: list[tuple[float, float, float]], voxel_size: float = CONNECTIVITY_VOXEL_METERS) -> dict[str, Any]:
    if voxel_size <= 0:
        raise ValueError("voxel_size must be positive")
    if not points:
        return {
            "schema": SCHEMA,
            "diagnostic_only": True,
            "geometry_point_count": 0,
            "connectivity_voxel_m": voxel_size,
            "occupied_voxel_count": 0,
            "component_count": 0,
            "largest_component_point_ratio": 0.0,
            "large_component_count": 0,
            "fragmentation_suspected": True,
            "reason": "no_finite_geometry_points",
        }

    counts: collections.Counter[tuple[int, int, int]] = collections.Counter(_voxel(point, voxel_size) for point in points)
    remaining = set(counts)
    component_points: list[int] = []
    while remaining:
        start = remaining.pop()
        stack = [start]
        total = counts[start]
        while stack:
            current = stack.pop()
            for neighbor in _neighbors(current):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    stack.append(neighbor)
                    total += counts[neighbor]
        component_points.append(total)

    component_points.sort(reverse=True)
    total_points = len(points)
    largest_ratio = component_points[0] / total_points
    large_components = [count for count in component_points if count / total_points >= SEVERE_COMPONENT_MIN_RATIO]
    severe = largest_ratio < SEVERE_LARGEST_COMPONENT_RATIO and len(large_components) >= SEVERE_COMPONENT_COUNT

    mins = tuple(min(point[axis] for point in points) for axis in range(3))
    maxs = tuple(max(point[axis] for point in points) for axis in range(3))
    spans = tuple(maxs[axis] - mins[axis] for axis in range(3))
    return {
        "schema": SCHEMA,
        "diagnostic_only": True,
        "geometry_point_count": total_points,
        "connectivity_voxel_m": voxel_size,
        "occupied_voxel_count": len(counts),
        "component_count": len(component_points),
        "largest_component_point_ratio": round(largest_ratio, 6),
        "large_component_count": len(large_components),
        "top_component_point_counts": component_points[:10],
        "bounds_min_m": [round(value, 6) for value in mins],
        "bounds_max_m": [round(value, 6) for value in maxs],
        "bounds_span_m": [round(value, 6) for value in spans],
        "fragmentation_suspected": severe,
        "severe_thresholds": {
            "largest_component_ratio_lt": SEVERE_LARGEST_COMPONENT_RATIO,
            "component_ratio_gte": SEVERE_COMPONENT_MIN_RATIO,
            "large_component_count_gte": SEVERE_COMPONENT_COUNT,
        },
    }


def diagnose_ply(path: pathlib.Path, geometry_point_count: int | None = None) -> dict[str, Any]:
    return diagnose_points(_read_ascii_ply_xyz(path, geometry_point_count))


def _write_fixture(path: pathlib.Path, points: list[tuple[float, float, float]], sky: list[tuple[float, float, float]] | None = None) -> None:
    all_points = points + (sky or [])
    lines = [
        "ply", "format ascii 1.0", f"element vertex {len(all_points)}",
        "property float x", "property float y", "property float z",
        "property uchar red", "property uchar green", "property uchar blue", "end_header",
    ]
    lines.extend(f"{x} {y} {z} 128 128 128" for x, y, z in all_points)
    path.write_text("\n".join(lines) + "\n")


def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        coherent = [(x * 0.02, y * 0.02, -1.0) for x in range(12) for y in range(12)]
        coherent_path = root / "coherent.ply"
        _write_fixture(coherent_path, coherent, sky=[(100.0, 100.0, 100.0)])
        report = diagnose_ply(coherent_path, geometry_point_count=len(coherent))
        assert report["geometry_point_count"] == len(coherent)
        assert report["component_count"] == 1, report
        assert report["largest_component_point_ratio"] == 1.0
        assert report["fragmentation_suspected"] is False
        assert report["bounds_max_m"][0] < 1.0, "sky seed must be excluded"

        islands: list[tuple[float, float, float]] = []
        for island in range(5):
            base = island * 1.0
            islands.extend((base + x * 0.01, y * 0.01, -1.0) for x in range(5) for y in range(5))
        fragmented_path = root / "fragmented.ply"
        _write_fixture(fragmented_path, islands)
        fragmented = diagnose_ply(fragmented_path, geometry_point_count=len(islands))
        assert fragmented["large_component_count"] == 5, fragmented
        assert fragmented["largest_component_point_ratio"] == 0.2, fragmented
        assert fragmented["fragmentation_suspected"] is True

    print("PASS: S19 seed geometry coherence diagnostic self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ply", nargs="?", type=pathlib.Path)
    parser.add_argument("--geometry-point-count", type=int)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.ply is None:
        parser.error("ply is required unless --self-test is used")
    report = diagnose_ply(args.ply, args.geometry_point_count)
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(encoded)
    else:
        print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
