#!/usr/bin/env python3
"""L1-A26 one-command Lane 1 regression/dependency closure audit.

Engineering evidence only. It cannot promote PARITY.
"""
from __future__ import annotations

import argparse
import ast
import json
import os
import py_compile
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from lane1_source_snapshot import SourceSnapshotError, build_source_snapshot

TOOL_VERSION = "L1-A26-v2"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
ERROR_CODE = re.compile(r"\b(?:SEP|GEN|GENRT|GENRET|GEN_FACADE|L1A\d+|L1M\d+)_[A-Z0-9_]+\b")
GIT_SHA = re.compile(r"^[0-9a-f]{40}$")


def _rel(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _python_files(audio_root: Path) -> list[Path]:
    sep = audio_root / "Separation"
    out = []
    for directory, pattern in (
        (sep / "Server", "*.py"),
        (sep / "Evaluation", "*.py"),
        (sep / "Tests", "test_*.py"),
    ):
        if directory.is_dir():
            out.extend(sorted(directory.glob(pattern)))
    return sorted(set(out))


def _json_files(audio_root: Path) -> list[Path]:
    out = []
    for directory in (
        audio_root / "Separation" / "Evaluation",
        audio_root / "Processing" / "Tests",
    ):
        if directory.is_dir():
            out.extend(sorted(p for p in directory.rglob("*.json") if p.is_file()))
    return sorted(set(out))


def _compile_python(files: list[Path], root: Path) -> dict[str, Any]:
    failures = []
    for path in files:
        try:
            py_compile.compile(str(path), doraise=True)
        except Exception as e:
            failures.append({"path": _rel(path, root), "error_type": type(e).__name__})
    return {"checked": len(files), "failures": failures, "state": "PASS" if not failures else "FAIL"}


def _parse_json(files: list[Path], root: Path) -> dict[str, Any]:
    failures = []
    parsed = {}
    for path in files:
        try:
            parsed[path] = json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            failures.append({"path": _rel(path, root), "error_type": type(e).__name__})
    return {"checked": len(files), "failures": failures, "state": "PASS" if not failures else "FAIL", "parsed": parsed}


def _check_schemas(parsed: dict[Path, Any], root: Path) -> dict[str, Any]:
    schemas = {p: v for p, v in parsed.items() if p.name.endswith(".schema.json")}
    try:
        import jsonschema
    except ImportError:
        return {"checked": 0, "available": False, "failures": [], "state": "FAIL_DEPENDENCY_MISSING"}
    failures = []
    for path, schema in schemas.items():
        try:
            jsonschema.Draft202012Validator.check_schema(schema)
        except Exception as e:
            failures.append({"path": _rel(path, root), "error_type": type(e).__name__})
    return {"checked": len(schemas), "available": True, "failures": failures, "state": "PASS" if not failures else "FAIL"}


def _run_unittest(audio_root: Path, timeout_seconds: int) -> dict[str, Any]:
    sep = audio_root / "Separation"
    env = os.environ.copy()
    pythonpath = [str(sep / "Server"), str(sep / "Evaluation"), str(sep / "Tests")]
    if env.get("PYTHONPATH"):
        pythonpath.append(env["PYTHONPATH"])
    env["PYTHONPATH"] = os.pathsep.join(pythonpath)
    cmd = [sys.executable, "-m", "unittest", "discover", "-s", str(sep / "Tests"), "-p", "test_*.py"]
    try:
        proc = subprocess.run(cmd, cwd=str(audio_root), env=env, capture_output=True, text=True, timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        return {"state": "FAIL_TIMEOUT", "returncode": None, "tests_run": None, "failures": None, "errors": None, "skipped": None}
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    match = re.search(r"Ran\s+(\d+)\s+tests?", combined)
    failures = re.search(r"failures=(\d+)", combined)
    errors = re.search(r"errors=(\d+)", combined)
    skipped = re.search(r"skipped=(\d+)", combined)
    return {
        "state": "PASS" if proc.returncode == 0 else "FAIL",
        "returncode": proc.returncode,
        "tests_run": int(match.group(1)) if match else None,
        "failures": int(failures.group(1)) if failures else (0 if proc.returncode == 0 else None),
        "errors": int(errors.group(1)) if errors else (0 if proc.returncode == 0 else None),
        "skipped": int(skipped.group(1)) if skipped else 0,
    }


def _dependency_checks(audio_root: Path) -> dict[str, Any]:
    server = audio_root / "Separation" / "Server"
    tests_dir = audio_root / "Separation" / "Tests"
    required_files = {
        "A21_contract": server / "ai_stem_generation_contract.py",
        "A22_runtime": server / "ai_stem_generation_runtime.py",
        "A23_mix": server / "generated_stem_mix_compatibility.py",
        "A24_retention": server / "generated_stem_retention.py",
        "A25_facade": server / "ai_stem_generation_processing_facade.py",
        "A25_delete_resume": server / "ai_stem_generation_delete_resume.py",
        "A26_retention_gateway": server / "ai_stem_generation_retention_gateway.py",
    }
    required_safety_files = {
        "A27_topology": server / "mutation_topology.py",
        "A28_privacy": server / "privacy_retention.py",
        "A29_reconciliation": server / "provider_delete_reconciliation.py",
    }
    required_safety_regressions = {
        "A27_A35_topology_regression": tests_dir / "test_mutation_topology.py",
        "A28_privacy_regression": tests_dir / "test_privacy_retention.py",
        "A28_privacy_concurrency_regression": tests_dir / "test_privacy_retention_concurrency.py",
        "A29_reconciliation_regression": tests_dir / "test_provider_delete_reconciliation.py",
        "A30_reconciliation_resume_regression": tests_dir / "test_provider_delete_reconciliation_resume.py",
        "A31_reconciliation_ordering_regression": tests_dir / "test_provider_delete_reconciliation_ordering.py",
        "A32_reconciliation_crash_atomicity_regression": tests_dir / "test_provider_delete_reconciliation_crash_atomicity.py",
        "A33_reconciliation_temporal_regression": tests_dir / "test_provider_delete_reconciliation_temporal_causality.py",
        "A34_reconciliation_expiry_regression": tests_dir / "test_provider_delete_reconciliation_documented_expiry.py",
    }
    failures = []
    for name, path in required_files.items():
        if not path.is_file():
            failures.append({"check": name, "code": "L1A26_REQUIRED_FILE_MISSING"})
    for name, path in required_safety_files.items():
        if not path.is_file():
            failures.append({"check": name, "code": "L1A36_REQUIRED_SAFETY_FILE_MISSING"})
    for name, path in required_safety_regressions.items():
        if not path.is_file():
            failures.append({"check": name, "code": "L1A36_REQUIRED_REGRESSION_MISSING"})

    stale_policy = audio_root / "Separation" / "Evaluation" / "schemas" / "generated-stem-retention-policy.schema.json"
    if stale_policy.exists():
        failures.append({"check": "stale_a24_policy_schema", "code": "L1A26_STALE_A24_SCHEMA_PRESENT"})

    def methods(path: Path, class_name: str) -> set[str]:
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"))
        except Exception:
            return set()
        for node in tree.body:
            if isinstance(node, ast.ClassDef) and node.name == class_name:
                return {n.name for n in node.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
        return set()

    if required_files["A24_retention"].is_file():
        a24 = methods(required_files["A24_retention"], "GeneratedStemRetentionCoordinator")
        expected = {"begin_delete", "execute_local_delete", "assert_generation_not_deleted", "privacy_safe_evidence", "record_runtime_delete"}
        if not expected <= a24:
            failures.append({"check": "a24_coordinator_surface", "code": "L1A26_A24_SURFACE_MISMATCH", "missing": sorted(expected - a24)})
        text = required_files["A24_retention"].read_text(encoding="utf-8")
        if "self.manifests" not in text or "self.active" not in text or "_collect_referenced_artifacts" not in text:
            failures.append({"check": "a24_reference_graph", "code": "L1A26_A24_REFERENCE_GRAPH_INCOMPLETE"})

    if required_files["A26_retention_gateway"].is_file():
        gateway = methods(required_files["A26_retention_gateway"], "A24RetentionGateway")
        expected = {"register_variant", "request_delete", "snapshot"}
        if not expected <= gateway:
            failures.append({"check": "a24_a25_gateway_surface", "code": "L1A26_GATEWAY_SURFACE_MISMATCH", "missing": sorted(expected - gateway)})

    if required_files["A25_facade"].is_file():
        text = required_files["A25_facade"].read_text(encoding="utf-8")
        for token in ("register_variant", "request_delete", "snapshot", "retention_policy_sha256"):
            if token not in text:
                failures.append({"check": "a25_retention_expectation", "code": "L1A26_A25_RETENTION_EXPECTATION_MISSING", "token": token})

    return {
        "checked": 4 + len(required_files) + len(required_safety_files) + len(required_safety_regressions),
        "failures": failures,
        "state": "PASS" if not failures else "FAIL",
    }


def _stable_code_inventory(files: list[Path], root: Path) -> dict[str, Any]:
    owners: dict[str, set[str]] = {}
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        for code in ERROR_CODE.findall(text):
            owners.setdefault(code, set()).add(_rel(path, root))
    multi_owner = {code: sorted(paths) for code, paths in owners.items() if len(paths) > 1}
    return {
        "unique_codes": len(owners),
        "multi_owner_codes": len(multi_owner),
        "note": "multi-owner is inventory only; duplicates are not automatically conflicts",
    }


def _git_head_check(audio_root: Path, expected_git_head: str | None) -> dict[str, Any]:
    if expected_git_head is None:
        return {"state": "FAIL_EXPECTED_HEAD_REQUIRED", "expected_git_head": None, "actual_git_head": None}
    expected = expected_git_head.strip().lower()
    if not GIT_SHA.fullmatch(expected):
        return {"state": "FAIL_EXPECTED_HEAD_INVALID", "expected_git_head": expected_git_head, "actual_git_head": None}
    repo_root = audio_root.resolve().parents[1]
    try:
        proc = subprocess.run(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"state": "FAIL_GIT_HEAD_UNAVAILABLE", "expected_git_head": expected, "actual_git_head": None}
    actual = (proc.stdout or "").strip().lower()
    if proc.returncode != 0 or not GIT_SHA.fullmatch(actual):
        return {"state": "FAIL_GIT_HEAD_UNAVAILABLE", "expected_git_head": expected, "actual_git_head": None}
    return {
        "state": "PASS" if actual == expected else "FAIL_GIT_HEAD_MISMATCH",
        "expected_git_head": expected,
        "actual_git_head": actual,
    }


def _source_snapshot(audio_root: Path, excludes: list[Path]) -> dict[str, Any]:
    try:
        snapshot = build_source_snapshot(audio_root, excludes=excludes)
    except SourceSnapshotError as exc:
        return {"state": "FAIL", "stable_error_code": exc.code, "snapshot": None}
    return {"state": "PASS", "stable_error_code": None, "snapshot": snapshot}


def run(
    audio_root: Path,
    *,
    timeout_seconds: int = 300,
    expected_git_head: str | None = None,
    snapshot_excludes: list[Path] | None = None,
) -> dict[str, Any]:
    audio_root = audio_root.resolve()
    snapshot_result = _source_snapshot(audio_root, snapshot_excludes or [])
    git_result = _git_head_check(audio_root, expected_git_head)
    python_files = _python_files(audio_root)
    json_files = _json_files(audio_root)
    compile_result = _compile_python(python_files, audio_root)
    json_result = _parse_json(json_files, audio_root)
    schema_result = _check_schemas(json_result.pop("parsed"), audio_root)
    dependency_result = _dependency_checks(audio_root)
    unittest_result = _run_unittest(audio_root, timeout_seconds)
    states = [
        snapshot_result["state"],
        git_result["state"],
        compile_result["state"],
        json_result["state"],
        schema_result["state"],
        dependency_result["state"],
        unittest_result["state"],
    ]
    overall = "PASS" if all(s == "PASS" for s in states) else "FAIL"
    return {
        "schema_version": 2,
        "tool_version": TOOL_VERSION,
        "evidence_state": EVIDENCE_STATE,
        "parity_claim": "NONE",
        "overall_state": overall,
        "git_head_binding": git_result,
        "owned_source_snapshot": snapshot_result,
        "python_compile": compile_result,
        "json_syntax": json_result,
        "json_schema_self_validation": schema_result,
        "dependency_contracts": dependency_result,
        "unittest_discovery": unittest_result,
        "stable_error_code_inventory": _stable_code_inventory(python_files, audio_root),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--timeout-seconds", type=int, default=300)
    parser.add_argument("--expected-git-head", required=True, help="Exact 40-hex Worker branch commit expected in this checkout")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    excludes: list[Path] = []
    if args.output:
        try:
            args.output.resolve().relative_to(args.audio_root.resolve())
        except ValueError:
            pass
        else:
            excludes.append(args.output)
    report = run(
        args.audio_root,
        timeout_seconds=args.timeout_seconds,
        expected_git_head=args.expected_git_head,
        snapshot_excludes=excludes,
    )
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0 if report["overall_state"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
