from __future__ import annotations

import subprocess
import time
from pathlib import Path
from typing import Any, Mapping

from differential_common import (
    EVIDENCE_STATE, SCHEMA_VERSION, GateError, dump_json, evaluator_call,
    load_json, relpath, req_map, stable_idempotency_key, command_for_case,
    validate_run, validate_system_identity, sha256_file,
)

def execute_project_cases(
    config: Mapping[str, Any], evaluator: Path, root: Path, output_dir: Path
) -> dict[str, Any]:
    batch_id = str(config["batch_id"])
    attempts_out: list[dict[str, Any]] = []
    case_results: list[dict[str, Any]] = []
    for case in config["cases"]:
        project_run_path = Path(case["project_run_path"])
        case_start = time.monotonic()
        succeeded = False
        attempt_count = 0
        last_code: str | None = None
        if project_run_path.is_file():
            try:
                validate_run(evaluator, root, case, project_run_path, float(config["timeout_seconds"]))
                validate_system_identity(project_run_path, expected="PROJECT")
                succeeded = True
            except GateError:
                # Invalid stale output is never trusted. Provider receives the same stable key on retry.
                succeeded = False
        while not succeeded and attempt_count < int(config["max_attempts"]):
            attempt_count += 1
            argv = command_for_case(config["command"], root, case, batch_id)
            started = time.monotonic()
            try:
                completed = subprocess.run(
                    argv, cwd=str(root), capture_output=True, text=True,
                    timeout=float(config["timeout_seconds"]), check=False,
                )
                wall_ms = (time.monotonic() - started) * 1000.0
                exit_code = completed.returncode
                if exit_code == 0 and project_run_path.is_file():
                    try:
                        validate_run(evaluator, root, case, project_run_path, float(config["timeout_seconds"]))
                        validate_system_identity(project_run_path, expected="PROJECT")
                        succeeded = True
                        last_code = None
                    except GateError as exc:
                        last_code = exc.code
                else:
                    last_code = "DRIVER_EXIT_" + str(exit_code)
            except subprocess.TimeoutExpired:
                wall_ms = (time.monotonic() - started) * 1000.0
                exit_code = 124
                last_code = "DRIVER_TIMEOUT"
            attempts_out.append({
                "case_id": case["case_id"], "attempt": attempt_count,
                "wall_time_ms": round(wall_ms, 3), "exit_code": exit_code,
                "status": "PASS" if succeeded else "FAIL", "stable_error_code": last_code,
                "idempotency_key": stable_idempotency_key(batch_id, str(case["case_id"])),
            })
        case_results.append({
            "case_id": case["case_id"], "success": succeeded, "attempts": attempt_count,
            "orchestrator_wall_time_ms": round((time.monotonic() - case_start) * 1000.0, 3),
            "stable_error_code": last_code,
            "project_run_manifest": relpath(root, project_run_path),
        })
    execution = {
        "schema_version": SCHEMA_VERSION, "evidence_state": EVIDENCE_STATE,
        "batch_id": batch_id, "cases": case_results, "attempts": attempts_out,
    }
    dump_json(output_dir / "batch-execution.json", execution)
    return execution


def run_evaluation(evaluator: Path, root: Path, case: Mapping[str, Any], run_path: Path, output_path: Path, timeout: float) -> Mapping[str, Any]:
    evaluator_call(
        evaluator,
        ["evaluate", "--fixture", str(case["fixture_path"]), "--run", str(run_path), "--root", str(root),
         "--purpose", "REGRESSION", "--output", str(output_path)],
        cwd=root, timeout=timeout,
    )
    return req_map(load_json(output_path), "evaluation")


def build_comparison_inputs(config: Mapping[str, Any], root: Path, output_dir: Path) -> tuple[dict[str, Any], list[str]]:
    rows = []
    missing_reference = []
    for case in config["cases"]:
        reference = Path(case["reference_run_path"])
        if not reference.is_file():
            missing_reference.append(case["case_id"])
        project_run = Path(case["project_run_path"])
        fixture_path = Path(case["fixture_path"])
        rows.append({
            "case_id": case["case_id"], "genre": case["genre"], "duration_bucket": case["duration_bucket"],
            "target_roles": case["target_roles"], "fixture_manifest": relpath(root, fixture_path),
            "fixture_manifest_sha256": sha256_file(fixture_path),
            "project_run_manifest": relpath(root, project_run),
            "project_run_manifest_sha256": sha256_file(project_run) if project_run.is_file() else None,
            "reference_run_manifest": relpath(root, reference),
            "reference_run_manifest_sha256": sha256_file(reference) if reference.is_file() else None,
            "reference_assets_copied_by_executor": False,
        })
    result = {
        "schema_version": SCHEMA_VERSION, "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"], "reference_system": "MOISES_CURRENT_IPHONE",
        "asset_policy": "REFERENCE_ASSETS_ARE_EXTERNALLY_CAPTURED_AND_REFERENCED_BY_MANIFEST_PATH_ONLY",
        "cases": rows,
    }
    dump_json(output_dir / "comparison-input-manifest.json", result)
    return result, missing_reference



def evaluate_all_runs(config: Mapping[str, Any], evaluator: Path, root: Path, output_dir: Path) -> dict[str, Any]:
    cases_out: list[dict[str, Any]] = []
    for case in config["cases"]:
        project_eval_path = output_dir / "evaluations" / f"{case['case_id']}.project.json"
        reference_eval_path = output_dir / "evaluations" / f"{case['case_id']}.reference.json"
        project_eval = run_evaluation(evaluator, root, case, Path(case["project_run_path"]), project_eval_path, float(config["timeout_seconds"]))
        reference_eval = run_evaluation(evaluator, root, case, Path(case["reference_run_path"]), reference_eval_path, float(config["timeout_seconds"]))
        cases_out.append({
            "case_id": case["case_id"], "project_evaluation": relpath(root, project_eval_path),
            "reference_evaluation": relpath(root, reference_eval_path),
            "project": project_eval, "reference": reference_eval,
        })
    return {"cases": cases_out}
