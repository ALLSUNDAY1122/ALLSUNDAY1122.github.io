"""Side-effect-free product/profile planning for Lane 1 production starts.

The iOS transport sends the exact canonical role set and quality mode, not a provider model list.
This module binds that request to the checked-in provider-neutral Reference profile registry and a
trusted server-side account tier before any upload/provider side effect may occur.

It intentionally does *not* start a provider task and does not claim PARITY. The current production
orchestrator accepts provider models but has no provider-quality-token parameter; therefore a plan
that requires a non-default provider quality token is rejected rather than silently degrading the
requested quality semantics.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

from reference_profiles import (
    ProfileRegistry,
    ProfileRegistryError,
    ProviderCapabilities,
    ProviderPlan,
    load_registry,
    negotiate_provider,
    resolve_request,
)

_ROLE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")


class ProductAwareStartPlannerError(RuntimeError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


@dataclass(frozen=True)
class ProductionStartPlan:
    profile_id: str
    canonical_roles: tuple[str, ...]
    quality_mode: str
    provider_models: tuple[str, ...]
    provider_key: str


class ProductAwareStartPlanner:
    """Resolve exact app roles/quality into one orchestrator-compatible provider model plan.

    `account_tier` is trusted server-side entitlement state. A future concrete start service must
    resolve it from the authenticated principal/project binding; it must never trust a client header
    for this value.
    """

    def __init__(
        self,
        *,
        capabilities: ProviderCapabilities,
        registry: ProfileRegistry | None = None,
    ):
        self._registry = registry or load_registry()
        self._capabilities = capabilities

    def plan(
        self,
        *,
        canonical_roles: Iterable[str],
        quality_profile: str,
        account_tier: str,
    ) -> ProductionStartPlan:
        roles = _require_transport_canonical_roles(canonical_roles)
        profile_id = self._resolve_unique_profile_id(roles)

        profile = self._registry.profiles[profile_id]
        selected_roles: tuple[str, ...] = () if profile.selection_mode == "fixed" else roles
        try:
            request = resolve_request(
                profile_id,
                account_tier=account_tier,
                selected_roles=selected_roles,
                quality_mode=quality_profile,
                registry=self._registry,
            )
            provider = negotiate_provider(
                request,
                self._capabilities,
                registry=self._registry,
            )
        except ProfileRegistryError as exc:
            raise ProductAwareStartPlannerError(exc.code) from exc

        if set(provider.canonical_roles) != set(roles) or len(provider.canonical_roles) != len(roles):
            raise ProductAwareStartPlannerError("SEP_START_PROFILE_ROLE_REBIND_MISMATCH")
        if provider.quality_mode != quality_profile:
            raise ProductAwareStartPlannerError("SEP_START_PROFILE_QUALITY_REBIND_MISMATCH")
        if provider.provider_quality_token is not None:
            # ProductionSeparationOrchestrator currently accepts `models` only. Do not pretend a
            # provider-specific Hi-Fi/quality token was honored when there is no transport for it.
            raise ProductAwareStartPlannerError("SEP_PRODUCTION_QUALITY_TRANSPORT_UNSUPPORTED")

        return ProductionStartPlan(
            profile_id=provider.profile_id,
            canonical_roles=roles,
            quality_mode=provider.quality_mode,
            provider_models=provider.provider_models,
            provider_key=provider.provider_key,
        )

    def _resolve_unique_profile_id(self, roles: tuple[str, ...]) -> str:
        requested = set(roles)
        candidates: list[str] = []
        for profile in self._registry.profiles.values():
            if profile.selection_mode == "fixed":
                if len(profile.fixed_roles) == len(roles) and set(profile.fixed_roles) == requested:
                    candidates.append(profile.profile_id)
            elif profile.selection_mode == "custom":
                allowlist = set(profile.custom_role_allowlist)
                if requested and requested.issubset(allowlist):
                    candidates.append(profile.profile_id)
            else:  # registry loader should already reject this; retain fail-closed defense.
                raise ProductAwareStartPlannerError("SEP_START_PROFILE_SELECTION_MODE_INVALID")

        if not candidates:
            raise ProductAwareStartPlannerError("SEP_START_PROFILE_UNRESOLVED")
        if len(candidates) != 1:
            raise ProductAwareStartPlannerError("SEP_START_PROFILE_AMBIGUOUS")
        return candidates[0]


def _require_transport_canonical_roles(values: Iterable[str]) -> tuple[str, ...]:
    if isinstance(values, (str, bytes)):
        raise ProductAwareStartPlannerError("SEP_START_ROLES_INVALID")
    try:
        roles = tuple(values)
    except TypeError as exc:
        raise ProductAwareStartPlannerError("SEP_START_ROLES_INVALID") from exc
    if not roles or len(roles) > 32:
        raise ProductAwareStartPlannerError("SEP_START_ROLES_INVALID")
    if any(not isinstance(role, str) or not _ROLE.fullmatch(role) for role in roles):
        raise ProductAwareStartPlannerError("SEP_START_ROLES_INVALID")
    if len(set(roles)) != len(roles) or tuple(sorted(roles)) != roles:
        raise ProductAwareStartPlannerError("SEP_START_ROLES_NONCANONICAL")
    return roles
