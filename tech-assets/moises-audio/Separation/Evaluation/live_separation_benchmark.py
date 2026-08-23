"""L1-E03 live separation benchmark gate.

This module executes the approved project separation driver against E02-cleared
real-audio fixtures and records privacy-safe, reproducible NON-PARITY evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

from evaluation_core import (
    EvaluationError,
    evaluate_run,
    load_json as evaluation_load_json,
    normalize_sha256,
    safe_relative_path,
    sha256_file,
    validate_fixture_manifest,
    validate_run_manifest,
)

SCHEMA_VERSION = 1
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
TOOL_VERSION = "L1-E03-v1"
EXIT_FAIL = 2
EXIT_EXTERNAL_INPUT_REQUIRED = 3
MODE_CLASSES = {"TWO_STEM", "CORE_FOUR_STEM", "CUSTOM_INSTRUMENT", "HIFI_ADVANCED"}
BASIC_CORE_ROLES = {"vocals", "drums", "bass", "other", "instrumental"}
ADVANCED_ROLES = {"guitar", "piano", "keys", "strings", "wind", "voice", "background_vocals", "percussion"}
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
ENV_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")

class BenchmarkError(ValueError):
    def __init__(self, code: str, message: str, *, exit_code: int = EXIT_FAIL):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message
        self.exit_code = exit_code

def err(code: str, message: str = "live benchmark validation failed", *, external: bool = False) -> BenchmarkError:
    return BenchmarkError(code, message, exit_code=EXIT_EXTERNAL_INPUT_REQUIRED if external else EXIT_FAIL)

def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise err("L1E03_SCHEMA_TYPE", f"{field} must be object")
    return value

def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise err("L1E03_SCHEMA_REQUIRED", f"{field} must be non-empty string")
    return value.strip()

def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise err("L1E03_SCHEMA_TYPE", f"{field} must be boolean")
    return value

def req_int(value: Any, field: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise err("L1E03_SCHEMA_INTEGER", f"{field} must be integer >= {minimum}")
    return value

def req_num(value: Any, field: str, minimum: float | None = None, maximum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise err("L1E03_SCHEMA_NUMBER", f"{field} must be finite number")
    number = float(value)
    if minimum is not None and number < minimum:
        raise err("L1E03_SCHEMA_RANGE", f"{field} below minimum")
    if maximum is not None and number > maximum:
        raise err("L1E03_SCHEMA_RANGE", f"{field} above maximum")
    return number

def strict_keys(value: Mapping[str, Any], allowed: set[str], field: str) -> None:
    unknown = sorted(set(value) - allowed)
    if unknown:
        raise err("L1E03_SCHEMA_UNKNOWN_FIELD", f"{field} has unknown fields: {','.join(unknown)}")

def sha_text(value: Any, field: str) -> str:
    raw = req_str(value, field).lower()
    if raw.startswith("sha256:"):
        raw = raw[7:]
    if not SHA_RE.fullmatch(raw):
        raise err("L1E03_SHA256_INVALID", f"{field} must be SHA-256")
    return raw

def canonical_sha(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    return hashlib.sha256(raw).hexdigest()

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def safe_path(root: Path, raw: Any, field: str) -> Path:
    text = req_str(raw, field)
    rel = Path(text)
    if rel.is_absolute() or ".." in rel.parts:
        raise err("L1E03_PATH_UNSAFE", f"{field} must be safe relative path")
    base = root.resolve()
    candidate = (base / rel).resolve()
    try:
        candidate.relative_to(base)
    except ValueError as exc:
        raise err("L1E03_PATH_OUTSIDE_ROOT", f"{field} escapes root") from exc
    cur = base
    for part in rel.parts:
        cur /= part
        if cur.is_symlink():
            raise err("L1E03_PATH_SYMLINK", f"{field} may not traverse symlink")
    return candidate

def atomic_dump(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name("." + path.name + ".tmp")
    try:
        with temp.open("w", encoding="utf-8") as handle:
            handle.write(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    except OSError as exc:
        try:
            temp.unlink(missing_ok=True)
        except OSError:
            pass
        raise err("L1E03_WRITE_FAILED", "cannot atomically persist benchmark evidence") from exc

def load_json(path: Path, field: str) -> Mapping[str, Any]:
    try:
        return req_map(json.loads(path.read_text(encoding="utf-8")), field)
    except BenchmarkError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise err("L1E03_JSON_INVALID", f"cannot read {field}") from exc

def validate_e01(evidence: Mapping[str, Any]) -> dict[str, Any]:
    if evidence.get("schema_version") != 1 or evidence.get("evidence_kind") != "COMMERCIAL_ROUTE_APPROVAL":
        raise err("L1E03_E01_SCHEMA", "E01 evidence identity invalid")
    if evidence.get("evidence_state") != EVIDENCE_STATE or evidence.get("parity_claim") != "NONE":
        raise err("L1E03_E01_EVIDENCE_STATE", "E01 must remain NON-PARITY")
    if evidence.get("result") != "READY_FOR_LIVE_PROVIDER_GATE":
        raise err("L1E03_E01_NOT_READY", "E01 live route is not approved", external=True)
    provider = req_map(evidence.get("provider"), "e01.provider")
    provider_id = req_str(provider.get("provider_id"), "e01.provider.provider_id")
    models_raw = provider.get("models")
    if not isinstance(models_raw, list) or not models_raw:
        raise err("L1E03_E01_MODELS_MISSING", "E01 approved model catalog missing")
    models: dict[tuple[str, str, str], set[str]] = {}
    for i, raw in enumerate(models_raw):
        model = req_map(raw, f"e01.provider.models[{i}]")
        name = req_str(model.get("model_name"), "model_name")
        version = req_str(model.get("model_version"), "model_version")
        quality = req_str(model.get("quality_profile"), "quality_profile")
        roles_raw = model.get("canonical_roles")
        if not isinstance(roles_raw, list) or not roles_raw:
            raise err("L1E03_E01_MODEL_ROLES", "approved model roles missing")
        roles = {req_str(v, "canonical_roles[]").lower() for v in roles_raw}
        key = (name, version, quality)
        if key in models:
            raise err("L1E03_E01_MODEL_DUPLICATE", "duplicate approved model tuple")
        models[key] = roles
    preflight = req_map(evidence.get("credential_preflight"), "e01.credential_preflight")
    names = preflight.get("environment_names")
    if not isinstance(names, list) or not names:
        raise err("L1E03_E01_CREDENTIAL_ENV", "credential env list missing")
    env_names = []
    for raw in names:
        name = req_str(raw, "environment_names[]")
        if not ENV_RE.fullmatch(name):
            raise err("L1E03_E01_CREDENTIAL_ENV", "unsafe credential env name")
        env_names.append(name)
    if preflight.get("all_present") is not True or preflight.get("server_side_only") is not True:
        raise err("L1E03_E01_CREDENTIAL_PREFLIGHT", "E01 credential preflight not complete", external=True)
    if preflight.get("values_persisted") is not False or preflight.get("client_distribution_prohibited") is not True:
        raise err("L1E03_E01_SECRET_POLICY", "E01 secret policy invalid")
    if preflight.get("repository_exact_secret_scan") != "PASS":
        raise err("L1E03_E01_SECRET_SCAN", "E01 exact-secret repository scan must PASS")
    approval_id = sha_text(evidence.get("approval_manifest_identity_sha256"), "e01.approval_manifest_identity_sha256")
    return {"provider_id": provider_id, "models": models, "credential_env_names": sorted(set(env_names)), "approval_identity_sha256": approval_id}

def validate_e02(evidence: Mapping[str, Any]) -> dict[str, Any]:
    if evidence.get("schema_version") != 1 or evidence.get("evidence_kind") != "RIGHTS_CLEARED_REAL_AUDIO_INTAKE":
        raise err("L1E03_E02_SCHEMA", "E02 evidence identity invalid")
    if evidence.get("evidence_state") != EVIDENCE_STATE or evidence.get("parity_state") != "NON_PARITY_EVIDENCE_ONLY":
        raise err("L1E03_E02_EVIDENCE_STATE", "E02 must remain NON-PARITY")
    if evidence.get("intake_state") != "READY_FOR_HQ_LIVE_AUDIO_GATE":
        raise err("L1E03_E02_NOT_READY", "E02 rights-cleared intake is not ready", external=True)
    a19_lock = sha_text(evidence.get("a19_corpus_lock_sha256"), "e02.a19_corpus_lock_sha256")
    e02_lock = sha_text(evidence.get("e02_rights_intake_lock_sha256"), "e02.e02_rights_intake_lock_sha256")
    rows = evidence.get("fixtures")
    if not isinstance(rows, list) or not rows:
        raise err("L1E03_E02_FIXTURES_MISSING", "E02 fixture evidence missing")
    fixtures: dict[str, dict[str, Any]] = {}
    for i, raw in enumerate(rows):
        row = req_map(raw, f"e02.fixtures[{i}]")
        fid = req_str(row.get("fixture_id"), "fixture_id")
        if fid in fixtures:
            raise err("L1E03_E02_FIXTURE_DUPLICATE", "duplicate E02 fixture")
        group = req_str(row.get("group"), "group")
        if group not in {"G1", "G2"}:
            raise err("L1E03_E02_GROUP", "E02 group must be G1/G2")
        fixtures[fid] = {
            "group": group,
            "manifest_sha256": sha_text(row.get("manifest_sha256"), "manifest_sha256"),
            "mixture_sha256": sha_text(row.get("mixture_sha256"), "mixture_sha256"),
        }
    return {"a19_lock": a19_lock, "e02_lock": e02_lock, "fixtures": fixtures}

def validate_plan(plan: Mapping[str, Any], root: Path, e01: Mapping[str, Any], e02: Mapping[str, Any]) -> dict[str, Any]:
    strict_keys(plan, {"schema_version","evidence_state","benchmark_id","execution","requirements","modes","cases"}, "plan")
    if plan.get("schema_version") != SCHEMA_VERSION:
        raise err("L1E03_PLAN_SCHEMA", "unsupported plan schema")
    if plan.get("evidence_state") != EVIDENCE_STATE:
        raise err("L1E03_PLAN_EVIDENCE_STATE", "plan must be NON-PARITY")
    benchmark_id = req_str(plan.get("benchmark_id"), "benchmark_id")
    if not SAFE_ID.fullmatch(benchmark_id):
        raise err("L1E03_ID_INVALID", "benchmark_id invalid")

    execution = req_map(plan.get("execution"), "execution")
    strict_keys(execution, {"provider_command","timeout_seconds","max_attempts_per_run","driver_guarantees_stable_idempotency"}, "execution")
    command = execution.get("provider_command")
    if not isinstance(command, list) or not command:
        raise err("L1E03_PROVIDER_COMMAND", "provider_command must be non-empty argv")
    command = [req_str(v, "provider_command[]") for v in command]
    if not req_bool(execution.get("driver_guarantees_stable_idempotency"), "driver_guarantees_stable_idempotency"):
        raise err("L1E03_IDEMPOTENCY_UNPROVEN", "live retries require stable provider idempotency")
    if not any("{idempotency_key}" in part for part in command):
        raise err("L1E03_IDEMPOTENCY_NOT_PASSED", "provider command must receive idempotency key")
    timeout = req_num(execution.get("timeout_seconds"), "timeout_seconds", 1)
    max_attempts = req_int(execution.get("max_attempts_per_run"), "max_attempts_per_run", 1)

    requirements = req_map(plan.get("requirements"), "requirements")
    strict_keys(requirements, {
        "minimum_successful_runs_per_mode","minimum_g1_objective_runs","max_final_failure_fraction",
        "max_retry_fraction","require_two_stem","require_core_four_stem","require_custom_instrument",
        "hifi_required_by_reference"
    }, "requirements")
    min_success = req_int(requirements.get("minimum_successful_runs_per_mode"), "minimum_successful_runs_per_mode", 2)
    min_g1 = req_int(requirements.get("minimum_g1_objective_runs"), "minimum_g1_objective_runs", 1)
    max_fail = req_num(requirements.get("max_final_failure_fraction"), "max_final_failure_fraction", 0, 1)
    max_retry = req_num(requirements.get("max_retry_fraction"), "max_retry_fraction", 0, 1)
    required_classes = set()
    for field, klass in (
        ("require_two_stem","TWO_STEM"),
        ("require_core_four_stem","CORE_FOUR_STEM"),
        ("require_custom_instrument","CUSTOM_INSTRUMENT"),
        ("hifi_required_by_reference","HIFI_ADVANCED"),
    ):
        if req_bool(requirements.get(field), field):
            required_classes.add(klass)

    modes_raw = plan.get("modes")
    if not isinstance(modes_raw, list) or not modes_raw:
        raise err("L1E03_MODES_EMPTY", "modes required")
    modes: dict[str, dict[str, Any]] = {}
    classes_present = set()
    for i, raw in enumerate(modes_raw):
        mode = req_map(raw, f"modes[{i}]")
        strict_keys(mode, {"mode_id","mode_class","model_name","model_version","quality_profile","target_roles","required"}, f"modes[{i}]")
        mode_id = req_str(mode.get("mode_id"), "mode_id")
        if not SAFE_ID.fullmatch(mode_id) or mode_id in modes:
            raise err("L1E03_MODE_ID", "invalid/duplicate mode_id")
        klass = req_str(mode.get("mode_class"), "mode_class").upper()
        if klass not in MODE_CLASSES:
            raise err("L1E03_MODE_CLASS", f"unsupported mode class {klass}")
        roles_raw = mode.get("target_roles")
        if not isinstance(roles_raw, list) or len(roles_raw) < 2:
            raise err("L1E03_MODE_ROLES", "mode requires >=2 roles")
        roles = sorted({req_str(v, "target_roles[]").lower() for v in roles_raw})
        if len(roles) != len(roles_raw):
            raise err("L1E03_MODE_ROLES", "duplicate mode role")
        if klass == "TWO_STEM" and set(roles) != {"vocals","instrumental"}:
            raise err("L1E03_TWO_STEM_ROLES", "2-stem mode must be vocals/instrumental")
        if klass == "CORE_FOUR_STEM" and set(roles) != {"vocals","drums","bass","other"}:
            raise err("L1E03_FOUR_STEM_ROLES", "core 4-stem mode must be vocals/drums/bass/other")
        if klass == "CUSTOM_INSTRUMENT" and not (set(roles) & ADVANCED_ROLES):
            raise err("L1E03_CUSTOM_NOT_ADDITIONAL", "custom mode must include an additional instrument role")
        name = req_str(mode.get("model_name"), "model_name")
        version = req_str(mode.get("model_version"), "model_version")
        quality = req_str(mode.get("quality_profile"), "quality_profile")
        model_key = (name, version, quality)
        approved_roles = e01["models"].get(model_key)
        if approved_roles is None:
            raise err("L1E03_MODEL_NOT_E01_APPROVED", f"mode {mode_id} model/version/quality absent from E01")
        if not set(roles) <= approved_roles:
            raise err("L1E03_MODEL_ROLE_NOT_APPROVED", f"mode {mode_id} roles exceed E01 capability snapshot")
        required = req_bool(mode.get("required"), "required")
        modes[mode_id] = {"mode_id":mode_id,"mode_class":klass,"model_name":name,"model_version":version,"quality_profile":quality,"target_roles":roles,"required":required}
        classes_present.add(klass)
    if required_classes - classes_present:
        raise err("L1E03_REQUIRED_MODE_CLASS_MISSING", f"missing required mode classes {sorted(required_classes-classes_present)}")
    for klass in required_classes:
        if not any(m["mode_class"] == klass and m["required"] for m in modes.values()):
            raise err("L1E03_REQUIRED_MODE_NOT_MARKED", f"required {klass} mode must be marked required")

    cases_raw = plan.get("cases")
    if not isinstance(cases_raw, list) or not cases_raw:
        raise err("L1E03_CASES_EMPTY", "cases required")
    cases = []
    seen_case_ids = set()
    observed_modes = set()
    objective_capacity = 0
    for i, raw in enumerate(cases_raw):
        case = req_map(raw, f"cases[{i}]")
        strict_keys(case, {"case_id","fixture_manifest","mode_id","repeat_count","run_manifest_template"}, f"cases[{i}]")
        case_id = req_str(case.get("case_id"), "case_id")
        if not SAFE_ID.fullmatch(case_id) or case_id in seen_case_ids:
            raise err("L1E03_CASE_ID", "invalid/duplicate case_id")
        seen_case_ids.add(case_id)
        mode_id = req_str(case.get("mode_id"), "mode_id")
        if mode_id not in modes:
            raise err("L1E03_CASE_MODE_UNKNOWN", "case mode_id unknown")
        repeat_count = req_int(case.get("repeat_count"), "repeat_count", 1)
        fixture_path = safe_path(root, case.get("fixture_manifest"), "fixture_manifest")
        if not fixture_path.is_file():
            raise err("L1E03_FIXTURE_MISSING", f"fixture missing for {case_id}", external=True)
        fixture = req_map(evaluation_load_json(fixture_path), "fixture")
        try:
            summary = validate_fixture_manifest(fixture, root, purpose="PARITY_CANDIDATE", verify_hashes=True)
        except EvaluationError as exc:
            raise err("L1E03_FIXTURE_INVALID", f"{case_id}: {exc.code}") from exc
        fid = req_str(summary.get("fixture_id"), "fixture_id")
        e02_row = e02["fixtures"].get(fid)
        if e02_row is None:
            raise err("L1E03_FIXTURE_NOT_E02_CLEARED", f"{fid} absent from E02")
        physical_manifest_sha = sha256_file(fixture_path)
        if physical_manifest_sha != e02_row["manifest_sha256"]:
            raise err("L1E03_FIXTURE_E02_SHA_MISMATCH", f"{fid} manifest changed after E02")
        fixture_roles = sorted(str(v).lower() for v in summary["requested_roles"])
        if fixture_roles != modes[mode_id]["target_roles"]:
            raise err("L1E03_CASE_MODE_ROLE_MISMATCH", f"{case_id} fixture roles do not match mode")
        template = req_str(case.get("run_manifest_template"), "run_manifest_template")
        if "{repeat}" not in template:
            raise err("L1E03_RUN_TEMPLATE_REPEAT_REQUIRED", "run_manifest_template must contain {repeat}")
        for repeat in range(1, repeat_count + 1):
            rendered = template.format(repeat=repeat)
            safe_path(root, rendered, "run_manifest_template")
        observed_modes.add(mode_id)
        if e02_row["group"] == "G1":
            objective_capacity += repeat_count
        cases.append({
            "case_id":case_id,"fixture_path":fixture_path,"fixture_id":fid,"fixture_group":e02_row["group"],
            "mode_id":mode_id,"repeat_count":repeat_count,"run_manifest_template":template
        })
    missing_modes = {mid for mid,m in modes.items() if m["required"]} - observed_modes
    if missing_modes:
        raise err("L1E03_REQUIRED_MODE_NO_CASE", f"required modes missing cases: {sorted(missing_modes)}")
    for mid, mode in modes.items():
        if mode["required"]:
            planned = sum(c["repeat_count"] for c in cases if c["mode_id"] == mid)
            if planned < min_success:
                raise err("L1E03_REPEAT_PLAN_INSUFFICIENT", f"{mid} has only {planned} planned runs")
    if objective_capacity < min_g1:
        raise err("L1E03_G1_OBJECTIVE_PLAN_INSUFFICIENT", "not enough G1 runs for objective metric floor")
    return {
        "benchmark_id":benchmark_id,"command":command,"timeout_seconds":timeout,"max_attempts":max_attempts,
        "min_success":min_success,"min_g1":min_g1,"max_fail":max_fail,"max_retry":max_retry,
        "required_classes":sorted(required_classes),"modes":modes,"cases":cases
    }

def stable_idempotency_key(benchmark_id: str, logical_run_id: str) -> str:
    return "l1e03-" + hashlib.sha256(f"{benchmark_id}:{logical_run_id}".encode()).hexdigest()[:40]

def parse_driver_code(stdout: str, stderr: str, exit_code: int) -> str:
    for payload in (stderr, stdout):
        for line in reversed(payload.splitlines()):
            try:
                value = json.loads(line.strip())
            except (json.JSONDecodeError, AttributeError):
                continue
            if isinstance(value, Mapping):
                for key in ("stable_error_code","code"):
                    raw = value.get(key)
                    if isinstance(raw, str) and raw.strip():
                        return raw.strip()[:128]
    return f"DRIVER_EXIT_{exit_code}"

def command_for_run(template: Sequence[str], root: Path, case: Mapping[str, Any], mode: Mapping[str, Any], run_path: Path, repeat: int, benchmark_id: str) -> list[str]:
    logical = f"{case['case_id']}:r{repeat:03d}"
    values = {
        "root":str(root),"fixture":str(case["fixture_path"]),"project_run":str(run_path),
        "case_id":str(case["case_id"]),"logical_run_id":logical,"repeat":str(repeat),
        "mode_id":str(mode["mode_id"]),"roles_csv":",".join(mode["target_roles"]),
        "model_name":str(mode["model_name"]),"model_version":str(mode["model_version"]),
        "quality_profile":str(mode["quality_profile"]),
        "idempotency_key":stable_idempotency_key(benchmark_id, logical),
    }
    out = []
    for part in template:
        try:
            out.append(part.format(**values))
        except KeyError as exc:
            raise err("L1E03_COMMAND_PLACEHOLDER", f"unknown command placeholder {exc}") from exc
    return out

def session_identity(plan: Mapping[str, Any], e01_hash: str, e02_hash: str, normalized: Mapping[str, Any]) -> str:
    semantic = {
        "plan_sha256": canonical_sha(plan),
        "e01_evidence_sha256": e01_hash,
        "e02_evidence_sha256": e02_hash,
        "e01_approval_identity_sha256": normalized["e01"]["approval_identity_sha256"],
        "e02_rights_intake_lock_sha256": normalized["e02"]["e02_lock"],
    }
    return canonical_sha(semantic)

def init_or_load_session(path: Path, identity: str, logical_runs: Sequence[str], preexisting_paths: Sequence[Path]) -> dict[str, Any]:
    if path.is_file():
        session = load_json(path, "e03_session")
        if session.get("schema_version") != 1 or session.get("identity_sha256") != identity:
            raise err("L1E03_SESSION_IDENTITY_MISMATCH", "existing session belongs to different benchmark identity")
        runs = req_map(session.get("runs"), "session.runs")
        if set(runs) != set(logical_runs):
            raise err("L1E03_SESSION_RUN_SET_MISMATCH", "session logical run set changed")
        return dict(session)
    if preexisting_paths:
        raise err("L1E03_PREEXISTING_RUN_UNBOUND", "run manifest exists without matching E03 session")
    session = {
        "schema_version":1,"identity_sha256":identity,"created_at":now_iso(),
        "runs":{logical:{"status":"PENDING","attempts":[],"run_manifest_sha256":None} for logical in logical_runs}
    }
    atomic_dump(path, session)
    return session

def validate_project_run(run: Mapping[str, Any], fixture: Mapping[str, Any], root: Path, e01: Mapping[str, Any], mode: Mapping[str, Any]) -> dict[str, Any]:
    try:
        validate_run_manifest(run, fixture, root, verify_hashes=True)
    except EvaluationError as exc:
        raise err("L1E03_RUN_INVALID", exc.code) from exc
    provider = req_map(run.get("provider"), "run.provider")
    if provider.get("provider_id") != e01["provider_id"]:
        raise err("L1E03_RUN_PROVIDER_MISMATCH", "run provider differs from E01 approved route")
    if provider.get("model_name") != mode["model_name"] or provider.get("model_version") != mode["model_version"]:
        raise err("L1E03_RUN_MODEL_MISMATCH", "run model/version differs from approved mode")
    topology = req_str(provider.get("execution_topology"), "execution_topology").lower()
    if topology != "server":
        raise err("L1E03_RUN_TOPOLOGY", "E03 production provider must execute server-side")
    results = run.get("results")
    artifacts = []
    for raw in results:
        result = req_map(raw, "run.result")
        role = req_str(result.get("role"), "result.role").lower()
        artifact_raw = result.get("artifact_path")
        if not artifact_raw:
            raise err("L1E03_LOCAL_ARTIFACT_REQUIRED", "E03 requires project-controlled local output")
        artifact = safe_relative_path(root, artifact_raw, "artifact_path")
        if not artifact.is_file():
            raise err("L1E03_LOCAL_ARTIFACT_MISSING", "local result artifact missing")
        declared = normalize_sha256(result.get("sha256"), "result.sha256")
        actual = sha256_file(artifact)
        if actual != declared:
            raise err("L1E03_ARTIFACT_SHA_MISMATCH", "local result changed")
        artifacts.append({"role":role,"sha256":actual,"byte_count":artifact.stat().st_size})
    if sorted(a["role"] for a in artifacts) != mode["target_roles"]:
        raise err("L1E03_ARTIFACT_ROLE_SET", "artifact role set differs from mode")
    return {"artifacts":sorted(artifacts,key=lambda x:x["role"])}

def recover_started(session: dict[str, Any], logical: str, run_path: Path, validator) -> bool:
    entry = req_map(session["runs"][logical], f"session.runs.{logical}")
    attempts = entry.get("attempts")
    if not isinstance(attempts, list) or not attempts:
        return False
    last = attempts[-1]
    if not isinstance(last, Mapping) or last.get("status") != "STARTED":
        return False
    if run_path.is_file():
        validator()
        actual = sha256_file(run_path)
        last["status"] = "RECOVERED_OUTPUT"
        last["finished_at"] = now_iso()
        entry["status"] = "PASS"
        entry["run_manifest_sha256"] = actual
        return True
    last["status"] = "INTERRUPTED"
    last["finished_at"] = now_iso()
    entry["status"] = "PENDING"
    return False

def run_live_benchmark(*, plan: Mapping[str, Any], root: Path | str, e01_evidence: Mapping[str, Any], e02_evidence: Mapping[str, Any], output_dir: Path | str, env: Mapping[str,str] | None = None, plan_file_sha256: str | None = None, e01_file_sha256: str | None = None, e02_file_sha256: str | None = None) -> dict[str, Any]:
    root = Path(root).resolve()
    output_dir = Path(output_dir).resolve()
    if not root.is_dir():
        raise err("L1E03_ROOT_INVALID", "benchmark root missing", external=True)
    e01 = validate_e01(e01_evidence)
    e02 = validate_e02(e02_evidence)
    source_env = os.environ if env is None else env
    missing_env = [name for name in e01["credential_env_names"] if not source_env.get(name)]
    if missing_env:
        raise err("L1E03_RUNTIME_CREDENTIAL_MISSING", "E01-approved runtime credential not present", external=True)
    normalized = validate_plan(plan, root, e01, e02)
    normalized["e01"], normalized["e02"] = e01, e02

    plan_hash = plan_file_sha256 or canonical_sha(plan)
    e01_hash = e01_file_sha256 or canonical_sha(e01_evidence)
    e02_hash = e02_file_sha256 or canonical_sha(e02_evidence)
    for value, field in ((plan_hash,"plan_file_sha256"),(e01_hash,"e01_file_sha256"),(e02_hash,"e02_file_sha256")):
        sha_text(value, field)

    expanded = []
    for case in normalized["cases"]:
        mode = normalized["modes"][case["mode_id"]]
        for repeat in range(1, case["repeat_count"] + 1):
            logical = f"{case['case_id']}:r{repeat:03d}"
            run_rel = case["run_manifest_template"].format(repeat=repeat)
            run_path = safe_path(root, run_rel, "run_manifest")
            expanded.append((logical,case,mode,repeat,run_path))
    session_path = output_dir / "e03-session.json"
    preexisting = [item[4] for item in expanded if item[4].is_file()]
    identity = session_identity(plan, e01_hash, e02_hash, normalized)
    session = init_or_load_session(session_path, identity, [item[0] for item in expanded], preexisting)

    measurements = []
    for logical, case, mode, repeat, run_path in expanded:
        fixture = req_map(evaluation_load_json(case["fixture_path"]), "fixture")
        def validator() -> dict[str,Any]:
            run = req_map(evaluation_load_json(run_path), "run")
            validate_project_run(run, fixture, root, e01, mode)
            return run

        entry = session["runs"][logical]
        if entry.get("status") == "PASS":
            if not run_path.is_file():
                raise err("L1E03_BOUND_RUN_MISSING", f"{logical} bound run missing")
            actual = sha256_file(run_path)
            if actual != entry.get("run_manifest_sha256"):
                raise err("L1E03_BOUND_RUN_MUTATED", f"{logical} run manifest mutated")
            run = validator()
        else:
            recovered = recover_started(session, logical, run_path, validator)
            if recovered:
                atomic_dump(session_path, session)
                run = validator()
            else:
                atomic_dump(session_path, session)
                attempts = entry["attempts"]
                while entry.get("status") != "PASS" and len(attempts) < normalized["max_attempts"]:
                    attempt_no = len(attempts) + 1
                    attempt = {"attempt":attempt_no,"status":"STARTED","started_at":now_iso(),"wall_time_ms":None,"exit_code":None,"stable_error_code":None}
                    attempts.append(attempt)
                    atomic_dump(session_path, session)
                    argv = command_for_run(normalized["command"], root, case, mode, run_path, repeat, normalized["benchmark_id"])
                    started = time.monotonic()
                    try:
                        completed = subprocess.run(argv, cwd=str(root), capture_output=True, text=True, timeout=normalized["timeout_seconds"], check=False, env=dict(source_env))
                        wall_ms = (time.monotonic() - started) * 1000.0
                        attempt["exit_code"] = completed.returncode
                        attempt["wall_time_ms"] = round(wall_ms,3)
                        attempt["finished_at"] = now_iso()
                        if completed.returncode == 0 and run_path.is_file():
                            try:
                                run = validator()
                            except BenchmarkError as exc:
                                attempt["status"] = "FAIL"
                                attempt["stable_error_code"] = exc.code
                            else:
                                attempt["status"] = "PASS"
                                attempt["stable_error_code"] = None
                                entry["status"] = "PASS"
                                entry["run_manifest_sha256"] = sha256_file(run_path)
                        else:
                            attempt["status"] = "FAIL"
                            attempt["stable_error_code"] = parse_driver_code(completed.stdout, completed.stderr, completed.returncode)
                    except subprocess.TimeoutExpired:
                        wall_ms = (time.monotonic() - started) * 1000.0
                        attempt.update({"status":"TIMEOUT","wall_time_ms":round(wall_ms,3),"exit_code":124,"stable_error_code":"DRIVER_TIMEOUT","finished_at":now_iso()})
                    atomic_dump(session_path, session)
                if entry.get("status") != "PASS":
                    measurements.append({"logical_run_id":logical,"case_id":case["case_id"],"fixture_id":case["fixture_id"],"fixture_group":case["fixture_group"],"mode_id":mode["mode_id"],"mode_class":mode["mode_class"],"repeat":repeat,"success":False,"attempt_count":len(attempts),"retry_count":max(0,len(attempts)-1),"stable_error_code":attempts[-1].get("stable_error_code") if attempts else "L1E03_NO_ATTEMPT"})
                    continue
                run = validator()

        run_validation = validate_project_run(run, fixture, root, e01, mode)
        try:
            evaluated = evaluate_run(fixture, run, root, purpose="REGRESSION")
        except EvaluationError as exc:
            raise err("L1E03_EVALUATION_FAILED", exc.code) from exc
        attempts = entry["attempts"]
        provider_timing = req_map(run.get("timing_ms"), "run.timing_ms")
        cost = req_map(run.get("cost"), "run.cost")
        basis = req_str(cost.get("basis"), "run.cost.basis")
        cost_total = req_num(cost.get("total"), "run.cost.total", 0)
        currency = req_str(cost.get("currency"), "run.cost.currency").upper()
        objective = req_map(evaluated.get("objective_metrics"), "objective_metrics")
        if case["fixture_group"] == "G1" and not req_map(objective.get("per_stem"), "objective.per_stem"):
            raise err("L1E03_G1_OBJECTIVE_MISSING", f"{logical} lacks G1 objective metrics")
        measurements.append({
            "logical_run_id":logical,"case_id":case["case_id"],"fixture_id":case["fixture_id"],"fixture_group":case["fixture_group"],
            "mode_id":mode["mode_id"],"mode_class":mode["mode_class"],"repeat":repeat,"success":True,
            "attempt_count":len(attempts),"retry_count":max(0,len(attempts)-1),"stable_error_code":None,
            "run_manifest_sha256":sha256_file(run_path),
            "provider":{"provider_id":e01["provider_id"],"model_name":mode["model_name"],"model_version":mode["model_version"],"quality_profile":mode["quality_profile"]},
            "timing_ms":{k:req_num(provider_timing.get(k), f"timing_ms.{k}",0) for k in ("upload","queue","inference","download","total")},
            "orchestrator_attempt_wall_time_ms":round(sum(float(a.get("wall_time_ms") or 0) for a in attempts),3),
            "cost":{"currency":currency,"total":cost_total,"credits":cost.get("credits"),"basis_sha256":hashlib.sha256(("l1e03-cost-basis-v1\0"+basis).encode()).hexdigest()},
            "artifacts":run_validation["artifacts"],
            "objective_metrics":objective,
        })

    total = len(measurements)
    failures = sum(1 for r in measurements if not r["success"])
    retries = sum(1 for r in measurements if r["retry_count"] > 0)
    successful = [r for r in measurements if r["success"]]
    mode_summary = {}
    for mid, mode in normalized["modes"].items():
        rows = [r for r in measurements if r["mode_id"] == mid]
        ok = [r for r in rows if r["success"]]
        mode_summary[mid] = {
            "mode_class":mode["mode_class"],"required":mode["required"],"planned_runs":len(rows),"successful_runs":len(ok),
            "failed_runs":len(rows)-len(ok),"mean_provider_total_ms":round(sum(r["timing_ms"]["total"] for r in ok)/len(ok),3) if ok else None,
            "mean_orchestrator_attempt_wall_ms":round(sum(r["orchestrator_attempt_wall_time_ms"] for r in ok)/len(ok),3) if ok else None,
        }
    g1_success = [r for r in successful if r["fixture_group"] == "G1"]
    checks = {
        "required_mode_repetition":all(mode_summary[mid]["successful_runs"] >= normalized["min_success"] for mid,m in normalized["modes"].items() if m["required"]),
        "g1_objective_floor":len(g1_success) >= normalized["min_g1"],
        "final_failure_fraction":(failures/total if total else 1.0) <= normalized["max_fail"],
        "retry_fraction":(retries/total if total else 1.0) <= normalized["max_retry"],
        "all_success_artifacts_local_and_hashed":all(bool(r.get("artifacts")) for r in successful),
    }
    benchmark_state = "READY_FOR_HQ_E03_LIVE_REVIEW" if all(checks.values()) else "LIVE_BENCHMARK_FAILED"
    evidence_rows = sorted(measurements, key=lambda x:x["logical_run_id"])
    lock_payload = {
        "session_identity_sha256":identity,"plan_sha256":plan_hash,
        "e01_approval_identity_sha256":e01["approval_identity_sha256"],"e02_rights_intake_lock_sha256":e02["e02_lock"],
        "runs":[{"logical_run_id":r["logical_run_id"],"success":r["success"],"run_manifest_sha256":r.get("run_manifest_sha256"),"artifact_sha256_by_role":{a["role"]:a["sha256"] for a in r.get("artifacts",[])}} for r in evidence_rows],
        "acceptance_checks":checks,
    }
    report = {
        "schema_version":1,"tool_version":TOOL_VERSION,"evidence_kind":"LIVE_SEPARATION_BENCHMARK",
        "evidence_state":EVIDENCE_STATE,"benchmark_state":benchmark_state,"parity_claim":"NONE",
        "benchmark_id":normalized["benchmark_id"],
        "source_evidence":{
            "plan_sha256":plan_hash,"e01_evidence_sha256":e01_hash,"e02_evidence_sha256":e02_hash,
            "e01_approval_identity_sha256":e01["approval_identity_sha256"],
            "a19_corpus_lock_sha256":e02["a19_lock"],"e02_rights_intake_lock_sha256":e02["e02_lock"],
        },
        "requirements":{
            "minimum_successful_runs_per_mode":normalized["min_success"],"minimum_g1_objective_runs":normalized["min_g1"],
            "max_final_failure_fraction":normalized["max_fail"],"max_retry_fraction":normalized["max_retry"],
            "required_mode_classes":normalized["required_classes"],
        },
        "summary":{
            "logical_run_count":total,"successful_runs":len(successful),"failed_runs":failures,
            "runs_with_retry":retries,"final_failure_fraction":failures/total if total else 1.0,
            "retry_fraction":retries/total if total else 1.0,"g1_objective_run_count":len(g1_success),"modes":mode_summary,
        },
        "acceptance_checks":checks,"runs":evidence_rows,
        "privacy":{
            "raw_audio_emitted":False,"media_paths_emitted":False,"media_titles_emitted":False,
            "raw_rights_ids_emitted":False,"credential_values_emitted":False,"signed_urls_emitted":False,
            "cost_basis_text_emitted":False,
        },
        "e03_live_benchmark_lock_sha256":canonical_sha(lock_payload),
        "parity_reason":"E03 measures the approved project separator on E02-cleared real audio. Current-iPhone differential listening, recovery semantics, device evidence and HQ PARITY remain separate gates.",
    }
    atomic_dump(output_dir/"e03-live-separation-benchmark.json", report)
    return report

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lane 1 E03 live separation benchmark")
    parser.add_argument("--root", required=True)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--e01", required=True)
    parser.add_argument("--e02", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args(argv)
    try:
        plan_path = Path(args.plan)
        e01_path = Path(args.e01)
        e02_path = Path(args.e02)
        report = run_live_benchmark(
            plan=load_json(plan_path,"plan"), root=args.root,
            e01_evidence=load_json(e01_path,"e01"), e02_evidence=load_json(e02_path,"e02"),
            output_dir=args.output_dir,
            plan_file_sha256=sha256_file(plan_path), e01_file_sha256=sha256_file(e01_path), e02_file_sha256=sha256_file(e02_path),
        )
    except BenchmarkError as exc:
        print(json.dumps({"status":"FAIL","code":exc.code,"message":exc.message},sort_keys=True),file=sys.stderr)
        return exc.exit_code
    print(json.dumps({"status":"PASS" if report["benchmark_state"]=="READY_FOR_HQ_E03_LIVE_REVIEW" else "FAIL","benchmark_state":report["benchmark_state"],"lock":report["e03_live_benchmark_lock_sha256"]},sort_keys=True))
    return 0 if report["benchmark_state"]=="READY_FOR_HQ_E03_LIVE_REVIEW" else EXIT_FAIL

if __name__ == "__main__":
    raise SystemExit(main())
