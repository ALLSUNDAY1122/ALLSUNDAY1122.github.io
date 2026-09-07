"""L1-E08 Generic Runtime-Authority Live Gate.

Authority-neutral recovery/capacity evidence for hosted providers, licensed local SDKs,
and project-owned runtimes. Engineering/live-evidence gate only; never product PARITY.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-E08-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"

ROUTE_AUTHORITY = {
    "LICENSED_LOCAL_INFERENCE_SDK": "LOCAL_RUNTIME",
    "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER": "HOSTED_PROVIDER_ACCOUNT",
    "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE": "PROJECT_OWNED_RUNTIME",
}
REQUIRED_SCENARIOS = (
    "INPUT_INTERRUPTION",
    "CANCEL_PRE_START",
    "CANCEL_EXECUTING",
    "CANCEL_FINALIZING",
    "AMBIGUOUS_START_RETRY",
    "RELAUNCH",
    "OUTPUT_AVAILABILITY_LOSS",
    "CAPACITY_LIMIT",
    "LONG_TRACK",
    "STORAGE_PRESSURE",
)
CANCEL_SCENARIOS = {"CANCEL_PRE_START", "CANCEL_EXECUTING", "CANCEL_FINALIZING"}
SAFE_PROJECT_STATES = {"ready", "recoverable", "cancelled", "failed_closed"}
CAPACITY_STATUS = {"ADEQUATE", "INSUFFICIENT", "UNKNOWN"}
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")


class RuntimeAuthorityError(ValueError):
    def __init__(self, code: str, message: str = "runtime authority live gate validation failed"):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message


def fail(code: str, message: str = "runtime authority live gate validation failed") -> None:
    raise RuntimeAuthorityError(code, message)


def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        fail("L1E08_SCHEMA_TYPE", f"{field} must be object")
    return value


def req_list(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        fail("L1E08_SCHEMA_TYPE", f"{field} must be array")
    return value


def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail("L1E08_SCHEMA_REQUIRED", field)
    return value.strip()


def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        fail("L1E08_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def req_int(value: Any, field: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        fail("L1E08_SCHEMA_INTEGER", field)
    return value


def req_num(value: Any, field: str, minimum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        fail("L1E08_SCHEMA_NUMBER", field)
    out = float(value)
    if minimum is not None and out < minimum:
        fail("L1E08_SCHEMA_RANGE", field)
    return out


def normalize_sha(value: Any, field: str) -> str:
    raw = req_str(value, field).lower().removeprefix("sha256:")
    if not SHA_RE.fullmatch(raw):
        fail("L1E08_SHA_INVALID", field)
    return raw


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise RuntimeAuthorityError("L1E08_FILE_UNREADABLE", str(path)) from exc
    return digest.hexdigest()


def ensure_private_root(repo_root: Path, private_root: Path) -> tuple[Path, Path]:
    repo = repo_root.resolve()
    private = private_root.resolve()
    try:
        private.relative_to(repo)
    except ValueError:
        return repo, private
    fail("L1E08_PRIVATE_ROOT_INSIDE_REPOSITORY")


def safe_private_file(
    repo_root: Path, private_root: Path, raw_path: Any, expected_sha: Any, field: str
) -> str:
    repo, private = ensure_private_root(repo_root, private_root)
    rel = Path(req_str(raw_path, field))
    if rel.is_absolute() or ".." in rel.parts:
        fail("L1E08_PRIVATE_PATH_UNSAFE", field)
    cursor = private
    for part in rel.parts:
        cursor /= part
        if cursor.is_symlink():
            fail("L1E08_PRIVATE_PATH_SYMLINK", field)
    path = (private / rel).resolve()
    try:
        path.relative_to(private)
    except ValueError as exc:
        raise RuntimeAuthorityError("L1E08_PRIVATE_PATH_ESCAPE", field) from exc
    if not path.is_file():
        fail("L1E08_PRIVATE_FILE_MISSING", field)
    actual = sha256_file(path)
    if actual != normalize_sha(expected_sha, field + "_sha256"):
        fail("L1E08_PRIVATE_FILE_SHA_MISMATCH", field)
    return actual


def validate_e07(evidence: Mapping[str, Any], physical_sha256: Any) -> dict[str, Any]:
    if (
        evidence.get("schema_version") != 1
        or evidence.get("evidence_kind") != "PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE"
        or evidence.get("evidence_state") != EVIDENCE_STATE
        or evidence.get("parity_claim") != "NONE"
    ):
        fail("L1E08_E07_SCHEMA")
    state = req_str(evidence.get("conformance_state"), "e07.conformance_state")
    if state not in {
        "READY_FOR_HQ_E07_SUBSTITUTION_REVIEW",
        "CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE",
    }:
        fail("L1E08_E07_NOT_CONFORMANT")
    route_id = req_str(evidence.get("route_id"), "e07.route_id")
    route_kind = req_str(evidence.get("route_kind"), "e07.route_kind").upper()
    if route_kind not in ROUTE_AUTHORITY:
        fail("L1E08_E07_ROUTE_KIND")
    authority = req_map(evidence.get("capacity_authority"), "e07.capacity_authority")
    authority_kind = req_str(authority.get("kind"), "e07.capacity_authority.kind").upper()
    if authority_kind != ROUTE_AUTHORITY[route_kind]:
        fail("L1E08_E07_AUTHORITY_KIND_MISMATCH")
    provenance = normalize_sha(authority.get("provenance_sha256"), "e07.authority_provenance")
    runtime = req_map(evidence.get("runtime"), "e07.runtime")
    artifact = normalize_sha(runtime.get("artifact_sha256"), "e07.runtime.artifact_sha256")
    compatibility = req_map(evidence.get("compatibility"), "e07.compatibility")
    if compatibility.get("shared_app_contract_changed") is not False:
        fail("L1E08_SHARED_APP_CHANGE_FORBIDDEN")
    if compatibility.get("provider_neutral_publication_contract_preserved") is not True:
        fail("L1E08_PROVIDER_NEUTRAL_CONTRACT_NOT_PRESERVED")
    lock = normalize_sha(evidence.get("e07_substitution_lock_sha256"), "e07.lock")
    return {
        "physical_sha256": normalize_sha(physical_sha256, "e07_physical_sha256"),
        "route_id": route_id,
        "route_kind": route_kind,
        "authority_kind": authority_kind,
        "authority_provenance_sha256": provenance,
        "runtime_artifact_sha256": artifact,
        "substitution_lock_sha256": lock,
    }


def validate_plan(plan: Mapping[str, Any], e07: Mapping[str, Any]) -> dict[str, Any]:
    if (
        plan.get("schema_version") != 1
        or plan.get("evidence_state") != EVIDENCE_STATE
        or plan.get("parity_claim") != "NONE"
    ):
        fail("L1E08_PLAN_SCHEMA")
    gate_id = req_str(plan.get("gate_id"), "gate_id")
    if not SAFE_ID.fullmatch(gate_id):
        fail("L1E08_GATE_ID_INVALID")
    if req_str(plan.get("route_id"), "route_id") != e07["route_id"]:
        fail("L1E08_PLAN_ROUTE_MISMATCH")
    route_kind = req_str(plan.get("route_kind"), "route_kind").upper()
    if route_kind != e07["route_kind"]:
        fail("L1E08_PLAN_ROUTE_KIND_MISMATCH")
    scenarios = req_list(plan.get("scenarios"), "scenarios")
    normalized = [req_str(x, "scenario").upper() for x in scenarios]
    if len(normalized) != len(REQUIRED_SCENARIOS) or set(normalized) != set(REQUIRED_SCENARIOS):
        fail("L1E08_SCENARIO_SET_INVALID")
    policy = req_map(plan.get("policy"), "policy")
    degraded = req_num(policy.get("maximum_non_cancel_degraded_fraction"), "maximum_non_cancel_degraded_fraction", 0)
    if degraded > 1:
        fail("L1E08_SCHEMA_RANGE", "maximum_non_cancel_degraded_fraction")
    if policy.get("require_capacity_attestation") is not True:
        fail("L1E08_CAPACITY_ATTESTATION_REQUIRED")
    if policy.get("engineering_policy_not_reference_fact") is not True:
        fail("L1E08_POLICY_REFERENCE_FACT_PROHIBITED")
    return {"gate_id": gate_id, "route_kind": route_kind, "maximum_non_cancel_degraded_fraction": degraded}


def validate_result(
    result: Mapping[str, Any],
    expected_kind: str,
    *,
    e07: Mapping[str, Any],
    repo_root: Path,
    private_root: Path,
) -> dict[str, Any]:
    if result.get("schema_version") != 1 or result.get("evidence_state") != EVIDENCE_STATE:
        fail("L1E08_RESULT_SCHEMA")
    kind = req_str(result.get("scenario_kind"), "scenario_kind").upper()
    if kind != expected_kind:
        fail("L1E08_RESULT_KIND_MISMATCH")
    authority = req_map(result.get("authority"), "authority")
    authority_kind = req_str(authority.get("kind"), "authority.kind").upper()
    if authority_kind != e07["authority_kind"]:
        fail("L1E08_AUTHORITY_KIND_MISMATCH")
    authority_sha = safe_private_file(
        repo_root,
        private_root,
        authority.get("provenance_path"),
        authority.get("provenance_sha256"),
        "authority_provenance",
    )
    if authority_sha != e07["authority_provenance_sha256"]:
        fail("L1E08_AUTHORITY_PROVENANCE_MISMATCH")
    if authority_kind != "HOSTED_PROVIDER_ACCOUNT":
        forbidden = {
            "provider_account_id",
            "provider_account_path",
            "provider_account_sha256",
            "provider_account_provenance_sha256",
        }
        if forbidden & set(authority):
            fail("L1E08_FAKE_PROVIDER_ACCOUNT_FORBIDDEN")

    fault = req_map(result.get("fault_injection"), "fault_injection")
    fault_sha = safe_private_file(
        repo_root,
        private_root,
        fault.get("path"),
        fault.get("sha256"),
        "fault_injection",
    )

    project_state = req_str(result.get("project_state_after"), "project_state_after")
    if project_state not in SAFE_PROJECT_STATES:
        fail("L1E08_PROJECT_STATE_INVALID")
    corrupted = req_bool(result.get("project_corrupted"), "project_corrupted")
    partial = req_bool(result.get("partial_result_published"), "partial_result_published")
    start_requests = req_int(result.get("work_start_request_count"), "work_start_request_count")
    executions = req_int(result.get("distinct_execution_count"), "distinct_execution_count")
    cancel_requests = req_int(result.get("upstream_cancel_request_count"), "upstream_cancel_request_count")
    billable = req_int(result.get("billable_execution_count"), "billable_execution_count")
    automatic_reposts = req_int(result.get("automatic_start_repost_count"), "automatic_start_repost_count")
    duplicate = req_bool(result.get("duplicate_execution_detected"), "duplicate_execution_detected")
    reconciliation = req_bool(result.get("reconciliation_performed"), "reconciliation_performed")
    logical_cancelled = req_bool(result.get("logical_cancelled"), "logical_cancelled")
    outputs_after_cancel = req_bool(result.get("outputs_published_after_cancel"), "outputs_published_after_cancel")
    logical_identity = normalize_sha(result.get("logical_job_identity_sha256"), "logical_job_identity_sha256")
    idempotency_identity = normalize_sha(result.get("idempotency_key_sha256"), "idempotency_key_sha256")
    identity_preserved = req_bool(result.get("logical_identity_preserved"), "logical_identity_preserved")
    upstream_state = req_str(result.get("upstream_cancel_state"), "upstream_cancel_state")
    claimed_cancelled = req_bool(result.get("claimed_upstream_cancelled"), "claimed_upstream_cancelled")
    relaunch = req_bool(result.get("relaunch_observed"), "relaunch_observed")
    capacity_limit = req_bool(result.get("capacity_limit_observed"), "capacity_limit_observed")
    streaming = req_bool(result.get("bounded_streaming_observed"), "bounded_streaming_observed")
    storage_preflight = req_bool(result.get("storage_preflight_observed"), "storage_preflight_observed")
    output_resolution = req_str(result.get("output_availability_resolution"), "output_availability_resolution")
    runtime_artifact = normalize_sha(result.get("runtime_artifact_sha256"), "runtime_artifact_sha256")
    stable = req_list(result.get("stable_error_codes"), "stable_error_codes")
    if not all(isinstance(code, str) and 0 < len(code) <= 128 for code in stable):
        fail("L1E08_STABLE_CODES_INVALID")

    if runtime_artifact != e07["runtime_artifact_sha256"]:
        fail("L1E08_RUNTIME_ARTIFACT_MISMATCH")
    if corrupted or partial:
        fail("L1E08_PROJECT_INTEGRITY_FAIL")
    if executions > 1 or billable > 1 or duplicate:
        fail("L1E08_DUPLICATE_EXECUTION_OR_BILLING")
    if automatic_reposts > 0:
        fail("L1E08_AUTOMATIC_START_REPOST_FORBIDDEN")
    if not identity_preserved:
        fail("L1E08_LOGICAL_IDENTITY_NOT_PRESERVED")
    if claimed_cancelled and upstream_state != "confirmed":
        fail("L1E08_CANCEL_CLAIM_UNTRUTHFUL")

    if kind in CANCEL_SCENARIOS:
        if not logical_cancelled or outputs_after_cancel or project_state != "cancelled":
            fail("L1E08_CANCEL_SEMANTICS_FAIL")
        if cancel_requests > 1:
            fail("L1E08_CANCEL_REQUEST_DUPLICATE")
        if kind == "CANCEL_PRE_START" and start_requests != 0:
            fail("L1E08_CANCEL_PRE_START_EXECUTED")
        if upstream_state not in {
            "confirmed",
            "requested",
            "unsupported",
            "unknown_after_error",
            "not_addressable",
        }:
            fail("L1E08_CANCEL_STATE_INVALID")
    elif outputs_after_cancel or cancel_requests != 0:
        fail("L1E08_NON_CANCEL_SCENARIO_CANCEL_SIDE_EFFECT")

    if kind == "AMBIGUOUS_START_RETRY" and (not reconciliation or start_requests > 1):
        fail("L1E08_AMBIGUOUS_START_NOT_RECONCILED")
    if kind == "RELAUNCH" and not relaunch:
        fail("L1E08_RELAUNCH_NOT_OBSERVED")
    if kind == "CAPACITY_LIMIT" and not capacity_limit:
        fail("L1E08_CAPACITY_LIMIT_NOT_OBSERVED")
    if kind == "LONG_TRACK" and not streaming:
        fail("L1E08_LONG_TRACK_NOT_STREAMED")
    if kind == "STORAGE_PRESSURE" and not storage_preflight:
        fail("L1E08_STORAGE_PREFLIGHT_NOT_OBSERVED")
    if kind == "OUTPUT_AVAILABILITY_LOSS" and output_resolution not in {
        "verified_project_copy",
        "refreshed_authority_handle",
        "failed_closed",
    }:
        fail("L1E08_OUTPUT_AVAILABILITY_UNSAFE")
    if kind == "INPUT_INTERRUPTION" and not stable:
        fail("L1E08_INPUT_INTERRUPTION_CODE_MISSING")

    return {
        "scenario_kind": kind,
        "project_state_after": project_state,
        "stable_error_codes": sorted(set(stable)),
        "work_start_request_count": start_requests,
        "distinct_execution_count": executions,
        "upstream_cancel_request_count": cancel_requests,
        "billable_execution_count": billable,
        "automatic_start_repost_count": automatic_reposts,
        "reconciliation_performed": reconciliation,
        "logical_cancelled": logical_cancelled,
        "logical_job_identity_sha256": logical_identity,
        "idempotency_key_sha256": idempotency_identity,
        "logical_identity_preserved": identity_preserved,
        "upstream_cancel_state": upstream_state,
        "claimed_upstream_cancelled": claimed_cancelled,
        "outputs_published_after_cancel": outputs_after_cancel,
        "relaunch_observed": relaunch,
        "capacity_limit_observed": capacity_limit,
        "bounded_streaming_observed": streaming,
        "storage_preflight_observed": storage_preflight,
        "output_availability_resolution": output_resolution,
        "runtime_artifact_sha256": runtime_artifact,
        "fault_injection_provenance_sha256": fault_sha,
        "authority_provenance_sha256": authority_sha,
    }


def validate_capacity(
    capacity: Mapping[str, Any],
    *,
    e07: Mapping[str, Any],
    repo_root: Path,
    private_root: Path,
) -> dict[str, Any]:
    if (
        capacity.get("schema_version") != 1
        or capacity.get("evidence_kind") != "RUNTIME_AUTHORITY_CAPACITY_SNAPSHOT"
        or capacity.get("evidence_state") != EVIDENCE_STATE
        or capacity.get("parity_claim") != "NONE"
    ):
        fail("L1E08_CAPACITY_SCHEMA")
    if req_str(capacity.get("route_id"), "capacity.route_id") != e07["route_id"]:
        fail("L1E08_CAPACITY_ROUTE_MISMATCH")
    authority = req_map(capacity.get("authority"), "capacity.authority")
    authority_kind = req_str(authority.get("kind"), "capacity.authority.kind").upper()
    if authority_kind != e07["authority_kind"]:
        fail("L1E08_CAPACITY_AUTHORITY_KIND_MISMATCH")
    authority_sha = normalize_sha(authority.get("provenance_sha256"), "capacity.authority.provenance_sha256")
    if authority_sha != e07["authority_provenance_sha256"]:
        fail("L1E08_CAPACITY_AUTHORITY_PROVENANCE_MISMATCH")
    measurement = req_map(capacity.get("measurement"), "capacity.measurement")
    measurement_sha = safe_private_file(
        repo_root,
        private_root,
        measurement.get("path"),
        measurement.get("sha256"),
        "capacity_measurement",
    )
    statuses = {}
    raw = req_map(capacity.get("capacity"), "capacity.capacity")
    for field in ("execution_capacity_status", "cost_headroom_status", "throughput_headroom_status"):
        value = req_str(raw.get(field), field).upper()
        if value not in CAPACITY_STATUS:
            fail("L1E08_CAPACITY_STATUS_INVALID", field)
        statuses[field] = value
    privacy = req_map(capacity.get("privacy"), "capacity.privacy")
    for field in (
        "authority_ids_emitted",
        "raw_capacity_values_emitted",
        "raw_billing_records_emitted",
        "private_paths_emitted",
    ):
        if privacy.get(field) is not False:
            fail("L1E08_CAPACITY_PRIVACY_FAIL", field)
    return {
        **statuses,
        "authority_provenance_sha256": authority_sha,
        "measurement_sha256": measurement_sha,
        "unknown": any(v == "UNKNOWN" for v in statuses.values()),
        "insufficient": any(v == "INSUFFICIENT" for v in statuses.values()),
    }


def evaluate_gate(
    *,
    plan: Mapping[str, Any],
    e07: Mapping[str, Any],
    e07_source_sha256: Any,
    results_by_scenario: Mapping[str, Mapping[str, Any]],
    capacity: Mapping[str, Any],
    repo_root: Path | str,
    private_root: Path | str,
) -> dict[str, Any]:
    repo, private = ensure_private_root(Path(repo_root), Path(private_root))
    e7 = validate_e07(e07, e07_source_sha256)
    p = validate_plan(plan, e7)
    if set(results_by_scenario) != set(REQUIRED_SCENARIOS):
        fail("L1E08_RESULT_SET_MISMATCH")

    rows = []
    for kind in REQUIRED_SCENARIOS:
        rows.append(
            validate_result(
                req_map(results_by_scenario[kind], kind),
                kind,
                e07=e7,
                repo_root=repo,
                private_root=private,
            )
        )
    cap = validate_capacity(capacity, e07=e7, repo_root=repo, private_root=private)

    non_cancel = [row for row in rows if row["scenario_kind"] not in CANCEL_SCENARIOS]
    degraded_fraction = sum(
        row["project_state_after"] in {"recoverable", "failed_closed"} for row in non_cancel
    ) / len(non_cancel)

    checks = {
        "all_required_scenarios_present": len(rows) == len(REQUIRED_SCENARIOS),
        "authority_identity_consistent": all(
            row["authority_provenance_sha256"] == e7["authority_provenance_sha256"] for row in rows
        ),
        "runtime_artifact_consistent": all(
            row["runtime_artifact_sha256"] == e7["runtime_artifact_sha256"] for row in rows
        ),
        "no_duplicate_execution_or_billing": all(
            row["distinct_execution_count"] <= 1 and row["billable_execution_count"] <= 1 for row in rows
        ),
        "no_automatic_ambiguous_start_repost": all(
            row["automatic_start_repost_count"] == 0 for row in rows
        ),
        "logical_identity_preserved": all(row["logical_identity_preserved"] for row in rows),
        "cancel_claims_truthful": all(
            (not row["claimed_upstream_cancelled"]) or row["upstream_cancel_state"] == "confirmed"
            for row in rows
        ),
        "bounded_long_track_streaming": next(
            row for row in rows if row["scenario_kind"] == "LONG_TRACK"
        )["bounded_streaming_observed"],
        "storage_preflight_observed": next(
            row for row in rows if row["scenario_kind"] == "STORAGE_PRESSURE"
        )["storage_preflight_observed"],
        "non_cancel_degraded_fraction_within_policy": degraded_fraction
        <= p["maximum_non_cancel_degraded_fraction"],
    }

    if cap["insufficient"] or not all(checks.values()):
        gate_state = "LIVE_AUTHORITY_REJECTED"
    elif cap["unknown"]:
        gate_state = "PENDING_EXTERNAL_EVIDENCE"
    else:
        gate_state = "READY_FOR_HQ_E08_LIVE_REVIEW"

    lock_payload = {
        "domain": "l1-e08-runtime-authority-live-gate-v1",
        "gate_id": p["gate_id"],
        "route_id": e7["route_id"],
        "route_kind": e7["route_kind"],
        "authority_kind": e7["authority_kind"],
        "e07_source_sha256": e7["physical_sha256"],
        "e07_substitution_lock_sha256": e7["substitution_lock_sha256"],
        "runtime_artifact_sha256": e7["runtime_artifact_sha256"],
        "authority_provenance_sha256": e7["authority_provenance_sha256"],
        "rows": rows,
        "capacity": cap,
        "checks": checks,
        "gate_state": gate_state,
    }
    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "evidence_kind": "RUNTIME_AUTHORITY_LIVE_GATE",
        "evidence_state": EVIDENCE_STATE,
        "gate_state": gate_state,
        "parity_claim": "NONE",
        "gate_id": p["gate_id"],
        "route_id": e7["route_id"],
        "route_kind": e7["route_kind"],
        "authority": {
            "kind": e7["authority_kind"],
            "provenance_sha256": e7["authority_provenance_sha256"],
        },
        "runtime_artifact_sha256": e7["runtime_artifact_sha256"],
        "source_evidence": {
            "e07_evidence_sha256": e7["physical_sha256"],
            "e07_substitution_lock_sha256": e7["substitution_lock_sha256"],
        },
        "policy": {
            "maximum_non_cancel_degraded_fraction": p["maximum_non_cancel_degraded_fraction"],
            "require_capacity_attestation": True,
            "engineering_policy_not_reference_fact": True,
        },
        "summary": {
            "scenario_count": len(rows),
            "non_cancel_degraded_fraction": degraded_fraction,
            "capacity": {
                "execution_capacity_status": cap["execution_capacity_status"],
                "cost_headroom_status": cap["cost_headroom_status"],
                "throughput_headroom_status": cap["throughput_headroom_status"],
            },
        },
        "checks": checks,
        "scenarios": rows,
        "capacity_evidence": {
            "measurement_sha256": cap["measurement_sha256"],
            "authority_provenance_sha256": cap["authority_provenance_sha256"],
        },
        "privacy": {
            "credential_values_emitted": False,
            "authority_ids_emitted": False,
            "provider_account_ids_emitted": False,
            "private_paths_emitted": False,
            "raw_capacity_values_emitted": False,
            "raw_billing_records_emitted": False,
            "raw_audio_emitted": False,
        },
        "e08_live_authority_lock_sha256": canonical_sha(lock_payload),
        "parity_reason": (
            "E08 proves authority-neutral live recovery/capacity semantics only. "
            "Real-audio quality, current-iPhone differential, physical-device integration and HQ PARITY remain separate gates."
        ),
    }


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        return req_map(json.loads(path.read_text(encoding="utf-8")), str(path))
    except RuntimeAuthorityError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeAuthorityError("L1E08_JSON_INVALID", str(path)) from exc


def atomic_dump(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    try:
        with tmp.open("w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except OSError as exc:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        raise RuntimeAuthorityError("L1E08_WRITE_FAILED") from exc


def main(argv: Sequence[str] | None = None) -> int:
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="Lane 1 E08 generic runtime-authority live gate")
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--private-root", required=True)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--e07", required=True)
    parser.add_argument("--results-index", required=True)
    parser.add_argument("--capacity", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    try:
        repo = Path(args.repo_root).resolve()
        private = Path(args.private_root).resolve()
        index = load_json(Path(args.results_index))
        paths = req_map(index.get("results"), "results_index.results")
        if set(paths) != set(REQUIRED_SCENARIOS):
            fail("L1E08_RESULT_SET_MISMATCH")
        results = {}
        for kind, raw in paths.items():
            rel = Path(req_str(raw, f"results.{kind}"))
            if rel.is_absolute() or ".." in rel.parts:
                fail("L1E08_RESULT_PATH_UNSAFE", kind)
            p = (private / rel).resolve()
            try:
                p.relative_to(private)
            except ValueError as exc:
                raise RuntimeAuthorityError("L1E08_RESULT_PATH_ESCAPE", kind) from exc
            if not p.is_file():
                fail("L1E08_RESULT_MISSING", kind)
            results[kind] = load_json(p)
        e07_path = Path(args.e07)
        report = evaluate_gate(
            plan=load_json(Path(args.plan)),
            e07=load_json(e07_path),
            e07_source_sha256=sha256_file(e07_path),
            results_by_scenario=results,
            capacity=load_json(Path(args.capacity)),
            repo_root=repo,
            private_root=private,
        )
        atomic_dump(Path(args.out), report)
        print(json.dumps({"status": "PASS", "gate_state": report["gate_state"], "lock": report["e08_live_authority_lock_sha256"]}, sort_keys=True))
        return 0
    except RuntimeAuthorityError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
