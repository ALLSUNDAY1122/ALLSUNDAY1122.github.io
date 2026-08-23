"""L1-E07 Provider Fallback Substitution Conformance.

Engineering gate for substituting a rejected separation route without weakening Lane 1
A06-A20 safety contracts. This module is NON-PARITY evidence only.

The route authority vocabulary is intentionally generic:
- HOSTED_PROVIDER_ACCOUNT
- LOCAL_RUNTIME
- PROJECT_OWNED_RUNTIME

A local SDK or project-owned model must never fabricate a provider-account identity merely
to fit hosted-provider evidence schemas.
"""
from __future__ import annotations

import ast
import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-E07-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"

FALLBACK_ORDER = (
    "LICENSED_LOCAL_INFERENCE_SDK",
    "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER",
    "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE",
)
AUTHORITY_KIND = {
    "LICENSED_LOCAL_INFERENCE_SDK": "LOCAL_RUNTIME",
    "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER": "HOSTED_PROVIDER_ACCOUNT",
    "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE": "PROJECT_OWNED_RUNTIME",
}
REQUIRED_PROVIDER_METHODS = (
    "upload_asset",
    "create_separation_task",
    "get_task_state",
    "find_tasks_by_metadata",
)
REQUIRED_INVARIANTS = (
    "A06_PROVIDER_NEUTRAL_ORCHESTRATION",
    "A07_IDEMPOTENCY_DUPLICATE_BILLING",
    "A08_CANCELLATION_TRUTH",
    "A09_RETENTION_DELETION_PRIVACY",
    "A10_COST_QUOTA_RATE_GUARD",
    "A11_REFERENCE_PROFILE_REGISTRY",
    "A12_ADVANCED_CAPABILITY_MAPPING",
    "A13_ARTIFACT_INTEGRITY",
    "A14_ATOMIC_MULTI_STEM_PUBLICATION",
    "A15_LONG_TRACK_STORAGE_PRESSURE",
    "A16_DURABLE_RELAUNCH_RECOVERY",
    "A17_FAULT_NORMALIZATION",
    "A18_PRIVACY_SAFE_OBSERVABILITY",
    "A19_GOLDEN_INPUT_BINDING",
    "A20_DIFFERENTIAL_REPRODUCIBILITY",
)
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")


class SubstitutionError(ValueError):
    def __init__(self, code: str, message: str = "fallback substitution conformance failed"):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message


def fail(code: str, message: str = "fallback substitution conformance failed") -> None:
    raise SubstitutionError(code, message)


def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        fail("L1E07_SCHEMA_TYPE", f"{field} must be object")
    return value


def req_list(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        fail("L1E07_SCHEMA_TYPE", f"{field} must be array")
    return value


def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail("L1E07_SCHEMA_REQUIRED", f"{field} required")
    return value.strip()


def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        fail("L1E07_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def normalize_sha(value: Any, field: str) -> str:
    raw = req_str(value, field).lower().removeprefix("sha256:")
    if not SHA_RE.fullmatch(raw):
        fail("L1E07_SHA_INVALID", field)
    return raw


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    try:
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
    except OSError as exc:
        raise SubstitutionError("L1E07_FILE_UNREADABLE", str(path)) from exc
    return h.hexdigest()


def safe_repo_file(repo_root: Path, raw: Any, expected_sha: Any, field: str) -> Path:
    rel = Path(req_str(raw, field))
    if rel.is_absolute() or ".." in rel.parts:
        fail("L1E07_REPO_PATH_UNSAFE", field)
    root = repo_root.resolve()
    cur = root
    for part in rel.parts:
        cur /= part
        if cur.is_symlink():
            fail("L1E07_REPO_PATH_SYMLINK", field)
    path = (root / rel).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise SubstitutionError("L1E07_REPO_PATH_ESCAPE", field) from exc
    if not path.is_file():
        fail("L1E07_REPO_FILE_MISSING", field)
    if sha256_file(path) != normalize_sha(expected_sha, field + "_sha256"):
        fail("L1E07_REPO_FILE_SHA_MISMATCH", field)
    return path


def safe_private_file(repo_root: Path, private_root: Path, raw: Any, expected_sha: Any, field: str) -> str:
    repo = repo_root.resolve()
    private = private_root.resolve()
    try:
        private.relative_to(repo)
    except ValueError:
        pass
    else:
        fail("L1E07_PRIVATE_ROOT_INSIDE_REPOSITORY")
    rel = Path(req_str(raw, field))
    if rel.is_absolute() or ".." in rel.parts:
        fail("L1E07_PRIVATE_PATH_UNSAFE", field)
    cur = private
    for part in rel.parts:
        cur /= part
        if cur.is_symlink():
            fail("L1E07_PRIVATE_PATH_SYMLINK", field)
    path = (private / rel).resolve()
    try:
        path.relative_to(private)
    except ValueError as exc:
        raise SubstitutionError("L1E07_PRIVATE_PATH_ESCAPE", field) from exc
    if not path.is_file():
        fail("L1E07_PRIVATE_FILE_MISSING", field)
    actual = sha256_file(path)
    if actual != normalize_sha(expected_sha, field + "_sha256"):
        fail("L1E07_PRIVATE_FILE_SHA_MISMATCH", field)
    return actual


def validate_adapter_surface(path: Path, class_name: str) -> dict[str, Any]:
    if not SAFE_ID.fullmatch(class_name):
        fail("L1E07_ADAPTER_CLASS_INVALID")
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, SyntaxError) as exc:
        raise SubstitutionError("L1E07_ADAPTER_SOURCE_INVALID") from exc
    cls = next((n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == class_name), None)
    if cls is None:
        fail("L1E07_ADAPTER_CLASS_MISSING", class_name)
    methods = {
        n.name
        for n in cls.body
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
    }
    missing = sorted(set(REQUIRED_PROVIDER_METHODS) - methods)
    if missing:
        fail("L1E07_ADAPTER_METHOD_MISSING", ",".join(missing))
    return {
        "class_name": class_name,
        "required_methods": list(REQUIRED_PROVIDER_METHODS),
        "optional_cancel_supported": "cancel_task" in methods,
        "optional_delete_asset_supported": "delete_asset" in methods,
        "optional_delete_task_supported": "delete_task" in methods,
    }


def validate_plan(plan: Mapping[str, Any]) -> dict[str, Any]:
    if plan.get("schema_version") != 1 or plan.get("evidence_state") != EVIDENCE_STATE:
        fail("L1E07_PLAN_SCHEMA")
    substitution_id = req_str(plan.get("substitution_id"), "substitution_id")
    replaced_route_id = req_str(plan.get("replaced_route_id"), "replaced_route_id")
    route_kind = req_str(plan.get("selected_fallback_kind"), "selected_fallback_kind").upper()
    if not SAFE_ID.fullmatch(substitution_id) or not SAFE_ID.fullmatch(replaced_route_id):
        fail("L1E07_ID_INVALID")
    if route_kind not in FALLBACK_ORDER:
        fail("L1E07_FALLBACK_KIND_INVALID")
    if plan.get("fallback_order") != list(FALLBACK_ORDER):
        fail("L1E07_FALLBACK_ORDER_CHANGED")
    if plan.get("parity_claim") != "NONE":
        fail("L1E07_PARITY_CLAIM_FORBIDDEN")
    return {
        "substitution_id": substitution_id,
        "replaced_route_id": replaced_route_id,
        "route_kind": route_kind,
    }


def validate_prior_dispositions(manifest: Mapping[str, Any], route_kind: str, repo_root: Path, private_root: Path) -> list[dict[str, Any]]:
    selected_idx = FALLBACK_ORDER.index(route_kind)
    rows = req_list(manifest.get("prior_fallback_dispositions", []), "prior_fallback_dispositions")
    by_kind: dict[str, Mapping[str, Any]] = {}
    for raw in rows:
        row = req_map(raw, "prior_fallback_disposition")
        kind = req_str(row.get("fallback_kind"), "fallback_kind").upper()
        if kind in by_kind or kind not in FALLBACK_ORDER:
            fail("L1E07_PRIOR_DISPOSITION_INVALID")
        by_kind[kind] = row
    required = set(FALLBACK_ORDER[:selected_idx])
    if set(by_kind) != required:
        fail("L1E07_FALLBACK_ORDER_SKIP_UNPROVEN")
    out = []
    for kind in FALLBACK_ORDER[:selected_idx]:
        row = by_kind[kind]
        state = req_str(row.get("disposition"), "disposition").upper()
        if state not in {"UNAVAILABLE", "REJECTED"}:
            fail("L1E07_PRIOR_DISPOSITION_STATE_INVALID")
        evidence_sha = safe_private_file(repo_root, private_root, row.get("evidence_path"), row.get("evidence_sha256"), f"prior_disposition_{kind}")
        out.append({"fallback_kind": kind, "disposition": state, "evidence_sha256": evidence_sha})
    return out


def validate_invariants(manifest: Mapping[str, Any], repo_root: Path) -> list[dict[str, Any]]:
    rows = req_list(manifest.get("invariants"), "invariants")
    by_id: dict[str, Mapping[str, Any]] = {}
    for raw in rows:
        row = req_map(raw, "invariant")
        iid = req_str(row.get("invariant_id"), "invariant_id")
        if iid in by_id:
            fail("L1E07_INVARIANT_DUPLICATE", iid)
        by_id[iid] = row
    if set(by_id) != set(REQUIRED_INVARIANTS):
        fail("L1E07_INVARIANT_SET_INCOMPLETE")
    out = []
    for iid in REQUIRED_INVARIANTS:
        row = by_id[iid]
        if req_str(row.get("status"), "status").upper() != "PASS":
            fail("L1E07_INVARIANT_NOT_PASS", iid)
        if row.get("waived") is not False:
            fail("L1E07_INVARIANT_WAIVER_FORBIDDEN", iid)
        evidence_path = safe_repo_file(repo_root, row.get("evidence_path"), row.get("evidence_sha256"), f"invariant_{iid}")
        out.append({"invariant_id": iid, "status": "PASS", "evidence_sha256": sha256_file(evidence_path)})
    return out


def validate_route_specific(manifest: Mapping[str, Any], route_kind: str, repo_root: Path, private_root: Path) -> dict[str, Any]:
    authority = req_map(manifest.get("capacity_authority"), "capacity_authority")
    authority_kind = req_str(authority.get("kind"), "capacity_authority.kind").upper()
    expected_authority = AUTHORITY_KIND[route_kind]
    if authority_kind != expected_authority:
        fail("L1E07_CAPACITY_AUTHORITY_KIND_MISMATCH")
    if route_kind != "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER":
        forbidden = {"provider_account_id", "provider_account_path", "provider_account_sha256", "provider_account_provenance_sha256"}
        if forbidden & set(authority):
            fail("L1E07_FAKE_PROVIDER_ACCOUNT_FORBIDDEN")
    authority_sha = safe_private_file(repo_root, private_root, authority.get("provenance_path"), authority.get("provenance_sha256"), "capacity_authority")

    commercial = req_map(manifest.get("commercial_basis"), "commercial_basis")
    commercial_sha = safe_private_file(repo_root, private_root, commercial.get("document_path"), commercial.get("document_sha256"), "commercial_basis")
    if commercial.get("consumer_app_commercial_use_allowed") is not True:
        fail("L1E07_COMMERCIAL_USE_NOT_APPROVED")
    if commercial.get("output_export_allowed") is not True:
        fail("L1E07_OUTPUT_EXPORT_NOT_APPROVED")
    if commercial.get("provider_training_on_user_content_allowed") is True:
        fail("L1E07_PROVIDER_TRAINING_NOT_ALLOWED")

    runtime = req_map(manifest.get("runtime"), "runtime")
    runtime_id = req_str(runtime.get("runtime_id"), "runtime.runtime_id")
    model_name = req_str(runtime.get("model_name"), "runtime.model_name")
    model_version = req_str(runtime.get("model_version"), "runtime.model_version")
    quality_profile = req_str(runtime.get("quality_profile"), "runtime.quality_profile")
    artifact_sha = safe_private_file(repo_root, private_root, runtime.get("artifact_path"), runtime.get("artifact_sha256"), "runtime_artifact")

    training_rights_sha = None
    if route_kind == "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE":
        training = req_map(manifest.get("training_rights"), "training_rights")
        if training.get("rights_cleared_for_training") is not True:
            fail("L1E07_TRAINING_RIGHTS_NOT_CLEARED")
        training_rights_sha = safe_private_file(repo_root, private_root, training.get("evidence_path"), training.get("evidence_sha256"), "training_rights")
    elif manifest.get("training_rights") is not None:
        fail("L1E07_TRAINING_RIGHTS_UNEXPECTED")

    return {
        "capacity_authority_kind": authority_kind,
        "capacity_authority_provenance_sha256": authority_sha,
        "commercial_basis_sha256": commercial_sha,
        "runtime": {"runtime_id": runtime_id, "model_name": model_name, "model_version": model_version, "quality_profile": quality_profile, "artifact_sha256": artifact_sha},
        "training_rights_evidence_sha256": training_rights_sha,
    }


def evaluate_substitution(*, plan: Mapping[str, Any], manifest: Mapping[str, Any], repo_root: Path | str, private_root: Path | str) -> dict[str, Any]:
    repo = Path(repo_root).resolve()
    private = Path(private_root).resolve()
    p = validate_plan(plan)
    if manifest.get("schema_version") != 1 or manifest.get("evidence_state") != EVIDENCE_STATE:
        fail("L1E07_MANIFEST_SCHEMA")
    if manifest.get("parity_claim") != "NONE":
        fail("L1E07_PARITY_CLAIM_FORBIDDEN")
    route_id = req_str(manifest.get("route_id"), "route_id")
    route_kind = req_str(manifest.get("route_kind"), "route_kind").upper()
    replaced = req_str(manifest.get("replaced_route_id"), "replaced_route_id")
    if route_kind != p["route_kind"] or replaced != p["replaced_route_id"]:
        fail("L1E07_PLAN_MANIFEST_MISMATCH")
    if route_id == replaced:
        fail("L1E07_ROUTE_ID_REUSE_FORBIDDEN")

    adapter = req_map(manifest.get("adapter"), "adapter")
    adapter_path = safe_repo_file(repo, adapter.get("source_path"), adapter.get("source_sha256"), "adapter_source")
    adapter_surface = validate_adapter_surface(adapter_path, req_str(adapter.get("class_name"), "adapter.class_name"))

    if manifest.get("shared_app_contract_changed") is not False:
        fail("L1E07_SHARED_APP_CHANGE_FORBIDDEN")
    if manifest.get("provider_neutral_publication_contract_preserved") is not True:
        fail("L1E07_PROVIDER_NEUTRAL_CONTRACT_NOT_PRESERVED")

    prior = validate_prior_dispositions(manifest, route_kind, repo, private)
    invariants = validate_invariants(manifest, repo)
    route_specific = validate_route_specific(manifest, route_kind, repo, private)

    legacy_hosted_live_gate_compatible = route_kind == "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER"
    generic_live_authority_required = not legacy_hosted_live_gate_compatible

    identity_payload = {
        "domain": "l1-e07-fallback-substitution-v1",
        "substitution_id": p["substitution_id"], "route_id": route_id, "route_kind": route_kind, "replaced_route_id": replaced,
        "adapter_source_sha256": sha256_file(adapter_path), "adapter_class": adapter_surface["class_name"],
        "runtime": route_specific["runtime"], "capacity_authority_kind": route_specific["capacity_authority_kind"],
        "capacity_authority_provenance_sha256": route_specific["capacity_authority_provenance_sha256"],
        "commercial_basis_sha256": route_specific["commercial_basis_sha256"],
        "training_rights_evidence_sha256": route_specific["training_rights_evidence_sha256"],
        "prior_fallback_dispositions": prior, "invariants": invariants,
    }
    identity = canonical_sha(identity_payload)
    state = "READY_FOR_HQ_E07_SUBSTITUTION_REVIEW" if legacy_hosted_live_gate_compatible else "CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE"
    report = {
        "schema_version": 1, "tool_version": TOOL_VERSION, "evidence_kind": "PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE",
        "evidence_state": EVIDENCE_STATE, "conformance_state": state, "parity_claim": "NONE",
        "substitution_id": p["substitution_id"], "route_id": route_id, "route_kind": route_kind, "replaced_route_id": replaced,
        "fallback_order": list(FALLBACK_ORDER), "prior_fallback_dispositions": prior,
        "adapter": {**adapter_surface, "source_sha256": sha256_file(adapter_path)}, "runtime": route_specific["runtime"],
        "capacity_authority": {"kind": route_specific["capacity_authority_kind"], "provenance_sha256": route_specific["capacity_authority_provenance_sha256"]},
        "commercial_basis_sha256": route_specific["commercial_basis_sha256"], "training_rights_evidence_sha256": route_specific["training_rights_evidence_sha256"],
        "invariants": invariants,
        "compatibility": {"legacy_e05_e06_hosted_account_schema_compatible": legacy_hosted_live_gate_compatible, "generic_capacity_authority_live_gate_required": generic_live_authority_required, "shared_app_contract_changed": False, "provider_neutral_publication_contract_preserved": True},
        "substitution_identity_sha256": identity,
        "privacy": {"credential_values_emitted": False, "provider_account_ids_emitted": False, "private_paths_emitted": False, "private_contract_text_emitted": False, "training_data_emitted": False, "raw_audio_emitted": False},
        "parity_reason": "E07 proves engineering substitution conformance only. Any fallback route must still complete fresh real-audio/provider/current-iPhone/recovery evidence and HQ PARITY.",
    }
    report["e07_substitution_lock_sha256"] = canonical_sha({"identity": identity, "report": report})
    return report


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        return req_map(json.loads(path.read_text(encoding="utf-8")), str(path))
    except SubstitutionError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise SubstitutionError("L1E07_JSON_INVALID", str(path)) from exc


def atomic_dump(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False); f.write("\n"); f.flush(); os.fsync(f.fileno())
    os.replace(tmp, path)


def main(argv: Sequence[str] | None = None) -> int:
    import argparse
    import sys
    parser = argparse.ArgumentParser(description="Lane 1 E07 fallback substitution conformance")
    parser.add_argument("--repo-root", required=True); parser.add_argument("--private-root", required=True); parser.add_argument("--plan", required=True); parser.add_argument("--manifest", required=True); parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    try:
        report = evaluate_substitution(plan=load_json(Path(args.plan)), manifest=load_json(Path(args.manifest)), repo_root=args.repo_root, private_root=args.private_root)
        atomic_dump(Path(args.out), report)
        print(json.dumps({"status": "PASS", "conformance_state": report["conformance_state"], "lock": report["e07_substitution_lock_sha256"]}, sort_keys=True)); return 0
    except SubstitutionError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr); return 2


if __name__ == "__main__":
    raise SystemExit(main())
