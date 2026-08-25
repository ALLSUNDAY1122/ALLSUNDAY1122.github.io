"""Privacy-safe retention/deletion enforcement for Lane 1 separation processing.

This module owns only separation/processing-controlled data. It never deletes an app/library
source file outside ``artifact_root``. Vendor deletion is capability-driven and fail-closed:
an unsupported or ambiguous provider response is never reported as confirmed erasure.

AudioShake retention defaults reflect public developer documentation observed 2026-08-23:
uploaded Assets expire after 72 hours; Task output download links expire after one hour.
The current public developer index documents no Asset/Task DELETE endpoint, so those defaults
are expiry evidence only, not a claim that task metadata/content is synchronously erased.

The file-backed privacy registry is single-host only. Every read-modify-write mutation is
serialized with POSIX flock and committed by fsync + atomic replace. Multi-host independent
writers still require a shared transactional authority and are rejected by mutation_topology.
"""
from __future__ import annotations

import json
import os
import re
import shutil
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Callable

SCHEMA_VERSION = 1
AUDIOSHAKE_ASSET_TTL_SECONDS = 72 * 60 * 60
AUDIOSHAKE_OUTPUT_LINK_TTL_SECONDS = 60 * 60
_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_SAFE_PROVIDER_ID = re.compile(r"^[A-Za-z0-9._:-]{1,200}$")
_SAFE_ERROR = re.compile(r"^[A-Z0-9_.:-]{1,200}$")
_ALLOWED_DIAGNOSTIC_KEYS = {
    "state",
    "stable_error_code",
    "fraction_complete",
    "retryable",
    "attempt",
    "elapsed_ms",
    "source_bytes",
    "output_bytes",
    "cost_units",
}
_PROVIDER_DELETE_RECEIPTS = {"accepted", "confirmed", "not_found"}
_PROVIDER_INFLIGHT_STATE = "unknown_after_inflight"


class PrivacyRetentionError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


@dataclass(frozen=True)
class RetentionPolicy:
    vendor_asset_ttl_seconds: int | None
    vendor_output_link_ttl_seconds: int | None
    local_policy: str = "until_project_delete"
    local_ttl_seconds: int | None = None

    def validate(self) -> None:
        if self.local_policy not in {"until_project_delete", "explicit_expiry", "manual_delete"}:
            raise PrivacyRetentionError("SEP_PRIVACY_LOCAL_POLICY_INVALID")
        for value, code in (
            (self.vendor_asset_ttl_seconds, "SEP_PRIVACY_VENDOR_ASSET_TTL_INVALID"),
            (self.vendor_output_link_ttl_seconds, "SEP_PRIVACY_VENDOR_OUTPUT_TTL_INVALID"),
            (self.local_ttl_seconds, "SEP_PRIVACY_LOCAL_TTL_INVALID"),
        ):
            if value is not None and (not isinstance(value, int) or value <= 0):
                raise PrivacyRetentionError(code)
        if self.local_policy == "explicit_expiry" and self.local_ttl_seconds is None:
            raise PrivacyRetentionError("SEP_PRIVACY_LOCAL_TTL_REQUIRED")
        if self.local_policy != "explicit_expiry" and self.local_ttl_seconds is not None:
            raise PrivacyRetentionError("SEP_PRIVACY_LOCAL_TTL_UNEXPECTED")


def audioshake_documented_policy(*, local_policy: str = "until_project_delete", local_ttl_seconds: int | None = None) -> RetentionPolicy:
    policy = RetentionPolicy(
        vendor_asset_ttl_seconds=AUDIOSHAKE_ASSET_TTL_SECONDS,
        vendor_output_link_ttl_seconds=AUDIOSHAKE_OUTPUT_LINK_TTL_SECONDS,
        local_policy=local_policy,
        local_ttl_seconds=local_ttl_seconds,
    )
    policy.validate()
    return policy


@dataclass
class PrivacyRecord:
    logical_job_id: str
    provider_asset_id_hash: str | None
    provider_task_id_hash: str | None
    created_at_epoch: int
    vendor_asset_expires_at_epoch: int | None
    vendor_output_links_expire_at_epoch: int | None
    local_policy: str
    local_expires_at_epoch: int | None
    local_delete_requested: bool = False
    local_delete_confirmed: bool = False
    local_delete_reason: str | None = None
    provider_asset_delete_state: str = "not_requested"
    provider_task_delete_state: str = "not_requested"
    provider_delete_requested: bool = False
    delete_requested_at_epoch: int | None = None
    diagnostics: list[dict[str, Any]] = field(default_factory=list)


class AtomicPrivacyRegistry:
    """Single-host atomic JSON registry with full read-modify-write serialization."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def _locked(self):
        try:
            import fcntl
        except ImportError as exc:  # pragma: no cover - non-POSIX deployment must fail closed
            raise PrivacyRetentionError("SEP_PRIVACY_LOCK_UNAVAILABLE", retryable=True) from exc
        try:
            handle = self.lock_path.open("a+b")
        except OSError as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_LOCK_UNAVAILABLE", retryable=True) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise PrivacyRetentionError("SEP_PRIVACY_LOCK_UNAVAILABLE", retryable=True) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def load(self) -> dict[str, PrivacyRecord]:
        with self._locked():
            return self._load_unlocked()

    def get(self, logical_job_id: str) -> PrivacyRecord | None:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._locked():
            return self._load_unlocked().get(logical_job_id)

    def mutate(
        self,
        logical_job_id: str,
        operation: Callable[[PrivacyRecord | None], PrivacyRecord],
    ) -> PrivacyRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._locked():
            records = self._load_unlocked()
            updated = operation(records.get(logical_job_id))
            _validate_record(updated)
            if updated.logical_job_id != logical_job_id:
                raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_IDENTITY_MISMATCH")
            records[logical_job_id] = updated
            self._save_unlocked(records)
            return updated

    def _load_unlocked(self) -> dict[str, PrivacyRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_CORRUPT") from exc
        if not isinstance(raw, dict) or raw.get("schema_version") != SCHEMA_VERSION:
            raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_SCHEMA_INVALID")
        records = raw.get("records")
        if not isinstance(records, dict):
            raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_RECORDS_INVALID")
        parsed: dict[str, PrivacyRecord] = {}
        try:
            for key, value in records.items():
                if not isinstance(key, str) or not isinstance(value, dict):
                    raise TypeError
                record = PrivacyRecord(**value)
                _validate_record(record)
                if record.logical_job_id != key:
                    raise ValueError
                parsed[key] = record
        except (TypeError, ValueError, PrivacyRetentionError) as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_RECORD_INVALID") from exc
        return parsed

    def _save_unlocked(self, records: dict[str, PrivacyRecord]) -> None:
        for key, record in records.items():
            _validate_record(record)
            if key != record.logical_job_id:
                raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_IDENTITY_MISMATCH")
        payload = {
            "schema_version": SCHEMA_VERSION,
            "records": {key: asdict(value) for key, value in sorted(records.items())},
        }
        tmp = self.path.with_name(self.path.name + ".tmp")
        encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        try:
            with tmp.open("w", encoding="utf-8") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, self.path)
            _fsync_directory(self.path.parent)
        except OSError as exc:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass
            raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_WRITE_FAILED", retryable=True) from exc


class PrivacyRetentionService:
    def __init__(
        self,
        *,
        artifact_root: str | Path,
        registry_path: str | Path,
        provider: Any,
        now_epoch: Callable[[], int] | None = None,
    ):
        self.artifact_root = Path(artifact_root).resolve()
        self.artifact_root.mkdir(parents=True, exist_ok=True)
        self.registry = AtomicPrivacyRegistry(registry_path)
        self.provider = provider
        self.now_epoch = now_epoch or (lambda: int(__import__("time").time()))

    def register(
        self,
        *,
        logical_job_id: str,
        provider_asset_id: str | None,
        provider_task_id: str | None,
        policy: RetentionPolicy,
        created_at_epoch: int | None = None,
    ) -> PrivacyRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        policy.validate()
        created = self.now_epoch() if created_at_epoch is None else _positive_epoch(created_at_epoch)
        asset_hash = _hash_provider_id(provider_asset_id)
        task_hash = _hash_provider_id(provider_task_id)

        def operation(existing: PrivacyRecord | None) -> PrivacyRecord:
            if existing is not None:
                if (
                    existing.provider_asset_id_hash != asset_hash
                    or existing.provider_task_id_hash != task_hash
                    or existing.local_policy != policy.local_policy
                ):
                    raise PrivacyRetentionError("SEP_PRIVACY_REGISTRATION_CONFLICT")
                return existing
            return PrivacyRecord(
                logical_job_id=logical_job_id,
                provider_asset_id_hash=asset_hash,
                provider_task_id_hash=task_hash,
                created_at_epoch=created,
                vendor_asset_expires_at_epoch=_add_ttl(created, policy.vendor_asset_ttl_seconds),
                vendor_output_links_expire_at_epoch=_add_ttl(created, policy.vendor_output_link_ttl_seconds),
                local_policy=policy.local_policy,
                local_expires_at_epoch=_add_ttl(created, policy.local_ttl_seconds),
            )

        return self.registry.mutate(logical_job_id, operation)

    def record_diagnostic(self, logical_job_id: str, fields: dict[str, Any]) -> PrivacyRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        sanitized = _sanitize_diagnostic(fields)

        def operation(existing: PrivacyRecord | None) -> PrivacyRecord:
            record = _require_existing_record(existing)
            record.diagnostics.append(sanitized)
            if len(record.diagnostics) > 32:
                record.diagnostics = record.diagnostics[-32:]
            return record

        return self.registry.mutate(logical_job_id, operation)

    def request_delete(
        self,
        logical_job_id: str,
        *,
        provider_asset_id: str | None = None,
        provider_task_id: str | None = None,
        reason: str = "user_delete",
        delete_provider: bool = True,
    ) -> PrivacyRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        if reason not in {"user_delete", "account_delete", "retention_expired", "cancel_cleanup"}:
            raise PrivacyRetentionError("SEP_PRIVACY_DELETE_REASON_INVALID")

        def persist_intent(existing: PrivacyRecord | None) -> PrivacyRecord:
            record = _require_existing_record(existing)
            if not record.local_delete_requested:
                record.local_delete_requested = True
                record.local_delete_reason = reason
                record.delete_requested_at_epoch = self.now_epoch()
            return record

        self.registry.mutate(logical_job_id, persist_intent)
        self._delete_local_artifacts(logical_job_id)

        def confirm_local(existing: PrivacyRecord | None) -> PrivacyRecord:
            record = _require_existing_record(existing)
            record.local_delete_confirmed = True
            return record

        current = self.registry.mutate(logical_job_id, confirm_local)
        if not delete_provider:
            return current

        should_contact = {"value": False}
        asset_input_hash = _hash_provider_id(provider_asset_id)
        task_input_hash = _hash_provider_id(provider_task_id)

        def reserve_provider(existing: PrivacyRecord | None) -> PrivacyRecord:
            record = _require_existing_record(existing)
            if record.provider_delete_requested:
                return record
            record.provider_delete_requested = True
            should_contact["value"] = True
            record.provider_asset_delete_state = _reserved_provider_state(
                expected_hash=record.provider_asset_id_hash,
                supplied_hash=asset_input_hash,
            )
            record.provider_task_delete_state = _reserved_provider_state(
                expected_hash=record.provider_task_id_hash,
                supplied_hash=task_input_hash,
            )
            return record

        reserved = self.registry.mutate(logical_job_id, reserve_provider)
        if not should_contact["value"]:
            return reserved

        asset_state = self._delete_provider_object(
            method_name="delete_asset",
            object_id=provider_asset_id,
            expected_hash=reserved.provider_asset_id_hash,
            unsupported_state="unsupported_expiry_only",
        )
        task_state = self._delete_provider_object(
            method_name="delete_task",
            object_id=provider_task_id,
            expected_hash=reserved.provider_task_id_hash,
            unsupported_state="unsupported_unknown_retention",
        )

        def finish_provider(existing: PrivacyRecord | None) -> PrivacyRecord:
            record = _require_existing_record(existing)
            record.provider_asset_delete_state = asset_state
            record.provider_task_delete_state = task_state
            return record

        return self.registry.mutate(logical_job_id, finish_provider)

    def sweep_expired(self) -> tuple[str, ...]:
        now = self.now_epoch()
        candidates = tuple(
            record.logical_job_id
            for record in self.registry.load().values()
            if record.local_policy == "explicit_expiry"
            and record.local_expires_at_epoch is not None
            and now >= record.local_expires_at_epoch
            and not record.local_delete_confirmed
        )
        deleted: list[str] = []
        for logical_job_id in candidates:
            should_delete = {"value": False}

            def reserve(existing: PrivacyRecord | None) -> PrivacyRecord:
                record = _require_existing_record(existing)
                if (
                    record.local_policy == "explicit_expiry"
                    and record.local_expires_at_epoch is not None
                    and now >= record.local_expires_at_epoch
                    and not record.local_delete_confirmed
                ):
                    if not record.local_delete_requested:
                        record.local_delete_requested = True
                        record.local_delete_reason = "retention_expired"
                        record.delete_requested_at_epoch = now
                    should_delete["value"] = True
                return record

            self.registry.mutate(logical_job_id, reserve)
            if not should_delete["value"]:
                continue
            self._delete_local_artifacts(logical_job_id)

            def confirm(existing: PrivacyRecord | None) -> PrivacyRecord:
                record = _require_existing_record(existing)
                record.local_delete_confirmed = True
                return record

            self.registry.mutate(logical_job_id, confirm)
            deleted.append(logical_job_id)
        return tuple(deleted)

    def snapshot(self, logical_job_id: str) -> dict[str, Any]:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        record = _require_existing_record(self.registry.get(logical_job_id))
        now = self.now_epoch()
        asset_expired = (
            record.vendor_asset_expires_at_epoch is not None and now >= record.vendor_asset_expires_at_epoch
        )
        output_links_expired = (
            record.vendor_output_links_expire_at_epoch is not None
            and now >= record.vendor_output_links_expire_at_epoch
        )
        provider_erasure_complete = (
            record.provider_asset_delete_state in {"confirmed", "not_found", "expired"}
            and record.provider_task_delete_state in {"confirmed", "not_found"}
        )
        return {
            "logicalJobID": logical_job_id,
            "localDeleteConfirmed": record.local_delete_confirmed,
            "localPolicy": record.local_policy,
            "vendorAssetExpiredByDocumentedTTL": asset_expired,
            "vendorOutputLinksExpiredByDocumentedTTL": output_links_expired,
            "providerAssetDeleteState": (
                "expired" if asset_expired and record.provider_asset_delete_state == "not_requested"
                else record.provider_asset_delete_state
            ),
            "providerTaskDeleteState": record.provider_task_delete_state,
            "providerErasureComplete": provider_erasure_complete,
            "overallPrivacyDeletionComplete": record.local_delete_confirmed and provider_erasure_complete,
            "diagnosticEventCount": len(record.diagnostics),
            "parityState": "NON_PARITY_EVIDENCE_ONLY",
        }

    def _delete_local_artifacts(self, logical_job_id: str) -> None:
        target = self._artifact_directory(logical_job_id)
        if target.exists():
            try:
                shutil.rmtree(target)
            except OSError as exc:
                raise PrivacyRetentionError("SEP_PRIVACY_LOCAL_DELETE_FAILED", retryable=True) from exc
        if target.exists():
            raise PrivacyRetentionError("SEP_PRIVACY_LOCAL_DELETE_UNCONFIRMED", retryable=True)

    def _artifact_directory(self, logical_job_id: str) -> Path:
        target = (self.artifact_root / logical_job_id).resolve()
        try:
            relative = target.relative_to(self.artifact_root)
        except ValueError as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_ARTIFACT_PATH_UNSAFE") from exc
        if len(relative.parts) != 1 or relative.name != logical_job_id:
            raise PrivacyRetentionError("SEP_PRIVACY_ARTIFACT_PATH_UNSAFE")
        return target

    def _delete_provider_object(
        self,
        *,
        method_name: str,
        object_id: str | None,
        expected_hash: str | None,
        unsupported_state: str,
    ) -> str:
        if expected_hash is None:
            return "not_applicable"
        if object_id is None or _hash_provider_id(object_id) != expected_hash:
            return "identifier_unavailable"
        method = getattr(self.provider, method_name, None)
        if not callable(method):
            return unsupported_state
        try:
            receipt = method(object_id)
        except Exception:
            return "unknown_after_error"
        if receipt not in _PROVIDER_DELETE_RECEIPTS:
            return "unknown_invalid_receipt"
        return receipt


def _reserved_provider_state(*, expected_hash: str | None, supplied_hash: str | None) -> str:
    if expected_hash is None:
        return "not_applicable"
    if supplied_hash != expected_hash:
        return "identifier_unavailable"
    return _PROVIDER_INFLIGHT_STATE


def _sanitize_diagnostic(fields: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(fields, dict) or not fields:
        raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_INVALID")
    unknown = set(fields) - _ALLOWED_DIAGNOSTIC_KEYS
    if unknown:
        raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_KEY_FORBIDDEN")
    sanitized: dict[str, Any] = {}
    for key, value in fields.items():
        if key in {"fraction_complete", "elapsed_ms", "source_bytes", "output_bytes", "cost_units", "attempt"}:
            if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
                raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_VALUE_INVALID")
            sanitized[key] = value
        elif key == "retryable":
            if not isinstance(value, bool):
                raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_VALUE_INVALID")
            sanitized[key] = value
        elif key in {"state", "stable_error_code"}:
            if not isinstance(value, str) or not _SAFE_ERROR.fullmatch(value):
                raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_VALUE_INVALID")
            sanitized[key] = value
        else:
            raise PrivacyRetentionError("SEP_PRIVACY_DIAGNOSTIC_KEY_FORBIDDEN")
    return sanitized


def _hash_provider_id(value: str | None) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str) or not _SAFE_PROVIDER_ID.fullmatch(value):
        raise PrivacyRetentionError("SEP_PRIVACY_PROVIDER_ID_INVALID")
    return __import__("hashlib").sha256(value.encode("utf-8")).hexdigest()


def _validate_logical_job_id(value: str) -> str:
    if not isinstance(value, str) or not _LOGICAL_JOB_ID.fullmatch(value):
        raise PrivacyRetentionError("SEP_PRIVACY_LOGICAL_JOB_ID_INVALID")
    return value


def _positive_epoch(value: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise PrivacyRetentionError("SEP_PRIVACY_EPOCH_INVALID")
    return value


def _add_ttl(epoch: int, ttl: int | None) -> int | None:
    return None if ttl is None else epoch + ttl


def _require_existing_record(record: PrivacyRecord | None) -> PrivacyRecord:
    if record is None:
        raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
    return record


def _validate_record(record: PrivacyRecord) -> None:
    if not isinstance(record, PrivacyRecord):
        raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_RECORD_INVALID")
    _validate_logical_job_id(record.logical_job_id)
    if record.local_policy not in {"until_project_delete", "explicit_expiry", "manual_delete"}:
        raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_RECORD_INVALID")
    if not isinstance(record.diagnostics, list):
        raise PrivacyRetentionError("SEP_PRIVACY_REGISTRY_RECORD_INVALID")


def _fsync_directory(path: Path) -> None:
    flags = getattr(os, "O_DIRECTORY", 0) | os.O_RDONLY
    fd = os.open(path, flags)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
