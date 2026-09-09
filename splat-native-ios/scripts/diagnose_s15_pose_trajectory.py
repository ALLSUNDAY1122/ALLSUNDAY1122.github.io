#!/usr/bin/env python3
"""Diagnose camera-pose trajectory discontinuities without changing reconstruction behavior.

S15 diagnostic-only helper for same-RAW investigations. It accepts a NeRF-style JSON
object with ``frames[*].transform_matrix`` and reports finite/rigid-transform defects plus
large frame-to-frame translation or rotation jumps. Thresholds are intentionally warnings,
not reconstruction filters.
"""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys
from typing import Any

DEFAULT_TRANSLATION_JUMP_M = 0.75
DEFAULT_ROTATION_JUMP_DEG = 45.0
ORTHONORMAL_TOLERANCE = 0.03
DETERMINANT_TOLERANCE = 0.05


def _is_matrix4(value: Any) -> bool:
    return (
        isinstance(value, list)
        and len(value) == 4
        and all(isinstance(row, list) and len(row) == 4 for row in value)
    )


def _finite_matrix(matrix: list[list[Any]]) -> bool:
    try:
        return all(math.isfinite(float(value)) for row in matrix for value in row)
    except (TypeError, ValueError):
        return False


def _position(matrix: list[list[Any]]) -> tuple[float, float, float]:
    return (float(matrix[0][3]), float(matrix[1][3]), float(matrix[2][3]))


def _rotation(matrix: list[list[Any]]) -> tuple[tuple[float, float, float], ...]:
    return tuple(tuple(float(matrix[r][c]) for c in range(3)) for r in range(3))


def _dot(a: tuple[float, ...], b: tuple[float, ...]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _det3(r: tuple[tuple[float, float, float], ...]) -> float:
    return (
        r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1])
        - r[0][1] * (r[1][0] * r[2][2] - r[1][2] * r[2][0])
        + r[0][2] * (r[1][0] * r[2][1] - r[1][1] * r[2][0])
    )


def _rigid_defect(matrix: list[list[Any]]) -> str | None:
    if not _is_matrix4(matrix):
        return "shape"
    if not _finite_matrix(matrix):
        return "nonfinite"
    bottom = tuple(float(v) for v in matrix[3])
    if any(abs(a - b) > 1e-4 for a, b in zip(bottom, (0.0, 0.0, 0.0, 1.0))):
        return "homogeneous_row"
    r = _rotation(matrix)
    rows = r
    for i in range(3):
        if abs(_dot(rows[i], rows[i]) - 1.0) > ORTHONORMAL_TOLERANCE:
            return "rotation_norm"
        for j in range(i + 1, 3):
            if abs(_dot(rows[i], rows[j])) > ORTHONORMAL_TOLERANCE:
                return "rotation_orthogonality"
    if abs(_det3(r) - 1.0) > DETERMINANT_TOLERANCE:
        return "rotation_determinant"
    return None


def _rotation_delta_degrees(
    a: tuple[tuple[float, float, float], ...],
    b: tuple[tuple[float, float, float], ...],
) -> float:
    # Relative rotation trace = trace(A^T B).
    trace = sum(a[k][i] * b[k][i] for i in range(3) for k in range(3))
    cosine = max(-1.0, min(1.0, (trace - 1.0) * 0.5))
    return math.degrees(math.acos(cosine))


def diagnose(
    payload: dict[str, Any],
    translation_jump_m: float = DEFAULT_TRANSLATION_JUMP_M,
    rotation_jump_deg: float = DEFAULT_ROTATION_JUMP_DEG,
) -> dict[str, Any]:
    frames = payload.get("frames")
    if not isinstance(frames, list):
        raise ValueError("input JSON must contain frames[]")

    defects: list[dict[str, Any]] = []
    jumps: list[dict[str, Any]] = []
    valid: list[tuple[int, list[list[Any]]]] = []

    for index, frame in enumerate(frames):
        matrix = frame.get("transform_matrix") if isinstance(frame, dict) else None
        defect = _rigid_defect(matrix) if isinstance(matrix, list) else "missing_transform"
        if defect is not None:
            defects.append({"frame": index, "kind": defect})
            continue
        valid.append((index, matrix))

    translation_deltas: list[float] = []
    rotation_deltas: list[float] = []
    for (left_index, left), (right_index, right) in zip(valid, valid[1:]):
        # Do not bridge across an invalid frame; that would manufacture a false adjacent jump.
        if right_index != left_index + 1:
            continue
        lp, rp = _position(left), _position(right)
        translation = math.sqrt(sum((a - b) ** 2 for a, b in zip(lp, rp)))
        rotation = _rotation_delta_degrees(_rotation(left), _rotation(right))
        translation_deltas.append(translation)
        rotation_deltas.append(rotation)
        reasons = []
        if translation > translation_jump_m:
            reasons.append("translation")
        if rotation > rotation_jump_deg:
            reasons.append("rotation")
        if reasons:
            jumps.append(
                {
                    "from": left_index,
                    "to": right_index,
                    "translation_m": round(translation, 6),
                    "rotation_deg": round(rotation, 4),
                    "reasons": reasons,
                }
            )

    return {
        "frame_count": len(frames),
        "valid_pose_count": len(valid),
        "invalid_pose_count": len(defects),
        "pose_jump_count": len(jumps),
        "max_translation_delta_m": round(max(translation_deltas, default=0.0), 6),
        "max_rotation_delta_deg": round(max(rotation_deltas, default=0.0), 4),
        "translation_jump_threshold_m": translation_jump_m,
        "rotation_jump_threshold_deg": rotation_jump_deg,
        "invalid_poses": defects,
        "pose_jumps": jumps,
        "diagnostic_only": True,
    }


def _pose(tx: float, yaw_deg: float = 0.0) -> list[list[float]]:
    theta = math.radians(yaw_deg)
    c, s = math.cos(theta), math.sin(theta)
    return [
        [c, 0.0, s, tx],
        [0.0, 1.0, 0.0, 0.0],
        [-s, 0.0, c, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def self_test() -> None:
    smooth = {"frames": [{"transform_matrix": _pose(i * 0.04, i * 3.0)} for i in range(8)]}
    report = diagnose(smooth)
    assert report["invalid_pose_count"] == 0, report
    assert report["pose_jump_count"] == 0, report

    jumped = {"frames": [{"transform_matrix": _pose(0.0)}, {"transform_matrix": _pose(0.04, 2.0)}, {"transform_matrix": _pose(1.25, 78.0)}]}
    report = diagnose(jumped)
    assert report["pose_jump_count"] == 1, report
    assert set(report["pose_jumps"][0]["reasons"]) == {"translation", "rotation"}, report

    broken = _pose(0.0)
    broken[0][0] = 2.0
    report = diagnose({"frames": [{"transform_matrix": broken}]})
    assert report["invalid_pose_count"] == 1, report
    assert report["invalid_poses"][0]["kind"] == "rotation_norm", report
    print("PASS: S15 pose trajectory diagnostic self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("json_path", nargs="?", type=pathlib.Path)
    parser.add_argument("--translation-jump-m", type=float, default=DEFAULT_TRANSLATION_JUMP_M)
    parser.add_argument("--rotation-jump-deg", type=float, default=DEFAULT_ROTATION_JUMP_DEG)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--strict", action="store_true", help="exit 2 when invalid poses or jumps are detected")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0
    if args.json_path is None:
        parser.error("json_path is required unless --self-test is used")
    payload = json.loads(args.json_path.read_text())
    report = diagnose(payload, args.translation_jump_m, args.rotation_jump_deg)
    print(json.dumps(report, indent=2, sort_keys=True))
    if args.strict and (report["invalid_pose_count"] or report["pose_jump_count"]):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
