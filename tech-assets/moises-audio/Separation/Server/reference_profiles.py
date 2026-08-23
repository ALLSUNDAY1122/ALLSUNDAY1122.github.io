"""Provider-neutral current-iPhone separation profile registry for Lane 1.

The public registry contains only canonical product profile IDs, canonical stem roles and
Reference evidence boundaries. Provider-specific model names are supplied separately through a
capability descriptor, so callers/HQ never need to encode a vendor name in a product request.

This module is NON-PARITY evidence. It intentionally fails closed on any role/profile/quality
combination not established by the checked-in Reference registry.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping

_SCHEMA_VERSION = 1
_PROFILE_ID = re.compile(r"^sep\.[a-z0-9_.-]{1,96}$")
_ROLE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
_TIER_ORDER = {"free": 0, "premium": 1, "pro": 2}
_DEFAULT_REGISTRY_PATH = Path(__file__).resolve().parents[1] / "Profiles" / "reference_profiles.v1.json"


class ProfileRegistryError(RuntimeError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


@dataclass(frozen=True)
class SeparationProfile:
    profile_id: str
    selection_mode: str
    fixed_roles: tuple[str, ...]
    custom_role_allowlist: tuple[str, ...]
    minimum_tier: str
    allowed_quality_modes: tuple[str, ...]
    hifi_minimum_tier: str | None
    output_policy: str
    reference_basis: str
    reference_note: str


@dataclass(frozen=True)
class ProfileRegistry:
    schema_version: int
    reference_id: str
    captured_at: str
    parity_state: str
    canonical_roles: frozenset[str]
    quality_modes: frozenset[str]
    profiles: Mapping[str, SeparationProfile]
    unknowns: tuple[str, ...]


@dataclass(frozen=True)
class ProfileRequest:
    profile_id: str
    account_tier: str
    quality_mode: str
    canonical_roles: tuple[str, ...]


@dataclass(frozen=True)
class ProviderCapabilities:
    """Internal provider descriptor.

    `provider_key` is diagnostics-only and must not be embedded in public profile IDs.
    `role_model_map` maps canonical roles to provider-specific model/target names.
    `quality_mode_map` maps canonical quality modes to provider request tokens. A None token is
    valid and means the provider's default mode.
    """

    provider_key: str
    role_model_map: Mapping[str, str]
    quality_mode_map: Mapping[str, str | None]
    supports_custom_selection: bool
    max_targets: int | None = None
    incompatible_role_sets: tuple[frozenset[str], ...] = ()


@dataclass(frozen=True)
class ProviderPlan:
    profile_id: str
    canonical_roles: tuple[str, ...]
    provider_models: tuple[str, ...]
    quality_mode: str
    provider_quality_token: str | None
    provider_key: str


def load_registry(path: str | Path = _DEFAULT_REGISTRY_PATH) -> ProfileRegistry:
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProfileRegistryError("SEP_PROFILE_REGISTRY_UNREADABLE") from exc
    if not isinstance(raw, dict) or raw.get("schema_version") != _SCHEMA_VERSION:
        raise ProfileRegistryError("SEP_PROFILE_REGISTRY_SCHEMA_INVALID")

    reference_id = raw.get("reference_id")
    captured_at = raw.get("captured_at")
    parity_state = raw.get("parity_state")
    roles_raw = raw.get("canonical_roles")
    quality_raw = raw.get("quality_modes")
    profiles_raw = raw.get("profiles")
    unknowns_raw = raw.get("unknowns", [])
    if not isinstance(reference_id, str) or not reference_id:
        raise ProfileRegistryError("SEP_PROFILE_REFERENCE_ID_INVALID")
    if not isinstance(captured_at, str) or not captured_at:
        raise ProfileRegistryError("SEP_PROFILE_CAPTURE_DATE_INVALID")
    if parity_state != "NON_PARITY_EVIDENCE_ONLY":
        raise ProfileRegistryError("SEP_PROFILE_PARITY_STATE_INVALID")
    if not isinstance(roles_raw, list) or not roles_raw:
        raise ProfileRegistryError("SEP_PROFILE_CANONICAL_ROLES_INVALID")
    if not isinstance(quality_raw, list) or not quality_raw:
        raise ProfileRegistryError("SEP_PROFILE_QUALITY_MODES_INVALID")
    if not isinstance(profiles_raw, list) or not profiles_raw:
        raise ProfileRegistryError("SEP_PROFILE_LIST_INVALID")
    if not isinstance(unknowns_raw, list) or any(not isinstance(v, str) for v in unknowns_raw):
        raise ProfileRegistryError("SEP_PROFILE_UNKNOWNS_INVALID")

    canonical_roles = frozenset(_validate_role_list(roles_raw, "SEP_PROFILE_CANONICAL_ROLES_INVALID"))
    quality_modes = frozenset(_unique_strings(quality_raw, "SEP_PROFILE_QUALITY_MODES_INVALID"))
    if "standard" not in quality_modes:
        raise ProfileRegistryError("SEP_PROFILE_STANDARD_QUALITY_MISSING")

    profiles: dict[str, SeparationProfile] = {}
    for value in profiles_raw:
        profile = _parse_profile(value, canonical_roles, quality_modes)
        if profile.profile_id in profiles:
            raise ProfileRegistryError("SEP_PROFILE_DUPLICATE_ID")
        profiles[profile.profile_id] = profile

    return ProfileRegistry(
        schema_version=_SCHEMA_VERSION,
        reference_id=reference_id,
        captured_at=captured_at,
        parity_state=parity_state,
        canonical_roles=canonical_roles,
        quality_modes=quality_modes,
        profiles=profiles,
        unknowns=tuple(unknowns_raw),
    )


def resolve_request(
    profile_id: str,
    *,
    account_tier: str,
    selected_roles: Iterable[str] = (),
    quality_mode: str = "standard",
    registry: ProfileRegistry | None = None,
) -> ProfileRequest:
    registry = registry or load_registry()
    if account_tier not in _TIER_ORDER:
        raise ProfileRegistryError("SEP_PROFILE_ACCOUNT_TIER_INVALID")
    try:
        profile = registry.profiles[profile_id]
    except KeyError as exc:
        raise ProfileRegistryError("SEP_PROFILE_UNKNOWN") from exc
    if _TIER_ORDER[account_tier] < _TIER_ORDER[profile.minimum_tier]:
        raise ProfileRegistryError("SEP_PROFILE_ENTITLEMENT_REQUIRED")
    if quality_mode not in profile.allowed_quality_modes:
        raise ProfileRegistryError("SEP_PROFILE_QUALITY_UNSUPPORTED_BY_REFERENCE")
    if quality_mode == "hifi":
        minimum = profile.hifi_minimum_tier
        if minimum is None or _TIER_ORDER[account_tier] < _TIER_ORDER[minimum]:
            raise ProfileRegistryError("SEP_PROFILE_HIFI_ENTITLEMENT_REQUIRED")

    selected = _normalize_request_roles(selected_roles)
    if profile.selection_mode == "fixed":
        if selected:
            raise ProfileRegistryError("SEP_PROFILE_FIXED_SELECTION_OVERRIDE_FORBIDDEN")
        canonical_roles = profile.fixed_roles
    elif profile.selection_mode == "custom":
        if not selected:
            raise ProfileRegistryError("SEP_PROFILE_CUSTOM_SELECTION_REQUIRED")
        allowed = set(profile.custom_role_allowlist)
        if any(role not in allowed for role in selected):
            raise ProfileRegistryError("SEP_PROFILE_CUSTOM_ROLE_NOT_REFERENCE_CONFIRMED")
        canonical_roles = selected
    else:
        raise ProfileRegistryError("SEP_PROFILE_SELECTION_MODE_INVALID")

    return ProfileRequest(
        profile_id=profile.profile_id,
        account_tier=account_tier,
        quality_mode=quality_mode,
        canonical_roles=canonical_roles,
    )


def negotiate_provider(
    request: ProfileRequest,
    capabilities: ProviderCapabilities,
    *,
    registry: ProfileRegistry | None = None,
) -> ProviderPlan:
    registry = registry or load_registry()
    try:
        profile = registry.profiles[request.profile_id]
    except KeyError as exc:
        raise ProfileRegistryError("SEP_PROFILE_UNKNOWN") from exc

    if profile.selection_mode == "custom" and not capabilities.supports_custom_selection:
        raise ProfileRegistryError("SEP_PROVIDER_CUSTOM_SELECTION_UNSUPPORTED")
    if request.quality_mode not in capabilities.quality_mode_map:
        raise ProfileRegistryError("SEP_PROVIDER_QUALITY_MODE_UNSUPPORTED")
    if capabilities.max_targets is not None:
        if not isinstance(capabilities.max_targets, int) or capabilities.max_targets <= 0:
            raise ProfileRegistryError("SEP_PROVIDER_MAX_TARGETS_INVALID")
        if len(request.canonical_roles) > capabilities.max_targets:
            raise ProfileRegistryError("SEP_PROVIDER_TARGET_LIMIT_EXCEEDED")

    requested = frozenset(request.canonical_roles)
    for incompatible in capabilities.incompatible_role_sets:
        if incompatible and incompatible.issubset(requested):
            raise ProfileRegistryError("SEP_PROVIDER_ROLE_COMBINATION_UNSUPPORTED")

    provider_models: list[str] = []
    seen_models: set[str] = set()
    for role in request.canonical_roles:
        model = capabilities.role_model_map.get(role)
        if not isinstance(model, str) or not model:
            raise ProfileRegistryError("SEP_PROVIDER_ROLE_UNSUPPORTED")
        if model in seen_models:
            raise ProfileRegistryError("SEP_PROVIDER_ROLE_MAP_COLLISION")
        provider_models.append(model)
        seen_models.add(model)

    return ProviderPlan(
        profile_id=request.profile_id,
        canonical_roles=request.canonical_roles,
        provider_models=tuple(provider_models),
        quality_mode=request.quality_mode,
        provider_quality_token=capabilities.quality_mode_map[request.quality_mode],
        provider_key=capabilities.provider_key,
    )


def validate_output_completeness(request: ProfileRequest, observed_roles: Iterable[str]) -> tuple[str, ...]:
    observed = _normalize_output_roles(observed_roles)
    if set(observed) != set(request.canonical_roles) or len(observed) != len(request.canonical_roles):
        raise ProfileRegistryError("SEP_PROFILE_OUTPUT_SET_INCOMPLETE")
    return tuple(role for role in request.canonical_roles if role in set(observed))


def audioshake_core_capabilities() -> ProviderCapabilities:
    """Capability descriptor for the currently implemented core adapter only.

    This deliberately advertises no custom-selection or Hi-Fi support because those are not
    implemented/verified in the checked-in AudioShake adapter. A12 may extend provider mappings
    after capability evidence exists.
    """

    return ProviderCapabilities(
        provider_key="audioshake-core-current-adapter",
        role_model_map={
            "vocals": "vocals",
            "instrumental": "instrumental",
            "drums": "drums",
            "bass": "bass",
            "other": "other",
        },
        quality_mode_map={"standard": None},
        supports_custom_selection=False,
        max_targets=5,
    )


def public_registry_snapshot(registry: ProfileRegistry | None = None) -> dict[str, object]:
    """Return the provider-neutral product registry for HQ/App integration evidence."""

    registry = registry or load_registry()
    return {
        "schema_version": registry.schema_version,
        "reference_id": registry.reference_id,
        "captured_at": registry.captured_at,
        "parity_state": registry.parity_state,
        "canonical_roles": sorted(registry.canonical_roles),
        "quality_modes": sorted(registry.quality_modes),
        "profiles": [
            {
                "profile_id": p.profile_id,
                "selection_mode": p.selection_mode,
                "fixed_roles": list(p.fixed_roles),
                "custom_role_allowlist": list(p.custom_role_allowlist),
                "minimum_tier": p.minimum_tier,
                "allowed_quality_modes": list(p.allowed_quality_modes),
                "hifi_minimum_tier": p.hifi_minimum_tier,
                "output_policy": p.output_policy,
                "reference_basis": p.reference_basis,
            }
            for p in sorted(registry.profiles.values(), key=lambda item: item.profile_id)
        ],
        "unknowns": list(registry.unknowns),
    }


def _parse_profile(raw: object, canonical_roles: frozenset[str], quality_modes: frozenset[str]) -> SeparationProfile:
    if not isinstance(raw, dict):
        raise ProfileRegistryError("SEP_PROFILE_RECORD_INVALID")
    profile_id = raw.get("profile_id")
    selection_mode = raw.get("selection_mode")
    minimum_tier = raw.get("minimum_tier")
    output_policy = raw.get("output_policy")
    reference_basis = raw.get("reference_basis")
    reference_note = raw.get("reference_note")
    if not isinstance(profile_id, str) or not _PROFILE_ID.fullmatch(profile_id):
        raise ProfileRegistryError("SEP_PROFILE_ID_INVALID")
    if selection_mode not in {"fixed", "custom"}:
        raise ProfileRegistryError("SEP_PROFILE_SELECTION_MODE_INVALID")
    if minimum_tier not in _TIER_ORDER:
        raise ProfileRegistryError("SEP_PROFILE_MINIMUM_TIER_INVALID")
    if output_policy != "exact_set":
        raise ProfileRegistryError("SEP_PROFILE_OUTPUT_POLICY_INVALID")
    if not isinstance(reference_basis, str) or not reference_basis:
        raise ProfileRegistryError("SEP_PROFILE_REFERENCE_BASIS_INVALID")
    if not isinstance(reference_note, str) or not reference_note:
        raise ProfileRegistryError("SEP_PROFILE_REFERENCE_NOTE_INVALID")

    fixed_roles = tuple(_validate_role_list(raw.get("fixed_roles"), "SEP_PROFILE_FIXED_ROLES_INVALID"))
    custom_roles = tuple(_validate_role_list(raw.get("custom_role_allowlist"), "SEP_PROFILE_CUSTOM_ROLES_INVALID"))
    allowed_quality = tuple(_unique_strings(raw.get("allowed_quality_modes"), "SEP_PROFILE_ALLOWED_QUALITY_INVALID"))
    if any(value not in quality_modes for value in allowed_quality):
        raise ProfileRegistryError("SEP_PROFILE_ALLOWED_QUALITY_INVALID")
    hifi_minimum = raw.get("hifi_minimum_tier")
    if hifi_minimum is not None and hifi_minimum not in _TIER_ORDER:
        raise ProfileRegistryError("SEP_PROFILE_HIFI_TIER_INVALID")
    if "hifi" in allowed_quality and hifi_minimum is None:
        raise ProfileRegistryError("SEP_PROFILE_HIFI_TIER_MISSING")
    if "hifi" not in allowed_quality and hifi_minimum is not None:
        raise ProfileRegistryError("SEP_PROFILE_HIFI_TIER_UNEXPECTED")

    role_set = set(fixed_roles) | set(custom_roles)
    if any(role not in canonical_roles for role in role_set):
        raise ProfileRegistryError("SEP_PROFILE_ROLE_NOT_CANONICAL")
    if selection_mode == "fixed":
        if not fixed_roles or custom_roles:
            raise ProfileRegistryError("SEP_PROFILE_FIXED_SHAPE_INVALID")
    else:
        if fixed_roles or not custom_roles:
            raise ProfileRegistryError("SEP_PROFILE_CUSTOM_SHAPE_INVALID")

    return SeparationProfile(
        profile_id=profile_id,
        selection_mode=selection_mode,
        fixed_roles=fixed_roles,
        custom_role_allowlist=custom_roles,
        minimum_tier=minimum_tier,
        allowed_quality_modes=allowed_quality,
        hifi_minimum_tier=hifi_minimum,
        output_policy=output_policy,
        reference_basis=reference_basis,
        reference_note=reference_note,
    )


def _validate_role_list(value: object, code: str) -> list[str]:
    if not isinstance(value, list):
        raise ProfileRegistryError(code)
    if any(not isinstance(role, str) or not _ROLE.fullmatch(role) for role in value):
        raise ProfileRegistryError(code)
    if len(value) != len(set(value)):
        raise ProfileRegistryError(code)
    return list(value)


def _unique_strings(value: object, code: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(v, str) or not v for v in value):
        raise ProfileRegistryError(code)
    if len(value) != len(set(value)):
        raise ProfileRegistryError(code)
    return list(value)


def _normalize_request_roles(roles: Iterable[str]) -> tuple[str, ...]:
    if isinstance(roles, (str, bytes)):
        raise ProfileRegistryError("SEP_PROFILE_SELECTED_ROLES_INVALID")
    selected = tuple(roles)
    if any(not isinstance(role, str) or not _ROLE.fullmatch(role) for role in selected):
        raise ProfileRegistryError("SEP_PROFILE_SELECTED_ROLES_INVALID")
    if len(selected) != len(set(selected)):
        raise ProfileRegistryError("SEP_PROFILE_SELECTED_ROLES_DUPLICATE")
    return selected


def _normalize_output_roles(roles: Iterable[str]) -> tuple[str, ...]:
    if isinstance(roles, (str, bytes)):
        raise ProfileRegistryError("SEP_PROFILE_OUTPUT_ROLES_INVALID")
    observed = tuple(roles)
    if any(not isinstance(role, str) or not _ROLE.fullmatch(role) for role in observed):
        raise ProfileRegistryError("SEP_PROFILE_OUTPUT_ROLES_INVALID")
    if len(observed) != len(set(observed)):
        raise ProfileRegistryError("SEP_PROFILE_OUTPUT_ROLE_DUPLICATE")
    return observed
