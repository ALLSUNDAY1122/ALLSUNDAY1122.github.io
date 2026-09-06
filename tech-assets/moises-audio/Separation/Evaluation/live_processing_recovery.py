"""L1-E05 live processing recovery/provider-semantics evidence gate.

Engineering harness only. A PASS is still NON_PARITY and requires external provenance
from an actual approved production provider run. The module does not fabricate or
simulate live provider behavior.
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
TOOL_VERSION = "L1-E05-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
REQUIRED_SCENARIOS = (
    "NETWORK_INTERRUPTION",
    "CANCEL_UPLOAD",
    "CANCEL_SEPARATING",
    "CANCEL_FINALIZING",
    "AMBIGUOUS_CREATE_RETRY",
    "RELAUNCH",
    "OUTPUT_EXPIRY",
    "RATE_LIMIT",
    "LONG_TRACK",
    "STORAGE_PRESSURE",
)
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
SAFE_STATES = {"ready", "recoverable", "cancelled", "failed_closed"}
CANCEL_SCENARIOS = {"CANCEL_UPLOAD", "CANCEL_SEPARATING", "CANCEL_FINALIZING"}


class RecoveryGateError(ValueError):
    def __init__(self, code: str, msg: str = "recovery gate validation failed"):
        super().__init__(f"{code}: {msg}")
        self.code = code
        self.message = msg


def err(code: str, msg: str = "recovery gate validation failed") -> RecoveryGateError:
    return RecoveryGateError(code, msg)


def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise err("L1E05_SCHEMA_TYPE", f"{field} must be object")
    return value


def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise err("L1E05_SCHEMA_REQUIRED", f"{field} required")
    return value.strip()


def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise err("L1E05_SCHEMA_TYPE", f"{field} must be bool")
    return value


def req_int(value: Any, field: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise err("L1E05_SCHEMA_INTEGER", f"{field} invalid")
    return value


def req_num(value: Any, field: str, minimum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise err("L1E05_SCHEMA_NUMBER", f"{field} invalid")
    number = float(value)
    if minimum is not None and number < minimum:
        raise err("L1E05_SCHEMA_RANGE", f"{field} below minimum")
    return number


def normalize_sha(value: Any, field: str) -> str:
    raw = req_str(value, field).lower().removeprefix("sha256:")
    if not SHA_RE.fullmatch(raw):
        raise err("L1E05_SHA_INVALID", f"{field} invalid")
    return raw


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        ).encode()
    ).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise err("L1E05_PROVENANCE_UNREADABLE") from exc
    return digest.hexdigest()


def ensure_external_file(
    repo_root: Path,
    private_root: Path,
    raw_path: Any,
    expected_sha: Any,
    field: str,
) -> str:
    relative = Path(req_str(raw_path, field))
    if relative.is_absolute() or ".." in relative.parts:
        raise err("L1E05_PROVENANCE_PATH_UNSAFE")

    repository = repo_root.resolve()
    private = private_root.resolve()
    try:
        private.relative_to(repository)
    except ValueError:
        pass
    else:
        raise err("L1E05_PRIVATE_ROOT_INSIDE_REPOSITORY")

    path = (private / relative).resolve()
    try:
        path.relative_to(private)
    except ValueError as exc:
        raise err("L1E05_PROVENANCE_PATH_ESCAPE") from exc

    cursor = private
    for part in relative.parts:
        cursor /= part
        if cursor.is_symlink():
            raise err("L1E05_PROVENANCE_SYMLINK")

    if not path.is_file():
        raise err("L1E05_PROVENANCE_MISSING")
    actual = sha256_file(path)
    if actual != normalize_sha(expected_sha, field + "_sha256"):
        raise err("L1E05_PROVENANCE_SHA_MISMATCH", field)
    return actual


def validate_e01(evidence: Mapping[str, Any]) -> dict[str, Any]:
    if evidence.get("schema_version") != 1 or evidence.get("evidence_kind") != "COMMERCIAL_ROUTE_APPROVAL":
        raise err("L1E05_E01_SCHEMA")
    if evidence.get("evidence_state") != EVIDENCE_STATE or evidence.get("parity_claim") != "NONE":
        raise err("L1E05_E01_STATE")
    if evidence.get("result") != "READY_FOR_LIVE_PROVIDER_GATE":
        raise err("L1E05_E01_NOT_READY")
    preflight = req_map(evidence.get("credential_preflight"), "e01.credential_preflight")
    if (
        preflight.get("all_present") is not True
        or preflight.get("server_side_only") is not True
        or preflight.get("values_persisted") is not False
    ):
        raise err("L1E05_E01_CREDENTIAL_POLICY")
    return {
        "approval_identity": normalize_sha(
            evidence.get("approval_manifest_identity_sha256"),
            "approval_manifest_identity_sha256",
        )
    }


def validate_e03(evidence: Mapping[str, Any]) -> dict[str, Any]:
    if evidence.get("schema_version") != 1 or evidence.get("evidence_kind") != "LIVE_SEPARATION_BENCHMARK":
        raise err("L1E05_E03_SCHEMA")
    if evidence.get("evidence_state") != EVIDENCE_STATE or evidence.get("parity_claim") != "NONE":
        raise err("L1E05_E03_STATE")
    if evidence.get("benchmark_state") != "READY_FOR_HQ_E03_LIVE_REVIEW":
        raise err("L1E05_E03_NOT_READY")
    checks = req_map(evidence.get("acceptance_checks"), "e03.acceptance_checks")
    if not checks or not all(value is True for value in checks.values()):
        raise err("L1E05_E03_CHECKS_NOT_PASS")
    return {
        "lock": normalize_sha(
            evidence.get("e03_live_benchmark_lock_sha256"),
            "e03_live_benchmark_lock_sha256",
        )
    }


def validate_plan(plan: Mapping[str, Any]) -> dict[str, Any]:
    if plan.get("schema_version") != SCHEMA_VERSION or plan.get("evidence_state") != EVIDENCE_STATE:
        raise err("L1E05_PLAN_SCHEMA")
    campaign_id = req_str(plan.get("recovery_campaign_id"), "recovery_campaign_id")
    if not SAFE_ID.fullmatch(campaign_id):
        raise err("L1E05_ID_INVALID")
    scenarios = plan.get("scenarios")
    if not isinstance(scenarios, list):
        raise err("L1E05_SCENARIOS_TYPE")

    seen: dict[str, str] = {}
    for raw in scenarios:
        scenario = req_map(raw, "scenario")
        scenario_id = req_str(scenario.get("scenario_id"), "scenario_id")
        kind = req_str(scenario.get("scenario_kind"), "scenario_kind").upper()
        if not SAFE_ID.fullmatch(scenario_id) or scenario_id in seen:
            raise err("L1E05_SCENARIO_ID")
        if kind not in REQUIRED_SCENARIOS:
            raise err("L1E05_SCENARIO_KIND")
        if kind in seen.values():
            raise err("L1E05_SCENARIO_KIND_DUPLICATE")
        seen[scenario_id] = kind

    if set(seen.values()) != set(REQUIRED_SCENARIOS):
        raise err("L1E05_REQUIRED_SCENARIO_MISSING")
    return {"campaign_id": campaign_id, "scenarios": seen}


def validate_result(
    result: Mapping[str, Any],
    kind: str,
    repo_root: Path,
    private_root: Path,
) -> dict[str, Any]:
    if result.get("schema_version") != 1 or result.get("evidence_state") != EVIDENCE_STATE:
        raise err("L1E05_RESULT_SCHEMA")
    if req_str(result.get("scenario_kind"), "scenario_kind").upper() != kind:
        raise err("L1E05_RESULT_KIND_MISMATCH")

    stable = result.get("stable_error_codes")
    if not isinstance(stable, list) or not all(
        isinstance(value, str) and 0 < len(value) <= 128 for value in stable
    ):
        raise err("L1E05_STABLE_CODES")

    project_state = req_str(result.get("project_state_after"), "project_state_after")
    if project_state not in SAFE_STATES:
        raise err("L1E05_PROJECT_STATE")

    corrupted = req_bool(result.get("project_corrupted"), "project_corrupted")
    partial_published = req_bool(result.get("partial_result_published"), "partial_result_published")
    create_count = req_int(result.get("provider_create_request_count"), "provider_create_request_count")
    distinct_tasks = req_int(result.get("provider_distinct_task_count"), "provider_distinct_task_count")
    cancel_requests = req_int(result.get("provider_cancel_request_count"), "provider_cancel_request_count")
    billable = req_int(result.get("provider_billable_task_count"), "provider_billable_task_count")
    automatic_reposts = req_int(result.get("automatic_create_repost_count"), "automatic_create_repost_count")
    duplicate = req_bool(result.get("duplicate_provider_task_detected"), "duplicate_provider_task_detected")
    reconciliation = req_bool(result.get("reconciliation_performed"), "reconciliation_performed")
    logical_cancel = req_bool(result.get("logical_cancelled"), "logical_cancelled")
    logical_identity = normalize_sha(result.get("logical_job_identity_sha256"), "logical_job_identity_sha256")
    idempotency_identity = normalize_sha(result.get("idempotency_key_sha256"), "idempotency_key_sha256")
    identity_preserved = req_bool(result.get("logical_identity_preserved"), "logical_identity_preserved")
    upstream = req_str(result.get("upstream_cancel_state"), "upstream_cancel_state")
    claimed_upstream_cancelled = req_bool(
        result.get("claimed_upstream_cancelled"), "claimed_upstream_cancelled"
    )
    outputs_after_cancel = req_bool(
        result.get("outputs_published_after_cancel"), "outputs_published_after_cancel"
    )
    relaunch = req_bool(result.get("relaunch_observed"), "relaunch_observed")
    rate_limit = req_bool(result.get("rate_limit_observed"), "rate_limit_observed")
    streaming = req_bool(result.get("bounded_streaming_observed"), "bounded_streaming_observed")
    storage_preflight = req_bool(
        result.get("storage_preflight_observed"), "storage_preflight_observed"
    )
    expiry_resolution = req_str(result.get("output_expiry_resolution"), "output_expiry_resolution")

    before = result.get("committed_result_sha256_before")
    after = result.get("committed_result_sha256_after")
    if before is not None:
        before = normalize_sha(before, "committed_result_sha256_before")
    if after is not None:
        after = normalize_sha(after, "committed_result_sha256_after")

    provenance = req_map(result.get("provenance"), "provenance")
    fault_sha = ensure_external_file(
        repo_root,
        private_root,
        provenance.get("fault_injection_path"),
        provenance.get("fault_injection_sha256"),
        "fault_injection",
    )
    account_sha = ensure_external_file(
        repo_root,
        private_root,
        provenance.get("provider_account_path"),
        provenance.get("provider_account_sha256"),
        "provider_account",
    )

    if corrupted or partial_published:
        raise err("L1E05_PROJECT_INTEGRITY_FAIL")
    if billable > 1 or duplicate or distinct_tasks > 1:
        raise err("L1E05_DUPLICATE_BILLING_OR_TASK")
    if not identity_preserved:
        raise err("L1E05_LOGICAL_IDENTITY_NOT_PRESERVED")
    if automatic_reposts > 0:
        raise err("L1E05_AUTOMATIC_CREATE_REPOST_FORBIDDEN")
    if claimed_upstream_cancelled and upstream != "confirmed":
        raise err("L1E05_CANCEL_CLAIM_UNTRUTHFUL")

    if kind in CANCEL_SCENARIOS:
        if not logical_cancel or outputs_after_cancel or project_state != "cancelled":
            raise err("L1E05_CANCEL_SEMANTICS_FAIL")
        if cancel_requests > 1:
            raise err("L1E05_CANCEL_PROVIDER_REQUEST_DUPLICATE")
        if kind == "CANCEL_UPLOAD" and create_count != 0:
            raise err("L1E05_CANCEL_UPLOAD_CREATED_TASK")
        if upstream not in {
            "confirmed",
            "requested",
            "unsupported",
            "unknown_after_error",
            "not_addressable",
        }:
            raise err("L1E05_CANCEL_STATE_INVALID")
    elif outputs_after_cancel or cancel_requests != 0:
        raise err("L1E05_OUTPUT_AFTER_CANCEL_INVALID")

    if kind == "AMBIGUOUS_CREATE_RETRY" and (not reconciliation or create_count > 1):
        raise err("L1E05_AMBIGUOUS_CREATE_NOT_RECONCILED")
    if kind == "RELAUNCH" and not relaunch:
        raise err("L1E05_RELAUNCH_NOT_OBSERVED")
    if kind == "RATE_LIMIT" and not rate_limit:
        raise err("L1E05_RATE_LIMIT_NOT_OBSERVED")
    if kind == "LONG_TRACK" and not streaming:
        raise err("L1E05_LONG_TRACK_NOT_STREAMED")
    if kind == "STORAGE_PRESSURE" and not storage_preflight:
        raise err("L1E05_STORAGE_PREFLIGHT_NOT_OBSERVED")
    if kind == "OUTPUT_EXPIRY" and expiry_resolution not in {
        "verified_local_copy",
        "refreshed_provider_url",
        "failed_closed",
    }:
        raise err("L1E05_OUTPUT_EXPIRY_UNSAFE")
    if kind == "NETWORK_INTERRUPTION" and not stable:
        raise err("L1E05_NETWORK_FAULT_CODE_MISSING")
    if before is not None and after is not None and project_state == "failed_closed" and before != after:
        raise err("L1E05_FAILED_CLOSED_MUTATED_RESULT")

    return {
        "scenario_kind": kind,
        "project_state_after": project_state,
        "stable_error_codes": sorted(set(stable)),
        "provider_create_request_count": create_count,
        "provider_distinct_task_count": distinct_tasks,
        "provider_cancel_request_count": cancel_requests,
        "provider_billable_task_count": billable,
        "automatic_create_repost_count": automatic_reposts,
        "reconciliation_performed": reconciliation,
        "logical_cancelled": logical_cancel,
        "logical_job_identity_sha256": logical_identity,
        "idempotency_key_sha256": idempotency_identity,
        "logical_identity_preserved": identity_preserved,
        "upstream_cancel_state": upstream,
        "claimed_upstream_cancelled": claimed_upstream_cancelled,
        "outputs_published_after_cancel": outputs_after_cancel,
        "relaunch_observed": relaunch,
        "rate_limit_observed": rate_limit,
        "bounded_streaming_observed": streaming,
        "storage_preflight_observed": storage_preflight,
        "output_expiry_resolution": expiry_resolution,
        "committed_result_sha256_before": before,
        "committed_result_sha256_after": after,
        "fault_injection_provenance_sha256": fault_sha,
        "provider_account_provenance_sha256": account_sha,
    }


def evaluate_campaign(
    *,
    plan: Mapping[str, Any],
    e01: Mapping[str, Any],
    e03: Mapping[str, Any],
    results_by_scenario: Mapping[str, Mapping[str, Any]],
    repo_root: Path | str,
    private_root: Path | str,
) -> dict[str, Any]:
    repository = Path(repo_root).resolve()
    private = Path(private_root).resolve()
    normalized_plan = validate_plan(plan)
    e01_normalized = validate_e01(e01)
    e03_normalized = validate_e03(e03)

    if set(results_by_scenario) != set(normalized_plan["scenarios"]):
        raise err("L1E05_RESULT_SET_MISMATCH")

    rows = []
    for scenario_id in sorted(normalized_plan["scenarios"]):
        row = validate_result(
            req_map(results_by_scenario[scenario_id], scenario_id),
            normalized_plan["scenarios"][scenario_id],
            repository,
            private,
        )
        rows.append({"scenario_id": scenario_id, **row})

    checks = {
        "all_required_scenarios_present": len(rows) == len(REQUIRED_SCENARIOS),
        "no_project_corruption_or_partial_publish": True,
        "no_duplicate_billable_task": all(
            row["provider_billable_task_count"] <= 1
            and row["provider_distinct_task_count"] <= 1
            for row in rows
        ),
        "logical_identity_preserved": all(row["logical_identity_preserved"] for row in rows),
        "no_automatic_ambiguous_create_repost": all(
            row["automatic_create_repost_count"] == 0 for row in rows
        ),
        "cancel_claims_truthful": all(
            (not row["claimed_upstream_cancelled"])
            or row["upstream_cancel_state"] == "confirmed"
            for row in rows
        ),
        "external_provenance_bound": all(
            row["fault_injection_provenance_sha256"]
            and row["provider_account_provenance_sha256"]
            for row in rows
        ),
    }

    plan_hash = canonical_sha(plan)
    e01_hash = canonical_sha(e01)
    e03_hash = canonical_sha(e03)
    lock_payload = {
        "plan_sha256": plan_hash,
        "e01_evidence_sha256": e01_hash,
        "e03_evidence_sha256": e03_hash,
        "e01_approval_identity_sha256": e01_normalized["approval_identity"],
        "e03_live_benchmark_lock_sha256": e03_normalized["lock"],
        "rows": rows,
        "checks": checks,
    }

    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "evidence_kind": "LIVE_PROCESSING_RECOVERY",
        "evidence_state": EVIDENCE_STATE,
        "recovery_state": (
            "READY_FOR_HQ_E05_LIVE_REVIEW"
            if all(checks.values())
            else "LIVE_RECOVERY_FAILED"
        ),
        "parity_claim": "NONE",
        "recovery_campaign_id": normalized_plan["campaign_id"],
        "source_evidence": {
            "plan_sha256": plan_hash,
            "e01_evidence_sha256": e01_hash,
            "e03_evidence_sha256": e03_hash,
            "e01_approval_identity_sha256": e01_normalized["approval_identity"],
            "e03_live_benchmark_lock_sha256": e03_normalized["lock"],
        },
        "checks": checks,
        "scenarios": rows,
        "privacy": {
            "credential_values_emitted": False,
            "provider_task_ids_emitted": False,
            "provider_asset_ids_emitted": False,
            "private_paths_emitted": False,
            "raw_account_evidence_emitted": False,
            "raw_audio_emitted": False,
        },
        "e05_live_recovery_lock_sha256": canonical_sha(lock_payload),
        "parity_reason": (
            "E05 verifies live provider recovery semantics only; current-iPhone product "
            "integration/device evidence and HQ PARITY remain separate gates."
        ),
    }


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        return req_map(json.loads(path.read_text(encoding="utf-8")), str(path))
    except RecoveryGateError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise err("L1E05_JSON_INVALID", str(path)) from exc


def atomic_dump(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    try:
        with tmp.open("w", encoding="utf-8") as handle:
            json.dump(
                payload,
                handle,
                indent=2,
                sort_keys=True,
                ensure_ascii=False,
                allow_nan=False,
            )
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except OSError as exc:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        raise err("L1E05_WRITE_FAILED") from exc


def main(argv: Sequence[str] | None = None) -> int:
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="Lane 1 E05 live recovery evidence validator")
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--private-root", required=True)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--e01", required=True)
    parser.add_argument("--e03", required=True)
    parser.add_argument(
        "--results-index",
        required=True,
        help="private JSON mapping scenario_id to result JSON path relative to private-root",
    )
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    try:
        repository = Path(args.repo_root).resolve()
        private = Path(args.private_root).resolve()
        index = load_json(Path(args.results_index))
        result_paths = req_map(index.get("results"), "results_index.results")
        plan = load_json(Path(args.plan))
        normalized = validate_plan(plan)
        if set(result_paths) != set(normalized["scenarios"]):
            raise err("L1E05_RESULT_SET_MISMATCH")

        results: dict[str, Mapping[str, Any]] = {}
        for scenario_id, raw in result_paths.items():
            relative = Path(req_str(raw, f"results.{scenario_id}"))
            if relative.is_absolute() or ".." in relative.parts:
                raise err("L1E05_RESULT_PATH_UNSAFE")
            result_path = (private / relative).resolve()
            try:
                result_path.relative_to(private)
            except ValueError as exc:
                raise err("L1E05_RESULT_PATH_ESCAPE") from exc
            if not result_path.is_file():
                raise err("L1E05_RESULT_MISSING", scenario_id)
            results[scenario_id] = load_json(result_path)

        report = evaluate_campaign(
            plan=plan,
            e01=load_json(Path(args.e01)),
            e03=load_json(Path(args.e03)),
            results_by_scenario=results,
            repo_root=repository,
            private_root=private,
        )
        atomic_dump(Path(args.out), report)
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "recovery_state": report["recovery_state"],
                    "lock": report["e05_live_recovery_lock_sha256"],
                },
                sort_keys=True,
            )
        )
        return 0
    except RecoveryGateError as exc:
        print(
            json.dumps(
                {"status": "FAIL", "code": exc.code, "message": exc.message},
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
