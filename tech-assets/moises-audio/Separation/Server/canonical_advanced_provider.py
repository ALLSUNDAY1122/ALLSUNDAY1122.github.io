"""Canonical-role boundary for the A12/A44 AudioShake advanced provider path.

A06/A07 orchestration must remain provider-neutral. This wrapper accepts canonical role IDs,
translates them to account-enabled AudioShake model IDs only at POST /tasks, and maps provider
output model IDs back to canonical roles before returning task state. A44 also exposes a media-free
request preflight so the production entrypoint can reject impossible advanced requests before upload.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

from advanced_capabilities import (
    AdvancedCapabilityError,
    AdvancedRoleCatalog,
    AudioShakeLikeClient,
    discover_audioshake_models,
    load_advanced_role_catalog,
    validate_canonical_role_combination,
)
from audioshake_task_contract import (
    AUDIOSHAKE_TASK_MAX_TARGETS,
    build_contract_bound_audioshake_capabilities,
)


@dataclass(frozen=True)
class CanonicalTargetState:
    model: str
    status: str
    output_url: str | None
    error_code: str | None


@dataclass(frozen=True)
class CanonicalTaskState:
    task_id: str
    phase: str
    fraction_complete: float
    retryable: bool
    stable_error_code: str | None
    targets: tuple[CanonicalTargetState, ...]


class CanonicalAdvancedAudioShakeAdapter:
    def __init__(self, client: AudioShakeLikeClient, *, catalog: AdvancedRoleCatalog | None = None):
        self.client = client
        self.catalog = catalog or load_advanced_role_catalog()
        self._snapshot = None
        self._role_to_model: dict[str, str] = {}
        self._model_to_role: dict[str, str] = {}

    def _refresh_maps(self) -> None:
        self._snapshot = discover_audioshake_models(self.client)
        caps = build_contract_bound_audioshake_capabilities(
            self._snapshot,
            catalog=self.catalog,
        )
        self._role_to_model = dict(caps.role_model_map)
        inverse: dict[str, str] = {}
        for role, model in self._role_to_model.items():
            if model in inverse:
                raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODEL_COLLISION")
            inverse[model] = role
        self._model_to_role = inverse

    def preflight_separation(self, models: Iterable[str]) -> tuple[str, ...]:
        """Validate task shape and account access without reading or uploading user media."""
        canonical_roles = validate_canonical_role_combination(
            models,
            catalog=self.catalog,
            max_targets=AUDIOSHAKE_TASK_MAX_TARGETS,
        )
        if self._snapshot is None:
            self._refresh_maps()
        for role in canonical_roles:
            if self._role_to_model.get(role) is None:
                raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODEL_NOT_ENABLED")
        return canonical_roles

    def upload_asset(self, source_path):
        # Discovery precedes user-content upload so unavailable accounts fail before media transfer.
        if self._snapshot is None:
            self._refresh_maps()
        return self.client.upload_asset(source_path)

    def create_separation_task(self, asset_id: str, models: Iterable[str], *, metadata=None) -> str:
        if not isinstance(asset_id, str) or not asset_id:
            raise AdvancedCapabilityError("SEP_ADV_ASSET_ID_INVALID")
        # Defense in depth: callers that do not use the A44 production preflight still cannot POST
        # an over-limit or account-disabled task.
        canonical_roles = self.preflight_separation(models)
        provider_models = [self._role_to_model[role] for role in canonical_roles]
        body: dict[str, Any] = {
            "assetId": asset_id,
            "targets": [{"model": model, "formats": ["wav"]} for model in provider_models],
        }
        if metadata is not None:
            import json
            try:
                encoded = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
            except (TypeError, ValueError) as exc:
                raise AdvancedCapabilityError("SEP_ADV_METADATA_INVALID") from exc
            if len(encoded.encode("utf-8")) > 4096:
                raise AdvancedCapabilityError("SEP_ADV_METADATA_TOO_LARGE")
            body["metadata"] = encoded
        payload = self.client._json_request("POST", "/tasks", body)
        if not isinstance(payload, dict) or not isinstance(payload.get("id"), str) or not payload["id"]:
            raise AdvancedCapabilityError("SEP_ADV_TASK_RESPONSE_INVALID")
        return payload["id"]

    def get_task_state(self, task_id: str) -> CanonicalTaskState:
        if self._snapshot is None:
            self._refresh_maps()
        raw = self.client.get_task_state(task_id)
        raw_targets = getattr(raw, "targets", None)
        try:
            raw_targets = tuple(raw_targets)
        except (TypeError, ValueError) as exc:
            raise AdvancedCapabilityError("SEP_ADV_TASK_STATE_INVALID") from exc
        targets: list[CanonicalTargetState] = []
        for target in raw_targets:
            provider_model = getattr(target, "model", None)
            canonical_role = self._model_to_role.get(provider_model)
            if canonical_role is None:
                raise AdvancedCapabilityError("SEP_ADV_OUTPUT_MODEL_UNKNOWN")
            targets.append(CanonicalTargetState(
                model=canonical_role,
                status=getattr(target, "status", None),
                output_url=getattr(target, "output_url", None),
                error_code=getattr(target, "error_code", None),
            ))
        raw_task_id = getattr(raw, "task_id", None)
        phase = getattr(raw, "phase", None)
        fraction = getattr(raw, "fraction_complete", None)
        retryable = getattr(raw, "retryable", None)
        if (
            not isinstance(raw_task_id, str) or not raw_task_id
            or phase not in {"separating", "ready", "failed"}
            or isinstance(fraction, bool) or not isinstance(fraction, (int, float))
            or not 0.0 <= float(fraction) <= 1.0
            or not isinstance(retryable, bool)
        ):
            raise AdvancedCapabilityError("SEP_ADV_TASK_STATE_INVALID")
        return CanonicalTaskState(
            task_id=raw_task_id,
            phase=phase,
            fraction_complete=float(fraction),
            retryable=retryable,
            stable_error_code=getattr(raw, "stable_error_code", None),
            targets=tuple(targets),
        )

    def find_tasks_by_metadata(self, metadata):
        return self.client.find_tasks_by_metadata(metadata)
