"""Advanced instrument / Hi-Fi capability hardening for Lane 1.

This module separates three concepts that must not be conflated:
1. provider-neutral canonical roles that Lane 1 can represent;
2. current-iPhone Reference activation (owned by the profile registry/evidence);
3. models actually enabled for a production provider account.

AudioShake model discovery uses GET /models through the existing server-side client. The
presence of a documented model never implies account access, Reference parity, or Hi-Fi support.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Protocol

from reference_profiles import ProviderCapabilities

_SCHEMA_VERSION = 1
_MODEL_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
_ROLE_ID = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
_DEFAULT_CATALOG_PATH = Path(__file__).resolve().parents[1] / "Profiles" / "advanced_role_catalog.v1.json"
_ALLOWED_REFERENCE_STATES = {
    "BASIC_REFERENCE_CONFIRMED",
    "DIRECT_CURRENT_IPHONE_CONFIRMED",
    "UNVERIFIED_CURRENT_IPHONE",
}


class AdvancedCapabilityError(RuntimeError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


@dataclass(frozen=True)
class AdvancedRole:
    canonical_role: str
    reference_state: str
    audioshake_model: str | None
    family: str
    notes: str


@dataclass(frozen=True)
class AdvancedRoleCatalog:
    schema_version: int
    captured_at: str
    parity_state: str
    roles: Mapping[str, AdvancedRole]
    incompatible_role_sets: tuple[frozenset[str], ...]
    unknowns: tuple[str, ...]


@dataclass(frozen=True)
class DiscoveredModel:
    model_id: str
    category: str
    access: str
    output_formats: tuple[str, ...]
    credits_per_minute: float | None
    max_input_duration_seconds: float | None


@dataclass(frozen=True)
class AudioShakeDiscoverySnapshot:
    models: Mapping[str, DiscoveredModel]

    @property
    def enabled_instrument_models(self) -> frozenset[str]:
        return frozenset(
            model.model_id
            for model in self.models.values()
            if model.category == "instrumentStemSeparation"
            and model.access == "enabled"
            and "wav" in model.output_formats
        )


class AudioShakeLikeClient(Protocol):
    def upload_asset(self, source_path: str | Path) -> str: ...
    def get_task_state(self, task_id: str) -> Any: ...
    def find_tasks_by_metadata(self, metadata: dict[str, Any]) -> Iterable[str]: ...
    def _json_request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any: ...


def load_advanced_role_catalog(path: str | Path = _DEFAULT_CATALOG_PATH) -> AdvancedRoleCatalog:
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_UNREADABLE") from exc
    if not isinstance(raw, dict) or raw.get("schema_version") != _SCHEMA_VERSION:
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_SCHEMA_INVALID")
    if raw.get("parity_state") != "NON_PARITY_EVIDENCE_ONLY":
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_PARITY_STATE_INVALID")
    captured_at = raw.get("captured_at")
    roles_raw = raw.get("roles")
    incompatible_raw = raw.get("incompatible_role_sets")
    unknowns = raw.get("unknowns", [])
    if not isinstance(captured_at, str) or not captured_at:
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_CAPTURE_DATE_INVALID")
    if not isinstance(roles_raw, list) or not roles_raw:
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_ROLES_INVALID")
    if not isinstance(incompatible_raw, list):
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_INCOMPATIBLE_INVALID")
    if not isinstance(unknowns, list) or any(not isinstance(v, str) for v in unknowns):
        raise AdvancedCapabilityError("SEP_ADV_CATALOG_UNKNOWNS_INVALID")

    roles: dict[str, AdvancedRole] = {}
    for value in roles_raw:
        if not isinstance(value, dict):
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_ROLE_INVALID")
        role = value.get("canonical_role")
        state = value.get("reference_state")
        model = value.get("audioshake_model")
        family = value.get("family")
        notes = value.get("notes")
        if not isinstance(role, str) or not _ROLE_ID.fullmatch(role):
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_ROLE_ID_INVALID")
        if role in roles:
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_ROLE_DUPLICATE")
        if state not in _ALLOWED_REFERENCE_STATES:
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_REFERENCE_STATE_INVALID")
        if model is not None and (not isinstance(model, str) or not _MODEL_ID.fullmatch(model)):
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_MODEL_ID_INVALID")
        if not isinstance(family, str) or not family or not isinstance(notes, str) or not notes:
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_ROLE_METADATA_INVALID")
        roles[role] = AdvancedRole(role, state, model, family, notes)

    incompatible: list[frozenset[str]] = []
    seen_sets: set[frozenset[str]] = set()
    for item in incompatible_raw:
        if not isinstance(item, list) or len(item) < 2:
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_INCOMPATIBLE_INVALID")
        role_set = frozenset(item)
        if len(role_set) != len(item) or any(role not in roles for role in role_set):
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_INCOMPATIBLE_INVALID")
        if role_set in seen_sets:
            raise AdvancedCapabilityError("SEP_ADV_CATALOG_INCOMPATIBLE_DUPLICATE")
        incompatible.append(role_set)
        seen_sets.add(role_set)

    return AdvancedRoleCatalog(
        schema_version=_SCHEMA_VERSION,
        captured_at=captured_at,
        parity_state="NON_PARITY_EVIDENCE_ONLY",
        roles=roles,
        incompatible_role_sets=tuple(incompatible),
        unknowns=tuple(unknowns),
    )


def parse_audioshake_models(payload: object) -> AudioShakeDiscoverySnapshot:
    if not isinstance(payload, dict):
        raise AdvancedCapabilityError("SEP_ADV_MODELS_ENVELOPE_INVALID")
    values = payload.get("models")
    if not isinstance(values, list):
        raise AdvancedCapabilityError("SEP_ADV_MODELS_LIST_INVALID")

    models: dict[str, DiscoveredModel] = {}
    for value in values:
        if not isinstance(value, dict):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_RECORD_INVALID")
        model_id = value.get("id")
        category = value.get("category")
        access = value.get("access")
        output_formats = value.get("outputFormats", [])
        credits = value.get("creditsPerMinute")
        limits = value.get("limits", {})
        if not isinstance(model_id, str) or not _MODEL_ID.fullmatch(model_id):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_ID_INVALID")
        if model_id in models:
            raise AdvancedCapabilityError("SEP_ADV_MODEL_DUPLICATE")
        if not isinstance(category, str) or not category:
            raise AdvancedCapabilityError("SEP_ADV_MODEL_CATEGORY_INVALID")
        if access not in {"enabled", "request_access"}:
            raise AdvancedCapabilityError("SEP_ADV_MODEL_ACCESS_INVALID")
        if not isinstance(output_formats, list) or any(
            not isinstance(fmt, str) or not fmt for fmt in output_formats
        ):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_OUTPUT_FORMATS_INVALID")
        if len(output_formats) != len(set(output_formats)):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_OUTPUT_FORMATS_INVALID")
        if credits is not None and (
            isinstance(credits, bool) or not isinstance(credits, (int, float)) or credits < 0
        ):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_CREDITS_INVALID")
        if limits is None:
            limits = {}
        if not isinstance(limits, dict):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_LIMITS_INVALID")
        max_duration = limits.get("maxInputDurationSeconds")
        if max_duration is not None and (
            isinstance(max_duration, bool)
            or not isinstance(max_duration, (int, float))
            or max_duration <= 0
        ):
            raise AdvancedCapabilityError("SEP_ADV_MODEL_LIMITS_INVALID")

        models[model_id] = DiscoveredModel(
            model_id=model_id,
            category=category,
            access=access,
            output_formats=tuple(output_formats),
            credits_per_minute=float(credits) if credits is not None else None,
            max_input_duration_seconds=float(max_duration) if max_duration is not None else None,
        )
    return AudioShakeDiscoverySnapshot(models=models)


def discover_audioshake_models(client: AudioShakeLikeClient) -> AudioShakeDiscoverySnapshot:
    try:
        payload = client._json_request("GET", "/models")
    except Exception as exc:
        code = getattr(exc, "code", None)
        raise AdvancedCapabilityError(
            code if isinstance(code, str) and code else "SEP_ADV_MODEL_DISCOVERY_FAILED"
        ) from exc
    return parse_audioshake_models(payload)


def build_audioshake_capabilities(
    snapshot: AudioShakeDiscoverySnapshot,
    *,
    catalog: AdvancedRoleCatalog | None = None,
    max_targets: int | None = None,
) -> ProviderCapabilities:
    catalog = catalog or load_advanced_role_catalog()
    if max_targets is not None and (
        isinstance(max_targets, bool) or not isinstance(max_targets, int) or max_targets <= 0
    ):
        raise AdvancedCapabilityError("SEP_ADV_MAX_TARGETS_INVALID")

    enabled = snapshot.enabled_instrument_models
    role_model_map: dict[str, str] = {}
    seen_models: set[str] = set()
    for role in catalog.roles.values():
        model = role.audioshake_model
        if model is None or model not in enabled:
            continue
        if model in seen_models:
            raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODEL_COLLISION")
        role_model_map[role.canonical_role] = model
        seen_models.add(model)

    if not role_model_map:
        raise AdvancedCapabilityError("SEP_ADV_NO_ENABLED_INSTRUMENT_MODELS")

    # The current public AudioShake API documents stem models and account access discovery, but
    # no Moises-equivalent Hi-Fi quality flag. Do not infer hifi from model availability.
    return ProviderCapabilities(
        provider_key="audioshake-live-model-discovery",
        role_model_map=role_model_map,
        quality_mode_map={"standard": None},
        supports_custom_selection=True,
        max_targets=max_targets,
        incompatible_role_sets=catalog.incompatible_role_sets,
    )


def validate_canonical_role_combination(
    roles: Iterable[str],
    *,
    catalog: AdvancedRoleCatalog | None = None,
    max_targets: int | None = None,
) -> tuple[str, ...]:
    catalog = catalog or load_advanced_role_catalog()
    if isinstance(roles, (str, bytes)):
        raise AdvancedCapabilityError("SEP_ADV_ROLE_SELECTION_INVALID")
    selected = tuple(roles)
    if not selected:
        raise AdvancedCapabilityError("SEP_ADV_ROLE_SELECTION_EMPTY")
    if any(not isinstance(role, str) or role not in catalog.roles for role in selected):
        raise AdvancedCapabilityError("SEP_ADV_ROLE_UNKNOWN")
    if len(selected) != len(set(selected)):
        raise AdvancedCapabilityError("SEP_ADV_ROLE_DUPLICATE")
    if max_targets is not None:
        if isinstance(max_targets, bool) or not isinstance(max_targets, int) or max_targets <= 0:
            raise AdvancedCapabilityError("SEP_ADV_MAX_TARGETS_INVALID")
        if len(selected) > max_targets:
            raise AdvancedCapabilityError("SEP_ADV_TARGET_LIMIT_EXCEEDED")
    requested = frozenset(selected)
    for incompatible in catalog.incompatible_role_sets:
        if incompatible.issubset(requested):
            raise AdvancedCapabilityError("SEP_ADV_ROLE_COMBINATION_OVERLAPS")
    return selected


def normalize_provider_output_models(
    canonical_roles: Iterable[str],
    provider_models: Iterable[str],
    observed_models: Iterable[str],
) -> tuple[str, ...]:
    roles = tuple(canonical_roles)
    planned = tuple(provider_models)
    observed = tuple(observed_models)
    if not roles or len(roles) != len(planned):
        raise AdvancedCapabilityError("SEP_ADV_OUTPUT_PLAN_INVALID")
    if len(set(roles)) != len(roles) or len(set(planned)) != len(planned):
        raise AdvancedCapabilityError("SEP_ADV_OUTPUT_PLAN_INVALID")
    if len(observed) != len(set(observed)):
        raise AdvancedCapabilityError("SEP_ADV_OUTPUT_MODEL_DUPLICATE")
    if set(observed) != set(planned):
        raise AdvancedCapabilityError("SEP_ADV_OUTPUT_MODEL_SET_MISMATCH")
    mapping = dict(zip(planned, roles))
    return tuple(mapping[model] for model in planned)


def public_capability_snapshot(
    snapshot: AudioShakeDiscoverySnapshot,
    *,
    catalog: AdvancedRoleCatalog | None = None,
) -> dict[str, object]:
    catalog = catalog or load_advanced_role_catalog()
    enabled = snapshot.enabled_instrument_models
    rows = []
    for role in sorted(catalog.roles.values(), key=lambda item: item.canonical_role):
        rows.append(
            {
                "canonical_role": role.canonical_role,
                "reference_state": role.reference_state,
                "provider_model": role.audioshake_model,
                "provider_enabled": bool(role.audioshake_model in enabled),
                "family": role.family,
            }
        )
    return {
        "schema_version": 1,
        "parity_state": "NON_PARITY_EVIDENCE_ONLY",
        "provider": "audioshake",
        "quality_modes": ["standard"],
        "hifi_provider_mapping": "UNVERIFIED_FAIL_CLOSED",
        "roles": rows,
        "unknowns": list(catalog.unknowns),
    }


class AdvancedAudioShakeAdapter:
    """A06-compatible provider adapter gated by live account model discovery.

    It delegates upload/state/reconciliation to the existing AudioShake client but performs a
    safe GET /models before permitting any advanced Task POST. A failed or gated model never
    reaches POST /tasks.
    """

    def __init__(
        self,
        client: AudioShakeLikeClient,
        *,
        catalog: AdvancedRoleCatalog | None = None,
    ):
        self.client = client
        self.catalog = catalog or load_advanced_role_catalog()
        self._snapshot: AudioShakeDiscoverySnapshot | None = None

    def discover(self, *, refresh: bool = False) -> AudioShakeDiscoverySnapshot:
        if self._snapshot is None or refresh:
            self._snapshot = discover_audioshake_models(self.client)
        return self._snapshot

    def upload_asset(self, source_path: str | Path) -> str:
        # Fail before user-content upload if account model discovery itself is unavailable.
        self.discover()
        return self.client.upload_asset(source_path)

    def create_separation_task(
        self,
        asset_id: str,
        models: Iterable[str],
        *,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        if not isinstance(asset_id, str) or not asset_id:
            raise AdvancedCapabilityError("SEP_ADV_ASSET_ID_INVALID")
        if isinstance(models, (str, bytes)):
            raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODELS_INVALID")
        selected = tuple(models)
        if not selected or any(
            not isinstance(model, str) or not _MODEL_ID.fullmatch(model) for model in selected
        ):
            raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODELS_INVALID")
        if len(selected) != len(set(selected)):
            raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODELS_DUPLICATE")

        snapshot = self.discover()
        enabled = snapshot.enabled_instrument_models
        if any(model not in enabled for model in selected):
            raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODEL_NOT_ENABLED")

        body: dict[str, Any] = {
            "assetId": asset_id,
            "targets": [{"model": model, "formats": ["wav"]} for model in selected],
        }
        if metadata is not None:
            body["metadata"] = _encode_metadata(metadata)
        payload = self.client._json_request("POST", "/tasks", body)
        if not isinstance(payload, dict):
            raise AdvancedCapabilityError("SEP_ADV_TASK_RESPONSE_INVALID")
        task_id = payload.get("id")
        if not isinstance(task_id, str) or not task_id:
            raise AdvancedCapabilityError("SEP_ADV_TASK_RESPONSE_INVALID")
        return task_id

    def get_task_state(self, task_id: str) -> Any:
        return self.client.get_task_state(task_id)

    def find_tasks_by_metadata(self, metadata: dict[str, Any]) -> Iterable[str]:
        return self.client.find_tasks_by_metadata(metadata)


def _encode_metadata(metadata: dict[str, Any]) -> str:
    try:
        encoded = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
    except (TypeError, ValueError) as exc:
        raise AdvancedCapabilityError("SEP_ADV_METADATA_INVALID") from exc
    if len(encoded.encode("utf-8")) > 4096:
        raise AdvancedCapabilityError("SEP_ADV_METADATA_TOO_LARGE")
    return encoded
