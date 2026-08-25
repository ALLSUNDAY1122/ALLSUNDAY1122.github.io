"""Provider deletion reconciliation for Lane 1 privacy retention.

NON-PARITY safety layer. It never blindly replays a provider delete after an
ambiguous/in-flight external side effect. Only a separately observed,
hash-bound provider state may resolve that ambiguity.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path

from privacy_retention import AtomicPrivacyRegistry, PrivacyRetentionError

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A29-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_OBJECT_KINDS = {"asset", "task"}
_SOURCE_KINDS = {"provider_api", "provider_console", "provider_support", "documented_expiry"}
_OBSERVED_STATES = {"confirmed", "not_found", "present", "unknown", "expired"}
_ERASURE_TERMINAL = {"confirmed", "not_found", "expired"}
_STATE_MAP = {
    "confirmed": "confirmed",
    "not_found": "not_found",
    "present": "reconciled_present",
    "unknown": "reconciled_unknown",
    "expired": "expired",
}


@dataclass(frozen=True)
class ProviderDeletionObservation:
    logical_job_id: str
    object_kind: str
    object_id_hash: str
    observed_state: str
    source_kind: str
    authority_ref_sha256: str
    observed_at_epoch: int

    def validate(self) -> None:
        if not _JOB_ID.fullmatch(self.logical_job_id):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_JOB_ID_INVALID")
        if self.object_kind not in _OBJECT_KINDS:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_KIND_INVALID")
        if not _SHA256.fullmatch(self.object_id_hash):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_HASH_INVALID")
        if self.observed_state not in _OBSERVED_STATES:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_STATE_INVALID")
        if self.source_kind not in _SOURCE_KINDS:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_SOURCE_INVALID")
        if not _SHA256.fullmatch(self.authority_ref_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_AUTHORITY_REF_INVALID")
        if not isinstance(self.observed_at_epoch, int) or isinstance(self.observed_at_epoch, bool) or self.observed_at_epoch <= 0:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_EPOCH_INVALID")
        if self.observed_state in {"confirmed", "not_found"} and self.source_kind == "documented_expiry":
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_SOURCE_INSUFFICIENT")
        if self.observed_state == "expired" and not (
            self.object_kind == "asset" and self.source_kind == "documented_expiry"
        ):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_EXPIRY_SCOPE_INVALID")

    @property
    def receipt_sha256(self) -> str:
        self.validate()
        return hashlib.sha256(
            json.dumps(asdict(self), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        ).hexdigest()


class AtomicDeletionReconciliationLedger:
    """Single-host durable, idempotent ledger of hashed reconciliation observations."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def _locked(self):
        try:
            import fcntl
        except ImportError as exc:  # pragma: no cover
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LOCK_UNAVAILABLE", retryable=True) from exc
        try:
            handle = self.lock_path.open("a+b")
        except OSError as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LOCK_UNAVAILABLE", retryable=True) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LOCK_UNAVAILABLE", retryable=True) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def append(self, observation: ProviderDeletionObservation) -> str:
        observation.validate()
        receipt = observation.receipt_sha256
        with self._locked():
            payload = self._load_unlocked()
            events = payload["events"]
            if receipt not in events:
                events[receipt] = {
                    "logical_job_id": observation.logical_job_id,
                    "object_kind": observation.object_kind,
                    "object_id_hash": observation.object_id_hash,
                    "observed_state": observation.observed_state,
                    "source_kind": observation.source_kind,
                    "authority_ref_sha256": observation.authority_ref_sha256,
                    "observed_at_epoch": observation.observed_at_epoch,
                    "application_state": "observed_not_applied",
                }
                self._save_unlocked(payload)
        return receipt

    def mark_applied(self, receipt_sha256: str) -> None:
        if not _SHA256.fullmatch(receipt_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_INVALID")
        with self._locked():
            payload = self._load_unlocked()
            event = payload["events"].get(receipt_sha256)
            if event is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_NOT_FOUND")
            if event.get("application_state") != "applied":
                event["application_state"] = "applied"
                self._save_unlocked(payload)

    def events_for(self, logical_job_id: str) -> tuple[dict, ...]:
        if not _JOB_ID.fullmatch(logical_job_id):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_JOB_ID_INVALID")
        with self._locked():
            payload = self._load_unlocked()
            rows = [
                {"receipt_sha256": receipt, **event}
                for receipt, event in payload["events"].items()
                if event["logical_job_id"] == logical_job_id
            ]
        rows.sort(key=lambda row: (row["observed_at_epoch"], row["receipt_sha256"]))
        return tuple(rows)

    def _load_unlocked(self) -> dict:
        if not self.path.exists():
            return {"schema_version": SCHEMA_VERSION, "events": {}}
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_CORRUPT") from exc
        if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_SCHEMA_INVALID")
        events = payload.get("events")
        if not isinstance(events, dict):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENTS_INVALID")
        for receipt, event in events.items():
            if not isinstance(receipt, str) or not _SHA256.fullmatch(receipt) or not isinstance(event, dict):
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID")
        return payload

    def _save_unlocked(self, payload: dict) -> None:
        tmp = self.path.with_name(self.path.name + ".tmp")
        encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        try:
            with tmp.open("w", encoding="utf-8") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, self.path)
            try:
                fd = os.open(self.path.parent, os.O_RDONLY)
            except OSError:
                return
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
        except OSError as exc:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_WRITE_FAILED", retryable=True) from exc


class ProviderDeletionReconciler:
    def __init__(self, *, registry_path: str | Path, ledger_path: str | Path):
        self.registry = AtomicPrivacyRegistry(registry_path)
        self.ledger = AtomicDeletionReconciliationLedger(ledger_path)

    def apply(self, observation: ProviderDeletionObservation) -> dict:
        observation.validate()
        receipt = self.ledger.append(observation)

        def operation(record):
            if record is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
            if not record.provider_delete_requested:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED")
            expected_hash = (
                record.provider_asset_id_hash if observation.object_kind == "asset"
                else record.provider_task_id_hash
            )
            if expected_hash is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_NOT_APPLICABLE")
            if expected_hash != observation.object_id_hash:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH")
            attr = (
                "provider_asset_delete_state" if observation.object_kind == "asset"
                else "provider_task_delete_state"
            )
            current = getattr(record, attr)
            proposed = _STATE_MAP[observation.observed_state]
            if current in _ERASURE_TERMINAL:
                if proposed not in _ERASURE_TERMINAL:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE")
                return record
            setattr(record, attr, proposed)
            return record

        record = self.registry.mutate(observation.logical_job_id, operation)
        self.ledger.mark_applied(receipt)
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": observation.logical_job_id,
            "object_kind": observation.object_kind,
            "applied_state": (
                record.provider_asset_delete_state
                if observation.object_kind == "asset"
                else record.provider_task_delete_state
            ),
            "observation_receipt_sha256": receipt,
            "parity_claim": "NONE",
        }

    def snapshot(self, logical_job_id: str) -> dict:
        rows = self.ledger.events_for(logical_job_id)
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": logical_job_id,
            "observation_count": len(rows),
            "observations": rows,
            "parity_claim": "NONE",
        }
