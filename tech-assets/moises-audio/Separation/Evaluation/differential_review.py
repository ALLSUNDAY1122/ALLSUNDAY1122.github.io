from __future__ import annotations

import hashlib
from datetime import datetime
from pathlib import Path
from typing import Any, Mapping, Sequence

from differential_common import (
    EVIDENCE_STATE, SCHEMA_VERSION, LISTENING_DIMENSIONS, GateError, dump_json,
    load_json, relpath, req_map, req_num, req_str, safe_path,
)

def extract_run_metrics(run: Mapping[str, Any], fixture: Mapping[str, Any]) -> dict[str, float | None]:
    timing = req_map(run.get("timing_ms"), "run.timing_ms")
    cost = req_map(run.get("cost"), "run.cost")
    duration = req_num(fixture.get("duration_seconds"), "fixture.duration_seconds", minimum=0.001)
    total_cost = req_num(cost.get("total"), "cost.total", minimum=0)
    return {
        "wall_time_ms": req_num(timing.get("total"), "timing_ms.total", minimum=0),
        "cost_total": total_cost,
        "cost_currency": req_str(cost.get("currency"), "cost.currency"),
        "cost_per_audio_minute": total_cost / (duration / 60.0),
    }


def local_artifact_path(root: Path, result: Mapping[str, Any], field: str) -> Path:
    path = safe_path(root, result.get("artifact_path"), field)
    if not path.is_file():
        raise GateError("L1M04_LOCAL_COMPARISON_ARTIFACT_REQUIRED", f"{field} must exist locally for blind comparison")
    return path


def blind_swap(batch_id: str, case_id: str, role: str) -> bool:
    digest = hashlib.sha256(f"{batch_id}:{case_id}:{role}:blind".encode("utf-8")).digest()
    return bool(digest[0] & 1)


def build_blind_review(config: Mapping[str, Any], root: Path, output_dir: Path) -> tuple[Path, Path, Path]:
    worksheet_rows: list[dict[str, Any]] = []
    reveal_rows: list[dict[str, Any]] = []
    for case in config["cases"]:
        project = req_map(load_json(Path(case["project_run_path"])), "project_run")
        reference = req_map(load_json(Path(case["reference_run_path"])), "reference_run")
        project_by_role = {str(item["role"]).lower(): item for item in project.get("results", []) if isinstance(item, Mapping)}
        reference_by_role = {str(item["role"]).lower(): item for item in reference.get("results", []) if isinstance(item, Mapping)}
        for role in case["target_roles"]:
            if role not in project_by_role or role not in reference_by_role:
                raise GateError("L1M04_REVIEW_ROLE_MISSING", f"comparison output missing role {case['case_id']}:{role}")
            swapped = blind_swap(str(config["batch_id"]), str(case["case_id"]), str(role))
            mapping = {"A": "REFERENCE", "B": "PROJECT"} if swapped else {"A": "PROJECT", "B": "REFERENCE"}
            project_path = local_artifact_path(root, project_by_role[role], f"{case['case_id']}.{role}.project_artifact")
            reference_path = local_artifact_path(root, reference_by_role[role], f"{case['case_id']}.{role}.reference_artifact")
            paths = {"PROJECT": relpath(root, project_path), "REFERENCE": relpath(root, reference_path)}
            worksheet_rows.append({
                "case_id": case["case_id"], "stem": role, "systems": ["A", "B"],
                "score_slots": {dimension: None for dimension in LISTENING_DIMENSIONS},
                "listener_id": None, "timestamp": None,
            })
            reveal_rows.append({
                "case_id": case["case_id"], "stem": role,
                "A": {"revealed_system": mapping["A"], "artifact_path": paths[mapping["A"]]},
                "B": {"revealed_system": mapping["B"], "artifact_path": paths[mapping["B"]]},
            })
    worksheet = {
        "schema_version": SCHEMA_VERSION, "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"], "instructions": "Reviewer scores blind IDs only; do not open private reveal map.",
        "rows": worksheet_rows,
    }
    reveal = {
        "schema_version": SCHEMA_VERSION, "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"], "private": True,
        "note": "Coordinator-only locator map. It references existing artifacts and copies none.",
        "rows": reveal_rows,
    }
    worksheet_path = output_dir / "reviewer-worksheet.template.json"
    reveal_path = output_dir / "reviewer-reveal-map.private.json"
    scores_path = output_dir / "reviewer-scores.json"
    dump_json(worksheet_path, worksheet)
    dump_json(reveal_path, reveal)
    if not scores_path.exists():
        dump_json(scores_path, {"schema_version": 1, "batch_id": config["batch_id"], "reviews": []})
    return worksheet_path, reveal_path, scores_path


def parse_reviews(config: Mapping[str, Any], output_dir: Path) -> list[dict[str, Any]]:
    scores_doc = req_map(load_json(output_dir / "reviewer-scores.json"), "reviewer_scores")
    reviews = scores_doc.get("reviews")
    if not isinstance(reviews, list) or not reviews:
        raise GateError(
            "L1M04_BLIND_REVIEW_REQUIRED", "reviewer-scores.json has no completed reviews",
            exit_code=3,
        )
    reveal = req_map(load_json(output_dir / "reviewer-reveal-map.private.json"), "reveal")
    reveal_index: dict[tuple[str, str, str], str] = {}
    for row in reveal.get("rows", []):
        if not isinstance(row, Mapping):
            continue
        for blind in ("A", "B"):
            item = row.get(blind)
            if isinstance(item, Mapping):
                reveal_index[(str(row.get("case_id")), str(row.get("stem")), blind)] = str(item.get("revealed_system"))
    normalized: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str, str]] = set()
    for index, raw in enumerate(reviews):
        review = req_map(raw, f"reviews[{index}]")
        case_id = req_str(review.get("case_id"), f"reviews[{index}].case_id")
        stem = req_str(review.get("stem"), f"reviews[{index}].stem").lower()
        blind = req_str(review.get("system_blind_id"), f"reviews[{index}].system_blind_id")
        listener = req_str(review.get("listener_id"), f"reviews[{index}].listener_id")
        key = (case_id, stem, blind, listener)
        if key in seen:
            raise GateError("L1M04_REVIEW_DUPLICATE", f"duplicate review {key}")
        seen.add(key)
        system = reveal_index.get((case_id, stem, blind))
        if system not in {"PROJECT", "REFERENCE"}:
            raise GateError("L1M04_REVIEW_REVEAL_MISSING", f"no reveal mapping for {case_id}:{stem}:{blind}")
        scores = req_map(review.get("scores"), f"reviews[{index}].scores")
        normalized_scores: dict[str, int] = {}
        for dimension in LISTENING_DIMENSIONS:
            value = scores.get(dimension)
            if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 4:
                raise GateError("L1M04_REVIEW_SCORE", f"{dimension} must be integer 0..4")
            normalized_scores[dimension] = value
        timestamp = req_str(review.get("timestamp"), f"reviews[{index}].timestamp")
        try:
            datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        except ValueError as exc:
            raise GateError("L1M04_REVIEW_TIMESTAMP", f"invalid timestamp {timestamp}") from exc
        normalized.append({
            "case_id": case_id, "stem": stem, "system_blind_id": blind,
            "revealed_system": system, "listener_id": listener, "timestamp": timestamp,
            "scores": normalized_scores,
        })
    return normalized



def mean(values: Sequence[float]) -> float | None:
    return sum(values) / len(values) if values else None


def calculate_acceptance(
    config: Mapping[str, Any], execution: Mapping[str, Any], evaluations: Mapping[str, Any],
    reviews: Sequence[Mapping[str, Any]], root: Path,
) -> dict[str, Any]:
    policy = config["policy"]
    failures = sum(1 for item in execution["cases"] if not item["success"])
    retry_cases = sum(1 for item in execution["cases"] if int(item["attempts"]) > 1)
    ncases = len(execution["cases"])
    failure_rate = failures / ncases
    retry_fraction = retry_cases / ncases

    time_ratios: list[float] = []
    objective_deltas: list[float] = []
    objective_case_ids: set[str] = set()
    cost_per_minute: list[float] = []
    for item in evaluations["cases"]:
        case_id = item["case_id"]
        case_cfg = next(c for c in config["cases"] if c["case_id"] == case_id)
        fixture = req_map(load_json(Path(case_cfg["fixture_path"])), "fixture")
        project_run = req_map(load_json(Path(case_cfg["project_run_path"])), "project_run")
        reference_run = req_map(load_json(Path(case_cfg["reference_run_path"])), "reference_run")
        pm = extract_run_metrics(project_run, fixture)
        rm = extract_run_metrics(reference_run, fixture)
        if float(rm["wall_time_ms"] or 0) > 0:
            time_ratios.append(float(pm["wall_time_ms"] or 0) / float(rm["wall_time_ms"] or 1))
        if policy.get("max_project_cost_per_audio_minute") is not None and pm["cost_currency"] != policy.get("cost_currency"):
            raise GateError("L1M04_COST_CURRENCY_MISMATCH", f"case {case_id} project cost currency {pm['cost_currency']} != policy {policy.get('cost_currency')}")
        cost_per_minute.append(float(pm["cost_per_audio_minute"] or 0))
        proj_stems = req_map(req_map(item["project"].get("objective_metrics"), "project.objective_metrics").get("per_stem"), "project.per_stem")
        ref_stems = req_map(req_map(item["reference"].get("objective_metrics"), "reference.objective_metrics").get("per_stem"), "reference.per_stem")
        common = set(proj_stems) & set(ref_stems)
        case_had_objective = False
        for role in common:
            p = req_map(proj_stems[role], f"project objective {role}").get("si_sdr_db")
            r = req_map(ref_stems[role], f"reference objective {role}").get("si_sdr_db")
            if isinstance(p, (int, float)) and isinstance(r, (int, float)):
                objective_deltas.append(float(p) - float(r))
                case_had_objective = True
        if case_had_objective:
            objective_case_ids.add(case_id)

    review_index: dict[tuple[str, str, str], list[Mapping[str, Any]]] = {}
    for review in reviews:
        review_index.setdefault((str(review["case_id"]), str(review["stem"]), str(review["revealed_system"])), []).append(review)
    listening_deltas: list[float] = []
    overall_role_deltas: list[float] = []
    review_coverage_failures: list[str] = []
    for case in config["cases"]:
        for role in case["target_roles"]:
            systems = {}
            for system in ("PROJECT", "REFERENCE"):
                rows = review_index.get((case["case_id"], role, system), [])
                systems[system] = rows
                if len(rows) < int(config["min_reviewers"]):
                    review_coverage_failures.append(f"{case['case_id']}:{role}:{system}")
            if not systems["PROJECT"] or not systems["REFERENCE"]:
                continue
            for dimension in LISTENING_DIMENSIONS:
                p = mean([float(r["scores"][dimension]) for r in systems["PROJECT"]])
                r = mean([float(x["scores"][dimension]) for x in systems["REFERENCE"]])
                if p is not None and r is not None:
                    listening_deltas.append(p - r)
                    if dimension == "overall_practice_usability":
                        overall_role_deltas.append(p - r)

    metrics = {
        "case_failure_rate": failure_rate,
        "retry_fraction": retry_fraction,
        "mean_wall_time_ratio_vs_reference": mean(time_ratios),
        "mean_objective_si_sdr_delta_db": mean(objective_deltas),
        "objective_case_count": len(objective_case_ids),
        "mean_listening_delta": mean(listening_deltas),
        "worst_role_overall_usability_delta": min(overall_role_deltas) if overall_role_deltas else None,
        "max_project_cost_per_audio_minute": max(cost_per_minute) if cost_per_minute else None,
        "review_coverage_failures": sorted(review_coverage_failures),
    }
    checks: list[dict[str, Any]] = []
    def check(name: str, passed: bool, actual: Any, threshold: Any) -> None:
        checks.append({"name": name, "passed": bool(passed), "actual": actual, "threshold": threshold})
    check("case_failure_rate", failure_rate <= float(policy["max_case_failure_rate"]), failure_rate, policy["max_case_failure_rate"])
    check("retry_fraction", retry_fraction <= float(policy["max_retry_fraction"]), retry_fraction, policy["max_retry_fraction"])
    ratio = metrics["mean_wall_time_ratio_vs_reference"]
    check("wall_time_ratio", ratio is not None and ratio <= float(policy["max_mean_wall_time_ratio_vs_reference"]), ratio, policy["max_mean_wall_time_ratio_vs_reference"])
    obj = metrics["mean_objective_si_sdr_delta_db"]
    obj_count_ok = len(objective_case_ids) >= int(config["minimum_objective_cases"])
    check("objective_case_count", obj_count_ok, len(objective_case_ids), config["minimum_objective_cases"])
    if int(config["minimum_objective_cases"]) > 0:
        check("objective_si_sdr_delta", obj is not None and obj >= float(policy["min_mean_objective_si_sdr_delta_db"]), obj, policy["min_mean_objective_si_sdr_delta_db"])
    listen = metrics["mean_listening_delta"]
    check("review_coverage", not review_coverage_failures, len(review_coverage_failures), 0)
    check("listening_delta", listen is not None and listen >= float(policy["min_mean_listening_delta"]), listen, policy["min_mean_listening_delta"])
    worst = metrics["worst_role_overall_usability_delta"]
    check("worst_role_overall_usability_delta", worst is not None and worst >= float(policy["min_worst_role_overall_usability_delta"]), worst, policy["min_worst_role_overall_usability_delta"])
    if policy.get("max_project_cost_per_audio_minute") is not None:
        cost = metrics["max_project_cost_per_audio_minute"]
        check("cost_per_audio_minute", cost is not None and cost <= float(policy["max_project_cost_per_audio_minute"]), cost, policy["max_project_cost_per_audio_minute"])
    passed = all(item["passed"] for item in checks)
    return {
        "schema_version": SCHEMA_VERSION, "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"], "acceptance_policy_id": policy["policy_id"],
        "result": "LANE_GATE_CANDIDATE_PASS" if passed else "LANE_GATE_CANDIDATE_FAIL",
        "parity_state": "NON_PARITY_EVIDENCE_ONLY",
        "parity_reason": "HQ must still perform integrated current-iPhone/device/product differential and update PARITY_MATRIX.",
        "metrics": metrics, "checks": checks,
    }
