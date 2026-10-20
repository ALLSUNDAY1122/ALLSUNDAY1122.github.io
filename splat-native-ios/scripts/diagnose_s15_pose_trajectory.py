#!/usr/bin/env python3
"""Diagnose camera-pose trajectory discontinuities without changing reconstruction behavior.

S15 diagnostic-only helper for same-RAW investigations. It accepts a NeRF-style JSON
object with ``frames[*].transform_matrix`` and reports finite/rigid-transform defects plus
frame-to-frame translation or rotation jumps. It combines conservative absolute warning
thresholds with a robust median/MAD baseline so smaller jumps that are abnormal for the
actual capture trajectory are visible without turning diagnostics into reconstruction filters.
"""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import statistics
import sys
from typing import Any

DEFAULT_TRANSLATION_JUMP_M = 0.75
DEFAULT_ROTATION_JUMP_DEG = 45.0
ROBUST_MIN_SAMPLE_COUNT = 5
ROBUST_SIGMA_MULTIPLIER = 6.0
ROBUST_TRANSLATION_FLOOR_M = 0.05
ROBUST_ROTATION_FLOOR_DEG = 5.0
MAD_TO_SIGMA = 1.4826
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


def _percentile(values: list[float], quantile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * quantile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    weight = position - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def _robust_upper_threshold(values: list[float], floor: float) -> dict[str, float | bool]:
    if len(values) < ROBUST_MIN_SAMPLE_COUNT:
        return {"enabled": False, "median": 0.0, "mad": 0.0, "threshold": 0.0}
    median = statistics.median(values)
    mad = statistics.median(abs(value - median) for value in values)
    spread = max(ROBUST_SIGMA_MULTIPLIER * MAD_TO_SIGMA * mad, floor)
    return {
        "enabled": True,
        "median": median,
        "mad": mad,
        "threshold": median + spread,
    }


def diagnose(
    payload: dict[str, Any],
    translation_jump_m: float = DEFAULT_TRANSLATION_JUMP_M,
    rotation_jump_deg: float = DEFAULT_ROTATION_JUMP_DEG,
) -> dict[str, Any]:
    frames = payload.get("frames")
    if not isinstance(frames, list):
        raise ValueError("input JSON must contain frames[]")

    defects: list[dict[str, Any]] = []
    valid: list[tuple[int, list[list[Any]]]] = []

    for index, frame in enumerate(frames):
        matrix = frame.get("transform_matrix") if isinstance(frame, dict) else None
        defect = _rigid_defect(matrix) if isinstance(matrix, list) else "missing_transform"
        if defect is not None:
            defects.append({"frame": index, "kind": defect})
            continue
        valid.append((index, matrix))

    steps: list[dict[str, Any]] = []
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
        steps.append(
            {
                "from": left_index,
                "to": right_index,
                "translation_m": translation,
                "rotation_deg": rotation,
            }
        )

    translation_robust = _robust_upper_threshold(translation_deltas, ROBUST_TRANSLATION_FLOOR_M)
    rotation_robust = _robust_upper_threshold(rotation_deltas, ROBUST_ROTATION_FLOOR_DEG)
    jumps: list[dict[str, Any]] = []
    for step in steps:
        translation = float(step["translation_m"])
        rotation = float(step["rotation_deg"])
        reasons: list[str] = []
        if translation > translation_jump_m:
            reasons.append("translation_absolute")
        if rotation > rotation_jump_deg:
            reasons.append("rotation_absolute")
        if bool(translation_robust["enabled"]) and translation > float(translation_robust["threshold"]):
            reasons.append("translation_robust")
        if bool(rotation_robust["enabled"]) and rotation > float(rotation_robust["threshold"]):
            reasons.append("rotation_robust")
        if reasons:
            jumps.append(
                {
                    "from": step["from"],
                    "to": step["to"],
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
        "translation_delta_m": {
            "median": round(statistics.median(translation_deltas), 6) if translation_deltas else 0.0,
            "p95": round(_percentile(translation_deltas, 0.95), 6),
            "max": round(max(translation_deltas, default=0.0), 6),
        },
        "rotation_delta_deg": {
            "median": round(statistics.median(rotation_deltas), 4) if rotation_deltas else 0.0,
            "p95": round(_percentile(rotation_deltas, 0.95), 4),
            "max": round(max(rotation_deltas, default=0.0), 4),
        },
        # Preserve the old top-level fields for downstream report compatibility.
        "max_translation_delta_m": round(max(translation_deltas, default=0.0), 6),
        "max_rotation_delta_deg": round(max(rotation_deltas, default=0.0), 4),
        "translation_jump_threshold_m": translation_jump_m,
        "rotation_jump_threshold_deg": rotation_jump_deg,
        "robust_translation_threshold_m": round(float(translation_robust["threshold"]), 6)
        if bool(translation_robust["enabled"])
        else None,
        "robust_rotation_threshold_deg": round(float(rotation_robust["threshold"]), 4)
        if bool(rotation_robust["enabled"])
        else None,
        "robust_sample_minimum": ROBUST_MIN_SAMPLE_COUNT,
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
    assert report["translation_delta_m"]["median"] == 0.04, report
    assert report["rotation_delta_deg"]["median"] == 3.0, report

    # Large absolute jump must still be visible and should also be robustly abnormal.
    jumped_frames = [{"transform_matrix": _pose(i * 0.04, i * 2.0)} for i in range(6)]
    jumped_frames.append({"transform_matrix": _pose(1.25, 78.0)})
    report = diagnose({"frames": jumped_frames})
    assert report["pose_jump_count"] == 1, report
    reasons = set(report["pose_jumps"][0]["reasons"])
    assert {"translation_absolute", "rotation_absolute", "translation_robust", "rotation_robust"} <= reasons, report

    # A sub-absolute-threshold discontinuity should be caught relative to a slow capture.
    subtle_frames = [{"transform_matrix": _pose(i * 0.03, i * 2.0)} for i in range(7)]
    subtle_frames.append({"transform_matrix": _pose(0.48, 24.0)})
    report = diagnose({"frames": subtle_frames})
    assert report["pose_jump_count"] == 1, report
    reasons = set(report["pose_jumps"][0]["reasons"])
    assert "translation_absolute" not in reasons and "rotation_absolute" not in reasons, report
    assert {"translation_robust", "rotation_robust"} <= reasons, report

    # Consistently faster movement should establish its own baseline, not be treated as a jump.
    fast_consistent = {"frames": [{"transform_matrix": _pose(i * 0.12, i * 8.0)} for i in range(8)]}
    report = diagnose(fast_consistent)
    assert report["pose_jump_count"] == 0, report

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
