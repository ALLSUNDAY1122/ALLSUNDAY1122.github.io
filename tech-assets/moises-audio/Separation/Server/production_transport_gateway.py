"""Framework-neutral authorization/application boundary for Lane 1 production transport.

This module does not authenticate HTTP/iOS requests and is not deployment/PARITY evidence.
A real transport must authenticate the caller first, then pass the stable principal identity into
this gateway. The gateway makes authorization and project/job ownership fail-closed before any
snapshot/result/cancel/delete side effect and routes processing operations only through the
canonical ProductionSeparationSafetyFacade / AccountProcessingDeletionService surfaces.

The design intentionally contains no raw production-backend methods. A future web framework
adapter should be thin: authenticate -> decode exact stable IDs -> call this gateway -> encode the
already-sanitized result.
"""
from __future__ import annotations

import re
import uuid
from typing import Any

_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_SAFE_PRINCIPAL_ID = re.compile(r"^[A-Za-z0-9._:@+\-]{1,200}$")
_ALLOWED_OPERATIONS = frozenset(
    {
        "processing_snapshot",
        "processing_result",
        "processing_cancel",
        "processing_delete",
        "account_project_delete",
    }
)


class ProductionTransportGatewayError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class DurableReconnectProjectResolver:
    """Binds a logical processing job to the durable project identity before authorization use."""

    def __init__(self, durable_reconnect: Any):
        registry = getattr(durable_reconnect, "registry", None)
        if registry is None or not callable(getattr(registry, "get", None)):
            raise ProductionTransportGatewayError("SEP_TRANSPORT_RECOVERY_REGISTRY_SURFACE_MISSING")
        self._registry = registry

    def project_id_for_job(self, logical_job_id: str) -> str:
        logical_job_id = _canonical_logical_job_id(logical_job_id)
        record = self._registry.get(logical_job_id)
        if record is None:
            raise ProductionTransportGatewayError("SEP_TRANSPORT_JOB_NOT_REGISTERED")
        project_id = getattr(record, "project_id", None)
        if not isinstance(project_id, str):
            raise ProductionTransportGatewayError("SEP_TRANSPORT_JOB_PROJECT_ID_INVALID")
        return _canonical_project_id(project_id)


class ProductionTransportAuthorizationGateway:
    """Authorization gate that keeps raw Lane 1 backend surfaces outside transport reach."""

    def __init__(
        self,
        *,
        safety_facade: Any,
        account_deletion: Any,
        authorizer: Any,
        project_resolver: Any,
    ):
        for name in ("snapshot", "result", "request_cancel", "request_delete"):
            if not callable(getattr(safety_facade, name, None)):
                raise ProductionTransportGatewayError("SEP_TRANSPORT_SAFETY_SURFACE_MISSING")
        if not callable(getattr(account_deletion, "delete_project", None)):
            raise ProductionTransportGatewayError("SEP_TRANSPORT_ACCOUNT_DELETE_SURFACE_MISSING")
        if not callable(getattr(authorizer, "authorize", None)):
            raise ProductionTransportGatewayError("SEP_TRANSPORT_AUTHORIZER_SURFACE_MISSING")
        if not callable(getattr(project_resolver, "project_id_for_job", None)):
            raise ProductionTransportGatewayError("SEP_TRANSPORT_PROJECT_RESOLVER_SURFACE_MISSING")

        self._safety = safety_facade
        self._account_deletion = account_deletion
        self._authorizer = authorizer
        self._project_resolver = project_resolver

    def snapshot(self, *, principal_id: str, project_id: str, logical_job_id: str) -> Any:
        project_id = self._authorize_project(
            principal_id=principal_id,
            project_id=project_id,
            operation="processing_snapshot",
        )
        logical_job_id = self._require_job_project(logical_job_id, project_id)
        return self._safety.snapshot(logical_job_id)

    def result(self, *, principal_id: str, project_id: str, logical_job_id: str) -> Any:
        project_id = self._authorize_project(
            principal_id=principal_id,
            project_id=project_id,
            operation="processing_result",
        )
        logical_job_id = self._require_job_project(logical_job_id, project_id)
        return self._safety.result(logical_job_id)

    def cancel(self, *, principal_id: str, project_id: str, logical_job_id: str) -> Any:
        project_id = self._authorize_project(
            principal_id=principal_id,
            project_id=project_id,
            operation="processing_cancel",
        )
        logical_job_id = self._require_job_project(logical_job_id, project_id)
        return self._safety.request_cancel(logical_job_id)

    def delete_processing_job(
        self,
        *,
        principal_id: str,
        project_id: str,
        logical_job_id: str,
    ) -> Any:
        project_id = self._authorize_project(
            principal_id=principal_id,
            project_id=project_id,
            operation="processing_delete",
        )
        logical_job_id = self._require_job_project(logical_job_id, project_id)
        return self._safety.request_delete(logical_job_id, reason="user_delete")

    def delete_account_project(self, *, principal_id: str, project_id: str) -> Any:
        project_id = self._authorize_project(
            principal_id=principal_id,
            project_id=project_id,
            operation="account_project_delete",
        )
        # AccountProcessingDeletionService re-enumerates every durable Lane 1 job for this exact
        # project and independently requires terminal privacy/provider evidence before tombstoning.
        return self._account_deletion.delete_project(project_id)

    def _authorize_project(self, *, principal_id: str, project_id: str, operation: str) -> str:
        principal_id = _canonical_principal_id(principal_id)
        project_id = _canonical_project_id(project_id)
        if operation not in _ALLOWED_OPERATIONS:
            raise ProductionTransportGatewayError("SEP_TRANSPORT_OPERATION_INVALID")
        try:
            allowed = self._authorizer.authorize(
                principal_id=principal_id,
                project_id=project_id,
                operation=operation,
            )
        except ProductionTransportGatewayError:
            raise
        except Exception as exc:
            raise ProductionTransportGatewayError(
                "SEP_TRANSPORT_AUTHORIZATION_UNAVAILABLE",
                retryable=True,
            ) from exc
        # Accept only the literal boolean True. Truthy strings/objects are not authorization proof.
        if allowed is not True:
            raise ProductionTransportGatewayError("SEP_TRANSPORT_FORBIDDEN", retryable=False)
        return project_id

    def _require_job_project(self, logical_job_id: str, authorized_project_id: str) -> str:
        logical_job_id = _canonical_logical_job_id(logical_job_id)
        try:
            actual_project_id = self._project_resolver.project_id_for_job(logical_job_id)
        except ProductionTransportGatewayError:
            raise
        except Exception as exc:
            raise ProductionTransportGatewayError(
                "SEP_TRANSPORT_PROJECT_RESOLUTION_UNAVAILABLE",
                retryable=True,
            ) from exc
        actual_project_id = _canonical_project_id(actual_project_id)
        if actual_project_id != authorized_project_id:
            raise ProductionTransportGatewayError("SEP_TRANSPORT_JOB_PROJECT_MISMATCH")
        return logical_job_id


def _canonical_principal_id(value: str) -> str:
    if not isinstance(value, str) or not _SAFE_PRINCIPAL_ID.fullmatch(value):
        raise ProductionTransportGatewayError("SEP_TRANSPORT_PRINCIPAL_ID_INVALID")
    return value


def _canonical_project_id(value: str) -> str:
    if not isinstance(value, str):
        raise ProductionTransportGatewayError("SEP_TRANSPORT_PROJECT_ID_INVALID")
    try:
        parsed = uuid.UUID(value)
    except (ValueError, AttributeError, TypeError) as exc:
        raise ProductionTransportGatewayError("SEP_TRANSPORT_PROJECT_ID_INVALID") from exc
    canonical = str(parsed)
    if value.lower() != canonical:
        raise ProductionTransportGatewayError("SEP_TRANSPORT_PROJECT_ID_NONCANONICAL")
    return canonical


def _canonical_logical_job_id(value: str) -> str:
    if not isinstance(value, str) or not _LOGICAL_JOB_ID.fullmatch(value):
        raise ProductionTransportGatewayError("SEP_TRANSPORT_LOGICAL_JOB_ID_INVALID")
    return value
