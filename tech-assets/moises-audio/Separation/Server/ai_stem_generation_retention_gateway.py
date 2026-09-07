"""L1-A26 compatibility gateway from A25 facade surface to final A24 coordinator.

NON-PARITY integration infrastructure. The gateway preserves A24's stricter delete/refund/
erasure semantics while exposing the small retention surface that A25 composes.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from generated_stem_retention import (
    EVIDENCE_STATE,
    TOOL_VERSION as A24_TOOL_VERSION,
    GeneratedStemRetentionError,
    canonical_sha,
)

TOOL_VERSION = "L1-A26-A24-GATEWAY-v1"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ID32 = re.compile(r"^[0-9a-f]{32}$")


class RetentionGatewayError(RuntimeError):
    def __init__(self, code: str, message: str = "A24 retention gateway failure"):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


def fail(code: str, message: str = "A24 retention gateway failure"):
    raise RetentionGatewayError(code, message)


def _sha(value: Any, field: str) -> str:
    if not isinstance(value, str):
        fail("GENRET_GATEWAY_SHA_INVALID", field)
    value = value.strip().lower().removeprefix("sha256:")
    if not HEX64.fullmatch(value):
        fail("GENRET_GATEWAY_SHA_INVALID", field)
    return value


def _variant(value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        fail("GENRET_GATEWAY_VARIANT_INVALID")
    return value


def _generation_ref_hash(logical_generation_id: str) -> str:
    if not isinstance(logical_generation_id, str) or not ID32.fullmatch(logical_generation_id):
        fail("GENRET_GATEWAY_LOGICAL_ID_INVALID")
    return hashlib.sha256(("l1-a21-generation-ref-v1:" + logical_generation_id).encode()).hexdigest()


def _execution_ref_hash(execution_id: str) -> str:
    if not isinstance(execution_id, str) or not execution_id:
        fail("GENRET_GATEWAY_EXECUTION_ID_INVALID")
    return hashlib.sha256(("l1-a21-execution-v1:" + execution_id).encode()).hexdigest()


@dataclass(frozen=True)
class RetentionRegistration:
    generation_ref_hash: str
    variant_index: int
    artifact_sha256: str
    mix_ready_receipt_sha256: str
    retention_policy_sha256: str


class A24RetentionGateway:
    """Exposes A25's required surface over `GeneratedStemRetentionCoordinator`.

    The gateway does not invent refund or remote-erasure success. Association deletion means
    only that the A23 local variant association was removed safely.
    """

    _REASON_MAP = {
        "USER_DELETE": "USER_DELETE",
        "PROJECT_DELETE": "PROJECT_DELETE",
        "ACCOUNT_DELETE": "ACCOUNT_DELETE",
        "CANCEL_CLEANUP": "CANCEL_CLEANUP",
        "SUPERSEDED_RETENTION": "REGENERATION_CLEANUP",
        "ORPHAN_ABANDONED": "CANCEL_CLEANUP",
        "REGENERATION_CLEANUP": "REGENERATION_CLEANUP",
        "RETENTION_EXPIRED": "RETENTION_EXPIRED",
    }

    def __init__(self, coordinator: Any):
        required = (
            "begin_delete", "execute_local_delete", "assert_generation_not_deleted",
            "privacy_safe_evidence", "record_runtime_delete",
        )
        if any(not callable(getattr(coordinator, name, None)) for name in required):
            fail("GENRET_GATEWAY_COORDINATOR_SURFACE_INVALID")
        for name in ("root", "manifests", "active", "ledger"):
            if not hasattr(coordinator, name):
                fail("GENRET_GATEWAY_COORDINATOR_SURFACE_INVALID")
        self.coordinator = coordinator
        self.retention_policy_sha256 = canonical_sha({
            "domain": "l1-a26-a24-retention-gateway-policy-v1",
            "a24_tool_version": A24_TOOL_VERSION,
            "reference_authority": ["all_manifests", "all_active_pointers"],
            "local_delete_implies_refund": False,
            "runtime_erasure_requires_authority": True,
            "evidence_state": EVIDENCE_STATE,
        })

    def _manifest_path(self, generation_ref_hash_value: str, variant_index: int) -> Path:
        gen = _sha(generation_ref_hash_value, "generation_ref_hash")
        vi = _variant(variant_index)
        return Path(self.coordinator.manifests) / f"{gen}.v{vi}.json"

    @staticmethod
    def _load_json(path: Path, code: str) -> dict[str, Any]:
        if path.is_symlink():
            fail("GENRET_GATEWAY_SYMLINK_FORBIDDEN")
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            raise RetentionGatewayError(code) from e
        if not isinstance(raw, dict):
            fail(code)
        return raw

    def _variant_record(self, generation_ref_hash_value: str, variant_index: int) -> dict[str, Any]:
        gen = _sha(generation_ref_hash_value, "generation_ref_hash")
        vi = _variant(variant_index)
        path = self._manifest_path(gen, vi)
        if not path.is_file() or path.is_symlink():
            fail("GENRET_GATEWAY_MANIFEST_MISSING")
        try:
            raw = self.coordinator._validate_variant_mapping(
                self._load_json(path, "GENRET_GATEWAY_MANIFEST_CORRUPT")
            )
        except GeneratedStemRetentionError as e:
            raise RetentionGatewayError("GENRET_GATEWAY_MANIFEST_INVALID") from e
        if raw["generation_ref_hash"] != gen or raw["variant_index"] != vi:
            fail("GENRET_GATEWAY_MANIFEST_IDENTITY_MISMATCH")
        return raw

    def register_variant(self, *, generation_ref_hash_value: str, variant_index: int) -> RetentionRegistration:
        gen = _sha(generation_ref_hash_value, "generation_ref_hash")
        vi = _variant(variant_index)
        try:
            self.coordinator.assert_generation_not_deleted(gen)
        except GeneratedStemRetentionError as e:
            raise RetentionGatewayError("GENRET_GATEWAY_GENERATION_TOMBSTONED") from e
        raw = self._variant_record(gen, vi)
        active_path = Path(self.coordinator.active) / f"{raw['project_ref_hash']}.{raw['role']}.json"
        if not active_path.is_file() or active_path.is_symlink():
            fail("GENRET_GATEWAY_ACTIVE_POINTER_MISSING")
        try:
            active = self.coordinator._validate_variant_mapping(
                self._load_json(active_path, "GENRET_GATEWAY_ACTIVE_POINTER_CORRUPT")
            )
        except GeneratedStemRetentionError as e:
            raise RetentionGatewayError("GENRET_GATEWAY_ACTIVE_POINTER_INVALID") from e
        identity = ("project_ref_hash", "role", "generation_ref_hash", "variant_index", "artifact_sha256")
        if any(active[k] != raw[k] for k in identity):
            fail("GENRET_GATEWAY_ACTIVE_POINTER_MISMATCH")
        return RetentionRegistration(
            gen, vi, raw["artifact_sha256"], raw["mix_ready_receipt_sha256"],
            self.retention_policy_sha256,
        )

    def _existing_delete(self, gen: str, vi: int):
        with self.coordinator.ledger.locked() as records:
            matches = [r for r in records.values() if r.generation_ref_hash == gen and r.variant_index == vi]
        if len(matches) > 1:
            fail("GENRET_GATEWAY_DUPLICATE_DELETE_RECORD")
        return matches[0] if matches else None

    def _binding_execution(self, binding_store_path: str | Path, generation_ref_hash_value: str):
        path = Path(binding_store_path)
        raw = self._load_json(path, "GENRET_GATEWAY_BINDING_STORE_CORRUPT")
        if raw.get("schema_version") != 1 or not isinstance(raw.get("records"), dict):
            fail("GENRET_GATEWAY_BINDING_STORE_SCHEMA_INVALID")
        matches = []
        for logical_id, record in raw["records"].items():
            if _generation_ref_hash(logical_id) == generation_ref_hash_value:
                matches.append(record)
        if len(matches) > 1:
            fail("GENRET_GATEWAY_BINDING_DUPLICATE_GENERATION")
        if not matches:
            return None
        record = matches[0]
        execution_id = record.get("execution_id")
        execution_ref = _sha(record.get("execution_ref_hash"), "execution_ref_hash")
        if _execution_ref_hash(execution_id) != execution_ref:
            fail("GENRET_GATEWAY_BINDING_IDENTITY_MISMATCH")
        return execution_id, execution_ref

    def _record_runtime_delete(self, record, *, runtime_delete, binding_store_path):
        if runtime_delete is None:
            return
        if not callable(runtime_delete):
            fail("GENRET_GATEWAY_RUNTIME_DELETE_INVALID")
        if binding_store_path is None:
            outcome = "UNKNOWN"
            authority = canonical_sha({
                "domain": "l1-a26-runtime-delete-bridge-v1",
                "generation_ref_hash": record.generation_ref_hash,
                "outcome": "IDENTIFIER_UNAVAILABLE",
            })
            self.coordinator.record_runtime_delete(record.deletion_id, outcome=outcome, authority_evidence_sha256=authority)
            return
        binding = self._binding_execution(binding_store_path, record.generation_ref_hash)
        if binding is None:
            outcome = "UNKNOWN"
            authority = canonical_sha({
                "domain": "l1-a26-runtime-delete-bridge-v1",
                "generation_ref_hash": record.generation_ref_hash,
                "outcome": "BINDING_NOT_FOUND",
            })
            self.coordinator.record_runtime_delete(record.deletion_id, outcome=outcome, authority_evidence_sha256=authority)
            return
        execution_id, execution_ref = binding
        try:
            receipt = runtime_delete(execution_id)
        except Exception:
            outcome = "UNKNOWN"
            receipt_name = "ERROR"
        else:
            receipt_name = str(receipt).strip().lower()
            outcome = {
                "confirmed": "CONFIRMED",
                "not_found": "NOT_FOUND",
                "accepted": "PENDING",
                "unsupported": "UNSUPPORTED",
            }.get(receipt_name, "UNKNOWN")
        authority = canonical_sha({
            "domain": "l1-a26-runtime-delete-bridge-v1",
            "generation_ref_hash": record.generation_ref_hash,
            "execution_ref_hash": execution_ref,
            "receipt": receipt_name,
            "mapped_outcome": outcome,
        })
        self.coordinator.record_runtime_delete(
            record.deletion_id, outcome=outcome, authority_evidence_sha256=authority
        )

    def request_delete(
        self, *, generation_ref_hash_value: str, variant_index: int, reason: str,
        runtime_delete=None, binding_store_path=None,
    ) -> dict[str, Any]:
        gen = _sha(generation_ref_hash_value, "generation_ref_hash")
        vi = _variant(variant_index)
        reason_raw = str(reason).strip().upper()
        mapped = self._REASON_MAP.get(reason_raw)
        if mapped is None:
            fail("GENRET_GATEWAY_DELETE_REASON_INVALID")
        record = self._existing_delete(gen, vi)
        if record is None:
            raw = self._variant_record(gen, vi)
            bridge_evidence = canonical_sha({
                "domain": "l1-a26-a25-delete-intent-bridge-v1",
                "generation_ref_hash": gen,
                "variant_index": vi,
                "a25_reason": reason_raw,
                "a24_reason": mapped,
            })
            record = self.coordinator.begin_delete(
                project_ref_hash=raw["project_ref_hash"], role=raw["role"],
                generation_ref_hash=gen, variant_index=vi,
                request_reason=mapped, delete_intent_evidence_sha256=bridge_evidence,
            )
        elif record.request_reason != mapped:
            fail("GENRET_GATEWAY_DELETE_REASON_CONFLICT")
        record = self.coordinator.execute_local_delete(record.deletion_id)
        self._record_runtime_delete(record, runtime_delete=runtime_delete, binding_store_path=binding_store_path)
        return self.snapshot(generation_ref_hash_value=gen, variant_index=vi)

    def snapshot(self, *, generation_ref_hash_value: str, variant_index: int) -> dict[str, Any]:
        gen = _sha(generation_ref_hash_value, "generation_ref_hash")
        vi = _variant(variant_index)
        record = self._existing_delete(gen, vi)
        if record is None:
            raw = self._variant_record(gen, vi)
            return {
                "schema_version": 1,
                "tool_version": TOOL_VERSION,
                "evidence_state": EVIDENCE_STATE,
                "retention_policy_sha256": self.retention_policy_sha256,
                "generation_ref_hash": gen,
                "variant_index": vi,
                "artifact_sha256": raw["artifact_sha256"],
                "association_delete_confirmed": False,
                "runtime_erasure_confirmed": False,
                "refund_confirmed": False,
                "parity_claim": "NONE",
            }
        evidence = self.coordinator.privacy_safe_evidence(record.deletion_id)
        return {
            "schema_version": 1,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "retention_policy_sha256": self.retention_policy_sha256,
            "generation_ref_hash": gen,
            "variant_index": vi,
            "artifact_sha256": record.artifact_sha256,
            "association_delete_confirmed": bool(evidence["local_deletion_complete"]),
            "physical_artifact_state": (
                "retained_shared_reference" if evidence["object_retained_due_to_reference"]
                else "confirmed_erased" if evidence["object_removed"]
                else "not_attempted"
            ),
            "runtime_delete_state": evidence["runtime_delete_state"].lower(),
            "runtime_erasure_confirmed": bool(evidence["runtime_erasure_authoritatively_complete"]),
            "refund_state": evidence["refund_state"].lower(),
            "refund_confirmed": bool(evidence["refund_confirmed"]),
            "privacy_erasure_complete": bool(evidence["overall_erasure_complete"]),
            "path_emitted": False,
            "raw_audio_emitted": False,
            "raw_runtime_id_emitted": False,
            "raw_credit_or_billing_record_emitted": False,
            "parity_claim": "NONE",
        }
