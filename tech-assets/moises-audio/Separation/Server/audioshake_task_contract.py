"""AudioShake Task-level request contract for Lane 1 advanced separation.

The provider-neutral planners intentionally do not encode vendor task limits. This module binds
AudioShake's documented Task contract at the provider boundary so an advanced request cannot upload
user media or reserve production cost only to fail later for a request shape we could reject locally.
This is runtime hardening, not Moises/current-iPhone PARITY evidence.
"""
from __future__ import annotations

from typing import Iterable

from advanced_capabilities import (
    AdvancedCapabilityError,
    AdvancedRoleCatalog,
    AudioShakeDiscoverySnapshot,
    build_audioshake_capabilities,
)

TOOL_VERSION = "L1-A44-v1"
AUDIOSHAKE_TASK_MAX_TARGETS = 20


def effective_audioshake_max_targets(configured_max_targets: int | None = None) -> int:
    """Return the effective Task cap; deployment policy may narrow but never widen provider truth."""
    if configured_max_targets is None:
        return AUDIOSHAKE_TASK_MAX_TARGETS
    if (
        isinstance(configured_max_targets, bool)
        or not isinstance(configured_max_targets, int)
        or configured_max_targets <= 0
    ):
        raise AdvancedCapabilityError("SEP_ADV_MAX_TARGETS_INVALID")
    return min(AUDIOSHAKE_TASK_MAX_TARGETS, configured_max_targets)


def build_contract_bound_audioshake_capabilities(
    snapshot: AudioShakeDiscoverySnapshot,
    *,
    catalog: AdvancedRoleCatalog,
    configured_max_targets: int | None = None,
):
    """Build AudioShake capabilities with its Task-wide target limit always represented."""
    return build_audioshake_capabilities(
        snapshot,
        catalog=catalog,
        max_targets=effective_audioshake_max_targets(configured_max_targets),
    )


def validate_audioshake_provider_targets(models: Iterable[str]) -> tuple[str, ...]:
    """Defensive raw provider-target check for callers that bypass canonical role planning."""
    if isinstance(models, (str, bytes)):
        raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODELS_INVALID")
    selected = tuple(models)
    if not selected:
        raise AdvancedCapabilityError("SEP_ADV_PROVIDER_MODELS_INVALID")
    if len(selected) > AUDIOSHAKE_TASK_MAX_TARGETS:
        raise AdvancedCapabilityError("SEP_ADV_TARGET_LIMIT_EXCEEDED")
    return selected
