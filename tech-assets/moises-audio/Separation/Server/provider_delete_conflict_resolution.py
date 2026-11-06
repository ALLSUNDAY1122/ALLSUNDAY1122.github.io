"""Durable equal-epoch conflict adjudication for provider deletion reconciliation.

Lane 1 NON-PARITY hardening layer. The base reconciler intentionally fails
closed when two independently sourced observations for the same provider
object have the same observation epoch but disagree on state. This module
adds an explicit operator/HQ adjudication path without inventing a winner:

* the decision names an existing observation receipt;
* authority and rationale are stored only as SHA-256 references;
* decisions are immutable and fsync/atomic-replace durable;
* a chosen observation is still revalidated against registry binding,
  deletion timing and terminal-erasure downgrade rules;
* no decision means the base ``EQUAL_EPOCH_CONFLICT`` behavior is preserved.

The underlying observation ledger remains single-host only. This module does
not claim distributed synchronization or product PARITY.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path

from privacy_retention import PrivacyRetentionError
from provider_delete_reconciliation import ProviderDeletionObservation, ProviderDeletionReconciler

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A37-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_OBJECT_KINDS = {"asset", "task"}
_WATERMARK_STATES = {"applying", "applied"}
_ERASURE_TERMINAL = {"confirmed", "not_found", "expired"}
_STATE_MAP = {
    "confirmed": "confirmed",
    "not_found": "not_found",
    "present": "reconciled_present",
    "unknown": "reconciled_unknown",
    "expired": "expired",
}


@dataclass(frozen=True)
class EqualEpochConflictDecision:
    logical_job_id: str
    object_kind: str
    observed_at_epoch: int
    chosen_observation_receipt_sha256: str
    decision_authority_ref_sha256: str
    rationale_ref_sha256: str
    decided_at_epoch: int

    def validate(self) -> None:
        if not _JOB_ID.fullmatch(self.logical_job_id):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_JOB_ID_INVALID")
        if self.object_kind not in _OBJECT_KINDS:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_OBJECT_KIND_INVALID")
        if (
            not isinstance(self.observed_at_epoch, int)
            or isinstance(self.observed_at_epoch, bool)
            or self.observed_at_epoch <= 0
        ):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_EPOCH_INVALID")
        if not _SHA256.fullmatch(self.chosen_observation_receipt_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_CHOSEN_RECEIPT_INVALID")
        if not _SHA256.fullmatch(self.decision_authority_ref_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_AUTHORITY_REF_INVALID")
        if not _SHA256.fullmatch(self.rationale_ref_sha256):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_RATIONALE_REF_INVALID")
        if (
            not isinstance(self.decided_at_epoch, int)
            or isinstance(self.decided_at_epoch, bool)
            or self.decided_at_epoch <= 0
        ):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_EPOCH_INVALID")
        if self.decided_at_epoch < self.observed_at_epoch:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_PRECEDES_OBSERVATION")

    @property
    def conflict_key_sha256(self) -> str:
        self.validate()
        encoded = f"{self.logical_job_id}:{self.object_kind}:{self.observed_at_epoch}"
        return hashlib.sha256(encoded.encode("utf-8")).hexdigest()

    @property
    def decision_receipt_sha256(self) -> str:
        self.validate()
        encoded = json.dumps(asdict(self), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def _decision_from_row(row: dict) -> EqualEpochConflictDecision:
    try:
        decision = EqualEpochConflictDecision(
            logical_job_id=row["logical_job_id"],
            object_kind=row["object_kind"],
            observed_at_epoch=row["observed_at_epoch"],
            chosen_observation_receipt_sha256=row["chosen_observation_receipt_sha256"],
            decision_authority_ref_sha256=row["decision_authority_ref_sha256"],
            rationale_ref_sha256=row["rationale_ref_sha256"],
            decided_at_epoch=row["decided_at_epoch"],
        )
    except (KeyError, TypeError) as exc:
        raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_INVALID") from exc
    decision.validate()
    return decision


def _observation_from_row(row: dict) -> ProviderDeletionObservation:
    try:
        observation = ProviderDeletionObservation(
            logical_job_id=row["logical_job_id"],
            object_kind=row["object_kind"],
            object_id_hash=row["object_id_hash"],
            observed_state=row["observed_state"],
            source_kind=row["source_kind"],
            authority_ref_sha256=row["authority_ref_sha256"],
            observed_at_epoch=row["observed_at_epoch"],
        )
    except (KeyError, TypeError) as exc:
        raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID") from exc
    observation.validate()
    return observation


class AtomicEqualEpochConflictDecisionStore:
    """Single-host immutable sidecar for hashed equal-epoch decisions."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def _locked(self):
        try:
            import fcntl
        except ImportError as exc:
            raise PrivacyRetentionError(
                "SEP_PRIVACY_RECONCILE_CONFLICT_LOCK_UNAVAILABLE", retryable=True
            ) from exc
        try:
            handle = self.lock_path.open("a+b")
        except OSError as exc:
            raise PrivacyRetentionError(
                "SEP_PRIVACY_RECONCILE_CONFLICT_LOCK_UNAVAILABLE", retryable=True
            ) from exc
        with handle:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                raise PrivacyRetentionError(
                    "SEP_PRIVACY_RECONCILE_CONFLICT_LOCK_UNAVAILABLE", retryable=True
                ) from exc
            try:
                yield
            finally:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass

    def record(self, decision: EqualEpochConflictDecision) -> str:
        decision.validate()
        key = decision.conflict_key_sha256
        receipt = decision.decision_receipt_sha256
        with self._locked():
            payload = self._load_unlocked()
            existing = payload["decisions"].get(key)
            if existing is not None:
                existing_decision = _decision_from_row(existing)
                if existing_decision.decision_receipt_sha256 != receipt:
                    raise PrivacyRetentionError(
                        "SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_IMMUTABLE"
                    )
                return receipt
            payload["decisions"][key] = {
                **asdict(decision),
                "decision_receipt_sha256": receipt,
            }
            self._save_unlocked(payload)
        return receipt

    def get(
        self,
        logical_job_id: str,
        object_kind: str,
        observed_at_epoch: int,
    ) -> EqualEpochConflictDecision | None:
        probe = EqualEpochConflictDecision(
            logical_job_id=logical_job_id,
            object_kind=object_kind,
            observed_at_epoch=observed_at_epoch,
            chosen_observation_receipt_sha256="0" * 64,
            decision_authority_ref_sha256="0" * 64,
            rationale_ref_sha256="0" * 64,
            decided_at_epoch=observed_at_epoch,
        )
        probe.validate()
        with self._locked():
            row = self._load_unlocked()["decisions"].get(probe.conflict_key_sha256)
        return None if row is None else _decision_from_row(row)

    def decisions_for(self, logical_job_id: str) -> tuple[dict, ...]:
        if not _JOB_ID.fullmatch(logical_job_id):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_JOB_ID_INVALID")
        with self._locked():
            payload = self._load_unlocked()
            rows = [
                {"conflict_key_sha256": key, **row}
                for key, row in payload["decisions"].items()
                if row.get("logical_job_id") == logical_job_id
            ]
        rows.sort(key=lambda row: (row["observed_at_epoch"], row["object_kind"]))
        return tuple(rows)

    def _load_unlocked(self) -> dict:
        if not self.path.exists():
            return {"schema_version": SCHEMA_VERSION, "decisions": {}}
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_STORE_CORRUPT") from exc
        if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_STORE_SCHEMA_INVALID")
        decisions = payload.get("decisions")
        if not isinstance(decisions, dict):
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_STORE_INVALID")
        for key, row in decisions.items():
            if not isinstance(key, str) or not _SHA256.fullmatch(key) or not isinstance(row, dict):
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_INVALID")
            decision = _decision_from_row(row)
            if decision.conflict_key_sha256 != key:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_KEY_MISMATCH")
            if row.get("decision_receipt_sha256") != decision.decision_receipt_sha256:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_RECEIPT_MISMATCH")
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
            raise PrivacyRetentionError(
                "SEP_PRIVACY_RECONCILE_CONFLICT_STORE_WRITE_FAILED", retryable=True
            ) from exc


class ConflictResolvingProviderDeletionReconciler(ProviderDeletionReconciler):
    """ProviderDeletionReconciler with explicit durable equal-epoch adjudication."""

    def __init__(self, *, conflict_decision_path: str | Path | None = None, **kwargs):
        super().__init__(**kwargs)
        if conflict_decision_path is None:
            conflict_decision_path = self.ledger.path.with_suffix(
                self.ledger.path.suffix + ".conflict-decisions.json"
            )
        self.conflict_decisions = AtomicEqualEpochConflictDecisionStore(conflict_decision_path)

    def _decision_rows(self, decision: EqualEpochConflictDecision) -> tuple[dict, ...]:
        return tuple(
            row
            for row in self.ledger.events_for(decision.logical_job_id)
            if row["object_kind"] == decision.object_kind
            and row["observed_at_epoch"] == decision.observed_at_epoch
        )

    def _validate_decision_against_ledger(
        self,
        decision: EqualEpochConflictDecision,
    ) -> ProviderDeletionObservation:
        rows = self._decision_rows(decision)
        if len(rows) < 2:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_NOT_ESTABLISHED")
        semantic_states = {(row["object_id_hash"], row["observed_state"]) for row in rows}
        if len(semantic_states) < 2:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_NOT_ESTABLISHED")
        chosen = next(
            (
                row
                for row in rows
                if row["receipt_sha256"] == decision.chosen_observation_receipt_sha256
            ),
            None,
        )
        if chosen is None:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_CHOSEN_RECEIPT_NOT_FOUND")
        newer_watermarks = [
            row
            for row in self.ledger.events_for(decision.logical_job_id)
            if row["object_kind"] == decision.object_kind
            and row["observed_at_epoch"] > decision.observed_at_epoch
            and row["application_state"] in _WATERMARK_STATES
        ]
        if newer_watermarks:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_STALE")
        observation = _observation_from_row(chosen)
        self._validate_registry_binding(observation)
        return observation

    def record_equal_epoch_conflict_resolution(
        self,
        decision: EqualEpochConflictDecision,
    ) -> dict:
        decision.validate()
        now = self._validated_now_epoch()
        if decision.decided_at_epoch > now + self.max_future_skew_seconds:
            raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_FROM_FUTURE")
        with self._application_locked():
            self._validate_decision_against_ledger(decision)
            decision_receipt = self.conflict_decisions.record(decision)
        resume = self.resume_pending(decision.logical_job_id)
        return {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "logical_job_id": decision.logical_job_id,
            "object_kind": decision.object_kind,
            "observed_at_epoch": decision.observed_at_epoch,
            "chosen_observation_receipt_sha256": decision.chosen_observation_receipt_sha256,
            "decision_receipt_sha256": decision_receipt,
            "resume_state": resume["state"],
            "remaining_pending_count": resume["remaining_pending_count"],
            "parity_claim": "NONE",
        }

    def _resolution_result(
        self,
        observation: ProviderDeletionObservation,
        receipt: str,
        *,
        decision: EqualEpochConflictDecision,
        applied_state: str,
        ordering_decision: str,
    ) -> dict:
        result = self._result(
            observation,
            receipt,
            applied_state=applied_state,
            decision=ordering_decision,
        )
        result["conflict_decision_receipt_sha256"] = decision.decision_receipt_sha256
        return result

    def apply(self, observation: ProviderDeletionObservation) -> dict:
        observation.validate()
        decision = self.conflict_decisions.get(
            observation.logical_job_id,
            observation.object_kind,
            observation.observed_at_epoch,
        )
        if decision is None:
            return super().apply(observation)

        with self._application_locked():
            receipt = self.ledger.append(observation)
            rows = self.ledger.events_for(observation.logical_job_id)
            own = next((row for row in rows if row["receipt_sha256"] == receipt), None)
            if own is None:
                raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_RECEIPT_NOT_FOUND")
            if own["application_state"] == "applied":
                self._validate_registry_binding(observation)
                return self._resolution_result(
                    observation,
                    receipt,
                    decision=decision,
                    applied_state=self._current_state(
                        observation.logical_job_id, observation.object_kind
                    ),
                    ordering_decision="ALREADY_APPLIED",
                )
            if own["application_state"] == "superseded_stale":
                return self._resolution_result(
                    observation,
                    receipt,
                    decision=decision,
                    applied_state=self._current_state(
                        observation.logical_job_id, observation.object_kind
                    ),
                    ordering_decision="CONFLICT_RESOLUTION_IGNORED",
                )

            chosen = next(
                (
                    row
                    for row in rows
                    if row["receipt_sha256"] == decision.chosen_observation_receipt_sha256
                ),
                None,
            )
            if chosen is None:
                raise PrivacyRetentionError(
                    "SEP_PRIVACY_RECONCILE_CONFLICT_CHOSEN_RECEIPT_NOT_FOUND"
                )

            if receipt != decision.chosen_observation_receipt_sha256:
                equivalent_to_chosen = (
                    own["object_id_hash"] == chosen["object_id_hash"]
                    and own["observed_state"] == chosen["observed_state"]
                )
                if equivalent_to_chosen and chosen["application_state"] == "applied":
                    self._validate_registry_binding(observation)
                    self.ledger.mark_applying(receipt)
                    self.ledger.mark_applied(receipt)
                    return self._resolution_result(
                        observation,
                        receipt,
                        decision=decision,
                        applied_state=self._current_state(
                            observation.logical_job_id, observation.object_kind
                        ),
                        ordering_decision="RESOLUTION_EQUIVALENT_APPLIED",
                    )
                self.ledger.mark_superseded_stale(receipt)
                return self._resolution_result(
                    observation,
                    receipt,
                    decision=decision,
                    applied_state=self._current_state(
                        observation.logical_job_id, observation.object_kind
                    ),
                    ordering_decision="CONFLICT_RESOLUTION_IGNORED",
                )

            newer_watermarks = [
                row
                for row in rows
                if row["receipt_sha256"] != receipt
                and row["object_kind"] == observation.object_kind
                and row["observed_at_epoch"] > observation.observed_at_epoch
                and row["application_state"] in _WATERMARK_STATES
            ]
            if newer_watermarks:
                self.ledger.mark_superseded_stale(receipt)
                return self._resolution_result(
                    observation,
                    receipt,
                    decision=decision,
                    applied_state=self._current_state(
                        observation.logical_job_id, observation.object_kind
                    ),
                    ordering_decision="STALE_IGNORED",
                )

            self._validate_registry_binding(observation)
            self.ledger.mark_applying(receipt)

            def operation(record):
                if record is None:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECORD_NOT_FOUND")
                if not record.provider_delete_requested:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED")
                expected_hash = (
                    record.provider_asset_id_hash
                    if observation.object_kind == "asset"
                    else record.provider_task_id_hash
                )
                if expected_hash is None:
                    raise PrivacyRetentionError(
                        "SEP_PRIVACY_RECONCILE_OBJECT_NOT_APPLICABLE"
                    )
                if expected_hash != observation.object_id_hash:
                    raise PrivacyRetentionError("SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH")
                self._validate_observation_timing(record, observation)
                attr = (
                    "provider_asset_delete_state"
                    if observation.object_kind == "asset"
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
            applied_state = (
                record.provider_asset_delete_state
                if observation.object_kind == "asset"
                else record.provider_task_delete_state
            )
            return self._resolution_result(
                observation,
                receipt,
                decision=decision,
                applied_state=applied_state,
                ordering_decision="CONFLICT_RESOLUTION_APPLIED",
            )

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
                if result["ordering_decision"] in {
                    "STALE_IGNORED",
                    "CONFLICT_RESOLUTION_IGNORED",
                }:
                    superseded.append(result)
                else:
                    applied.append(result)
            except PrivacyRetentionError as exc:
                failures.append(
                    {
                        "object_kind": observation.object_kind,
                        "observation_receipt_sha256": observation.receipt_sha256,
                        "stable_error_code": exc.code,
                    }
                )
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
        result = super().snapshot(logical_job_id)
        decisions = self.conflict_decisions.decisions_for(logical_job_id)
        result["tool_version"] = TOOL_VERSION
        result["equal_epoch_conflict_resolution_count"] = len(decisions)
        result["equal_epoch_conflict_resolutions"] = decisions
        return result
