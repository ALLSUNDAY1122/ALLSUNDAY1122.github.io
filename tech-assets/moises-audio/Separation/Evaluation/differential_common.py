from __future__ import annotations

import hashlib
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = 1
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
EXIT_FAIL = 2
EXIT_EXTERNAL_INPUT_REQUIRED = 3
EXIT_CANDIDATE_FAIL = 4
ENV_NAME_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")
ALLOWED_PURPOSES = {"REGRESSION", "PARITY_CANDIDATE"}
PARITY_MIN_CASES = 6
PARITY_MIN_GENRES = 3
PARITY_REQUIRED_DURATION_BUCKETS = {"short", "medium", "long"}
PARITY_CORE_TARGET_SET = tuple(sorted(("vocals", "drums", "bass", "other")))
ALLOWED_ROLES = {
    "vocals", "drums", "bass", "other", "instrumental", "guitar", "piano",
    "keys", "strings", "wind", "voice", "background_vocals", "percussion",
}
LISTENING_DIMENSIONS = (
    "target_preservation", "bleed", "musical_noise", "transient_integrity",
    "timbre_formant_integrity", "stereo_phase_integrity", "low_frequency_integrity",
    "reverb_ambience", "overall_practice_usability",
)


class GateError(ValueError):
    def __init__(self, code: str, message: str, *, exit_code: int = EXIT_FAIL):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message
        self.exit_code = exit_code


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GateError("L1M04_JSON_INVALID", f"cannot read {path}: {exc}") from exc


def dump_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n"
    temporary = path.with_name("." + path.name + ".tmp")
    temporary.write_text(payload, encoding="utf-8")
    temporary.replace(path)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            block = handle.read(1024 * 1024)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise GateError("L1M04_SCHEMA_TYPE", f"{field} must be object")
    return value


def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise GateError("L1M04_SCHEMA_REQUIRED", f"{field} must be non-empty string")
    return value.strip()


def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise GateError("L1M04_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def req_num(value: Any, field: str, *, minimum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise GateError("L1M04_SCHEMA_TYPE", f"{field} must be finite number")
    result = float(value)
    if minimum is not None and result < minimum:
        raise GateError("L1M04_SCHEMA_RANGE", f"{field} must be >= {minimum}")
    return result


def req_int(value: Any, field: str, *, minimum: int = 0) -> int:
    number = req_num(value, field, minimum=minimum)
    if int(number) != number:
        raise GateError("L1M04_SCHEMA_INTEGER", f"{field} must be integer")
    return int(number)


def safe_path(root: Path, raw: Any, field: str) -> Path:
    text = req_str(raw, field)
    relative = Path(text)
    if relative.is_absolute() or ".." in relative.parts:
        raise GateError("L1M04_PATH_UNSAFE", f"{field} must be safe path relative to root")
    resolved_root = root.resolve()
    resolved = (resolved_root / relative).resolve()
    try:
        resolved.relative_to(resolved_root)
    except ValueError as exc:
        raise GateError("L1M04_PATH_OUTSIDE_ROOT", f"{field} escapes root") from exc
    return resolved


def relpath(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def parse_json_line(payload: str) -> Mapping[str, Any] | None:
    for line in reversed(payload.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, Mapping):
            return value
    return None


def evaluator_call(evaluator: Path, argv: Sequence[str], *, cwd: Path, timeout: float) -> Mapping[str, Any]:
    try:
        completed = subprocess.run(
            [sys.executable, str(evaluator), *argv], cwd=str(cwd), capture_output=True,
            text=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise GateError("L1M04_EVALUATOR_TIMEOUT", f"evaluator timed out after {timeout}s") from exc
    parsed = parse_json_line(completed.stdout) or parse_json_line(completed.stderr)
    if completed.returncode != 0:
        code = str(parsed.get("code")) if parsed else "L1M04_EVALUATOR_FAILED"
        message = str(parsed.get("message")) if parsed else f"evaluator exit {completed.returncode}"
        raise GateError(code, message)
    if not parsed or parsed.get("status") != "PASS":
        raise GateError("L1M04_EVALUATOR_PROTOCOL", "evaluator did not emit PASS JSON")
    return parsed


def validate_plan(plan: Mapping[str, Any], root: Path) -> dict[str, Any]:
    if plan.get("schema_version") != SCHEMA_VERSION:
        raise GateError("L1M04_PLAN_SCHEMA", "unsupported schema_version")
    batch_id = req_str(plan.get("batch_id"), "batch_id")
    if plan.get("evidence_state") != EVIDENCE_STATE:
        raise GateError("L1M04_EVIDENCE_STATE", f"evidence_state must be {EVIDENCE_STATE}")
    purpose = req_str(plan.get("purpose"), "purpose").upper()
    if purpose not in ALLOWED_PURPOSES:
        raise GateError("L1M04_PURPOSE", f"unsupported purpose {purpose}")
    if req_str(plan.get("reference_system"), "reference_system") != "MOISES_CURRENT_IPHONE":
        raise GateError("L1M04_REFERENCE_SYSTEM", "reference_system must be MOISES_CURRENT_IPHONE")

    legal = req_map(plan.get("legal_gate"), "legal_gate")
    for name in (
        "commercial_approval_basis_id", "privacy_retention_approval_id",
        "reference_comparison_rights_id", "provider_idempotency_contract_id",
    ):
        req_str(legal.get(name), f"legal_gate.{name}")
    credentials = legal.get("production_credentials_env")
    if not isinstance(credentials, list) or not credentials:
        raise GateError("L1M04_CREDENTIAL_ENV", "production_credentials_env must be non-empty array")
    missing_env: list[str] = []
    for index, raw in enumerate(credentials):
        name = req_str(raw, f"legal_gate.production_credentials_env[{index}]")
        if not ENV_NAME_RE.fullmatch(name):
            raise GateError("L1M04_CREDENTIAL_ENV_NAME", f"unsafe env var name {name}")
        if purpose == "PARITY_CANDIDATE" and not os.environ.get(name):
            missing_env.append(name)
    if missing_env:
        raise GateError(
            "L1M04_PRODUCTION_CREDENTIALS_MISSING",
            "required credential environment variables are absent: " + ",".join(sorted(missing_env)),
        )

    execution = req_map(plan.get("execution"), "execution")
    max_attempts = req_int(execution.get("max_attempts_per_case"), "execution.max_attempts_per_case", minimum=1)
    timeout_seconds = req_num(execution.get("timeout_seconds"), "execution.timeout_seconds", minimum=1)
    stable = req_bool(execution.get("driver_guarantees_stable_idempotency"), "execution.driver_guarantees_stable_idempotency")
    command = execution.get("provider_command")
    if not isinstance(command, list) or not command:
        raise GateError("L1M04_PROVIDER_COMMAND", "execution.provider_command must be non-empty argv array")
    for index, part in enumerate(command):
        req_str(part, f"execution.provider_command[{index}]")
    if purpose == "PARITY_CANDIDATE" and not stable:
        raise GateError("L1M04_IDEMPOTENCY_UNPROVEN", "PARITY candidate retries require stable provider idempotency")
    if stable and not any("{idempotency_key}" in part for part in command):
        raise GateError("L1M04_IDEMPOTENCY_KEY_NOT_PASSED", "stable-idempotency driver must receive {idempotency_key}")

    coverage = req_map(plan.get("coverage_requirements"), "coverage_requirements")
    min_cases = req_int(coverage.get("min_cases"), "coverage_requirements.min_cases", minimum=1)
    min_genres = req_int(coverage.get("min_genres"), "coverage_requirements.min_genres", minimum=1)
    duration_buckets = coverage.get("required_duration_buckets")
    if not isinstance(duration_buckets, list) or not duration_buckets:
        raise GateError("L1M04_DURATION_BUCKETS", "required_duration_buckets must be non-empty array")
    required_buckets = {req_str(v, "required_duration_buckets[]") for v in duration_buckets}
    target_sets_raw = coverage.get("required_target_role_sets")
    if not isinstance(target_sets_raw, list) or not target_sets_raw:
        raise GateError("L1M04_TARGET_SETS", "required_target_role_sets must be non-empty array")
    required_target_sets: set[tuple[str, ...]] = set()
    for raw_set in target_sets_raw:
        if not isinstance(raw_set, list) or len(raw_set) < 2:
            raise GateError("L1M04_TARGET_SET_INVALID", "each required target set needs at least two roles")
        roles = tuple(sorted(req_str(v, "required_target_role_sets[]").lower() for v in raw_set))
        if any(role not in ALLOWED_ROLES for role in roles) or len(set(roles)) != len(roles):
            raise GateError("L1M04_TARGET_SET_INVALID", f"invalid target role set {roles}")
        required_target_sets.add(roles)

    cases = plan.get("cases")
    if not isinstance(cases, list) or len(cases) < min_cases:
        raise GateError("L1M04_CASE_COVERAGE", f"at least {min_cases} cases required")
    seen_ids: set[str] = set()
    genres: set[str] = set()
    buckets: set[str] = set()
    observed_target_sets: set[tuple[str, ...]] = set()
    normalized_cases: list[dict[str, Any]] = []
    for index, raw in enumerate(cases):
        case = req_map(raw, f"cases[{index}]")
        case_id = req_str(case.get("case_id"), f"cases[{index}].case_id")
        if case_id in seen_ids:
            raise GateError("L1M04_CASE_DUPLICATE", f"duplicate case_id {case_id}")
        seen_ids.add(case_id)
        genre = req_str(case.get("genre"), f"cases[{index}].genre").lower()
        duration_bucket = req_str(case.get("duration_bucket"), f"cases[{index}].duration_bucket").lower()
        genres.add(genre)
        buckets.add(duration_bucket)
        roles_raw = case.get("target_roles")
        if not isinstance(roles_raw, list) or len(roles_raw) < 2:
            raise GateError("L1M04_CASE_ROLES", f"case {case_id} target_roles requires at least two")
        roles = tuple(sorted(req_str(v, f"cases[{index}].target_roles[]").lower() for v in roles_raw))
        if len(set(roles)) != len(roles) or any(role not in ALLOWED_ROLES for role in roles):
            raise GateError("L1M04_CASE_ROLES", f"case {case_id} has invalid/duplicate target role")
        observed_target_sets.add(roles)
        fixture_path = safe_path(root, case.get("fixture_manifest"), f"cases[{index}].fixture_manifest")
        project_run_path = safe_path(root, case.get("project_run_manifest"), f"cases[{index}].project_run_manifest")
        reference_run_path = safe_path(root, case.get("reference_run_manifest"), f"cases[{index}].reference_run_manifest")
        normalized_cases.append({
            "case_id": case_id, "genre": genre, "duration_bucket": duration_bucket,
            "target_roles": list(roles), "fixture_path": fixture_path,
            "project_run_path": project_run_path, "reference_run_path": reference_run_path,
        })
    if len(genres) < min_genres:
        raise GateError("L1M04_GENRE_COVERAGE", f"need {min_genres} genres, got {len(genres)}")
    if purpose == "PARITY_CANDIDATE":
        if len(normalized_cases) < PARITY_MIN_CASES:
            raise GateError("L1M04_PARITY_CASE_FLOOR", f"PARITY candidate requires at least {PARITY_MIN_CASES} real cases")
        if len(genres) < PARITY_MIN_GENRES:
            raise GateError("L1M04_PARITY_GENRE_FLOOR", f"PARITY candidate requires at least {PARITY_MIN_GENRES} genres")
        parity_missing_buckets = PARITY_REQUIRED_DURATION_BUCKETS - buckets
        if parity_missing_buckets:
            raise GateError("L1M04_PARITY_DURATION_FLOOR", f"PARITY candidate missing duration buckets {sorted(parity_missing_buckets)}")
        if PARITY_CORE_TARGET_SET not in observed_target_sets:
            raise GateError("L1M04_PARITY_CORE_TARGET_FLOOR", "PARITY candidate requires vocals/drums/bass/other case")
    missing_buckets = required_buckets - buckets
    if missing_buckets:
        raise GateError("L1M04_DURATION_COVERAGE", f"missing duration buckets {sorted(missing_buckets)}")
    missing_target_sets = required_target_sets - observed_target_sets
    if missing_target_sets:
        raise GateError("L1M04_TARGET_COVERAGE", f"missing target role sets {sorted(missing_target_sets)}")

    policy = req_map(plan.get("acceptance_policy"), "acceptance_policy")
    req_str(policy.get("policy_id"), "acceptance_policy.policy_id")
    req_num(policy.get("max_case_failure_rate"), "acceptance_policy.max_case_failure_rate", minimum=0)
    req_num(policy.get("max_retry_fraction"), "acceptance_policy.max_retry_fraction", minimum=0)
    req_num(policy.get("max_mean_wall_time_ratio_vs_reference"), "acceptance_policy.max_mean_wall_time_ratio_vs_reference", minimum=0)
    req_num(policy.get("min_mean_objective_si_sdr_delta_db"), "acceptance_policy.min_mean_objective_si_sdr_delta_db")
    req_num(policy.get("min_mean_listening_delta"), "acceptance_policy.min_mean_listening_delta")
    req_num(policy.get("min_worst_role_overall_usability_delta"), "acceptance_policy.min_worst_role_overall_usability_delta")
    min_reviewers = req_int(policy.get("min_reviewers_per_system_per_role"), "acceptance_policy.min_reviewers_per_system_per_role", minimum=1)
    minimum_objective_cases = req_int(policy.get("minimum_objective_cases"), "acceptance_policy.minimum_objective_cases", minimum=0)
    max_cost = policy.get("max_project_cost_per_audio_minute")
    if max_cost is not None:
        req_num(max_cost, "acceptance_policy.max_project_cost_per_audio_minute", minimum=0)
        req_str(policy.get("cost_currency"), "acceptance_policy.cost_currency")

    return {
        "batch_id": batch_id, "purpose": purpose, "max_attempts": max_attempts,
        "timeout_seconds": timeout_seconds, "command": list(command), "cases": normalized_cases,
        "policy": dict(policy), "min_reviewers": min_reviewers, "minimum_objective_cases": minimum_objective_cases,
        "credential_env_names": list(credentials),
        "legal_gate": {
            "commercial_approval_basis_id": legal["commercial_approval_basis_id"],
            "privacy_retention_approval_id": legal["privacy_retention_approval_id"],
            "reference_comparison_rights_id": legal["reference_comparison_rights_id"],
            "provider_idempotency_contract_id": legal["provider_idempotency_contract_id"],
        },
    }


def validate_fixture_for_batch(
    evaluator: Path, root: Path, case: Mapping[str, Any], purpose: str, timeout: float
) -> Mapping[str, Any]:
    fixture_path = Path(case["fixture_path"])
    parsed = evaluator_call(
        evaluator,
        ["validate-fixture", "--fixture", str(fixture_path), "--root", str(root), "--purpose", purpose],
        cwd=root, timeout=timeout,
    )
    fixture = req_map(load_json(fixture_path), "fixture")
    manifest_roles = fixture.get("requested_roles")
    normalized_roles = sorted(str(v).lower() for v in manifest_roles) if isinstance(manifest_roles, list) else []
    if normalized_roles != list(case["target_roles"]):
        raise GateError("L1M04_FIXTURE_ROLE_MISMATCH", f"case {case['case_id']} target_roles mismatch fixture")
    if purpose == "PARITY_CANDIDATE":
        if fixture.get("rights_status") != "VERIFIED":
            raise GateError("L1M04_RIGHTS_UNVERIFIED", f"case {case['case_id']} rights not VERIFIED")
        if fixture.get("real_recorded_music") is not True or fixture.get("synthetic") is not False:
            raise GateError("L1M04_REAL_AUDIO_REQUIRED", f"case {case['case_id']} must be real non-synthetic audio")
        if fixture.get("reference_service_submission_allowed") is not True:
            raise GateError("L1M04_REFERENCE_SUBMISSION_RIGHTS", f"case {case['case_id']} lacks reference-service submission rights")
    return parsed


def stable_idempotency_key(batch_id: str, case_id: str) -> str:
    return "l1m04-" + hashlib.sha256(f"{batch_id}:{case_id}".encode("utf-8")).hexdigest()[:32]


def command_for_case(template: Sequence[str], root: Path, case: Mapping[str, Any], batch_id: str) -> list[str]:
    values = {
        "root": str(root),
        "fixture": str(case["fixture_path"]),
        "project_run": str(case["project_run_path"]),
        "reference_run": str(case["reference_run_path"]),
        "case_id": str(case["case_id"]),
        "roles_csv": ",".join(case["target_roles"]),
        "idempotency_key": stable_idempotency_key(batch_id, str(case["case_id"])),
    }
    result: list[str] = []
    for part in template:
        try:
            result.append(part.format(**values))
        except KeyError as exc:
            raise GateError("L1M04_COMMAND_PLACEHOLDER", f"unknown command placeholder {exc}") from exc
    return result


def validate_system_identity(run_path: Path, *, expected: str) -> None:
    run = req_map(load_json(run_path), "run")
    provider = req_map(run.get("provider"), "run.provider")
    provider_id = req_str(provider.get("provider_id"), "run.provider.provider_id")
    provider_kind = req_str(provider.get("provider_kind"), "run.provider.provider_kind")
    if expected == "REFERENCE":
        if provider_id != "MOISES_CURRENT_IPHONE" or provider_kind != "REFERENCE_APP_CURRENT_IPHONE":
            raise GateError("L1M04_REFERENCE_IDENTITY_MISMATCH", "reference run must identify MOISES_CURRENT_IPHONE / REFERENCE_APP_CURRENT_IPHONE")
    elif expected == "PROJECT":
        if provider_id == "MOISES_CURRENT_IPHONE" or provider_kind == "REFERENCE_APP_CURRENT_IPHONE":
            raise GateError("L1M04_PROJECT_IDENTITY_INVALID", "project run cannot identify as reference system")
    else:
        raise GateError("L1M04_INTERNAL_EXPECTED_SYSTEM", f"unknown expected system {expected}")


def validate_run(evaluator: Path, root: Path, case: Mapping[str, Any], run_path: Path, timeout: float) -> None:
    evaluator_call(
        evaluator,
        ["validate-run", "--fixture", str(case["fixture_path"]), "--run", str(run_path), "--root", str(root)],
        cwd=root, timeout=timeout,
    )
