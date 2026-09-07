from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = 1
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
EXIT_FAIL = 2
EXIT_EXTERNAL_INPUT_REQUIRED = 3
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
ENV_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")
MONEY_RE = re.compile(r"^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,12})?$")
TERMS_KINDS = ("commercial_use", "privacy_retention", "confidentiality", "output_use", "pricing")
DELETE_SEMANTICS = {"NOT_AVAILABLE", "SYNC_CONFIRMED", "ASYNC_CONFIRMED"}
BILLING_UNITS = {"AUDIO_SECOND", "AUDIO_MINUTE", "AUDIO_HOUR", "JOB", "CREDIT"}


class ApprovalError(ValueError):
    def __init__(self, code: str, message: str, *, exit_code: int = EXIT_FAIL):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message
        self.exit_code = exit_code


def req_map(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise ApprovalError("L1E01_SCHEMA_TYPE", f"{field} must be object")
    return value


def req_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ApprovalError("L1E01_SCHEMA_REQUIRED", f"{field} must be non-empty string")
    return value.strip()


def req_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise ApprovalError("L1E01_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def strict_keys(value: Mapping[str, Any], allowed: set[str], field: str) -> None:
    unknown = sorted(set(value) - allowed)
    if unknown:
        raise ApprovalError("L1E01_SCHEMA_UNKNOWN_FIELD", f"{field} has unknown fields: {','.join(unknown)}")


def sha256_text(value: Any, field: str) -> str:
    text = req_str(value, field).lower()
    text = text[7:] if text.startswith("sha256:") else text
    if not SHA_RE.fullmatch(text):
        raise ApprovalError("L1E01_SHA256_INVALID", f"{field} must be SHA-256 hex")
    return text


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(block)
    except OSError as exc:
        raise ApprovalError("L1E01_DOCUMENT_READ_FAILED", "approval document cannot be read") from exc
    return digest.hexdigest()


def sha256_json(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    return hashlib.sha256(raw).hexdigest()


def iso_date(value: Any, field: str) -> str:
    text = req_str(value, field)
    try:
        date.fromisoformat(text)
    except ValueError as exc:
        raise ApprovalError("L1E01_DATE_INVALID", f"{field} must be YYYY-MM-DD") from exc
    return text


def safe_relative(root: Path, value: Any, field: str) -> Path:
    rel = Path(req_str(value, field))
    if rel.is_absolute() or ".." in rel.parts:
        raise ApprovalError("L1E01_PATH_UNSAFE", f"{field} must be safe relative path")
    base = root.resolve()
    candidate = (base / rel).resolve()
    try:
        candidate.relative_to(base)
    except ValueError as exc:
        raise ApprovalError("L1E01_PATH_OUTSIDE_ROOT", f"{field} escapes documents root") from exc
    cursor = base
    for part in rel.parts:
        cursor /= part
        if cursor.is_symlink():
            raise ApprovalError("L1E01_PATH_SYMLINK", f"{field} may not traverse symlink")
    return candidate


def money(value: Any, field: str) -> str:
    text = req_str(value, field)
    if not MONEY_RE.fullmatch(text):
        raise ApprovalError("L1E01_PRICING_INVALID", f"{field} must be non-negative decimal string")
    try:
        number = Decimal(text)
    except InvalidOperation as exc:
        raise ApprovalError("L1E01_PRICING_INVALID", f"{field} invalid decimal") from exc
    if number < 0:
        raise ApprovalError("L1E01_PRICING_INVALID", f"{field} must be non-negative")
    return format(number, "f")


def validate_reference(raw: Any, kind: str, docs_root: Path, today: date) -> dict[str, Any]:
    ref = req_map(raw, f"terms.{kind}")
    strict_keys(ref, {"record_id", "document_path", "sha256", "effective_date", "expires_date"}, f"terms.{kind}")
    record_id = req_str(ref.get("record_id"), f"terms.{kind}.record_id")
    if record_id.upper().startswith("REPLACE_") or "PLACEHOLDER" in record_id.upper():
        raise ApprovalError("L1E01_TERMS_PLACEHOLDER", f"terms.{kind}.record_id is placeholder")
    effective = iso_date(ref.get("effective_date"), f"terms.{kind}.effective_date")
    if date.fromisoformat(effective) > today:
        raise ApprovalError("L1E01_TERMS_NOT_EFFECTIVE", f"terms.{kind} not effective yet")
    expires = None if ref.get("expires_date") is None else iso_date(ref.get("expires_date"), f"terms.{kind}.expires_date")
    if expires and date.fromisoformat(expires) < today:
        raise ApprovalError("L1E01_TERMS_EXPIRED", f"terms.{kind} expired")
    path = safe_relative(docs_root, ref.get("document_path"), f"terms.{kind}.document_path")
    if not path.is_file():
        raise ApprovalError("L1E01_DOCUMENT_MISSING", f"terms.{kind} approval document missing")
    expected = sha256_text(ref.get("sha256"), f"terms.{kind}.sha256")
    actual = sha256_file(path)
    if expected != actual:
        raise ApprovalError("L1E01_DOCUMENT_SHA_MISMATCH", f"terms.{kind} document SHA mismatch")
    return {
        "reference_id_sha256": hashlib.sha256(f"l1e01:{kind}:{record_id}".encode()).hexdigest(),
        "document_sha256": actual,
        "effective_date": effective,
        "expires_date": expires,
    }


def validate_models(provider: Mapping[str, Any], docs_root: Path) -> tuple[list[dict[str, Any]], str]:
    snap = req_map(provider.get("capability_snapshot"), "provider.capability_snapshot")
    strict_keys(snap, {"captured_at", "document_path", "sha256", "models"}, "provider.capability_snapshot")
    captured = req_str(snap.get("captured_at"), "provider.capability_snapshot.captured_at")
    try:
        datetime.fromisoformat(captured.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ApprovalError("L1E01_TIMESTAMP_INVALID", "provider.capability_snapshot.captured_at invalid") from exc
    path = safe_relative(docs_root, snap.get("document_path"), "provider.capability_snapshot.document_path")
    if not path.is_file():
        raise ApprovalError("L1E01_CAPABILITY_SNAPSHOT_MISSING", "provider capability snapshot document missing")
    snapshot_sha = sha256_text(snap.get("sha256"), "provider.capability_snapshot.sha256")
    if sha256_file(path) != snapshot_sha:
        raise ApprovalError("L1E01_CAPABILITY_SNAPSHOT_SHA_MISMATCH", "provider capability snapshot SHA mismatch")
    raw_models = snap.get("models")
    if not isinstance(raw_models, list) or not raw_models:
        raise ApprovalError("L1E01_MODEL_BINDING_REQUIRED", "provider.capability_snapshot.models must be non-empty array")
    normalized: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()
    for index, raw in enumerate(raw_models):
        item = req_map(raw, f"models[{index}]")
        strict_keys(item, {"model_name", "model_version", "quality_profile", "canonical_roles"}, f"models[{index}]")
        name = req_str(item.get("model_name"), f"models[{index}].model_name")
        version = req_str(item.get("model_version"), f"models[{index}].model_version")
        quality = req_str(item.get("quality_profile"), f"models[{index}].quality_profile")
        raw_roles = item.get("canonical_roles")
        if not isinstance(raw_roles, list) or not raw_roles:
            raise ApprovalError("L1E01_MODEL_ROLES_REQUIRED", f"models[{index}].canonical_roles required")
        roles = sorted({req_str(role, "canonical_roles[]").lower() for role in raw_roles})
        if len(roles) != len(raw_roles):
            raise ApprovalError("L1E01_MODEL_ROLES_DUPLICATE", f"models[{index}] has duplicate roles")
        key = (name, version, quality)
        if key in seen:
            raise ApprovalError("L1E01_MODEL_BINDING_DUPLICATE", "duplicate model/version/quality binding")
        seen.add(key)
        normalized.append({"model_name": name, "model_version": version, "quality_profile": quality, "canonical_roles": roles})
    normalized.sort(key=lambda row: (row["model_name"], row["model_version"], row["quality_profile"]))
    return normalized, snapshot_sha


def validate_operational(raw: Any) -> tuple[dict[str, Any], dict[str, Any]]:
    op = req_map(raw, "operational_terms")
    strict_keys(op, {
        "consumer_app_commercial_use_allowed", "input_confidential", "output_commercial_use_allowed",
        "output_export_to_end_user_allowed", "provider_training_on_user_content_allowed", "data_region",
        "uploaded_asset_retention_seconds", "output_url_ttl_seconds", "delete_api_available",
        "delete_confirmation_semantics", "pricing",
    }, "operational_terms")
    flags = {name: req_bool(op.get(name), f"operational_terms.{name}") for name in (
        "consumer_app_commercial_use_allowed", "input_confidential", "output_commercial_use_allowed", "output_export_to_end_user_allowed"
    )}
    if not all(flags.values()):
        raise ApprovalError("L1E01_COMMERCIAL_ROUTE_NOT_APPROVED", "required commercial/output rights are not approved")
    if req_bool(op.get("provider_training_on_user_content_allowed"), "operational_terms.provider_training_on_user_content_allowed"):
        raise ApprovalError("L1E01_PROVIDER_TRAINING_NOT_APPROVED", "provider training on user content must be disabled for this route")
    def seconds(name: str) -> int | None:
        value = op.get(name)
        if value is None:
            return None
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            raise ApprovalError("L1E01_RETENTION_INVALID", f"operational_terms.{name} must be positive integer or null")
        return value
    delete_api = req_bool(op.get("delete_api_available"), "operational_terms.delete_api_available")
    delete_sem = req_str(op.get("delete_confirmation_semantics"), "operational_terms.delete_confirmation_semantics").upper()
    if delete_sem not in DELETE_SEMANTICS or (delete_api and delete_sem == "NOT_AVAILABLE") or (not delete_api and delete_sem != "NOT_AVAILABLE"):
        raise ApprovalError("L1E01_DELETE_SEMANTICS_INVALID", "delete API and confirmation semantics disagree")
    pricing = req_map(op.get("pricing"), "operational_terms.pricing")
    strict_keys(pricing, {"currency", "billing_unit", "unit_price", "minimum_charge"}, "operational_terms.pricing")
    currency = req_str(pricing.get("currency"), "operational_terms.pricing.currency").upper()
    if len(currency) != 3 or not currency.isalpha():
        raise ApprovalError("L1E01_PRICING_INVALID", "currency must be three letters")
    unit = req_str(pricing.get("billing_unit"), "operational_terms.pricing.billing_unit").upper()
    if unit not in BILLING_UNITS:
        raise ApprovalError("L1E01_PRICING_INVALID", "unsupported billing_unit")
    pricing_norm = {"currency": currency, "billing_unit": unit, "unit_price": money(pricing.get("unit_price"), "unit_price"), "minimum_charge": money(pricing.get("minimum_charge"), "minimum_charge")}
    operational = {
        **flags,
        "provider_training_on_user_content_allowed": False,
        "data_region": req_str(op.get("data_region"), "operational_terms.data_region"),
        "uploaded_asset_retention_seconds": seconds("uploaded_asset_retention_seconds"),
        "output_url_ttl_seconds": seconds("output_url_ttl_seconds"),
        "delete_api_available": delete_api,
        "delete_confirmation_semantics": delete_sem,
    }
    return operational, pricing_norm


def file_contains(path: Path, secret: bytes) -> bool:
    overlap = max(0, len(secret) - 1)
    tail = b""
    try:
        with path.open("rb") as handle:
            while True:
                block = handle.read(1024 * 1024)
                if not block:
                    return False
                joined = tail + block
                if secret in joined:
                    return True
                tail = joined[-overlap:] if overlap else b""
    except OSError:
        return False


def scan_repository(repo_root: Path, secret: str) -> bool:
    needle = secret.encode()
    if len(needle) < 8:
        raise ApprovalError("L1E01_CREDENTIAL_TOO_SHORT", "credential value is unexpectedly short")
    root = repo_root.resolve()
    if not root.is_dir():
        raise ApprovalError("L1E01_REPOSITORY_ROOT_INVALID", "repository root missing")
    return any(file_contains(path, needle) for path in root.rglob("*") if path.is_file() and ".git" not in path.parts)


def validate_manifest(manifest: Mapping[str, Any], docs_root: Path, *, env: Mapping[str, str] | None = None, repo_root: Path | None = None, require_credentials: bool = True, today: date | None = None) -> dict[str, Any]:
    strict_keys(manifest, {"schema_version", "evidence_state", "approval_state", "provider", "credentials", "terms", "operational_terms"}, "manifest")
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise ApprovalError("L1E01_SCHEMA_VERSION", "unsupported schema_version")
    if manifest.get("evidence_state") != EVIDENCE_STATE:
        raise ApprovalError("L1E01_EVIDENCE_STATE", f"evidence_state must be {EVIDENCE_STATE}")
    if req_str(manifest.get("approval_state"), "approval_state").upper() != "APPROVED":
        raise ApprovalError("L1E01_APPROVAL_REQUIRED", "approval_state must be APPROVED")
    current_date = today or datetime.now(timezone.utc).date()

    provider = req_map(manifest.get("provider"), "provider")
    strict_keys(provider, {"provider_id", "provider_kind", "account_tier", "service_region", "capability_snapshot"}, "provider")
    models, capability_sha = validate_models(provider, docs_root)
    provider_out = {
        "provider_id": req_str(provider.get("provider_id"), "provider.provider_id"),
        "provider_kind": req_str(provider.get("provider_kind"), "provider.provider_kind"),
        "account_tier": req_str(provider.get("account_tier"), "provider.account_tier"),
        "service_region": req_str(provider.get("service_region"), "provider.service_region"),
        "capability_snapshot_sha256": capability_sha,
        "models": models,
    }

    creds = req_map(manifest.get("credentials"), "credentials")
    strict_keys(creds, {"environment_names", "server_side_only", "client_distribution_prohibited"}, "credentials")
    if not req_bool(creds.get("server_side_only"), "credentials.server_side_only"):
        raise ApprovalError("L1E01_SERVER_SIDE_SECRET_REQUIRED", "credentials must be server-side only")
    if not req_bool(creds.get("client_distribution_prohibited"), "credentials.client_distribution_prohibited"):
        raise ApprovalError("L1E01_CLIENT_SECRET_PROHIBITION_REQUIRED", "client credential distribution must be prohibited")
    raw_names = creds.get("environment_names")
    if not isinstance(raw_names, list) or not raw_names:
        raise ApprovalError("L1E01_CREDENTIAL_ENV_REQUIRED", "credentials.environment_names must be non-empty array")
    env_names: list[str] = []
    for raw in raw_names:
        name = req_str(raw, "credentials.environment_names[]")
        if not ENV_RE.fullmatch(name):
            raise ApprovalError("L1E01_CREDENTIAL_ENV_INVALID", f"invalid credential env name {name}")
        if name in env_names:
            raise ApprovalError("L1E01_CREDENTIAL_ENV_DUPLICATE", "duplicate credential env name")
        env_names.append(name)

    terms = req_map(manifest.get("terms"), "terms")
    strict_keys(terms, set(TERMS_KINDS), "terms")
    term_evidence = {kind: validate_reference(terms.get(kind), kind, docs_root, current_date) for kind in TERMS_KINDS}
    operational, pricing = validate_operational(manifest.get("operational_terms"))
    source_env = os.environ if env is None else env
    missing = sorted(name for name in env_names if not source_env.get(name))
    scan_state = "NOT_RUN"
    if repo_root is not None and not missing:
        for name in env_names:
            if scan_repository(repo_root, str(source_env[name])):
                raise ApprovalError("L1E01_SECRET_FOUND_IN_REPOSITORY", "credential value is present in repository content")
        scan_state = "PASS"
    elif repo_root is not None:
        scan_state = "PENDING_CREDENTIAL"

    policy_hash = sha256_json({"operational": operational, "pricing": pricing})
    identity = {"provider": provider_out, "terms": term_evidence, "operational_policy_sha256": policy_hash}
    report = {
        "schema_version": 1,
        "evidence_kind": "COMMERCIAL_ROUTE_APPROVAL",
        "evidence_state": EVIDENCE_STATE,
        "result": "READY_FOR_LIVE_PROVIDER_GATE" if not missing else "PENDING_EXTERNAL_CREDENTIAL",
        "parity_claim": "NONE",
        "provider": provider_out,
        "credential_preflight": {"environment_names": sorted(env_names), "all_present": not missing, "values_persisted": False, "server_side_only": True, "client_distribution_prohibited": True, "repository_exact_secret_scan": scan_state},
        "terms": term_evidence,
        "operational_policy": {
            "data_region": operational["data_region"],
            "uploaded_asset_retention_seconds": operational["uploaded_asset_retention_seconds"],
            "output_url_ttl_seconds": operational["output_url_ttl_seconds"],
            "delete_api_available": operational["delete_api_available"],
            "delete_confirmation_semantics": operational["delete_confirmation_semantics"],
            "provider_training_on_user_content_allowed": False,
            "commercial_route_flags": {key: True for key in ("consumer_app_commercial_use_allowed", "input_confidential", "output_commercial_use_allowed", "output_export_to_end_user_allowed")},
            "pricing_currency": pricing["currency"],
            "pricing_billing_unit": pricing["billing_unit"],
            "pricing_values_persisted": False,
            "pricing_config_sha256": sha256_json(pricing),
            "operational_policy_sha256": policy_hash,
        },
        "approval_manifest_identity_sha256": sha256_json(identity),
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    if require_credentials and missing:
        raise ApprovalError("L1E01_CREDENTIAL_ENV_MISSING", "required production credential environment variables are absent", exit_code=EXIT_EXTERNAL_INPUT_REQUIRED)
    return report


def load_json(path: Path) -> Mapping[str, Any]:
    try:
        return req_map(json.loads(path.read_text(encoding="utf-8")), "manifest")
    except ApprovalError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise ApprovalError("L1E01_MANIFEST_INVALID", "approval manifest cannot be read") from exc


def dump_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    tmp.replace(path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="L1-E01 commercial route approval and credential preflight")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--documents-root", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--repository-root")
    parser.add_argument("--allow-missing-credential", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = validate_manifest(load_json(Path(args.manifest)), Path(args.documents_root), repo_root=Path(args.repository_root) if args.repository_root else None, require_credentials=not args.allow_missing_credential)
        dump_json(Path(args.out), report)
        print(json.dumps({"status": "PASS", "result": report["result"]}, sort_keys=True))
        return 0
    except ApprovalError as exc:
        print(json.dumps({"status": "FAIL", "code": exc.code, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
