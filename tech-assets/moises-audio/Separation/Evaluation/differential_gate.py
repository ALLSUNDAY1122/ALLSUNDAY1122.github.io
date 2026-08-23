from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Mapping

from differential_common import (
    EVIDENCE_STATE, SCHEMA_VERSION, EXIT_CANDIDATE_FAIL, EXIT_EXTERNAL_INPUT_REQUIRED,
    GateError, dump_json, load_json, req_map, validate_fixture_for_batch, validate_plan,
    validate_run, validate_system_identity,
)
from differential_execute import build_comparison_inputs, evaluate_all_runs, execute_project_cases
from differential_review import build_blind_review, calculate_acceptance, parse_reviews
from differential_resume import (
    DifferentialResumeLedger, ResumeError, apply_replacements, build_reviewer_assignments,
    filter_reviews_for_active_assignments, load_replacements, load_reviewer_roster,
    reviewer_assignment_document, sha256_json,
)


def write_preflight(config: Mapping[str, Any], output_dir: Path, *, resume: DifferentialResumeLedger | None = None) -> None:
    path = output_dir / "preflight.json"
    dump_json(path, {
        "schema_version": SCHEMA_VERSION,
        "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"],
        "purpose": config["purpose"],
        "legal_gate": config["legal_gate"],
        "production_credentials": [
            {"env_name": name, "present": bool(os.environ.get(name)), "value_persisted": False}
            for name in config["credential_env_names"]
        ],
        "coverage": {
            "case_count": len(config["cases"]),
            "genres": sorted({c["genre"] for c in config["cases"]}),
            "duration_buckets": sorted({c["duration_bucket"] for c in config["cases"]}),
            "target_role_sets": sorted([c["target_roles"] for c in config["cases"]]),
        },
        "parity_state": EVIDENCE_STATE,
        "batch_identity_sha256": resume.batch_identity_sha256 if resume is not None else None,
    })
    if resume is not None:
        resume.bind_global_artifact("preflight", path)


def _normalize_golden_lock(plan: Mapping[str, Any], purpose: str) -> str | None:
    value = plan.get("golden_corpus_lock_sha256")
    if value is None:
        if purpose == "PARITY_CANDIDATE":
            raise GateError(
                "L1A20_GOLDEN_LOCK_REQUIRED",
                "PARITY_CANDIDATE requires the approved A19 Golden corpus lock",
                exit_code=EXIT_EXTERNAL_INPUT_REQUIRED,
            )
        return None
    if not isinstance(value, str):
        raise GateError("L1A20_GOLDEN_LOCK_INVALID", "golden_corpus_lock_sha256 must be SHA-256 hex")
    raw = value.lower().removeprefix("sha256:")
    if len(raw) != 64 or any(ch not in "0123456789abcdef" for ch in raw):
        raise GateError("L1A20_GOLDEN_LOCK_INVALID", "golden_corpus_lock_sha256 must be SHA-256 hex")
    return raw


def _toolchain_paths(evaluator: Path) -> list[Path]:
    base = Path(__file__).resolve().parent
    return [
        Path(__file__).resolve(),
        base / "differential_common.py",
        base / "differential_execute.py",
        base / "differential_review.py",
        base / "differential_resume.py",
        evaluator.resolve(),
    ]


def _ensure_review_control_files(output_dir: Path) -> tuple[Path, Path]:
    roster = output_dir / "reviewer-roster.json"
    replacements = output_dir / "reviewer-replacements.json"
    if not roster.exists():
        dump_json(roster, {"schema_version": 1, "reviewer_ids": []})
    if not replacements.exists():
        dump_json(replacements, {"schema_version": 1, "replacements": []})
    return roster, replacements


def _review_stage(config: Mapping[str, Any], root: Path, output_dir: Path, resume: DifferentialResumeLedger) -> list[Mapping[str, Any]]:
    worksheet_path, reveal_path, scores_path = build_blind_review(config, root, output_dir)
    resume.bind_global_artifact("reviewer_worksheet", worksheet_path)
    resume.bind_global_artifact("reviewer_reveal_map", reveal_path)

    roster_path, replacements_path = _ensure_review_control_files(output_dir)
    try:
        reviewer_ids = load_reviewer_roster(roster_path, min_reviewers=int(config["min_reviewers"]))
    except ResumeError as exc:
        if exc.code in {"L1A20_REVIEWER_ROSTER_REQUIRED", "L1A20_REVIEWER_ROSTER_INSUFFICIENT"}:
            resume.set_state("WAITING_REVIEWER_ROSTER")
        raise

    base_assignments = build_reviewer_assignments(
        config, resume.batch_identity_sha256, reviewer_ids, min_reviewers=int(config["min_reviewers"])
    )
    replacements = load_replacements(replacements_path)
    active_assignments, replacement_history = apply_replacements(
        base_assignments, replacements, resume.batch_identity_sha256
    )
    assignments_doc = reviewer_assignment_document(
        str(config["batch_id"]), resume.batch_identity_sha256, active_assignments, replacement_history
    )
    assignments_path = output_dir / "reviewer-assignments.json"
    dump_json(assignments_path, assignments_doc)

    try:
        normalized_reviews = parse_reviews(config, output_dir)
    except GateError as exc:
        if exc.code != "L1M04_BLIND_REVIEW_REQUIRED":
            raise
        normalized_reviews = []

    filtered_reviews, missing, review_audit = filter_reviews_for_active_assignments(
        normalized_reviews, base_assignments, active_assignments, replacement_history
    )
    review_status_path = output_dir / "review-status.json"
    dump_json(review_status_path, {
        "schema_version": 1,
        "tool_version": "L1-A20-v1",
        "evidence_state": EVIDENCE_STATE,
        "batch_id": config["batch_id"],
        "batch_identity_sha256": resume.batch_identity_sha256,
        "review_audit": review_audit,
        "missing_assignment_ids": missing,
    })

    resume.set_review_hashes(
        roster_sha256=sha256_json(sorted(reviewer_ids)),
        assignments_sha256=sha256_json(base_assignments),
        replacements_sha256=sha256_json(replacements),
        scores_sha256=sha256_json(normalized_reviews),
        active_assignment_sha256=sha256_json(active_assignments),
        missing_assignment_ids=missing,
    )
    if missing:
        resume.set_state("WAITING_REVIEW")
        raise ResumeError(
            "L1A20_REVIEW_ASSIGNMENTS_INCOMPLETE",
            f"{len(missing)} active review assignments are incomplete",
            exit_code=EXIT_EXTERNAL_INPUT_REQUIRED,
        )

    resume.bind_global_artifact("reviewer_roster", roster_path)
    resume.bind_global_artifact("reviewer_assignments", assignments_path)
    resume.bind_global_artifact("reviewer_replacements", replacements_path)
    resume.bind_global_artifact("reviewer_scores", scores_path)
    resume.bind_global_artifact("review_status", review_status_path)
    return filtered_reviews


def _write_reproducibility_audit(output_dir: Path, resume: DifferentialResumeLedger, acceptance: Mapping[str, Any]) -> Path:
    audit_path = output_dir / "reproducibility-audit.json"
    document = {
        "schema_version": 1,
        "tool_version": "L1-A20-v1",
        "evidence_kind": "DIFFERENTIAL_REPRODUCIBILITY_AUDIT",
        "evidence_state": EVIDENCE_STATE,
        "batch_id": resume.data["batch_id"],
        "batch_identity_sha256": resume.batch_identity_sha256,
        "acceptance_policy_sha256": resume.policy_sha256,
        "acceptance_policy": resume.semantic["acceptance_policy"],
        "golden_corpus_lock_sha256": resume.semantic["golden_corpus_lock_sha256"],
        "toolchain": resume.semantic.get("toolchain", []),
        "review": dict(resume.data["review"]),
        "acceptance_result": acceptance.get("result"),
        "acceptance_checks": acceptance.get("checks"),
        "evidence_chain_sha256": resume.data.get("evidence_chain_sha256"),
        "parity_state": EVIDENCE_STATE,
        "parity_reason": "A20 preserves differential evidence identity/reproducibility; HQ still owns real-device/current-iPhone PARITY judgment.",
    }
    dump_json(audit_path, document)
    return audit_path


def run(plan_path: Path, root: Path, output_dir: Path, evaluator: Path) -> dict[str, Any]:
    root = root.resolve()
    output_dir = output_dir.resolve()
    try:
        output_dir.relative_to(root)
    except ValueError as exc:
        raise GateError("L1M04_OUTPUT_OUTSIDE_ROOT", "output-dir must be inside root") from exc
    plan = req_map(load_json(plan_path), "plan")
    config = validate_plan(plan, root)
    if not evaluator.is_file():
        raise GateError("L1M04_EVALUATOR_MISSING", f"evaluation CLI missing: {evaluator}")
    golden_lock = _normalize_golden_lock(plan, str(config["purpose"]))

    resume = DifferentialResumeLedger(
        root, output_dir, config,
        golden_corpus_lock_sha256=golden_lock,
        toolchain_paths=_toolchain_paths(evaluator),
    )
    resume.verify_case_inputs()

    for case in config["cases"]:
        validate_fixture_for_batch(evaluator, root, case, str(config["purpose"]), float(config["timeout_seconds"]))

    if resume.data.get("state") == "COMPLETE":
        resume.verify_bound_artifacts()
        acceptance_path = output_dir / "acceptance.json"
        acceptance = req_map(load_json(acceptance_path), "acceptance")
        if acceptance.get("result") != "LANE_GATE_CANDIDATE_PASS":
            raise GateError("L1M04_ACCEPTANCE_FAILED", "candidate thresholds not met", exit_code=EXIT_CANDIDATE_FAIL)
        return dict(acceptance)

    write_preflight(config, output_dir, resume=resume)
    execution = execute_project_cases(config, evaluator, root, output_dir, resume=resume)
    failed_cases = [item["case_id"] for item in execution["cases"] if not item["success"]]
    if failed_cases:
        raise GateError("L1M04_PROJECT_BATCH_FAILED", "project runs failed: " + ",".join(sorted(failed_cases)), exit_code=EXIT_CANDIDATE_FAIL)
    resume.bind_global_artifact("batch_execution", output_dir / "batch-execution.json")

    _, missing_reference = build_comparison_inputs(config, root, output_dir, resume=resume)
    if missing_reference:
        resume.set_state("WAITING_REFERENCE")
        raise GateError(
            "L1M04_REFERENCE_CAPTURE_REQUIRED",
            "reference run manifests missing for: " + ",".join(sorted(missing_reference)),
            exit_code=EXIT_EXTERNAL_INPUT_REQUIRED,
        )

    for case in config["cases"]:
        reference_path = Path(case["reference_run_path"])
        validate_run(evaluator, root, case, reference_path, float(config["timeout_seconds"]))
        validate_system_identity(reference_path, expected="REFERENCE")
        resume.mark_reference_ready(str(case["case_id"]), reference_path)

    evaluations = evaluate_all_runs(config, evaluator, root, output_dir, resume=resume)
    reviews = _review_stage(config, root, output_dir, resume)
    acceptance = calculate_acceptance(config, execution, evaluations, reviews, root)
    acceptance["reproducibility"] = {
        "schema_version": 1,
        "tool_version": "L1-A20-v1",
        "batch_identity_sha256": resume.batch_identity_sha256,
        "acceptance_policy_sha256": resume.policy_sha256,
        "golden_corpus_lock_sha256": resume.semantic["golden_corpus_lock_sha256"],
        "active_assignment_sha256": resume.data["review"]["active_assignment_sha256"],
        "parity_state": EVIDENCE_STATE,
    }
    acceptance_path = output_dir / "acceptance.json"
    dump_json(acceptance_path, acceptance)
    resume.set_state("ACCEPTANCE_READY")
    resume.finalize(acceptance_path)
    _write_reproducibility_audit(output_dir, resume, acceptance)
    if acceptance["result"] != "LANE_GATE_CANDIDATE_PASS":
        raise GateError("L1M04_ACCEPTANCE_FAILED", "candidate thresholds not met", exit_code=EXIT_CANDIDATE_FAIL)
    return acceptance


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="L1-A20 resumable real-separator differential batch gate")
    sub = parser.add_subparsers(dest="command", required=True)
    command = sub.add_parser("run")
    command.add_argument("--plan", required=True)
    command.add_argument("--root", required=True)
    command.add_argument("--output-dir", required=True)
    command.add_argument("--evaluator", default=str(Path(__file__).with_name("cli.py")))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run(Path(args.plan), Path(args.root), Path(args.output_dir), Path(args.evaluator).resolve())
        print(json.dumps({"status": "PASS", "result": result}, sort_keys=True, allow_nan=False))
        return 0
    except ResumeError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return exc.exit_code
    except GateError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
