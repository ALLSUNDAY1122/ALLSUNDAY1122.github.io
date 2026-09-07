"""Product/profile-aware Lane 1 production start composition.

This is deterministic NON_PARITY infrastructure.  It composes the checked-in product/reference
profile registry, server-side entitlement resolution, provider capability negotiation, the
budget/quota guarded durable reconnect start surface, and privacy-retention registration without
exposing provider identifiers to transport callers.

A start is not reported as successful until the backend has a stable logical job plus concrete
provider Asset/Task identity and the privacy registry durably binds the same provider identity.
Ambiguous provider creation, incomplete identity, or privacy-registration failure remains a
fail-closed start failure.  The durable backend state is intentionally left available for an
idempotent retry/reconciliation path; this module never fabricates provider success.
"""
from __future__ import annotations

import re
from typing import Any, Callable, Iterable

from privacy_retention import (
    PrivacyRetentionError,
    RetentionPolicy,
    audioshake_documented_policy,
)
from reference_profiles import (
    ProfileRegistry,
    ProfileRegistryError,
    ProviderCapabilities,
    audioshake_core_capabilities,
    load_registry,
    negotiate_provider,
    resolve_request,
)

EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
_ROLE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
_LOGICAL_JOB_ID = re.compile(r"^[0-9a-f]{32}$")
_SAFE_PROVIDER_ID = re.compile(r"^[A-Za-z0-9._:-]{1,200}$")
_SAFE_ERROR = re.compile(r"^[A-Z0-9_.:-]{1,200}$")


class ProductAwareStartError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class ProductAwareProductionStartService:
    """Concrete start service for ``ProductionTransportAuthorizationGateway``.

    ``account_tier_resolver`` is server-owned authority.  The client never supplies or selects its
    own entitlement tier.  The default provider capabilities and retention policy describe the
    currently implemented AudioShake core adapter only; unsupported custom/Hi-Fi requests fail
    closed rather than being silently downgraded.
    """

    def __init__(
        self,
        *,
        durable_reconnect: Any,
        privacy_retention: Any,
        account_tier_resolver: Callable[[str], str],
        registry: ProfileRegistry | None = None,
        provider_capabilities: ProviderCapabilities | None = None,
        retention_policy: RetentionPolicy | None = None,
    ):
        if not callable(getattr(durable_reconnect, "begin_intent", None)) or not callable(
            getattr(durable_reconnect, "start", None)
        ):
            raise ProductAwareStartError("SEP_START_DURABLE_SURFACE_INVALID")
        if not callable(getattr(privacy_retention, "register", None)):
            raise ProductAwareStartError("SEP_START_PRIVACY_SURFACE_INVALID")
        if not callable(account_tier_resolver):
            raise ProductAwareStartError("SEP_START_ACCOUNT_TIER_RESOLVER_INVALID")

        self.durable_reconnect = durable_reconnect
        self.privacy_retention = privacy_retention
        self.account_tier_resolver = account_tier_resolver
        self.registry = registry or load_registry()
        self.provider_capabilities = provider_capabilities or audioshake_core_capabilities()
        self.retention_policy = retention_policy or audioshake_documented_policy()
        self.retention_policy.validate()

    def start(
        self,
        *,
        source_path: Any,
        project_id: str,
        asset_id: str,
        canonical_roles: Iterable[str],
        quality_profile: str,
        idempotency_key: str,
    ) -> dict[str, Any]:
        roles = _canonical_transport_roles(canonical_roles)
        profile_id, selected_roles = _select_reference_profile(roles, self.registry)
        account_tier = self._resolve_account_tier(project_id)

        try:
            request = resolve_request(
                profile_id,
                account_tier=account_tier,
                selected_roles=selected_roles,
                quality_mode=quality_profile,
                registry=self.registry,
            )
            plan = negotiate_provider(
                request,
                self.provider_capabilities,
                registry=self.registry,
            )
        except ProfileRegistryError:
            raise

        # The existing BudgetedProductionSeparationOrchestrator consumes model targets but does not
        # yet expose a provider-quality-token argument.  Only a capability whose negotiated token is
        # None may pass this composition; dropping a non-default token would silently weaken quality.
        if plan.provider_quality_token is not None:
            raise ProductAwareStartError("SEP_START_PROVIDER_QUALITY_TOKEN_UNSUPPORTED")

        try:
            intent = self.durable_reconnect.begin_intent(
                project_id=project_id,
                asset_id=asset_id,
                requested_profile_id=profile_id,
                models=plan.provider_models,
                idempotency_key=idempotency_key,
            )
        except Exception as exc:
            raise _stable_start_error(exc, "SEP_START_DURABLE_INTENT_FAILED") from exc

        logical_job_id = _require_logical_job_id(getattr(intent, "logical_job_id", None))

        try:
            job = self.durable_reconnect.start(
                source_path=source_path,
                project_id=project_id,
                asset_id=asset_id,
                requested_profile_id=profile_id,
                models=plan.provider_models,
                idempotency_key=idempotency_key,
            )
        except Exception as exc:
            # DurableReconnectService already preserves/rebinds any backend record it can recover.
            # Do not create a privacy record from partial/ambiguous provider identity here: account
            # deletion must remain visibly incomplete until provider identity becomes authoritative.
            raise _stable_start_error(exc, "SEP_START_BACKEND_FAILED") from exc

        actual_logical_job_id = _require_logical_job_id(getattr(job, "logical_job_id", None))
        if actual_logical_job_id != logical_job_id:
            raise ProductAwareStartError("SEP_START_LOGICAL_JOB_ID_MISMATCH")

        provider_asset_id = _require_provider_id(
            getattr(job, "provider_asset_id", None),
            "SEP_START_PROVIDER_ASSET_ID_INCOMPLETE",
        )
        provider_task_id = _require_provider_id(
            getattr(job, "provider_task_id", None),
            "SEP_START_PROVIDER_TASK_ID_INCOMPLETE",
        )

        try:
            privacy_record = self.privacy_retention.register(
                logical_job_id=logical_job_id,
                provider_asset_id=provider_asset_id,
                provider_task_id=provider_task_id,
                policy=self.retention_policy,
            )
        except PrivacyRetentionError:
            raise
        except Exception as exc:
            raise _stable_start_error(exc, "SEP_START_PRIVACY_REGISTRATION_FAILED") from exc

        # Re-read only the public identity hashes exposed by the privacy record object.  Raw provider
        # identifiers never cross this service boundary.
        if not isinstance(getattr(privacy_record, "provider_asset_id_hash", None), str) or not isinstance(
            getattr(privacy_record, "provider_task_id_hash", None), str
        ):
            raise ProductAwareStartError("SEP_START_PRIVACY_IDENTITY_UNCONFIRMED")

        return {
            "logical_job_id": logical_job_id,
            "profile_id": profile_id,
            "canonical_roles": list(request.canonical_roles),
            "quality_mode": request.quality_mode,
            "evidence_state": EVIDENCE_STATE,
            "parity_claim": "NONE",
        }

    def _resolve_account_tier(self, project_id: str) -> str:
        try:
            tier = self.account_tier_resolver(project_id)
        except Exception as exc:
            raise _stable_start_error(exc, "SEP_START_ACCOUNT_TIER_UNAVAILABLE", retryable=True) from exc
        if not isinstance(tier, str):
            raise ProductAwareStartError("SEP_START_ACCOUNT_TIER_INVALID")
        return tier


def _select_reference_profile(
    roles: tuple[str, ...],
    registry: ProfileRegistry,
) -> tuple[str, tuple[str, ...]]:
    requested_set = set(roles)
    candidates: list[tuple[str, tuple[str, ...]]] = []
    for profile in registry.profiles.values():
        if profile.selection_mode == "fixed":
            if len(profile.fixed_roles) == len(roles) and set(profile.fixed_roles) == requested_set:
                candidates.append((profile.profile_id, ()))
        elif profile.selection_mode == "custom":
            allow = set(profile.custom_role_allowlist)
            if requested_set and requested_set.issubset(allow):
                candidates.append((profile.profile_id, roles))
    if not candidates:
        raise ProductAwareStartError("SEP_START_PROFILE_UNRESOLVED")
    if len(candidates) != 1:
        raise ProductAwareStartError("SEP_START_PROFILE_AMBIGUOUS")
    return candidates[0]


def _canonical_transport_roles(values: Iterable[str]) -> tuple[str, ...]:
    if isinstance(values, (str, bytes)):
        raise ProductAwareStartError("SEP_START_ROLES_INVALID")
    try:
        roles = tuple(values)
    except TypeError as exc:
        raise ProductAwareStartError("SEP_START_ROLES_INVALID") from exc
    if not roles or len(roles) > 32:
        raise ProductAwareStartError("SEP_START_ROLES_INVALID")
    if any(not isinstance(role, str) or not _ROLE.fullmatch(role) for role in roles):
        raise ProductAwareStartError("SEP_START_ROLES_INVALID")
    if len(set(roles)) != len(roles) or tuple(sorted(roles)) != roles:
        raise ProductAwareStartError("SEP_START_ROLES_NONCANONICAL")
    return roles


def _require_logical_job_id(value: Any) -> str:
    if not isinstance(value, str) or not _LOGICAL_JOB_ID.fullmatch(value):
        raise ProductAwareStartError("SEP_START_LOGICAL_JOB_ID_INVALID")
    return value


def _require_provider_id(value: Any, code: str) -> str:
    if not isinstance(value, str) or not _SAFE_PROVIDER_ID.fullmatch(value):
        raise ProductAwareStartError(code)
    return value


def _stable_start_error(
    exc: Exception,
    fallback: str,
    *,
    retryable: bool | None = None,
) -> ProductAwareStartError:
    code = getattr(exc, "code", None)
    if not isinstance(code, str) or not _SAFE_ERROR.fullmatch(code):
        code = fallback
    if retryable is None:
        retryable = bool(getattr(exc, "retryable", False))
    return ProductAwareStartError(code, retryable=retryable)
