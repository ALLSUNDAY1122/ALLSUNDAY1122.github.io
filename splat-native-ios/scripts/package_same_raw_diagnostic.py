#!/usr/bin/env python3
"""Build a deterministic S15/S18/S19 same-RAW reconstruction diagnostic bundle.

Given one persisted Splat project directory, locate camera transforms, run the existing pose and
seed-geometry diagnostics, and inventory reconstruction evidence without mutating the project.
The emitted JSON is intentionally small enough to attach to an issue/chat while retaining hashes
needed to prove two runs used the same durable inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import pathlib
import tempfile
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
POSE_SCRIPT = HERE / "diagnose_s15_pose_trajectory.py"
SEED_GEOMETRY_SCRIPT = HERE / "diagnose_s19_seed_geometry.py"
CANDIDATE_TRANSFORM_FILES = (
    "transforms.json",
    "dataset/transforms.json",
    "nerf/transforms.json",
)
EVIDENCE_FILES = (
    "s14-seed-recipe.json",
    "points3D.ply",
    "checkpoint.bin",
    "trainer-checkpoint.bin",
    "result.spz",
    "output.spz",
)


def _load_module(name: str, path: pathlib.Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load diagnostic: {path.name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _file_record(root: pathlib.Path, path: pathlib.Path) -> dict[str, Any]:
    stat = path.stat()
    return {
        "path": path.relative_to(root).as_posix(),
        "bytes": stat.st_size,
        "sha256": _sha256(path),
    }


def _first_existing(root: pathlib.Path, candidates: tuple[str, ...]) -> pathlib.Path | None:
    for relative in candidates:
        path = root / relative
        if path.is_file():
            return path
    return None


def _discover_transform_file(root: pathlib.Path) -> pathlib.Path | None:
    direct = _first_existing(root, CANDIDATE_TRANSFORM_FILES)
    if direct:
        return direct
    matches = sorted(root.rglob("transforms.json"))
    return matches[0] if matches else None


def _discover_first(root: pathlib.Path, filename: str) -> pathlib.Path | None:
    direct = root / filename
    if direct.is_file():
        return direct
    matches = sorted(root.rglob(filename))
    return matches[0] if matches else None


def build_bundle(project_dir: pathlib.Path) -> dict[str, Any]:
    root = project_dir.resolve()
    if not root.is_dir():
        raise ValueError(f"project directory not found: {root}")

    transform_path = _discover_transform_file(root)
    pose_report: dict[str, Any] | None = None
    transform_record: dict[str, Any] | None = None
    if transform_path is not None:
        payload = json.loads(transform_path.read_text())
        pose_report = _load_module("s15_pose", POSE_SCRIPT).diagnose(payload)
        transform_record = _file_record(root, transform_path)

    evidence: list[dict[str, Any]] = []
    seen: set[pathlib.Path] = set()
    for filename in EVIDENCE_FILES:
        matches = sorted(root.rglob(filename))
        for path in matches:
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            evidence.append(_file_record(root, path))
    evidence.sort(key=lambda item: item["path"])

    seed_recipe = None
    recipe_path = _discover_first(root, "s14-seed-recipe.json")
    raw_recipe: dict[str, Any] | None = None
    if recipe_path:
        try:
            raw_recipe = json.loads(recipe_path.read_text())
            seed_recipe = {
                key: raw_recipe.get(key)
                for key in (
                    "recipeVersion",
                    "source",
                    "pointCount",
                    "depthFrameCount",
                    "geometryPointCount",
                    "skySeedCount",
                    "colorFrameCount",
                )
                if key in raw_recipe
            }
        except (OSError, json.JSONDecodeError):
            seed_recipe = {"parseError": True}

    points_path = _discover_first(root, "points3D.ply")
    seed_geometry: dict[str, Any] | None = None
    if points_path is not None:
        geometry_count = raw_recipe.get("geometryPointCount") if isinstance(raw_recipe, dict) else None
        if not isinstance(geometry_count, int):
            geometry_count = None
        try:
            seed_geometry = _load_module("s19_seed_geometry", SEED_GEOMETRY_SCRIPT).diagnose_ply(
                points_path,
                geometry_count,
            )
        except (OSError, UnicodeError, ValueError) as exc:
            seed_geometry = {"parse_error": type(exc).__name__}

    input_identity = {
        "transform_sha256": transform_record["sha256"] if transform_record else None,
        "points3d_sha256": next(
            (item["sha256"] for item in evidence if item["path"].endswith("points3D.ply")),
            None,
        ),
        "seed_recipe_sha256": next(
            (item["sha256"] for item in evidence if item["path"].endswith("s14-seed-recipe.json")),
            None,
        ),
    }

    return {
        "schema": "scanlab.same-raw-diagnostic.v1",
        "diagnostic_only": True,
        "project_name": root.name,
        "camera_transforms": transform_record,
        "same_raw_identity": input_identity,
        "pose": pose_report,
        "seed_recipe": seed_recipe,
        "seed_geometry": seed_geometry,
        "evidence_files": evidence,
        "interpretation": {
            "pose_anomaly": bool(
                pose_report
                and (pose_report.get("invalid_pose_count", 0) or pose_report.get("pose_jump_count", 0))
            ),
            "seed_fragmentation_suspected": bool(
                seed_geometry and seed_geometry.get("fragmentation_suspected", False)
            ),
            "has_seed_recipe": seed_recipe is not None,
            "has_points3d": any(item["path"].endswith("points3D.ply") for item in evidence),
            "has_finished_spz": any(item["path"].endswith(".spz") for item in evidence),
        },
    }


def _write_fixture_ply(path: pathlib.Path, geometry: list[tuple[float, float, float]], sky: list[tuple[float, float, float]]) -> None:
    points = geometry + sky
    lines = [
        "ply", "format ascii 1.0", f"element vertex {len(points)}",
        "property float x", "property float y", "property float z",
        "property uchar red", "property uchar green", "property uchar blue", "end_header",
    ]
    lines.extend(f"{x} {y} {z} 128 128 128" for x, y, z in points)
    path.write_text("\n".join(lines) + "\n")


def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp) / "project-A"
        root.mkdir()
        poses = {
            "frames": [
                {"transform_matrix": [
                    [1.0, 0.0, 0.0, i * 0.03],
                    [0.0, 1.0, 0.0, 0.0],
                    [0.0, 0.0, 1.0, 0.0],
                    [0.0, 0.0, 0.0, 1.0],
                ]}
                for i in range(8)
            ]
        }
        geometry = [(x * 0.02, y * 0.02, -1.0) for x in range(12) for y in range(12)]
        sky = [(100.0, 100.0, 100.0)]
        (root / "transforms.json").write_text(json.dumps(poses))
        (root / "s14-seed-recipe.json").write_text(json.dumps({
            "recipeVersion": 2,
            "source": "planeSweep",
            "pointCount": len(geometry) + len(sky),
            "depthFrameCount": 0,
            "geometryPointCount": len(geometry),
            "skySeedCount": len(sky),
        }))
        _write_fixture_ply(root / "points3D.ply", geometry, sky)
        (root / "result.spz").write_bytes(b"SPZfixture")

        first = build_bundle(root)
        second = build_bundle(root)
        assert first == second
        assert first["schema"] == "scanlab.same-raw-diagnostic.v1"
        assert first["pose"]["pose_jump_count"] == 0
        assert first["seed_recipe"]["recipeVersion"] == 2
        assert first["seed_recipe"]["source"] == "planeSweep"
        assert first["seed_geometry"]["geometry_point_count"] == len(geometry)
        assert first["seed_geometry"]["component_count"] == 1
        assert first["seed_geometry"]["largest_component_point_ratio"] == 1.0
        assert first["interpretation"] == {
            "pose_anomaly": False,
            "seed_fragmentation_suspected": False,
            "has_seed_recipe": True,
            "has_points3d": True,
            "has_finished_spz": True,
        }
        assert first["same_raw_identity"]["transform_sha256"]
        assert first["same_raw_identity"]["points3d_sha256"]

        poses["frames"][-1]["transform_matrix"][0][3] = 1.2
        (root / "transforms.json").write_text(json.dumps(poses))
        jumped = build_bundle(root)
        assert jumped["interpretation"]["pose_anomaly"] is True
        assert jumped["pose"]["pose_jump_count"] == 1
        assert jumped["same_raw_identity"]["transform_sha256"] != first["same_raw_identity"]["transform_sha256"]

        islands: list[tuple[float, float, float]] = []
        for island in range(5):
            base = island * 1.0
            islands.extend((base + x * 0.01, y * 0.01, -1.0) for x in range(5) for y in range(5))
        _write_fixture_ply(root / "points3D.ply", islands, [])
        (root / "s14-seed-recipe.json").write_text(json.dumps({
            "recipeVersion": 2,
            "source": "planeSweep",
            "pointCount": len(islands),
            "geometryPointCount": len(islands),
            "skySeedCount": 0,
        }))
        fragmented = build_bundle(root)
        assert fragmented["interpretation"]["seed_fragmentation_suspected"] is True
        assert fragmented["seed_geometry"]["large_component_count"] == 5

    print("PASS: same-RAW diagnostic bundle self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_dir", nargs="?", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0
    if args.project_dir is None:
        parser.error("project_dir is required unless --self-test is used")

    report = build_bundle(args.project_dir)
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(encoded)
    else:
        print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
