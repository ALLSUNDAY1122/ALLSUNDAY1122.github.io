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
"""
from __future__ import annotations

import json
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Protocol

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
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def load(self) -> dict[str, CancellationRecord]:
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
                if record.logical_job_id != key:
                    raise ValueError
                parsed[key] = record
        except (TypeError, ValueError) as exc:
            raise CancellationTruthError("SEP_CANCEL_REGISTRY_RECORD_INVALID") from exc
        return parsed

    def save(self, records: dict[str, CancellationRecord]) -> None:
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

    def request_cancel(self, logical_job_id: str) -> CancellationRecord:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        job = self.backend.get(logical_job_id)
        records = self.registry.load()
        record = records.get(logical_job_id)
        if record is None:
            record = CancellationRecord(logical_job_id=logical_job_id)
            records[logical_job_id] = record

        # Cancellation is idempotent. Once intent has been persisted, a repeated request must not
        # issue another provider cancellation call because provider cancellation idempotency is not
        # assumed by this lane.
        if record.cancel_requested:
            record.request_count += 1
            self.registry.save(records)
            return record

        record.cancel_requested = True
        record.request_count = 1
        record.output_disposition = "discard"
        record.logical_state = "cancel_requested"
        record.stable_error_code = "SEP_LOGICAL_CANCEL_REQUESTED"
        provider_task_id = getattr(job, "provider_task_id", None)
        record.provider_task_id = provider_task_id if isinstance(provider_task_id, str) else None

        # Persist intent BEFORE touching the provider. A process crash after this point cannot
        # resurrect output delivery on relaunch.
        self.registry.save(records)

        if record.provider_task_id is None:
            record.logical_state = "cancelled_unbound"
            record.upstream_cancel_state = "not_addressable"
            record.stable_error_code = "SEP_CANCELLED_WITHOUT_PROVIDER_TASK"
            self.registry.save(records)
            return record

        cancel_task = getattr(self.provider, "cancel_task", None)
        if not callable(cancel_task):
            record.logical_state = "cancelled_logical"
            record.upstream_cancel_state = "unsupported"
            record.stable_error_code = "SEP_CANCEL_UPSTREAM_NOT_SUPPORTED"
            self.registry.save(records)
            return record

        try:
            receipt = cancel_task(record.provider_task_id)
        except Exception as exc:
            record.logical_state = "cancelled_logical"
            record.upstream_cancel_state = "unknown_after_error"
            record.stable_error_code = _stable_error(exc, "SEP_CANCEL_UPSTREAM_REQUEST_FAILED")
            self.registry.save(records)
            return record

        if receipt not in _ALLOWED_UPSTREAM_RECEIPTS:
            record.logical_state = "cancelled_logical"
            record.upstream_cancel_state = "unknown_invalid_receipt"
            record.stable_error_code = "SEP_CANCEL_UPSTREAM_RECEIPT_INVALID"
            self.registry.save(records)
            return record

        if receipt == "confirmed":
            record.logical_state = "cancelled_upstream_confirmed"
            record.upstream_cancel_state = "confirmed"
            record.stable_error_code = "SEP_CANCEL_UPSTREAM_CONFIRMED"
        else:
            record.logical_state = "cancelled_logical"
            record.upstream_cancel_state = "requested"
            record.stable_error_code = "SEP_CANCEL_UPSTREAM_REQUESTED"
        self.registry.save(records)
        return record

    def observe(self, logical_job_id: str) -> dict[str, Any]:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        records = self.registry.load()
        cancellation = records.get(logical_job_id)
        if cancellation is None or not cancellation.cancel_requested:
            job = self.backend.observe(logical_job_id)
            return _normal_public_snapshot(job)

        # Logical cancellation remains authoritative even when the provider keeps working.
        # This is what prevents a ready-vs-cancel race from promoting outputs back to the user.
        if cancellation.provider_task_id is None:
            return _cancelled_public_snapshot(cancellation, fraction_complete=None)

        try:
            job = self.backend.observe(logical_job_id)
        except Exception as exc:
            cancellation.provider_phase_after_cancel = "unknown"
            cancellation.stable_error_code = _stable_error(exc, "SEP_CANCEL_OBSERVE_FAILED")
            records[logical_job_id] = cancellation
            self.registry.save(records)
            return _cancelled_public_snapshot(cancellation, fraction_complete=None)

        phase = _provider_phase(job)
        fraction = getattr(job, "fraction_complete", None)
        cancellation.provider_phase_after_cancel = phase

        if phase == "ready":
            cancellation.logical_state = "cancelled_provider_completed"
            cancellation.stable_error_code = "SEP_CANCEL_RACE_PROVIDER_COMPLETED_OUTPUT_DISCARDED"
        elif phase == "failed":
            cancellation.logical_state = "cancelled_provider_failed"
            cancellation.stable_error_code = (
                getattr(job, "stable_error_code", None) or "SEP_CANCELLED_PROVIDER_FAILED"
            )
        elif phase == "cancelled":
            cancellation.logical_state = "cancelled_upstream_confirmed"
            cancellation.upstream_cancel_state = "confirmed"
            cancellation.stable_error_code = "SEP_CANCEL_UPSTREAM_CONFIRMED"
        elif phase == "separating":
            if cancellation.upstream_cancel_state == "confirmed":
                cancellation.upstream_cancel_state = "confirmation_contradicted"
                cancellation.stable_error_code = "SEP_CANCEL_CONFIRMATION_CONTRADICTED"
            elif cancellation.upstream_cancel_state == "requested":
                cancellation.stable_error_code = "SEP_CANCEL_UPSTREAM_PENDING"
            elif cancellation.upstream_cancel_state == "unsupported":
                cancellation.stable_error_code = "SEP_CANCELLED_PROVIDER_MAY_CONTINUE"
        else:
            cancellation.stable_error_code = "SEP_CANCEL_PROVIDER_PHASE_UNKNOWN"

        records[logical_job_id] = cancellation
        self.registry.save(records)
        return _cancelled_public_snapshot(cancellation, fraction_complete=fraction)

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        cancellation = self.registry.load().get(logical_job_id)
        if cancellation is not None and cancellation.cancel_requested:
            raise CancellationTruthError("SEP_CANCELLED_OUTPUT_DISCARDED", retryable=False)
        return self.backend.collect_ready_outputs(logical_job_id)

    def get_cancellation(self, logical_job_id: str) -> CancellationRecord | None:
        logical_job_id = _validate_logical_job_id(logical_job_id)
        return self.registry.load().get(logical_job_id)


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
        # Existing Swift client can consume this canonical phase while ignoring the extra truth
        # object. The backend therefore preserves compatibility without pretending upstream stopped.
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


def _stable_error(exc: Exception, fallback: str) -> str:
    code = getattr(exc, "code", None)
    return code if isinstance(code, str) and code else fallback
