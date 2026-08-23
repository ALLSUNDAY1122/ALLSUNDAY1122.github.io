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

def write_preflight(config: Mapping[str, Any], output_dir: Path) -> None:
    dump_json(output_dir / "preflight.json", {
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
    })


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
    for case in config["cases"]:
        validate_fixture_for_batch(evaluator, root, case, str(config["purpose"]), float(config["timeout_seconds"]))
    write_preflight(config, output_dir)

    execution = execute_project_cases(config, evaluator, root, output_dir)
    failed_cases = [item["case_id"] for item in execution["cases"] if not item["success"]]
    _, missing_reference = build_comparison_inputs(config, root, output_dir)
    if failed_cases:
        raise GateError("L1M04_PROJECT_BATCH_FAILED", "project runs failed: " + ",".join(sorted(failed_cases)), exit_code=EXIT_CANDIDATE_FAIL)
    if missing_reference:
        raise GateError(
            "L1M04_REFERENCE_CAPTURE_REQUIRED",
            "reference run manifests missing for: " + ",".join(sorted(missing_reference)),
            exit_code=EXIT_EXTERNAL_INPUT_REQUIRED,
        )

    for case in config["cases"]:
        validate_run(evaluator, root, case, Path(case["reference_run_path"]), float(config["timeout_seconds"]))
        validate_system_identity(Path(case["reference_run_path"]), expected="REFERENCE")
    evaluations = evaluate_all_runs(config, evaluator, root, output_dir)
    build_blind_review(config, root, output_dir)
    reviews = parse_reviews(config, output_dir)
    acceptance = calculate_acceptance(config, execution, evaluations, reviews, root)
    dump_json(output_dir / "acceptance.json", acceptance)
    if acceptance["result"] != "LANE_GATE_CANDIDATE_PASS":
        raise GateError("L1M04_ACCEPTANCE_FAILED", "candidate thresholds not met", exit_code=EXIT_CANDIDATE_FAIL)
    return acceptance


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="L1-M04 real-separator differential batch gate")
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
    except GateError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
