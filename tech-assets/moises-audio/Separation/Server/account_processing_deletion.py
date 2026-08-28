"""Account/project processing-data deletion composition for Lane 1.

Server-side NON_PARITY infrastructure. It binds an account/project deletion
request to every durable Lane-1 processing job owned by that project, routes
local/provider deletion through PrivacyRetentionService, and tombstones durable
reconnect identity only after every applicable provider object is authoritatively
erased.

This module deliberately does not define an iOS/HTTP transport. A production
transport must authenticate/authorize the request and pass the exact ProjectID;
provider identifiers remain server-side and are resolved from durable state.
"""
from __future__ import annotations

import hashlib
import re
import uuid
from dataclasses import dataclass
from typing import Any

from privacy_retention import PrivacyRetentionError

EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
TOOL_VERSION = "L1-HQ-ACCOUNT-PROCESSING-DELETE-v1"
_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_ASSET_ERASURE_TERMINAL = frozenset({"confirmed", "not_found", "expired"})
_TASK_ERASURE_TERMINAL = frozenset({"confirmed", "not_found"})


class AccountProcessingDeletionError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


@dataclass(frozen=True)
class _JobOutcome:
    logical_job_id: str
    state: str
    local_delete_confirmed: bool
    provider_asset_state: str
    provider_task_state: str
    durable_tombstoned: bool
    stable_error_code: str | None = None


class AccountProcessingDeletionService:
    """Project-scoped deletion over durable Lane-1 job authority."""

    def __init__(
        self,
        *,
        privacy_retention: Any,
        durable_reconnect: Any,
        provider_reconciler: Any | None = None,
    ):
        if not callable(getattr(privacy_retention, "request_delete", None)):
            raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_PRIVACY_SURFACE_INVALID")
        if not callable(getattr(durable_reconnect, "mark_deleted", None)):
            raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_DURABLE_SURFACE_INVALID")
        registry = getattr(durable_reconnect, "registry", None)
        if registry is None or not callable(getattr(registry, "list_records", None)):
            raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_DURABLE_REGISTRY_INVALID")
        privacy_registry = getattr(privacy_retention, "registry", None)
        if privacy_registry is None or not callable(getattr(privacy_registry, "get", None)):
            raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_PRIVACY_REGISTRY_INVALID")
        if provider_reconciler is not None and not callable(
            getattr(provider_reconciler, "resume_pending", None)
        ):
            raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_RECONCILER_SURFACE_INVALID")
        self.privacy_retention = privacy_retention
        self.durable_reconnect = durable_reconnect
        self.provider_reconciler = provider_reconciler

    def delete_project(self, project_id: str) -> dict[str, Any]:
        project_key = _canonical_project_id(project_id)
        records = tuple(
            record
            for record in self.durable_reconnect.registry.list_records()
            if _record_project_matches(record, project_key)
        )
        outcomes = [self._delete_job(record) for record in records]
        incomplete = [outcome for outcome in outcomes if outcome.state != "complete"]
        return {
            "schemaVersion": 1,
            "toolVersion": TOOL_VERSION,
            "evidenceState": EVIDENCE_STATE,
            "projectRefHash": _project_ref_hash(project_key),
            "matchedJobCount": len(outcomes),
            "completedJobCount": len(outcomes) - len(incomplete),
            "incompleteJobCount": len(incomplete),
            "state": "COMPLETE" if not incomplete else "INCOMPLETE",
            "jobs": [_public_outcome(outcome) for outcome in outcomes],
            "parityClaim": "NONE",
        }

    def _delete_job(self, record: Any) -> _JobOutcome:
        logical_job_id = getattr(record, "logical_job_id", None)
        if not isinstance(logical_job_id, str) or not _LOGICAL_JOB_ID.fullmatch(logical_job_id):
            return _invalid_record_outcome("SEP_ACCOUNT_DELETE_LOGICAL_JOB_ID_INVALID")
        if getattr(record, "state", None) == "deleted":
            return self._verify_existing_tombstone(logical_job_id, record)
        try:
            self.privacy_retention.request_delete(
                logical_job_id,
                provider_asset_id=getattr(record, "provider_asset_id", None),
                provider_task_id=getattr(record, "provider_task_id", None),
                reason="account_delete",
                delete_provider=True,
            )
            if self.provider_reconciler is not None:
                self.provider_reconciler.resume_pending(logical_job_id)
            privacy_record = self.privacy_retention.registry.get(logical_job_id)
            if privacy_record is None:
                raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_PRIVACY_RECORD_NOT_FOUND")
            complete, asset_state, task_state = _privacy_complete(
                privacy_record=privacy_record,
                durable_record=record,
            )
            if not complete:
                return _JobOutcome(
                    logical_job_id,
                    "incomplete",
                    bool(getattr(privacy_record, "local_delete_confirmed", False)),
                    asset_state,
                    task_state,
                    False,
                    "SEP_ACCOUNT_DELETE_PROVIDER_ERASURE_INCOMPLETE",
                )
            self.durable_reconnect.mark_deleted(logical_job_id)
            return _JobOutcome(
                logical_job_id,
                "complete",
                True,
                asset_state,
                task_state,
                True,
            )
        except (PrivacyRetentionError, AccountProcessingDeletionError) as exc:
            return _JobOutcome(
                logical_job_id,
                "incomplete",
                False,
                "unknown",
                "unknown",
                False,
                getattr(exc, "code", "SEP_ACCOUNT_DELETE_FAILED"),
            )
        except Exception as exc:
            return _JobOutcome(
                logical_job_id,
                "incomplete",
                False,
                "unknown",
                "unknown",
                False,
                _safe_error_code(exc),
            )

    def _verify_existing_tombstone(self, logical_job_id: str, record: Any) -> _JobOutcome:
        privacy_record = self.privacy_retention.registry.get(logical_job_id)
        if privacy_record is None:
            return _JobOutcome(
                logical_job_id,
                "incomplete",
                False,
                "unknown",
                "unknown",
                True,
                "SEP_ACCOUNT_DELETE_TOMBSTONE_PRIVACY_UNVERIFIED",
            )
        complete, asset_state, task_state = _privacy_complete(
            privacy_record=privacy_record,
            durable_record=record,
        )
        return _JobOutcome(
            logical_job_id,
            "complete" if complete else "incomplete",
            bool(getattr(privacy_record, "local_delete_confirmed", False)),
            asset_state,
            task_state,
            True,
            None if complete else "SEP_ACCOUNT_DELETE_TOMBSTONE_PRIVACY_INCOMPLETE",
        )


def _privacy_complete(*, privacy_record: Any, durable_record: Any) -> tuple[bool, str, str]:
    local = bool(getattr(privacy_record, "local_delete_confirmed", False))
    expected_asset_hash = getattr(privacy_record, "provider_asset_id_hash", None)
    expected_task_hash = getattr(privacy_record, "provider_task_id_hash", None)
    asset_state = str(getattr(privacy_record, "provider_asset_delete_state", "unknown"))
    task_state = str(getattr(privacy_record, "provider_task_delete_state", "unknown"))
    durable_asset_id = getattr(durable_record, "provider_asset_id", None)
    durable_task_id = getattr(durable_record, "provider_task_id", None)
    asset_complete = (
        expected_asset_hash is None and durable_asset_id is None
    ) or asset_state in _ASSET_ERASURE_TERMINAL
    task_complete = (
        expected_task_hash is None and durable_task_id is None
    ) or task_state in _TASK_ERASURE_TERMINAL
    return local and asset_complete and task_complete, asset_state, task_state


def _canonical_project_id(value: str) -> str:
    if not isinstance(value, str):
        raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_PROJECT_ID_INVALID")
    try:
        return str(uuid.UUID(value))
    except (ValueError, AttributeError) as exc:
        raise AccountProcessingDeletionError("SEP_ACCOUNT_DELETE_PROJECT_ID_INVALID") from exc


def _record_project_matches(record: Any, project_key: str) -> bool:
    value = getattr(record, "project_id", None)
    if not isinstance(value, str):
        return False
    try:
        return str(uuid.UUID(value)) == project_key
    except ValueError:
        return False


def _project_ref_hash(project_key: str) -> str:
    return hashlib.sha256(("l1-account-project-v1:" + project_key).encode()).hexdigest()


def _logical_job_ref_hash(logical_job_id: str) -> str:
    return hashlib.sha256(("l1-account-job-v1:" + logical_job_id).encode()).hexdigest()


def _public_outcome(outcome: _JobOutcome) -> dict[str, Any]:
    return {
        "jobRefHash": _logical_job_ref_hash(outcome.logical_job_id),
        "state": outcome.state,
        "localDeleteConfirmed": outcome.local_delete_confirmed,
        "providerAssetState": outcome.provider_asset_state,
        "providerTaskState": outcome.provider_task_state,
        "durableTombstoned": outcome.durable_tombstoned,
        "stableErrorCode": outcome.stable_error_code,
    }


def _invalid_record_outcome(code: str) -> _JobOutcome:
    return _JobOutcome("0" * 32, "incomplete", False, "unknown", "unknown", False, code)


def _safe_error_code(exc: Exception) -> str:
    code = getattr(exc, "code", None)
    if isinstance(code, str) and re.fullmatch(r"[A-Z0-9_.:-]{1,200}", code):
        return code
    return "SEP_ACCOUNT_DELETE_FAILED"
