"""Truthful cancellation facade for production separation.

This lane-local server facade distinguishes a user's logical cancellation from any
provider-confirmed compute cancellation. It is intentionally provider-neutral and
does not require changes to the frozen Shared/App contracts.

The wrapped backend is expected to provide:
- get(logical_job_id)
- observe(logical_job_id)
- collect_ready_outputs(logical_job_id)

A provider may optionally expose cancel_task(provider_task_id) returning one of:
- "confirmed": upstream compute cancellation is authoritative.
- "accepted": cancellation was accepted/requested but completion is not authoritative yet.

Absence of cancel_task is treated as an explicit unsupported capability. No code path
claims upstream cancellation without authoritative provider evidence.

The cancellation registry is a single-host file authority. Registry read-modify-write
operations are serialized with POSIX flock, while a stable per-logical-job operation
lease linearizes cancel/observe/result across service instances. This prevents two
classes of false success: unrelated concurrent job updates cannot overwrite each
other, and an output collection cannot pass the cancellation check while a concurrent
cancel for the same logical job is being persisted.
"""
from __future__ import annotations

import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Protocol

SCHEMA_VERSION = 1
_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_ALLOWED_UPSTREAM_RECEIPTS = {"accepted", "confirmed"}


class CancellationTruthError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class SeparationBackend(Protocol):
    def get(self, logical_job_id: str) -> Any: ...
    def observe(self, logical_job_id: str) -> Any: ...
    def collect_ready_outputs(self, logical_job_id: str) -> Any: ...


@dataclass
class CancellationRecord:
    logical_job_id: str
    cancel_requested: bool = False
    request_count: int = 0
    logical_state: str = "active"
    upstream_cancel_state: str = "not_applicable"
    output_disposition: str = "keep"
    provider_task_id: str | None = None
    provider_phase_after_cancel: str | None = None
    stable_error_code: str | None = None


class AtomicCancellationRegistry:
    """Single-host atomic registry with serialized read-modify-write mutations."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def _locked(self):
        try:
            import fcntl
        except ImportError as exc:  # pragma: no cover - non-POSIX server must fail closed
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_LOCK_UNAVAILABLE", retryable=True) from exc
        try:
            handle = self.lock_path.open("a+b")
        except OSError as exc:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_LOCK_UNAVAILABLE", retryable=True) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise CancellationTruthError("SEP_CANCEL_REGISTRY_LOCK_UNAVAILABLE", retryable=True) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def load(self) -> dict[str, CancellationRecord]:
        with self._locked():
            return self._load_unlocked()

    def get(self, logical_job_id: str) -> CancellationRecord | None:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._locked():
            return self._load_unlocked().get(logical_job_id)

    def mutate(
        self,
        logical_job_id: str,
        operation: Callable[[CancellationRecord | None], CancellationRecord],
    ) -> CancellationRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._locked():
            records = self._load_unlocked()
            updated = operation(records.get(logical_job_id))
            _validate_record(updated)
            if updated.logical_job_id != logical_job_id:
                raise CancellationTruthError("SEP_CANCEL_REGISTRY_IDENTITY_MISMATCH")
            records[logical_job_id] = updated
            self._save_unlocked(records)
            return updated

    def _load_unlocked(self) -> dict[str, CancellationRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_CORRUPT") from exc
        if not isinstance(raw, dict) or raw.get("schema_version") != SCHEMA_VERSION:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_SCHEMA_INVALID")
        records = raw.get("records")
        if not isinstance(records, dict):
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORDS_INVALID")
        parsed: dict[str, CancellationRecord] = {}
        try:
            for key, value in records.items():
                if not isinstance(key, str) or not isinstance(value, dict):
                    raise TypeError
                record = CancellationRecord(**value)
                _validate_record(record)
                if record.logical_job_id != key:
                    raise ValueError
                parsed[key] = record
        except CancellationTruthError:
            raise
        except (TypeError, ValueError) as exc:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID") from exc
        return parsed

    def _save_unlocked(self, records: dict[str, CancellationRecord]) -> None:
        for key, record in records.items():
            _validate_record(record)
            if key != record.logical_job_id:
                raise CancellationTruthError("SEP_CANCEL_REGISTRY_IDENTITY_MISMATCH")
        payload = {
            "schema_version": SCHEMA_VERSION,
            "records": {key: asdict(value) for key, value in sorted(records.items())},
        }
        encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        tmp = self.path.with_name(self.path.name + ".tmp")
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
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_WRITE_FAILED", retryable=True) from exc


class TruthfulCancellationService:
    """Facade that makes logical cancellation authoritative without overstating provider state."""

    def __init__(
        self,
        *,
        backend: SeparationBackend,
        provider: Any,
        registry_path: str | Path,
    ):
        self.backend = backend
        self.provider = provider
        self.registry = AtomicCancellationRegistry(registry_path)
        self.operation_lock_root = self.registry.path.with_suffix(
            self.registry.path.suffix + ".job-locks"
        )
        try:
            self.operation_lock_root.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            raise CancellationTruthError("SEP_CANCEL_OPERATION_LOCK_UNAVAILABLE", retryable=True) from exc

    @contextmanager
    def _operation_lock(self, logical_job_id: str):
        logical_job_id = _validate_logical_job_id(logical_job_id)
        try:
            import fcntl
        except ImportError as exc:  # pragma: no cover - non-POSIX server must fail closed
            raise CancellationTruthError("SEP_CANCEL_OPERATION_LOCK_UNAVAILABLE", retryable=True) from exc
        lock_path = self.operation_lock_root / f"{logical_job_id}.lock"
        try:
            handle = lock_path.open("a+b")
        except OSError as exc:
            raise CancellationTruthError("SEP_CANCEL_OPERATION_LOCK_UNAVAILABLE", retryable=True) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise CancellationTruthError("SEP_CANCEL_OPERATION_LOCK_UNAVAILABLE", retryable=True) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def request_cancel(self, logical_job_id: str) -> CancellationRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._operation_lock(logical_job_id):
            existing = self.registry.get(logical_job_id)
            if existing is not None and existing.cancel_requested:
                return self.registry.mutate(
                    logical_job_id,
                    lambda record: _increment_repeated_request(record),
                )

            job = self.backend.get(logical_job_id)
            provider_task_id = getattr(job, "provider_task_id", None)
            provider_task_id = provider_task_id if isinstance(provider_task_id, str) else None

            def persist_intent(record: CancellationRecord | None) -> CancellationRecord:
                if record is None:
                    record = CancellationRecord(logical_job_id=logical_job_id)
                if record.cancel_requested:
                    return _increment_repeated_request(record)
                record.cancel_requested = True
                record.request_count = 1
                record.output_disposition = "discard"
                record.logical_state = "cancel_requested"
                record.stable_error_code = "SEP_LOGICAL_CANCEL_REQUESTED"
                record.provider_task_id = provider_task_id
                return record

            record = self.registry.mutate(logical_job_id, persist_intent)
            if record.request_count > 1:
                return record

            # Intent is durable before any provider side effect. The per-job operation lease remains
            # held while the provider call is in flight, so result collection in another service
            # instance cannot slip between the intent check and this authoritative mutation.
            if record.provider_task_id is None:
                return self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_cancel_outcome(
                        current,
                        logical_state="cancelled_unbound",
                        upstream_cancel_state="not_addressable",
                        stable_error_code="SEP_CANCELLED_WITHOUT_PROVIDER_TASK",
                    ),
                )

            cancel_task = getattr(self.provider, "cancel_task", None)
            if not callable(cancel_task):
                return self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_cancel_outcome(
                        current,
                        logical_state="cancelled_logical",
                        upstream_cancel_state="unsupported",
                        stable_error_code="SEP_CANCEL_UPSTREAM_NOT_SUPPORTED",
                    ),
                )

            try:
                receipt = cancel_task(record.provider_task_id)
            except Exception as exc:
                return self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_cancel_outcome(
                        current,
                        logical_state="cancelled_logical",
                        upstream_cancel_state="unknown_after_error",
                        stable_error_code=_stable_error(exc, "SEP_CANCEL_UPSTREAM_REQUEST_FAILED"),
                    ),
                )

            if receipt not in _ALLOWED_UPSTREAM_RECEIPTS:
                return self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_cancel_outcome(
                        current,
                        logical_state="cancelled_logical",
                        upstream_cancel_state="unknown_invalid_receipt",
                        stable_error_code="SEP_CANCEL_UPSTREAM_RECEIPT_INVALID",
                    ),
                )

            if receipt == "confirmed":
                return self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_cancel_outcome(
                        current,
                        logical_state="cancelled_upstream_confirmed",
                        upstream_cancel_state="confirmed",
                        stable_error_code="SEP_CANCEL_UPSTREAM_CONFIRMED",
                    ),
                )
            return self.registry.mutate(
                logical_job_id,
                lambda current: _set_cancel_outcome(
                    current,
                    logical_state="cancelled_logical",
                    upstream_cancel_state="requested",
                    stable_error_code="SEP_CANCEL_UPSTREAM_REQUESTED",
                ),
            )

    def observe(self, logical_job_id: str) -> dict[str, Any]:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._operation_lock(logical_job_id):
            cancellation = self.registry.get(logical_job_id)
            if cancellation is None or not cancellation.cancel_requested:
                job = self.backend.observe(logical_job_id)
                return _normal_public_snapshot(job)

            # Logical cancellation remains authoritative even when the provider keeps working.
            if cancellation.provider_task_id is None:
                return _cancelled_public_snapshot(cancellation, fraction_complete=None)

            try:
                job = self.backend.observe(logical_job_id)
            except Exception as exc:
                cancellation = self.registry.mutate(
                    logical_job_id,
                    lambda current: _set_observe_failure(current, exc),
                )
                return _cancelled_public_snapshot(cancellation, fraction_complete=None)

            phase = _provider_phase(job)
            fraction = getattr(job, "fraction_complete", None)
            cancellation = self.registry.mutate(
                logical_job_id,
                lambda current: _apply_cancelled_observation(current, phase, job),
            )
            return _cancelled_public_snapshot(cancellation, fraction_complete=fraction)

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        with self._operation_lock(logical_job_id):
            cancellation = self.registry.get(logical_job_id)
            if cancellation is not None and cancellation.cancel_requested:
                raise CancellationTruthError("SEP_CANCELLED_OUTPUT_DISCARDED", retryable=False)
            return self.backend.collect_ready_outputs(logical_job_id)

    def get_cancellation(self, logical_job_id: str) -> CancellationRecord | None:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        return self.registry.get(logical_job_id)


def _increment_repeated_request(record: CancellationRecord | None) -> CancellationRecord:
    if record is None or not record.cancel_requested:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_STATE_INVALID")
    record.request_count += 1
    return record


def _set_cancel_outcome(
    record: CancellationRecord | None,
    *,
    logical_state: str,
    upstream_cancel_state: str,
    stable_error_code: str,
) -> CancellationRecord:
    if record is None or not record.cancel_requested:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_STATE_INVALID")
    record.logical_state = logical_state
    record.upstream_cancel_state = upstream_cancel_state
    record.stable_error_code = stable_error_code
    return record


def _set_observe_failure(record: CancellationRecord | None, exc: Exception) -> CancellationRecord:
    if record is None or not record.cancel_requested:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_STATE_INVALID")
    record.provider_phase_after_cancel = "unknown"
    record.stable_error_code = _stable_error(exc, "SEP_CANCEL_OBSERVE_FAILED")
    return record


def _apply_cancelled_observation(
    record: CancellationRecord | None,
    phase: str,
    job: Any,
) -> CancellationRecord:
    if record is None or not record.cancel_requested:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_STATE_INVALID")
    record.provider_phase_after_cancel = phase
    if phase == "ready":
        record.logical_state = "cancelled_provider_completed"
        record.stable_error_code = "SEP_CANCEL_RACE_PROVIDER_COMPLETED_OUTPUT_DISCARDED"
    elif phase == "failed":
        record.logical_state = "cancelled_provider_failed"
        record.stable_error_code = getattr(job, "stable_error_code", None) or "SEP_CANCELLED_PROVIDER_FAILED"
    elif phase == "cancelled":
        record.logical_state = "cancelled_upstream_confirmed"
        record.upstream_cancel_state = "confirmed"
        record.stable_error_code = "SEP_CANCEL_UPSTREAM_CONFIRMED"
    elif phase == "separating":
        if record.upstream_cancel_state == "confirmed":
            record.upstream_cancel_state = "confirmation_contradicted"
            record.stable_error_code = "SEP_CANCEL_CONFIRMATION_CONTRADICTED"
        elif record.upstream_cancel_state == "requested":
            record.stable_error_code = "SEP_CANCEL_UPSTREAM_PENDING"
        elif record.upstream_cancel_state == "unsupported":
            record.stable_error_code = "SEP_CANCELLED_PROVIDER_MAY_CONTINUE"
    else:
        record.stable_error_code = "SEP_CANCEL_PROVIDER_PHASE_UNKNOWN"
    return record


def _normal_public_snapshot(job: Any) -> dict[str, Any]:
    return {
        "phase": _provider_phase(job),
        "fractionComplete": getattr(job, "fraction_complete", None),
        "retryable": bool(getattr(job, "retryable", False)),
        "stableErrorCode": getattr(job, "stable_error_code", None),
    }


def _cancelled_public_snapshot(
    record: CancellationRecord,
    *,
    fraction_complete: float | None,
) -> dict[str, Any]:
    return {
        "phase": "cancelled",
        "fractionComplete": fraction_complete,
        "retryable": True,
        "stableErrorCode": record.stable_error_code,
        "cancellationTruth": {
            "logicalCancelled": True,
            "logicalState": record.logical_state,
            "upstreamCancelState": record.upstream_cancel_state,
            "providerPhaseAfterCancel": record.provider_phase_after_cancel,
            "outputDisposition": record.output_disposition,
        },
    }


def _provider_phase(job: Any) -> str:
    phase = getattr(job, "provider_phase", None) or getattr(job, "state", None)
    return phase if isinstance(phase, str) and phase else "unknown"


def _validate_logical_job_id(value: str) -> str:
    if not isinstance(value, str) or not _LOGICAL_JOB_ID.fullmatch(value):
        raise CancellationTruthError("SEP_CANCEL_LOGICAL_JOB_ID_INVALID")
    return value


def _validate_record(record: CancellationRecord) -> None:
    _validate_logical_job_id(record.logical_job_id)
    if not isinstance(record.cancel_requested, bool):
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    if isinstance(record.request_count, bool) or not isinstance(record.request_count, int) or record.request_count < 0:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    if record.cancel_requested and record.request_count < 1:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    if record.provider_task_id is not None and not isinstance(record.provider_task_id, str):
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    for value in (
        record.logical_state,
        record.upstream_cancel_state,
        record.output_disposition,
    ):
        if not isinstance(value, str) or not value:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    if record.provider_phase_after_cancel is not None and not isinstance(record.provider_phase_after_cancel, str):
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")
    if record.stable_error_code is not None and not isinstance(record.stable_error_code, str):
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID")


def _stable_error(exc: Exception, fallback: str) -> str:
    code = getattr(exc, "code", None)
    return code if isinstance(code, str) and code else fallback


def _fsync_directory(path: Path) -> None:
    try:
        fd = os.open(str(path), os.O_RDONLY)
    except OSError as exc:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_WRITE_FAILED", retryable=True) from exc
    try:
        os.fsync(fd)
    except OSError as exc:
        raise CancellationTruthError("SEP_CANCEL_REGISTRY_WRITE_FAILED", retryable=True) from exc
    finally:
        os.close(fd)
