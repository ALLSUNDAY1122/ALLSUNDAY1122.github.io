"""Canonical Lane1 production snapshot/result/cancel/delete safety composition.

This module is an HQ composition boundary over the lane-local production backend. It does not
implement HTTP/authentication and does not claim live-provider or product parity. Its purpose is
to make the safe path explicit: public processing snapshots and result collection always pass
through TruthfulCancellationService, while privacy deletion intent is checked before and after
backend work so deletion cannot be hidden by a direct ready-output path.

The lower-level production orchestrators remain implementation components. Server transports
should bind to ProductionSeparationSafetyFacade rather than exposing their raw snapshot/result
methods directly.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from privacy_retention import PrivacyRetentionError
from truthful_cancellation import TruthfulCancellationService


class ProductionSafetyError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class ProductionSeparationSafetyFacade:
    """Single server-side safety surface for snapshot/result/cancel/delete operations."""

    def __init__(
        self,
        *,
        backend: Any,
        provider: Any,
        cancellation_registry_path: str | Path,
        privacy_service: Any,
    ):
        for name in ("get", "observe", "collect_ready_outputs"):
            if not callable(getattr(backend, name, None)):
                raise ProductionSafetyError("SEP_SAFETY_BACKEND_SURFACE_MISSING")
        if not callable(getattr(privacy_service, "request_delete", None)):
            raise ProductionSafetyError("SEP_SAFETY_PRIVACY_SURFACE_MISSING")
        registry = getattr(privacy_service, "registry", None)
        if registry is None or not callable(getattr(registry, "get", None)):
            raise ProductionSafetyError("SEP_SAFETY_PRIVACY_REGISTRY_SURFACE_MISSING")

        self._backend = backend
        self._privacy = privacy_service
        self._cancellation = TruthfulCancellationService(
            backend=backend,
            provider=provider,
            registry_path=cancellation_registry_path,
        )

    def request_cancel(self, logical_job_id: str) -> Any:
        return self._cancellation.request_cancel(logical_job_id)

    def snapshot(self, logical_job_id: str) -> dict[str, Any]:
        self._assert_privacy_not_deleting(logical_job_id)
        snapshot = self._cancellation.observe(logical_job_id)
        # A delete may have become durable while provider observation was in flight. Never return a
        # stale active/ready snapshot after that point.
        self._assert_privacy_not_deleting(logical_job_id)
        return snapshot

    def result(self, logical_job_id: str) -> Any:
        self._assert_privacy_not_deleting(logical_job_id)
        result = self._cancellation.collect_ready_outputs(logical_job_id)
        # A43's resume-cache lease/tombstone linearizes local artifact deletion with collection.
        # Re-check durable privacy intent after collection so an overlapping delete can discard the
        # just-collected value rather than returning it through this public facade.
        self._assert_privacy_not_deleting(logical_job_id)
        return result

    def request_delete(self, logical_job_id: str, *, reason: str = "user_delete") -> Any:
        # Provider identifiers remain server-private. Callers supply only the logical job identity.
        job = self._backend.get(logical_job_id)
        return self._privacy.request_delete(
            logical_job_id,
            provider_asset_id=_optional_identifier(job, "provider_asset_id"),
            provider_task_id=_optional_identifier(job, "provider_task_id"),
            reason=reason,
            delete_provider=True,
        )

    def cancellation_snapshot(self, logical_job_id: str) -> Any:
        return self._cancellation.get_cancellation(logical_job_id)

    def _assert_privacy_not_deleting(self, logical_job_id: str) -> None:
        try:
            record = self._privacy.registry.get(logical_job_id)
        except PrivacyRetentionError:
            raise
        if record is None:
            # Historical jobs may predate A09 registration. The facade does not fabricate deletion
            # evidence for them; account deletion remains fail-closed in account_processing_deletion.
            return
        if bool(getattr(record, "local_delete_requested", False)) or bool(
            getattr(record, "local_delete_confirmed", False)
        ):
            raise ProductionSafetyError("SEP_PRIVACY_DELETION_AUTHORITATIVE", retryable=False)


def _optional_identifier(job: Any, name: str) -> str | None:
    value = getattr(job, name, None)
    if value is None:
        return None
    if not isinstance(value, str) or not value:
        raise ProductionSafetyError("SEP_SAFETY_PROVIDER_ID_INVALID")
    return value
