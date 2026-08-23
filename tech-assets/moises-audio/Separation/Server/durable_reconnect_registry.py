"""A16 durable reconnect/relaunch registry for Lane 1 separation processing.

This module composes the existing A06/A07/A08/A14 server seams. It does not replace provider
idempotency or cancellation truth. It persists enough stable logical identity to reconstruct a
processing job after process/app relaunch and always prefers authoritative server/provider state
over a stale non-terminal cache.

Raw idempotency keys, source paths, filenames, signed output URLs and audio bytes are never written
to this registry. The logical job ID plus SHA-256 of the idempotency key are persisted instead.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Any, Callable, Iterable, Protocol

SCHEMA_VERSION = 1
_SAFE_ID = re.compile(r"^[A-Za-z0-9._:-]{1,160}$")
_SAFE_MODEL = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_ALLOWED_PHASES = {
    "queued",
    "separating",
    "recovering",
    "ready",
    "failed",
    "cancelled",
    "unknown",
    "deleted",
}
_PROVIDER_NOT_FOUND_CODES = {
    "SEP_JOB_NOT_FOUND",
    "SEP_PROVIDER_JOB_NOT_FOUND",
    "AUDIOSHAKE_HTTP_404",
    "SEP_OUTPUT_HTTP_404",
}


class DurableRecoveryError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class ProcessingBackend(Protocol):
    def start(
        self,
        *,
        source_path: str | Path,
        project_id: str,
        asset_id: str,
        models: Iterable[str],
        idempotency_key: str,
    ) -> Any: ...

    def get(self, logical_job_id: str) -> Any: ...
    def observe(self, logical_job_id: str) -> Any: ...
    def collect_ready_outputs(self, logical_job_id: str) -> Any: ...


@dataclass(frozen=True)
class RecoverySnapshot:
    revision: int
    logical_phase: str
    provider_phase: str | None
    fraction_complete: float | None
    retryable: bool
    stable_error_code: str | None
    source: str
    outputs_committed: bool
    observed_at_epoch_ms: int
    previous_phase: str | None = None


@dataclass(frozen=True)
class DurableJobRecord:
    logical_job_id: str
    project_id: str
    asset_id: str
    requested_profile_id: str
    requested_models: tuple[str, ...]
    idempotency_key_hash: str
    request_fingerprint: str | None
    source_sha256: str | None
    provider_asset_id: str | None
    provider_task_id: str | None
    state: str
    recovery_attempts: int
    created_at_epoch_ms: int
    updated_at_epoch_ms: int
    deleted_at_epoch_ms: int | None
    last_authoritative_snapshot: RecoverySnapshot


class AtomicDurableJobRegistry:
    """Atomic, process-safe JSON registry.

    Linux/macOS production paths require advisory file locking. If flock is unavailable the registry
    fails closed rather than silently allowing independent writers to lose recovery state.
    """

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def _locked(self):
        try:
            import fcntl
        except ImportError as exc:  # pragma: no cover - non-POSIX deployment gate
            raise DurableRecoveryError("SEP_RECOVERY_LOCK_UNAVAILABLE", retryable=True) from exc
        with self.lock_path.open("a+b") as handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def get(self, logical_job_id: str) -> DurableJobRecord | None:
        _validate_logical_job_id(logical_job_id)
        with self._locked():
            return self._load_unlocked().get(logical_job_id)

    def list_records(self) -> tuple[DurableJobRecord, ...]:
        with self._locked():
            return tuple(self._load_unlocked()[key] for key in sorted(self._load_unlocked()))

    def put(self, record: DurableJobRecord) -> DurableJobRecord:
        _validate_record(record)
        with self._locked():
            records = self._load_unlocked()
            records[record.logical_job_id] = record
            self._save_unlocked(records)
            return record

    def mutate(
        self,
        logical_job_id: str,
        operation: Callable[[DurableJobRecord | None], DurableJobRecord],
    ) -> DurableJobRecord:
        _validate_logical_job_id(logical_job_id)
        with self._locked():
            records = self._load_unlocked()
            updated = operation(records.get(logical_job_id))
            _validate_record(updated)
            if updated.logical_job_id != logical_job_id:
                raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_IDENTITY_MISMATCH")
            records[logical_job_id] = updated
            self._save_unlocked(records)
            return updated

    def _load_unlocked(self) -> dict[str, DurableJobRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_CORRUPT") from exc
        if not isinstance(raw, dict) or raw.get("schema_version") != SCHEMA_VERSION:
            raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_SCHEMA_INVALID")
        jobs = raw.get("jobs")
        if not isinstance(jobs, dict):
            raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_JOBS_INVALID")
        parsed: dict[str, DurableJobRecord] = {}
        try:
            for key, value in jobs.items():
                if not isinstance(key, str) or not isinstance(value, dict):
                    raise TypeError
                snapshot_raw = value.get("last_authoritative_snapshot")
                if not isinstance(snapshot_raw, dict):
                    raise TypeError
                copy = dict(value)
                copy["requested_models"] = tuple(copy.get("requested_models", ()))
                copy["last_authoritative_snapshot"] = RecoverySnapshot(**snapshot_raw)
                record = DurableJobRecord(**copy)
                _validate_record(record)
                if key != record.logical_job_id:
                    raise ValueError
                parsed[key] = record
        except (TypeError, ValueError, DurableRecoveryError) as exc:
            raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_RECORD_INVALID") from exc
        return parsed

    def _save_unlocked(self, records: dict[str, DurableJobRecord]) -> None:
        for key, record in records.items():
            _validate_record(record)
            if key != record.logical_job_id:
                raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_IDENTITY_MISMATCH")
        payload = {
            "schema_version": SCHEMA_VERSION,
            "jobs": {key: asdict(value) for key, value in sorted(records.items())},
        }
        encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        tmp = self.path.with_name(self.path.name + ".tmp")
        try:
            with tmp.open("w", encoding="utf-8") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, self.path)
        except OSError as exc:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass
            raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_WRITE_FAILED", retryable=True) from exc


class DurableReconnectService:
    """Relaunch-safe facade over the production backend.

    Precedence on recovery:
      deleted tombstone > logical cancellation > local committed outputs > provider observe >
      local non-terminal cache.

    A provider/network failure therefore never turns a stale cached `ready`/`separating` phase into
    a current authoritative phase. The current phase becomes `unknown` while the prior phase remains
    attached as `previous_phase` for diagnostics only.
    """

    def __init__(
        self,
        *,
        backend: ProcessingBackend,
        registry_path: str | Path,
        cancellation_service: Any | None = None,
        now_epoch_ms: Callable[[], int] | None = None,
        finalize_ready_outputs: bool = True,
    ):
        self.backend = backend
        self.registry = AtomicDurableJobRegistry(registry_path)
        self.cancellation_service = cancellation_service
        self.now_epoch_ms = now_epoch_ms or _system_epoch_ms
        self.finalize_ready_outputs = finalize_ready_outputs

    def begin_intent(
        self,
        *,
        project_id: str,
        asset_id: str,
        requested_profile_id: str,
        models: Iterable[str],
        idempotency_key: str,
    ) -> DurableJobRecord:
        project_id = _validate_safe_id(project_id, "SEP_RECOVERY_PROJECT_ID_INVALID")
        asset_id = _validate_safe_id(asset_id, "SEP_RECOVERY_ASSET_ID_INVALID")
        requested_profile_id = _validate_safe_id(
            requested_profile_id, "SEP_RECOVERY_PROFILE_ID_INVALID"
        )
        selected_models = _normalize_models(models)
        logical_job_id, key_hash = _logical_identity(idempotency_key)
        now = self.now_epoch_ms()

        def operation(existing: DurableJobRecord | None) -> DurableJobRecord:
            if existing is not None:
                if existing.state == "deleted":
                    raise DurableRecoveryError("SEP_RECOVERY_JOB_TOMBSTONED")
                if (
                    existing.project_id != project_id
                    or existing.asset_id != asset_id
                    or existing.requested_profile_id != requested_profile_id
                    or existing.requested_models != selected_models
                    or existing.idempotency_key_hash != key_hash
                ):
                    raise DurableRecoveryError("SEP_RECOVERY_INTENT_CONFLICT")
                return existing
            snapshot = RecoverySnapshot(
                revision=1,
                logical_phase="queued",
                provider_phase=None,
                fraction_complete=0.0,
                retryable=True,
                stable_error_code=None,
                source="local_intent",
                outputs_committed=False,
                observed_at_epoch_ms=now,
            )
            return DurableJobRecord(
                logical_job_id=logical_job_id,
                project_id=project_id,
                asset_id=asset_id,
                requested_profile_id=requested_profile_id,
                requested_models=selected_models,
                idempotency_key_hash=key_hash,
                request_fingerprint=None,
                source_sha256=None,
                provider_asset_id=None,
                provider_task_id=None,
                state="intent",
                recovery_attempts=0,
                created_at_epoch_ms=now,
                updated_at_epoch_ms=now,
                deleted_at_epoch_ms=None,
                last_authoritative_snapshot=snapshot,
            )

        return self.registry.mutate(logical_job_id, operation)

    def start(
        self,
        *,
        source_path: str | Path,
        project_id: str,
        asset_id: str,
        requested_profile_id: str,
        models: Iterable[str],
        idempotency_key: str,
    ) -> Any:
        intent = self.begin_intent(
            project_id=project_id,
            asset_id=asset_id,
            requested_profile_id=requested_profile_id,
            models=models,
            idempotency_key=idempotency_key,
        )
        try:
            job = self.backend.start(
                source_path=source_path,
                project_id=project_id,
                asset_id=asset_id,
                models=intent.requested_models,
                idempotency_key=idempotency_key,
            )
        except Exception:
            # A06 persists upload/start ambiguity before surfacing errors. Bind that server record
            # when it exists so a relaunch can reconcile it without issuing a blind second create.
            try:
                existing = self.backend.get(intent.logical_job_id)
            except Exception:
                raise
            self._bind_backend_job(intent.logical_job_id, existing)
            raise
        self._bind_backend_job(intent.logical_job_id, job)
        return job

    def recover(self, logical_job_id: str) -> RecoverySnapshot:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        record = self.registry.get(logical_job_id)
        if record is None:
            raise DurableRecoveryError("SEP_RECOVERY_JOB_NOT_REGISTERED")
        if record.state == "deleted":
            return record.last_authoritative_snapshot

        record = self._increment_recovery_attempt(record)

        try:
            job = self.backend.get(logical_job_id)
        except Exception as exc:
            if record.request_fingerprint is None:
                return self._save_snapshot(
                    record,
                    logical_phase="unknown",
                    provider_phase=None,
                    fraction_complete=None,
                    retryable=True,
                    stable_error_code="SEP_RECOVERY_BACKEND_NOT_STARTED",
                    source="local_intent",
                    outputs_committed=False,
                )
            return self._save_unknown_from_error(
                record,
                exc,
                missing_code="SEP_RECOVERY_BACKEND_RECORD_MISSING",
                default_code="SEP_RECOVERY_BACKEND_UNAVAILABLE",
            )

        record = self._bind_backend_job(logical_job_id, job)

        cancellation = self._cancellation_record(logical_job_id)
        if cancellation is not None and bool(getattr(cancellation, "cancel_requested", False)):
            return self._recover_cancelled(record)

        if bool(getattr(job, "outputs_committed", False)):
            return self._save_snapshot(
                record,
                logical_phase="ready",
                provider_phase=_phase(job),
                fraction_complete=1.0,
                retryable=False,
                stable_error_code=None,
                source="server_committed_outputs",
                outputs_committed=True,
            )

        state = _phase(job)
        if state in {"failed", "upload_failed"}:
            return self._save_snapshot(
                record,
                logical_phase="failed",
                provider_phase=getattr(job, "provider_phase", None),
                fraction_complete=_fraction(job),
                retryable=bool(getattr(job, "retryable", False)),
                stable_error_code=getattr(job, "stable_error_code", None) or "SEP_RECOVERY_SERVER_FAILED",
                source="server_terminal",
                outputs_committed=False,
            )

        job = self._reconcile_if_needed(record, job)
        record = self.registry.get(logical_job_id) or record
        if getattr(job, "provider_task_id", None) is None:
            state = _phase(job)
            if state in {
                "start_reconciliation_unresolved",
                "start_reconciliation_error",
                "start_reconciliation_unsupported",
                "duplicate_provider_tasks_detected",
            }:
                retryable = False
                code = getattr(job, "stable_error_code", None) or "SEP_RECOVERY_PROVIDER_TASK_UNRESOLVED"
            else:
                retryable = True
                code = "SEP_RECOVERY_INTERRUPTED_BEFORE_PROVIDER_BIND"
            return self._save_snapshot(
                record,
                logical_phase="unknown",
                provider_phase=getattr(job, "provider_phase", None),
                fraction_complete=_fraction(job),
                retryable=retryable,
                stable_error_code=code,
                source="server_registry",
                outputs_committed=False,
            )

        try:
            observed = self.backend.observe(logical_job_id)
        except Exception as exc:
            return self._save_unknown_from_error(
                record,
                exc,
                missing_code="SEP_RECOVERY_PROVIDER_JOB_MISSING",
                default_code="SEP_RECOVERY_AUTHORITATIVE_STATE_UNAVAILABLE",
            )

        record = self._bind_backend_job(logical_job_id, observed)
        phase = _phase(observed)
        if bool(getattr(observed, "outputs_committed", False)):
            return self._save_snapshot(
                record,
                logical_phase="ready",
                provider_phase=phase,
                fraction_complete=1.0,
                retryable=False,
                stable_error_code=None,
                source="server_committed_outputs",
                outputs_committed=True,
            )
        if phase == "ready":
            if self.finalize_ready_outputs:
                try:
                    committed = self.backend.collect_ready_outputs(logical_job_id)
                except Exception as exc:
                    return self._save_snapshot(
                        record,
                        logical_phase="recovering",
                        provider_phase="ready",
                        fraction_complete=1.0,
                        retryable=bool(getattr(exc, "retryable", True)),
                        stable_error_code=_error_code(exc, "SEP_RECOVERY_READY_COPY_PENDING"),
                        source="provider_ready_local_copy_pending",
                        outputs_committed=False,
                    )
                record = self._bind_backend_job(logical_job_id, committed)
                return self._save_snapshot(
                    record,
                    logical_phase="ready",
                    provider_phase="ready",
                    fraction_complete=1.0,
                    retryable=False,
                    stable_error_code=None,
                    source="server_committed_outputs",
                    outputs_committed=True,
                )
            return self._save_snapshot(
                record,
                logical_phase="recovering",
                provider_phase="ready",
                fraction_complete=1.0,
                retryable=True,
                stable_error_code="SEP_RECOVERY_READY_COPY_REQUIRED",
                source="provider",
                outputs_committed=False,
            )
        if phase == "failed":
            return self._save_snapshot(
                record,
                logical_phase="failed",
                provider_phase="failed",
                fraction_complete=_fraction(observed),
                retryable=bool(getattr(observed, "retryable", False)),
                stable_error_code=getattr(observed, "stable_error_code", None) or "SEP_RECOVERY_PROVIDER_FAILED",
                source="provider",
                outputs_committed=False,
            )
        if phase == "cancelled":
            return self._save_snapshot(
                record,
                logical_phase="cancelled",
                provider_phase="cancelled",
                fraction_complete=_fraction(observed),
                retryable=True,
                stable_error_code=getattr(observed, "stable_error_code", None),
                source="provider",
                outputs_committed=False,
            )
        if phase == "separating":
            return self._save_snapshot(
                record,
                logical_phase="separating",
                provider_phase="separating",
                fraction_complete=_fraction(observed),
                retryable=True,
                stable_error_code=getattr(observed, "stable_error_code", None),
                source="provider",
                outputs_committed=False,
            )
        return self._save_snapshot(
            record,
            logical_phase="unknown",
            provider_phase=phase,
            fraction_complete=_fraction(observed),
            retryable=True,
            stable_error_code="SEP_RECOVERY_PROVIDER_PHASE_UNKNOWN",
            source="provider",
            outputs_committed=False,
        )

    def mark_deleted(self, logical_job_id: str) -> RecoverySnapshot:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        now = self.now_epoch_ms()

        def operation(existing: DurableJobRecord | None) -> DurableJobRecord:
            if existing is None:
                raise DurableRecoveryError("SEP_RECOVERY_JOB_NOT_REGISTERED")
            if existing.state == "deleted":
                return existing
            snapshot = _next_snapshot(
                existing,
                logical_phase="deleted",
                provider_phase=None,
                fraction_complete=None,
                retryable=False,
                stable_error_code="SEP_RECOVERY_JOB_DELETED",
                source="server_tombstone",
                outputs_committed=False,
                observed_at_epoch_ms=now,
            )
            return replace(
                existing,
                state="deleted",
                provider_asset_id=None,
                provider_task_id=None,
                deleted_at_epoch_ms=now,
                updated_at_epoch_ms=now,
                last_authoritative_snapshot=snapshot,
            )

        return self.registry.mutate(logical_job_id, operation).last_authoritative_snapshot

    def recover_all(self) -> dict[str, RecoverySnapshot]:
        result: dict[str, RecoverySnapshot] = {}
        for record in self.registry.list_records():
            result[record.logical_job_id] = self.recover(record.logical_job_id)
        return result

    def get_record(self, logical_job_id: str) -> DurableJobRecord | None:
        return self.registry.get(logical_job_id)

    def _bind_backend_job(self, logical_job_id: str, job: Any) -> DurableJobRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        now = self.now_epoch_ms()

        def operation(existing: DurableJobRecord | None) -> DurableJobRecord:
            if existing is None:
                raise DurableRecoveryError("SEP_RECOVERY_JOB_NOT_REGISTERED")
            if existing.state == "deleted":
                raise DurableRecoveryError("SEP_RECOVERY_JOB_TOMBSTONED")
            _verify_backend_identity(existing, job)
            request_fingerprint = getattr(job, "request_fingerprint", None)
            source_sha256 = getattr(job, "source_sha256", None)
            if not isinstance(request_fingerprint, str) or not _SHA256.fullmatch(request_fingerprint):
                raise DurableRecoveryError("SEP_RECOVERY_REQUEST_FINGERPRINT_INVALID")
            if not isinstance(source_sha256, str) or not _SHA256.fullmatch(source_sha256):
                raise DurableRecoveryError("SEP_RECOVERY_SOURCE_SHA_INVALID")
            snapshot = _next_snapshot(
                existing,
                logical_phase=_local_phase(job),
                provider_phase=getattr(job, "provider_phase", None),
                fraction_complete=_fraction(job),
                retryable=bool(getattr(job, "retryable", False)),
                stable_error_code=getattr(job, "stable_error_code", None),
                source="server_registry",
                outputs_committed=bool(getattr(job, "outputs_committed", False)),
                observed_at_epoch_ms=now,
            )
            return replace(
                existing,
                request_fingerprint=request_fingerprint,
                source_sha256=source_sha256,
                provider_asset_id=_optional_id(getattr(job, "provider_asset_id", None)),
                provider_task_id=_optional_id(getattr(job, "provider_task_id", None)),
                state="bound",
                updated_at_epoch_ms=now,
                last_authoritative_snapshot=snapshot,
            )

        return self.registry.mutate(logical_job_id, operation)

    def _increment_recovery_attempt(self, record: DurableJobRecord) -> DurableJobRecord:
        now = self.now_epoch_ms()
        return self.registry.mutate(
            record.logical_job_id,
            lambda current: replace(
                _require_same_record(record, current),
                recovery_attempts=_require_same_record(record, current).recovery_attempts + 1,
                updated_at_epoch_ms=now,
            ),
        )

    def _reconcile_if_needed(self, record: DurableJobRecord, job: Any) -> Any:
        if getattr(job, "provider_task_id", None) is not None:
            return job
        if _phase(job) not in {
            "start_ambiguous",
            "start_reconciliation_unresolved",
            "start_reconciliation_error",
            "start_reconciliation_unsupported",
        }:
            return job
        reconcile = getattr(self.backend, "reconcile_ambiguous_start", None)
        if not callable(reconcile):
            return job
        try:
            reconciled = reconcile(record.logical_job_id)
        except Exception as exc:
            # Reconciliation may persist a more precise server record before raising (for example
            # duplicate provider tasks). Bind it if possible; recovery must never issue create here.
            try:
                persisted = self.backend.get(record.logical_job_id)
                self._bind_backend_job(record.logical_job_id, persisted)
            except Exception:
                pass
            raise DurableRecoveryError(
                _error_code(exc, "SEP_RECOVERY_RECONCILIATION_FAILED"),
                retryable=False,
            ) from exc
        self._bind_backend_job(record.logical_job_id, reconciled)
        return reconciled

    def _cancellation_record(self, logical_job_id: str) -> Any | None:
        service = self.cancellation_service
        if service is None:
            return None
        getter = getattr(service, "get_cancellation", None)
        return getter(logical_job_id) if callable(getter) else None

    def _recover_cancelled(self, record: DurableJobRecord) -> RecoverySnapshot:
        service = self.cancellation_service
        if service is None:
            raise DurableRecoveryError("SEP_RECOVERY_CANCEL_SERVICE_MISSING")
        try:
            public = service.observe(record.logical_job_id)
        except Exception as exc:
            return self._save_snapshot(
                record,
                logical_phase="cancelled",
                provider_phase=None,
                fraction_complete=None,
                retryable=True,
                stable_error_code=_error_code(exc, "SEP_RECOVERY_CANCEL_OBSERVE_FAILED"),
                source="server_logical_cancel",
                outputs_committed=False,
            )
        truth = public.get("cancellationTruth") if isinstance(public, dict) else None
        provider_phase = truth.get("providerPhaseAfterCancel") if isinstance(truth, dict) else None
        fraction = public.get("fractionComplete") if isinstance(public, dict) else None
        code = public.get("stableErrorCode") if isinstance(public, dict) else None
        return self._save_snapshot(
            record,
            logical_phase="cancelled",
            provider_phase=provider_phase if isinstance(provider_phase, str) else None,
            fraction_complete=float(fraction) if isinstance(fraction, (int, float)) else None,
            retryable=True,
            stable_error_code=code if isinstance(code, str) else None,
            source="server_logical_cancel",
            outputs_committed=False,
        )

    def _save_unknown_from_error(
        self,
        record: DurableJobRecord,
        exc: Exception,
        *,
        missing_code: str,
        default_code: str,
    ) -> RecoverySnapshot:
        code = _error_code(exc, default_code)
        missing = _is_not_found(code, getattr(exc, "status", None))
        return self._save_snapshot(
            record,
            logical_phase="unknown",
            provider_phase=None,
            fraction_complete=None,
            retryable=False if missing else bool(getattr(exc, "retryable", True)),
            stable_error_code=missing_code if missing else code,
            source="provider_missing" if missing else "authority_unavailable",
            outputs_committed=False,
        )

    def _save_snapshot(
        self,
        record: DurableJobRecord,
        *,
        logical_phase: str,
        provider_phase: str | None,
        fraction_complete: float | None,
        retryable: bool,
        stable_error_code: str | None,
        source: str,
        outputs_committed: bool,
    ) -> RecoverySnapshot:
        now = self.now_epoch_ms()

        def operation(current: DurableJobRecord | None) -> DurableJobRecord:
            current = _require_same_record(record, current)
            snapshot = _next_snapshot(
                current,
                logical_phase=logical_phase,
                provider_phase=provider_phase,
                fraction_complete=fraction_complete,
                retryable=retryable,
                stable_error_code=stable_error_code,
                source=source,
                outputs_committed=outputs_committed,
                observed_at_epoch_ms=now,
            )
            return replace(current, updated_at_epoch_ms=now, last_authoritative_snapshot=snapshot)

        return self.registry.mutate(record.logical_job_id, operation).last_authoritative_snapshot


def _require_same_record(
    expected: DurableJobRecord, current: DurableJobRecord | None
) -> DurableJobRecord:
    if current is None:
        raise DurableRecoveryError("SEP_RECOVERY_JOB_NOT_REGISTERED")
    if current.logical_job_id != expected.logical_job_id:
        raise DurableRecoveryError("SEP_RECOVERY_REGISTRY_IDENTITY_MISMATCH")
    if current.state == "deleted" and expected.state != "deleted":
        raise DurableRecoveryError("SEP_RECOVERY_JOB_TOMBSTONED")
    return current


def _verify_backend_identity(record: DurableJobRecord, job: Any) -> None:
    if getattr(job, "logical_job_id", None) != record.logical_job_id:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_LOGICAL_ID_MISMATCH")
    if getattr(job, "project_id", None) != record.project_id:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_PROJECT_MISMATCH")
    if getattr(job, "asset_id", None) != record.asset_id:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_ASSET_MISMATCH")
    if getattr(job, "idempotency_key_hash", None) != record.idempotency_key_hash:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_IDEMPOTENCY_MISMATCH")
    models = tuple(getattr(job, "requested_models", ()))
    if tuple(dict.fromkeys(models)) != record.requested_models:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_MODELS_MISMATCH")
    if record.request_fingerprint is not None and getattr(job, "request_fingerprint", None) != record.request_fingerprint:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_REQUEST_MISMATCH")
    if record.source_sha256 is not None and getattr(job, "source_sha256", None) != record.source_sha256:
        raise DurableRecoveryError("SEP_RECOVERY_BACKEND_SOURCE_MISMATCH")


def _validate_record(record: DurableJobRecord) -> None:
    _validate_logical_job_id(record.logical_job_id)
    _validate_safe_id(record.project_id, "SEP_RECOVERY_PROJECT_ID_INVALID")
    _validate_safe_id(record.asset_id, "SEP_RECOVERY_ASSET_ID_INVALID")
    _validate_safe_id(record.requested_profile_id, "SEP_RECOVERY_PROFILE_ID_INVALID")
    if not record.requested_models or tuple(dict.fromkeys(record.requested_models)) != record.requested_models:
        raise DurableRecoveryError("SEP_RECOVERY_MODELS_INVALID")
    if any(not _SAFE_MODEL.fullmatch(value) for value in record.requested_models):
        raise DurableRecoveryError("SEP_RECOVERY_MODELS_INVALID")
    if not _SHA256.fullmatch(record.idempotency_key_hash):
        raise DurableRecoveryError("SEP_RECOVERY_IDEMPOTENCY_HASH_INVALID")
    for value, code in (
        (record.request_fingerprint, "SEP_RECOVERY_REQUEST_FINGERPRINT_INVALID"),
        (record.source_sha256, "SEP_RECOVERY_SOURCE_SHA_INVALID"),
    ):
        if value is not None and not _SHA256.fullmatch(value):
            raise DurableRecoveryError(code)
    _optional_id(record.provider_asset_id)
    _optional_id(record.provider_task_id)
    if record.state not in {"intent", "bound", "deleted"}:
        raise DurableRecoveryError("SEP_RECOVERY_RECORD_STATE_INVALID")
    if not isinstance(record.recovery_attempts, int) or record.recovery_attempts < 0:
        raise DurableRecoveryError("SEP_RECOVERY_ATTEMPTS_INVALID")
    for value in (record.created_at_epoch_ms, record.updated_at_epoch_ms):
        if not isinstance(value, int) or value < 0:
            raise DurableRecoveryError("SEP_RECOVERY_TIMESTAMP_INVALID")
    if record.updated_at_epoch_ms < record.created_at_epoch_ms:
        raise DurableRecoveryError("SEP_RECOVERY_TIMESTAMP_INVALID")
    if record.state == "deleted":
        if record.deleted_at_epoch_ms is None:
            raise DurableRecoveryError("SEP_RECOVERY_DELETE_TIMESTAMP_MISSING")
    elif record.deleted_at_epoch_ms is not None:
        raise DurableRecoveryError("SEP_RECOVERY_DELETE_TIMESTAMP_INVALID")
    _validate_snapshot(record.last_authoritative_snapshot)


def _validate_snapshot(snapshot: RecoverySnapshot) -> None:
    if not isinstance(snapshot.revision, int) or snapshot.revision <= 0:
        raise DurableRecoveryError("SEP_RECOVERY_SNAPSHOT_REVISION_INVALID")
    if snapshot.logical_phase not in _ALLOWED_PHASES:
        raise DurableRecoveryError("SEP_RECOVERY_SNAPSHOT_PHASE_INVALID")
    if snapshot.provider_phase is not None and not isinstance(snapshot.provider_phase, str):
        raise DurableRecoveryError("SEP_RECOVERY_PROVIDER_PHASE_INVALID")
    if snapshot.fraction_complete is not None:
        if not isinstance(snapshot.fraction_complete, (int, float)) or not 0.0 <= float(snapshot.fraction_complete) <= 1.0:
            raise DurableRecoveryError("SEP_RECOVERY_FRACTION_INVALID")
    if not isinstance(snapshot.observed_at_epoch_ms, int) or snapshot.observed_at_epoch_ms < 0:
        raise DurableRecoveryError("SEP_RECOVERY_TIMESTAMP_INVALID")
    if snapshot.previous_phase is not None and snapshot.previous_phase not in _ALLOWED_PHASES:
        raise DurableRecoveryError("SEP_RECOVERY_PREVIOUS_PHASE_INVALID")


def _next_snapshot(
    record: DurableJobRecord,
    *,
    logical_phase: str,
    provider_phase: str | None,
    fraction_complete: float | None,
    retryable: bool,
    stable_error_code: str | None,
    source: str,
    outputs_committed: bool,
    observed_at_epoch_ms: int,
) -> RecoverySnapshot:
    previous = record.last_authoritative_snapshot.logical_phase
    snapshot = RecoverySnapshot(
        revision=record.last_authoritative_snapshot.revision + 1,
        logical_phase=logical_phase,
        provider_phase=provider_phase,
        fraction_complete=fraction_complete,
        retryable=retryable,
        stable_error_code=stable_error_code,
        source=source,
        outputs_committed=outputs_committed,
        observed_at_epoch_ms=observed_at_epoch_ms,
        previous_phase=previous,
    )
    _validate_snapshot(snapshot)
    return snapshot


def _logical_identity(idempotency_key: str) -> tuple[str, str]:
    if not isinstance(idempotency_key, str) or not idempotency_key or "\r" in idempotency_key or "\n" in idempotency_key:
        raise DurableRecoveryError("SEP_RECOVERY_IDEMPOTENCY_KEY_INVALID")
    encoded = idempotency_key.encode("utf-8")
    key_hash = hashlib.sha256(encoded).hexdigest()
    logical_job_id = hashlib.sha256(b"lane1:" + encoded).hexdigest()[:32]
    return logical_job_id, key_hash


def _normalize_models(models: Iterable[str]) -> tuple[str, ...]:
    try:
        selected = tuple(dict.fromkeys(models))
    except TypeError as exc:
        raise DurableRecoveryError("SEP_RECOVERY_MODELS_INVALID") from exc
    if not selected or any(not isinstance(value, str) or not _SAFE_MODEL.fullmatch(value) for value in selected):
        raise DurableRecoveryError("SEP_RECOVERY_MODELS_INVALID")
    return selected


def _validate_safe_id(value: str, code: str) -> str:
    if not isinstance(value, str) or not _SAFE_ID.fullmatch(value):
        raise DurableRecoveryError(code)
    return value


def _validate_logical_job_id(value: str) -> str:
    if not isinstance(value, str) or not _LOGICAL_JOB_ID.fullmatch(value):
        raise DurableRecoveryError("SEP_RECOVERY_LOGICAL_JOB_ID_INVALID")
    return value


def _optional_id(value: Any) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str) or not _SAFE_ID.fullmatch(value):
        raise DurableRecoveryError("SEP_RECOVERY_PROVIDER_ID_INVALID")
    return value


def _phase(job: Any) -> str:
    phase = getattr(job, "provider_phase", None) or getattr(job, "state", None)
    return phase if isinstance(phase, str) and phase else "unknown"


def _local_phase(job: Any) -> str:
    if bool(getattr(job, "outputs_committed", False)):
        return "ready"
    phase = _phase(job)
    if phase in {"failed", "upload_failed"}:
        return "failed"
    if phase == "cancelled":
        return "cancelled"
    if phase in {"separating", "ready"}:
        return "separating" if phase == "ready" else phase
    return "queued"


def _fraction(job: Any) -> float | None:
    value = getattr(job, "fraction_complete", None)
    return float(value) if isinstance(value, (int, float)) and 0.0 <= float(value) <= 1.0 else None


def _error_code(exc: Exception, fallback: str) -> str:
    code = getattr(exc, "code", None)
    return code if isinstance(code, str) and code else fallback


def _is_not_found(code: str, status: Any) -> bool:
    return code in _PROVIDER_NOT_FOUND_CODES or status == 404 or code.endswith("_HTTP_404")


def _system_epoch_ms() -> int:
    import time
    return int(time.time() * 1000)
