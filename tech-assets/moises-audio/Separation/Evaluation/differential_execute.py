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
    config: Mapping[str, Any], evaluator: Path, root: Path, output_dir: Path, *, resume: Any | None = None
) -> dict[str, Any]:
    batch_id = str(config["batch_id"])
    attempts_out: list[dict[str, Any]] = []
    case_results: list[dict[str, Any]] = []
    if resume is not None:
        resume.verify_case_inputs()

    for case in config["cases"]:
        project_run_path = Path(case["project_run_path"])
        case_start = time.monotonic()
        succeeded = False
        last_code: str | None = None

        trusted_before = False
        if resume is not None:
            trusted_before = resume.trusted_case_artifact(str(case["case_id"]), "project_run_manifest", project_run_path)

        if project_run_path.is_file():
            try:
                validate_run(evaluator, root, case, project_run_path, float(config["timeout_seconds"]))
                validate_system_identity(project_run_path, expected="PROJECT")
                succeeded = True
                if resume is not None:
                    attempts = resume.case_entry(str(case["case_id"])).get("attempts", [])
                    had_started = bool(attempts) and attempts[-1].get("status") == "STARTED"
                    if had_started:
                        resume.recover_started_attempt(str(case["case_id"]), output_recovered=True)
                        source = "RECOVERED_AFTER_TERMINATION"
                    elif trusted_before:
                        source = str(resume.case_entry(str(case["case_id"])).get("project_source") or "REUSED_PREEXISTING")
                    else:
                        source = "REUSED_PREEXISTING"
                    resume.mark_project_ready(str(case["case_id"]), project_run_path, source=source)
            except GateError:
                if trusted_before:
                    raise
                succeeded = False

        if resume is not None and not succeeded:
            resume.recover_started_attempt(str(case["case_id"]), output_recovered=False)
            attempt_count = resume.attempt_count(str(case["case_id"]))
        else:
            attempt_count = 0 if resume is None else resume.attempt_count(str(case["case_id"]))

        while not succeeded and attempt_count < int(config["max_attempts"]):
            if resume is not None:
                attempt_number = resume.begin_attempt(str(case["case_id"]))
                attempt_count = attempt_number
            else:
                attempt_count += 1
                attempt_number = attempt_count

            argv = command_for_case(config["command"], root, case, batch_id)
            started = time.monotonic()
            status = "FAIL"
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
                        status = "PASS"
                    except GateError as exc:
                        last_code = exc.code
                else:
                    last_code = "DRIVER_EXIT_" + str(exit_code)
            except subprocess.TimeoutExpired:
                wall_ms = (time.monotonic() - started) * 1000.0
                exit_code = 124
                last_code = "DRIVER_TIMEOUT"
                status = "TIMEOUT"

            if resume is not None:
                resume.finish_attempt(
                    str(case["case_id"]), attempt_number, status=status,
                    exit_code=exit_code, wall_time_ms=wall_ms, stable_error_code=last_code,
                )
                if succeeded:
                    resume.mark_project_ready(str(case["case_id"]), project_run_path, source="EXECUTED")
            else:
                attempts_out.append({
                    "case_id": case["case_id"], "attempt": attempt_number,
                    "wall_time_ms": round(wall_ms, 3), "exit_code": exit_code,
                    "status": "PASS" if succeeded else "FAIL", "stable_error_code": last_code,
                    "idempotency_key": stable_idempotency_key(batch_id, str(case["case_id"])),
                })

        if resume is None:
            case_results.append({
                "case_id": case["case_id"], "success": succeeded, "attempts": attempt_count,
                "orchestrator_wall_time_ms": round((time.monotonic() - case_start) * 1000.0, 3),
                "stable_error_code": last_code,
                "project_run_manifest": relpath(root, project_run_path),
            })

    if resume is not None:
        execution = resume.execution_document()
    else:
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


def build_comparison_inputs(config: Mapping[str, Any], root: Path, output_dir: Path, *, resume: Any | None = None) -> tuple[dict[str, Any], list[str]]:
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
    path = output_dir / "comparison-input-manifest.json"
    dump_json(path, result)
    if resume is not None and not missing_reference:
        resume.bind_global_artifact("comparison_input_manifest", path)
    return result, missing_reference


def evaluate_all_runs(config: Mapping[str, Any], evaluator: Path, root: Path, output_dir: Path, *, resume: Any | None = None) -> dict[str, Any]:
    cases_out: list[dict[str, Any]] = []
    for case in config["cases"]:
        case_id = str(case["case_id"])
        project_eval_path = output_dir / "evaluations" / f"{case_id}.project.json"
        reference_eval_path = output_dir / "evaluations" / f"{case_id}.reference.json"

        project_trusted = resume is not None and resume.trusted_case_artifact(case_id, "project_evaluation", project_eval_path)
        if project_trusted:
            project_eval = req_map(load_json(project_eval_path), "evaluation")
        else:
            project_eval = run_evaluation(evaluator, root, case, Path(case["project_run_path"]), project_eval_path, float(config["timeout_seconds"]))

        reference_trusted = resume is not None and resume.trusted_case_artifact(case_id, "reference_evaluation", reference_eval_path)
        if reference_trusted:
            reference_eval = req_map(load_json(reference_eval_path), "evaluation")
        else:
            reference_eval = run_evaluation(evaluator, root, case, Path(case["reference_run_path"]), reference_eval_path, float(config["timeout_seconds"]))

        if resume is not None:
            resume.mark_evaluated(case_id, project_eval_path, reference_eval_path)

        cases_out.append({
            "case_id": case_id, "project_evaluation": relpath(root, project_eval_path),
            "reference_evaluation": relpath(root, reference_eval_path),
            "project": project_eval, "reference": reference_eval,
        })
    return {"cases": cases_out}
