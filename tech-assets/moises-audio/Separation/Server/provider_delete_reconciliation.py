"""Provider deletion reconciliation for Lane 1 privacy retention.

NON-PARITY safety layer. It never blindly replays a provider delete after an
ambiguous/in-flight external side effect. Only separately observed, hash-bound
provider state may resolve that ambiguity.

A32 provides a durable ``applying`` watermark so a crash between registry
mutation and the final ledger commit cannot permit stale rollback. A33 adds a
temporal-causality gate before that watermark. A34 hardens documented-expiry
authority: policy TTL evidence may represent only asset ``expired`` state and
may become authoritative only after the registered vendor asset expiry epoch
has actually elapsed.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

from privacy_retention import AtomicPrivacyRegistry, PrivacyRetentionError

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A34-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
DEFAULT_MAX_FUTURE_SKEW_SECONDS = 300
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_OBJECT_KINDS = {"asset", "task"}
_SOURCE_KINDS = {"provider_api", "provider_console", "provider_support", "documented_expiry"}
_OBSERVED_STATES = {"confirmed", "not_found", "present", "unknown", "expired"}
_APPLICATION_STATES = {"observed_not_applied", "applying", "applied", "superseded_stale"}
_RESUMABLE_STATES = {"observed_not_applied", "applying"}
_ORDERING_WATERMARK_STATES = {"applying", "applied"}
_ERASURE_TERMINAL = {"confirmed", "not_found", "expired"}
_STATE_MAP = {
    "confirmed": "confirmed",
    "not_found": "not_found",
    "present": "reconciled_present",
    "unknown": "reconciled_unknown",
    "expired": "expired",
}
_ALLOWED_TRANSITIONS = {
    "observed_not_applied": {"observed_not_applied", "applying", "superseded_stale"},
    "applying": {"applying", "applied", "superseded_stale"},
    "applied": {"applied"},
    "superseded_stale": {"superseded_stale"},
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
        if self.source_kind == "documented_expiry" and self.observed_state != "expired":
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_STATE_INVALID")
        if self.observed_state == "expired" and not (
            self.object_kind == "asset" and self.source_kind == "documented_expiry"
        ):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_EXPIRY_SCOPE_INVALID")

    @property
    def receipt_sha256(self) -> str:
        self.validate()
        encoded = json.dumps(asdict(self), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _observation_from_event(event: dict) -> ProviderDeletionObservation:
    try:
        observation = ProviderDeletionObservation(
            logical_job_id=event["logical_job_id"],
            object_kind=event["object_kind"],
            object_id_hash=event["object_id_hash"],
            observed_state=event["observed_state"],
            source_kind=event["source_kind"],
            authority_ref_sha256=event["authority_ref_sha256"],
            observed_at_epoch=event["observed_at_epoch"],
        )
    except (KeyError, TypeError) as exc:
        raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID") from exc
    observation.validate()
    return observation


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
        except ImportError as exc:
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
            if receipt not in payload["events"]:
                payload["events"][receipt] = {
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

    def mark_applying(self, receipt_sha256: str) -> None:
        self._mark_application_state(receipt_sha256, "applying")

    def mark_applied(self, receipt_sha256: str) -> None:
        self._mark_application_state(receipt_sha256, "applied")

    def mark_superseded_stale(self, receipt_sha256: str) -> None:
        self._mark_application_state(receipt_sha256, "superseded_stale")

    def _mark_application_state(self, receipt_sha256: str, state: str) -> None:
        if not _SHA256.fullmatch(receipt_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_INVALID")
        if state not in _APPLICATION_STATES:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_APPLICATION_STATE_INVALID")
        with self._locked():
            payload = self._load_unlocked()
            event = payload["events"].get(receipt_sha256)
            if event is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_NOT_FOUND")
            current = event.get("application_state")
            if current not in _APPLICATION_STATES:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID")
            if state not in _ALLOWED_TRANSITIONS[current]:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_APPLICATION_TRANSITION_INVALID")
            if current != state:
                event["application_state"] = state
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

    def pending_observations(self, logical_job_id: str) -> tuple[ProviderDeletionObservation, ...]:
        return tuple(
            _observation_from_event(row)
            for row in self.events_for(logical_job_id)
            if row["application_state"] in _RESUMABLE_STATES
        )

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
            if event.get("application_state") not in _APPLICATION_STATES:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID")
            observation = _observation_from_event(event)
            if observation.receipt_sha256 != receipt:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_RECEIPT_MISMATCH")
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
            fd = os.open(self.path.parent, os.O_RDONLY)
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
    def __init__(
        self,
        *,
        registry_path: str | Path,
        ledger_path: str | Path,
        now_epoch: Callable[[], int] | None = None,
        max_future_skew_seconds: int = DEFAULT_MAX_FUTURE_SKEW_SECONDS,
    ):
        if (
            not isinstance(max_future_skew_seconds, int)
            or isinstance(max_future_skew_seconds, bool)
            or max_future_skew_seconds < 0
        ):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_FUTURE_SKEW_INVALID")
        self.registry = AtomicPrivacyRegistry(registry_path)
        self.ledger = AtomicDeletionReconciliationLedger(ledger_path)
        self.apply_lock_path = self.ledger.path.with_suffix(self.ledger.path.suffix + ".apply.lock")
        self.now_epoch = now_epoch or (lambda: int(__import__("time").time()))
        self.max_future_skew_seconds = max_future_skew_seconds

    @contextmanager
    def _application_locked(self):
        """Serialize ledger ordering decision + registry mutation on one host."""
        try:
            import fcntl
        except ImportError as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_APPLY_LOCK_UNAVAILABLE", retryable=True) from exc
        try:
            handle = self.apply_lock_path.open("a+b")
        except OSError as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_APPLY_LOCK_UNAVAILABLE", retryable=True) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_APPLY_LOCK_UNAVAILABLE", retryable=True) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def _validated_now_epoch(self) -> int:
        now = self.now_epoch()
        if not isinstance(now, int) or isinstance(now, bool) or now <= 0:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CLOCK_INVALID")
        return now

    def _current_state(self, logical_job_id: str, object_kind: str) -> str:
        record = self.registry.get(logical_job_id)
        if record is None:
            raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
        if not record.provider_delete_requested:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED")
        return record.provider_asset_delete_state if object_kind == "asset" else record.provider_task_delete_state

    def _validate_observation_timing(self, record, observation: ProviderDeletionObservation) -> None:
        delete_epoch = record.delete_requested_at_epoch
        if not isinstance(delete_epoch, int) or isinstance(delete_epoch, bool) or delete_epoch <= 0:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_EPOCH_INVALID")
        if observation.observed_at_epoch < delete_epoch:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBSERVATION_PRECEDES_DELETE")
        now = self._validated_now_epoch()
        if observation.observed_at_epoch > now + self.max_future_skew_seconds:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBSERVATION_FROM_FUTURE")
        if observation.source_kind == "documented_expiry":
            expiry_epoch = record.vendor_asset_expires_at_epoch
            if not isinstance(expiry_epoch, int) or isinstance(expiry_epoch, bool) or expiry_epoch <= 0:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_EPOCH_INVALID")
            if observation.observed_at_epoch < expiry_epoch:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_NOT_REACHED")
            if now < expiry_epoch:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LOCAL_CLOCK_BEFORE_EXPIRY")

    def _validate_registry_binding(self, observation: ProviderDeletionObservation) -> None:
        record = self.registry.get(observation.logical_job_id)
        if record is None:
            raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
        if not record.provider_delete_requested:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED")
        expected_hash = record.provider_asset_id_hash if observation.object_kind == "asset" else record.provider_task_id_hash
        if expected_hash is None:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_NOT_APPLICABLE")
        if expected_hash != observation.object_id_hash:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH")
        self._validate_observation_timing(record, observation)
        current = record.provider_asset_delete_state if observation.object_kind == "asset" else record.provider_task_delete_state
        proposed = _STATE_MAP[observation.observed_state]
        if current in _ERASURE_TERMINAL and proposed not in _ERASURE_TERMINAL:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE")

    def _result(self, observation: ProviderDeletionObservation, receipt: str, *, applied_state: str, decision: str) -> dict:
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": observation.logical_job_id,
            "object_kind": observation.object_kind,
            "applied_state": applied_state,
            "observation_receipt_sha256": receipt,
            "ordering_decision": decision,
            "parity_claim": "NONE",
        }

    def apply(self, observation: ProviderDeletionObservation) -> dict:
        observation.validate()
        with self._application_locked():
            receipt = self.ledger.append(observation)
            rows = self.ledger.events_for(observation.logical_job_id)
            own = next((row for row in rows if row["receipt_sha256"] == receipt), None)
            if own is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_NOT_FOUND")
            if own["application_state"] == "applied":
                self._validate_registry_binding(observation)
                return self._result(
                    observation,
                    receipt,
                    applied_state=self._current_state(observation.logical_job_id, observation.object_kind),
                    decision="ALREADY_APPLIED",
                )
            if own["application_state"] == "superseded_stale":
                return self._result(
                    observation,
                    receipt,
                    applied_state=self._current_state(observation.logical_job_id, observation.object_kind),
                    decision="STALE_IGNORED",
                )

            watermark_rows = [
                row for row in rows
                if row["receipt_sha256"] != receipt
                and row["object_kind"] == observation.object_kind
                and row["application_state"] in _ORDERING_WATERMARK_STATES
            ]
            if watermark_rows:
                newest_epoch = max(row["observed_at_epoch"] for row in watermark_rows)
                newest_rows = [row for row in watermark_rows if row["observed_at_epoch"] == newest_epoch]
                if observation.observed_at_epoch < newest_epoch:
                    self.ledger.mark_superseded_stale(receipt)
                    return self._result(
                        observation,
                        receipt,
                        applied_state=self._current_state(observation.logical_job_id, observation.object_kind),
                        decision="STALE_IGNORED",
                    )
                if observation.observed_at_epoch == newest_epoch:
                    equivalent = all(
                        row["object_id_hash"] == observation.object_id_hash
                        and row["observed_state"] == observation.observed_state
                        for row in newest_rows
                    )
                    if not equivalent:
                        raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT")
                    if any(row["application_state"] == "applied" for row in newest_rows):
                        self._validate_registry_binding(observation)
                        self.ledger.mark_applying(receipt)
                        self.ledger.mark_applied(receipt)
                        return self._result(
                            observation,
                            receipt,
                            applied_state=self._current_state(observation.logical_job_id, observation.object_kind),
                            decision="EQUIVALENT_EPOCH_APPLIED",
                        )

            self._validate_registry_binding(observation)
            self.ledger.mark_applying(receipt)

            def operation(record):
                if record is None:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
                if not record.provider_delete_requested:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED")
                expected_hash = record.provider_asset_id_hash if observation.object_kind == "asset" else record.provider_task_id_hash
                if expected_hash is None:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_NOT_APPLICABLE")
                if expected_hash != observation.object_id_hash:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH")
                self._validate_observation_timing(record, observation)
                attr = "provider_asset_delete_state" if observation.object_kind == "asset" else "provider_task_delete_state"
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
            applied_state = record.provider_asset_delete_state if observation.object_kind == "asset" else record.provider_task_delete_state
            return self._result(observation, receipt, applied_state=applied_state, decision="APPLIED")

    def resume_pending(self, logical_job_id: str) -> dict:
        if not _JOB_ID.fullmatch(logical_job_id):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_JOB_ID_INVALID")
        pending = self.ledger.pending_observations(logical_job_id)
        applied: list[dict] = []
        superseded: list[dict] = []
        failures: list[dict] = []
        for observation in pending:
            try:
                result = self.apply(observation)
                if result["ordering_decision"] == "STALE_IGNORED":
                    superseded.append(result)
                else:
                    applied.append(result)
            except PrivacyRetentionError as exc:
                failures.append({
                    "object_kind": observation.object_kind,
                    "observation_receipt_sha256": observation.receipt_sha256,
                    "stable_error_code": exc.code,
                })
        remaining = self.ledger.pending_observations(logical_job_id)
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": logical_job_id,
            "state": "PASS" if not failures and not remaining else "INCOMPLETE",
            "attempted_count": len(pending),
            "applied_count": len(applied),
            "superseded_stale_count": len(superseded),
            "failure_count": len(failures),
            "remaining_pending_count": len(remaining),
            "failures": failures,
            "parity_claim": "NONE",
        }

    def snapshot(self, logical_job_id: str) -> dict:
        rows = self.ledger.events_for(logical_job_id)
        pending_count = sum(row["application_state"] in _RESUMABLE_STATES for row in rows)
        inflight_count = sum(row["application_state"] == "applying" for row in rows)
        superseded_count = sum(row["application_state"] == "superseded_stale" for row in rows)
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": logical_job_id,
            "observation_count": len(rows),
            "pending_observation_count": pending_count,
            "inflight_observation_count": inflight_count,
            "superseded_stale_count": superseded_count,
            "reconciliation_required": pending_count > 0,
            "observations": rows,
            "parity_claim": "NONE",
        }
