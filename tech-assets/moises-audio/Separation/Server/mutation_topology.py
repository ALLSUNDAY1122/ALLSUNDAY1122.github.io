"""Lane 1 mutation-store deployment topology contract (NON-PARITY).

This module does not implement a distributed lock. It makes the opposite safety
property explicit: local file-backed synchronization must never be interpreted
as cross-host transactional coordination.

A35 extends the deployment inventory to the provider-delete reconciliation
ledger/application path introduced in A29-A34. A38 extends that contract to the
A37 equal-epoch conflict-decision sidecar and adds a composite reconciliation
preflight spanning the privacy registry, reconciliation ledger and decision
store.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass
from enum import Enum
from typing import Mapping

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A38-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")


class MutationTopologyError(RuntimeError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


class DeploymentTopology(str, Enum):
    SINGLE_HOST = "single_host"
    MULTI_HOST = "multi_host"


_REQUIRED_SHARED_CAPABILITIES = frozenset(
    {
        "atomic_compare_and_swap",
        "durable_commit",
        "monotonic_fencing_tokens",
        "read_after_write_consistency",
    }
)


@dataclass(frozen=True)
class StoreSafetyProfile:
    store_id: str
    local_serialization: str
    single_host_safe: bool
    shared_authority_adapter: bool
    risk: str

    def validate(self) -> None:
        if not _SAFE_ID.fullmatch(self.store_id):
            raise MutationTopologyError("L1A27_STORE_ID_INVALID")
        if self.local_serialization not in {"none", "posix_flock"}:
            raise MutationTopologyError("L1A27_LOCAL_SERIALIZATION_INVALID")
        if self.risk not in {
            "lost_update",
            "cross_host_race",
            "delete_refund_state_race",
            "active_pointer_race",
            "reconciliation_watermark_race",
            "adjudication_decision_race",
        }:
            raise MutationTopologyError("L1A27_STORE_RISK_INVALID")
        if self.local_serialization == "none" and self.single_host_safe:
            raise MutationTopologyError("L1A27_UNSERIALIZED_STORE_CANNOT_BE_SINGLE_HOST_SAFE")


@dataclass(frozen=True)
class SharedMutationAuthority:
    authority_ref_hash: str
    capabilities: tuple[str, ...]

    def validate(self) -> None:
        if not _SHA256.fullmatch(self.authority_ref_hash):
            raise MutationTopologyError("L1A27_AUTHORITY_REF_HASH_INVALID")
        normalized = tuple(sorted(set(self.capabilities)))
        if normalized != self.capabilities:
            raise MutationTopologyError("L1A27_AUTHORITY_CAPABILITIES_NOT_CANONICAL")
        if not set(normalized) >= _REQUIRED_SHARED_CAPABILITIES:
            raise MutationTopologyError("L1A27_SHARED_AUTHORITY_CAPABILITY_MISSING")


@dataclass(frozen=True)
class TopologyDecision:
    schema_version: int
    tool_version: str
    evidence_state: str
    store_id: str
    topology: str
    state: str
    stable_error_code: str | None
    authority_ref_hash: str | None
    required_shared_capabilities: tuple[str, ...]
    parity_claim: str = "NONE"

    @property
    def decision_sha256(self) -> str:
        payload = asdict(self)
        return hashlib.sha256(
            json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        ).hexdigest()


BUILTIN_STORE_PROFILES = {
    "a09_privacy_registry": StoreSafetyProfile(
        store_id="a09_privacy_registry",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="lost_update",
    ),
    "a16_reconnect_registry": StoreSafetyProfile(
        store_id="a16_reconnect_registry",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="cross_host_race",
    ),
    "a23_variant_store": StoreSafetyProfile(
        store_id="a23_variant_store",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="active_pointer_race",
    ),
    "a24_retention_store": StoreSafetyProfile(
        store_id="a24_retention_store",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="delete_refund_state_race",
    ),
    "a29_provider_delete_reconciliation_ledger": StoreSafetyProfile(
        store_id="a29_provider_delete_reconciliation_ledger",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="reconciliation_watermark_race",
    ),
    "a37_conflict_decision_store": StoreSafetyProfile(
        store_id="a37_conflict_decision_store",
        local_serialization="posix_flock",
        single_host_safe=True,
        shared_authority_adapter=False,
        risk="adjudication_decision_race",
    ),
}

EXPECTED_BUILTIN_STORE_IDS = frozenset(
    {
        "a09_privacy_registry",
        "a16_reconnect_registry",
        "a23_variant_store",
        "a24_retention_store",
        "a29_provider_delete_reconciliation_ledger",
        "a37_conflict_decision_store",
    }
)

RECONCILIATION_STORE_IDS = (
    "a09_privacy_registry",
    "a29_provider_delete_reconciliation_ledger",
    "a37_conflict_decision_store",
)
EXPECTED_RECONCILIATION_STORE_IDS = frozenset(
    {
        "a09_privacy_registry",
        "a29_provider_delete_reconciliation_ledger",
        "a37_conflict_decision_store",
    }
)


def _validate_builtin_inventory() -> None:
    if frozenset(BUILTIN_STORE_PROFILES) != EXPECTED_BUILTIN_STORE_IDS:
        raise MutationTopologyError("L1A35_BUILTIN_STORE_INVENTORY_MISMATCH")
    if len(set(RECONCILIATION_STORE_IDS)) != len(RECONCILIATION_STORE_IDS):
        raise MutationTopologyError("L1A38_RECONCILIATION_STORE_INVENTORY_INVALID")
    if frozenset(RECONCILIATION_STORE_IDS) != EXPECTED_RECONCILIATION_STORE_IDS:
        raise MutationTopologyError("L1A38_RECONCILIATION_STORE_INVENTORY_INVALID")
    if not EXPECTED_RECONCILIATION_STORE_IDS <= EXPECTED_BUILTIN_STORE_IDS:
        raise MutationTopologyError("L1A38_RECONCILIATION_STORE_INVENTORY_INVALID")
    for profile in BUILTIN_STORE_PROFILES.values():
        profile.validate()


_validate_builtin_inventory()


def required_shared_capabilities() -> tuple[str, ...]:
    return tuple(sorted(_REQUIRED_SHARED_CAPABILITIES))


def assess_store_topology(
    store_id: str,
    topology: DeploymentTopology | str,
    *,
    authority: SharedMutationAuthority | None = None,
    profile: StoreSafetyProfile | None = None,
) -> TopologyDecision:
    selected = profile or BUILTIN_STORE_PROFILES.get(store_id)
    if selected is None or selected.store_id != store_id:
        raise MutationTopologyError("L1A27_STORE_UNKNOWN")
    selected.validate()
    try:
        topology_value = DeploymentTopology(topology)
    except ValueError as exc:
        raise MutationTopologyError("L1A27_TOPOLOGY_INVALID") from exc

    error: str | None = None
    authority_hash: str | None = None
    if topology_value is DeploymentTopology.SINGLE_HOST:
        if not selected.single_host_safe:
            error = "L1A27_SINGLE_HOST_SERIALIZATION_INSUFFICIENT"
        if authority is not None:
            raise MutationTopologyError("L1A27_AUTHORITY_UNEXPECTED_FOR_SINGLE_HOST")
    else:
        if authority is None:
            error = "L1A27_SHARED_AUTHORITY_REQUIRED"
        else:
            authority.validate()
            authority_hash = authority.authority_ref_hash
            if not selected.shared_authority_adapter:
                error = "L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED"

    return TopologyDecision(
        schema_version=SCHEMA_VERSION,
        tool_version=TOOL_VERSION,
        evidence_state=EVIDENCE_STATE,
        store_id=selected.store_id,
        topology=topology_value.value,
        state="PASS" if error is None else "FAIL_CLOSED",
        stable_error_code=error,
        authority_ref_hash=authority_hash,
        required_shared_capabilities=required_shared_capabilities(),
    )


def assert_store_topology_safe(
    store_id: str,
    topology: DeploymentTopology | str,
    *,
    authority: SharedMutationAuthority | None = None,
    profile: StoreSafetyProfile | None = None,
) -> TopologyDecision:
    decision = assess_store_topology(store_id, topology, authority=authority, profile=profile)
    if decision.state != "PASS":
        raise MutationTopologyError(decision.stable_error_code or "L1A27_TOPOLOGY_UNSAFE")
    return decision


def reconciliation_topology_snapshot(
    topology: DeploymentTopology | str,
    *,
    authorities: Mapping[str, SharedMutationAuthority] | None = None,
) -> dict:
    _validate_builtin_inventory()
    authority_map = dict(authorities or {})
    unknown = set(authority_map) - set(RECONCILIATION_STORE_IDS)
    if unknown:
        raise MutationTopologyError("L1A38_RECONCILIATION_AUTHORITY_STORE_UNKNOWN")
    decisions = [
        assess_store_topology(store_id, topology, authority=authority_map.get(store_id))
        for store_id in RECONCILIATION_STORE_IDS
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "evidence_state": EVIDENCE_STATE,
        "topology": DeploymentTopology(topology).value,
        "store_inventory": RECONCILIATION_STORE_IDS,
        "stores": [asdict(d) | {"decision_sha256": d.decision_sha256} for d in decisions],
        "all_safe": all(d.state == "PASS" for d in decisions),
        "parity_claim": "NONE",
    }


def assert_reconciliation_topology_safe(
    topology: DeploymentTopology | str,
    *,
    authorities: Mapping[str, SharedMutationAuthority] | None = None,
) -> dict:
    snapshot = reconciliation_topology_snapshot(topology, authorities=authorities)
    if not snapshot["all_safe"]:
        first_failure = next(row for row in snapshot["stores"] if row["state"] != "PASS")
        raise MutationTopologyError(
            first_failure["stable_error_code"] or "L1A38_RECONCILIATION_TOPOLOGY_UNSAFE"
        )
    return snapshot


def lane1_topology_snapshot(topology: DeploymentTopology | str) -> dict:
    _validate_builtin_inventory()
    decisions = [
        assess_store_topology(store_id, topology)
        for store_id in sorted(BUILTIN_STORE_PROFILES)
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "evidence_state": EVIDENCE_STATE,
        "topology": DeploymentTopology(topology).value,
        "store_inventory": tuple(sorted(BUILTIN_STORE_PROFILES)),
        "stores": [asdict(d) | {"decision_sha256": d.decision_sha256} for d in decisions],
        "all_safe": all(d.state == "PASS" for d in decisions),
        "parity_claim": "NONE",
    }
