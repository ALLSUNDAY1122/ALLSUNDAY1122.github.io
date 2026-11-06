"""L1-A25 AI stem generation end-to-end processing facade / crash-recovery composition.

NON-PARITY engineering infrastructure. This module composes A21-A24 without weakening
their authority boundaries. Raw logical IDs and paths stay in private durable state only.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A25-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ID32 = re.compile(r"^[0-9a-f]{32}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")

PHASES = {
    "INTENT_DURABLE",
    "START_CALL_IN_FLIGHT",
    "START_UNKNOWN",
    "RUNTIME_BOUND",
    "RUNTIME_RUNNING",
    "RUNTIME_READY",
    "NORMALIZATION_REQUIRED",
    "MIX_COMMIT_IN_FLIGHT",
    "VARIANT_ACTIVE",
    "RETENTION_REGISTERED",
    "READY",
    "CANCEL_CALL_IN_FLIGHT",
    "CANCEL_PENDING",
    "CANCELLED",
    "FAILED",
    "DELETE_CALL_IN_FLIGHT",
    "DELETED_ASSOCIATION",
}
TERMINAL = {"READY", "CANCELLED", "FAILED", "DELETED_ASSOCIATION"}


class GenerationFacadeError(RuntimeError):
    def __init__(self, code: str, message: str = "AI stem generation facade failure", *, retryable: bool = False):
        self.code = code
        self.message = message
        self.retryable = retryable
        super().__init__(f"{code}: {message}")


def fail(code: str, message: str = "AI stem generation facade failure", *, retryable: bool = False):
    raise GenerationFacadeError(code, message, retryable=retryable)


def _sha(v: Any, field: str) -> str:
    if not isinstance(v, str):
        fail("GEN_FACADE_SHA_INVALID", field)
    x = v.strip().lower().removeprefix("sha256:")
    if not HEX64.fullmatch(x):
        fail("GEN_FACADE_SHA_INVALID", field)
    return x


def _safe(v: Any, field: str) -> str:
    if not isinstance(v, str) or not SAFE.fullmatch(v.strip()):
        fail("GEN_FACADE_SAFE_ID_INVALID", field)
    return v.strip()


def _int(v: Any, field: str, lo: int = 0) -> int:
    if isinstance(v, bool) or not isinstance(v, int) or v < lo:
        fail("GEN_FACADE_INTEGER_INVALID", field)
    return v


def canonical_sha(v: Any) -> str:
    return hashlib.sha256(
        json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


def generation_ref_hash(logical_generation_id: str) -> str:
    if not isinstance(logical_generation_id, str) or not ID32.fullmatch(logical_generation_id):
        fail("GEN_FACADE_LOGICAL_ID_INVALID")
    return hashlib.sha256(("l1-a21-generation-ref-v1:" + logical_generation_id).encode()).hexdigest()


def a22_output_path(project_output_root: str | Path, logical_generation_id: str, role: str) -> Path:
    if not isinstance(logical_generation_id, str) or not ID32.fullmatch(logical_generation_id):
        fail("GEN_FACADE_LOGICAL_ID_INVALID")
    role_n = _safe(role, "role").lower()
    ref = hashlib.sha256(("l1-a22-output-v1:" + logical_generation_id).encode()).hexdigest()[:24]
    return Path(project_output_root) / f"{ref}-{role_n}.wav"


def _fsync_dir(path: Path):
    try:
        fd = os.open(str(path), os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except OSError as e:
        raise GenerationFacadeError("GEN_FACADE_DIRECTORY_FSYNC_FAILED", retryable=True) from e


@dataclass
class FacadeRecord:
    logical_generation_id: str
    request_fingerprint: str
    project_ref_hash: str
    source_sha256: str
    source_sample_rate: int
    source_channels: int
    source_audio_format: int
    source_bits_per_sample: int
    source_frame_count: int
    target_role: str
    variant_index: int
    generation_ref_hash: str
    runtime_descriptor_sha256: str
    mix_policy_sha256: str
    retention_policy_sha256: str
    phase: str = "INTENT_DURABLE"
    start_receipt_sha256: str | None = None
    last_runtime_receipt_sha256: str | None = None
    mix_plan_sha256: str | None = None
    mix_ready_receipt_sha256: str | None = None
    active_artifact_sha256: str | None = None
    cancellation_requested: bool = False
    delete_requested: bool = False
    stable_error_code: str | None = None

    def validate(self):
        if not ID32.fullmatch(self.logical_generation_id):
            fail("GEN_FACADE_LOGICAL_ID_INVALID")
        for field in (
            "request_fingerprint", "project_ref_hash", "source_sha256", "generation_ref_hash",
            "runtime_descriptor_sha256", "mix_policy_sha256", "retention_policy_sha256",
        ):
            _sha(getattr(self, field), field)
        if generation_ref_hash(self.logical_generation_id) != self.generation_ref_hash:
            fail("GEN_FACADE_GENERATION_REF_MISMATCH")
        for field in ("source_sample_rate", "source_channels", "source_audio_format", "source_bits_per_sample", "source_frame_count"):
            _int(getattr(self, field), field, 1)
        _safe(self.target_role, "target_role")
        _int(self.variant_index, "variant_index")
        if self.phase not in PHASES:
            fail("GEN_FACADE_PHASE_INVALID")
        for field in (
            "start_receipt_sha256", "last_runtime_receipt_sha256", "mix_plan_sha256",
            "mix_ready_receipt_sha256", "active_artifact_sha256",
        ):
            value = getattr(self, field)
            if value is not None:
                _sha(value, field)
        if self.stable_error_code is not None:
            _safe(self.stable_error_code, "stable_error_code")


class AtomicFacadeJournal:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def locked(self):
        with self.lock_path.open("a+b") as handle:
            try:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            except ImportError as e:
                raise GenerationFacadeError("GEN_FACADE_LOCK_UNAVAILABLE") from e
            try:
                yield self._load()
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def _load(self) -> dict[str, FacadeRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception as e:
            raise GenerationFacadeError("GEN_FACADE_JOURNAL_CORRUPT") from e
        if raw.get("schema_version") != SCHEMA_VERSION or not isinstance(raw.get("records"), dict):
            fail("GEN_FACADE_JOURNAL_SCHEMA")
        out = {}
        try:
            for k, v in raw["records"].items():
                rec = FacadeRecord(**v)
                rec.validate()
                if k != rec.logical_generation_id:
                    raise ValueError("key")
                out[k] = rec
        except GenerationFacadeError:
            raise
        except Exception as e:
            raise GenerationFacadeError("GEN_FACADE_JOURNAL_RECORD_INVALID") from e
        return out

    def save(self, records: Mapping[str, FacadeRecord]):
        for rec in records.values():
            rec.validate()
        payload = {
            "schema_version": SCHEMA_VERSION,
            "records": {k: asdict(records[k]) for k in sorted(records)},
        }
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        try:
            with tmp.open("w", encoding="utf-8") as f:
                json.dump(payload, f, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
                f.write("\n")
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, self.path)
            _fsync_dir(self.path.parent)
        except OSError as e:
            tmp.unlink(missing_ok=True)
            raise GenerationFacadeError("GEN_FACADE_JOURNAL_WRITE_FAILED", retryable=True) from e


class A23MixGateway:
    """Production wrapper over the A23 mix-compatibility contract."""

    def __init__(self, *, variant_store: Any, policy: Any):
        self.variant_store = variant_store
        self.policy = policy
        policy.validate()
        self.policy_sha256 = policy.policy_sha256

    def finalize(
        self,
        *,
        facade_record: FacadeRecord,
        raw_output_path: str | Path,
        alignment_evidence_sha256: str,
        normalized_path: str | Path | None = None,
        normalization_receipt: Any | None = None,
    ) -> dict[str, Any]:
        from generated_stem_mix_compatibility import (
            SourceMixSpec,
            canonical_sha as a23_sha,
            plan_normalization,
            validate_mix_ready,
        )

        source = SourceMixSpec(
            source_sha256=facade_record.source_sha256,
            sample_rate=facade_record.source_sample_rate,
            channels=facade_record.source_channels,
            audio_format=facade_record.source_audio_format,
            bits_per_sample=facade_record.source_bits_per_sample,
            frame_count=facade_record.source_frame_count,
        )
        source.validate()
        plan = plan_normalization(
            raw_path=raw_output_path,
            source=source,
            policy=self.policy,
            timeline_origin_frames=0,
            alignment_evidence_sha256=_sha(alignment_evidence_sha256, "alignment_evidence_sha256"),
        )
        plan_sha = a23_sha(plan.public_dict())
        if not plan.ready_without_normalization and normalized_path is None:
            return {"state": "NORMALIZATION_REQUIRED", "plan_sha256": plan_sha}
        candidate = raw_output_path if plan.ready_without_normalization else normalized_path
        receipt = validate_mix_ready(
            candidate_path=candidate,
            source=source,
            plan=plan,
            normalization_receipt=normalization_receipt,
        )
        item = self.variant_store.commit_variant(
            project_ref_hash=facade_record.project_ref_hash,
            role=facade_record.target_role,
            generation_ref_hash=facade_record.generation_ref_hash,
            variant_index=facade_record.variant_index,
            candidate_path=candidate,
            receipt=receipt,
        )
        return {
            "state": "ACTIVE",
            "plan_sha256": plan_sha,
            "mix_ready_receipt_sha256": receipt.receipt_sha256,
            "artifact_sha256": item.artifact_sha256,
        }


class GeneratedStemProcessingFacade:
    """Durable single entry point that prevents A21-A24 ordering bypass."""

    def __init__(
        self,
        *,
        contract: Any,
        runtime: Any,
        mix_gateway: Any,
        retention: Any,
        journal_path: str | Path,
    ):
        self.contract = contract
        self.runtime = runtime
        self.mix_gateway = mix_gateway
        self.retention = retention
        self.journal = AtomicFacadeJournal(journal_path)
        self._assert_surfaces()

    def _assert_surfaces(self):
        for obj, names, code in (
            (self.contract, ("get", "request_cancel"), "GEN_FACADE_A21_SURFACE_MISSING"),
            (self.runtime, ("start", "reconcile", "observe", "cancel", "sanitized_receipt"), "GEN_FACADE_A22_SURFACE_MISSING"),
            (self.mix_gateway, ("finalize",), "GEN_FACADE_A23_SURFACE_MISSING"),
            (self.retention, ("register_variant", "request_delete", "snapshot"), "GEN_FACADE_A24_SURFACE_MISSING"),
        ):
            if any(not callable(getattr(obj, name, None)) for name in names):
                fail(code)
        runtime_descriptor = getattr(getattr(self.runtime, "descriptor", None), "descriptor_sha256", None)
        self.runtime_descriptor_sha256 = _sha(runtime_descriptor, "runtime_descriptor_sha256")
        self.mix_policy_sha256 = _sha(getattr(self.mix_gateway, "policy_sha256", None), "mix_policy_sha256")
        self.retention_policy_sha256 = _sha(
            getattr(self.retention, "retention_policy_sha256", None), "retention_policy_sha256"
        )

    def _get_record(self, gid: str) -> FacadeRecord:
        if not isinstance(gid, str) or not ID32.fullmatch(gid):
            fail("GEN_FACADE_LOGICAL_ID_INVALID")
        with self.journal.locked() as records:
            if gid not in records:
                fail("GEN_FACADE_RECORD_NOT_FOUND")
            return records[gid]

    def _mutate(self, gid: str, fn):
        with self.journal.locked() as records:
            if gid not in records:
                fail("GEN_FACADE_RECORD_NOT_FOUND")
            fn(records[gid])
            records[gid].validate()
            self.journal.save(records)
            return records[gid]

    def _receipt_hash(self, receipt: Any) -> str:
        if not isinstance(receipt, Mapping):
            fail("GEN_FACADE_RECEIPT_INVALID")
        supplied = receipt.get("receipt_sha256")
        if supplied is not None:
            return _sha(supplied, "receipt_sha256")
        return canonical_sha(receipt)

    def begin(
        self,
        *,
        intent: Any,
        entitlement: Any,
        source_path: str | Path,
        prompt: str | None = None,
        reference_audio_path: str | Path | None = None,
    ) -> dict[str, Any]:
        gid = getattr(intent, "logical_generation_id", None)
        if not isinstance(gid, str) or not ID32.fullmatch(gid):
            fail("GEN_FACADE_LOGICAL_ID_INVALID")
        request_fp = _sha(getattr(intent, "request_fingerprint", None), "request_fingerprint")
        project = _sha(getattr(intent, "project_ref_hash", None), "project_ref_hash")
        source_sha = _sha(getattr(intent, "source_sha256", None), "source_sha256")
        role = _safe(getattr(intent, "target_role", None), "target_role").lower()
        variant = _int(getattr(intent, "variant_index", None), "variant_index")
        gh = generation_ref_hash(gid)

        from generated_stem_mix_compatibility import SourceMixSpec
        source_spec = SourceMixSpec.from_wav(source_path)
        if source_spec.source_sha256 != source_sha:
            fail("GEN_FACADE_SOURCE_SHA_MISMATCH")

        with self.journal.locked() as records:
            old = records.get(gid)
            candidate = FacadeRecord(
                gid, request_fp, project, source_sha,
                source_spec.sample_rate, source_spec.channels, source_spec.audio_format,
                source_spec.bits_per_sample, source_spec.frame_count,
                role, variant, gh,
                self.runtime_descriptor_sha256, self.mix_policy_sha256, self.retention_policy_sha256
            )
            if old:
                immutable = (
                    "request_fingerprint", "project_ref_hash", "source_sha256", "source_sample_rate",
                    "source_channels", "source_audio_format", "source_bits_per_sample", "source_frame_count",
                    "target_role", "variant_index", "generation_ref_hash", "runtime_descriptor_sha256",
                    "mix_policy_sha256", "retention_policy_sha256",
                )
                if any(getattr(old, f) != getattr(candidate, f) for f in immutable):
                    fail("GEN_FACADE_IDEMPOTENCY_CONFLICT")
                safe_restart = False
                if old.phase in {"INTENT_DURABLE", "START_CALL_IN_FLIGHT"}:
                    try:
                        self.contract.get(gid)
                    except Exception as e:
                        if getattr(e, "code", None) == "GEN_RECORD_NOT_FOUND":
                            safe_restart = True
                        else:
                            raise
                existing = not safe_restart
            else:
                records[gid] = candidate
                self.journal.save(records)
                existing = False

        if existing:
            return self.snapshot(gid)
        self._mutate(gid, lambda r: setattr(r, "phase", "START_CALL_IN_FLIGHT"))
        try:
            receipt = self.runtime.start(
                intent=intent,
                entitlement=entitlement,
                source_path=source_path,
                prompt=prompt,
                reference_audio_path=reference_audio_path,
            )
        except Exception as e:
            code = getattr(e, "code", "GEN_FACADE_RUNTIME_START_EXCEPTION")
            def mark_unknown(r):
                r.phase = "START_UNKNOWN"
                r.stable_error_code = _safe(code, "stable_error_code")
            self._mutate(gid, mark_unknown)
            raise

        rh = self._receipt_hash(receipt)
        a21 = self.contract.get(gid)
        execution = getattr(a21, "execution_state", None)
        lifecycle = getattr(a21, "lifecycle_state", None)

        def after_start(r):
            r.start_receipt_sha256 = rh
            r.last_runtime_receipt_sha256 = rh
            r.stable_error_code = None
            if execution == "bound":
                r.phase = "RUNTIME_BOUND"
            elif execution in {"in_flight", "ambiguous"}:
                r.phase = "START_UNKNOWN"
            elif execution == "confirmed_absent":
                r.phase = "FAILED"
                r.stable_error_code = "GEN_START_CONFIRMED_ABSENT"
            else:
                fail("GEN_FACADE_A21_START_STATE_INVALID")
            if lifecycle == "failed":
                r.phase = "FAILED"
        self._mutate(gid, after_start)
        return self.snapshot(gid)

    def directive(self, logical_generation_id: str) -> str:
        rec = self._get_record(logical_generation_id)
        a21 = self.contract.get(logical_generation_id)
        self._assert_identity(rec, a21)

        if rec.delete_requested:
            return "RECONCILE_DELETE"
        if rec.cancellation_requested or getattr(a21, "logical_cancelled", False):
            if getattr(a21, "execution_state", None) in {"not_attempted", "confirmed_absent"}:
                return "SETTLE_CANCELLED"
            return "OBSERVE_RUNTIME_NO_CANCEL_RETRY"
        if rec.phase == "NORMALIZATION_REQUIRED":
            return "PROVIDE_NORMALIZED_ARTIFACT"
        if rec.phase in {"VARIANT_ACTIVE", "RETENTION_REGISTERED"}:
            return "REGISTER_RETENTION"
        if rec.phase == "READY":
            return "READY"
        if rec.phase in {"START_CALL_IN_FLIGHT", "START_UNKNOWN"}:
            return "RECONCILE_RUNTIME"
        if getattr(a21, "execution_state", None) == "bound":
            if getattr(a21, "lifecycle_state", None) == "ready":
                return "FINALIZE_MIX"
            if getattr(a21, "lifecycle_state", None) in {"starting", "generating", "unknown"}:
                return "OBSERVE_RUNTIME"
            if getattr(a21, "lifecycle_state", None) == "failed":
                return "FAILED"
        if getattr(a21, "execution_state", None) == "confirmed_absent":
            return "FAILED"
        return "FAIL_CLOSED_UNKNOWN"

    def _assert_identity(self, rec: FacadeRecord, a21: Any):
        checks = (
            (getattr(a21, "request_fingerprint", None), rec.request_fingerprint),
            (getattr(a21, "project_ref_hash", None), rec.project_ref_hash),
            (getattr(a21, "source_sha256", None), rec.source_sha256),
            (getattr(a21, "target_role", None), rec.target_role),
            (getattr(a21, "variant_index", None), rec.variant_index),
        )
        if any(a != b for a, b in checks):
            fail("GEN_FACADE_A21_IDENTITY_MISMATCH")

    def advance_runtime(self, logical_generation_id: str) -> dict[str, Any]:
        directive = self.directive(logical_generation_id)
        if directive == "RECONCILE_RUNTIME":
            receipt = self.runtime.reconcile(logical_generation_id=logical_generation_id)
        elif directive in {"OBSERVE_RUNTIME", "OBSERVE_RUNTIME_NO_CANCEL_RETRY"}:
            receipt = self.runtime.observe(logical_generation_id=logical_generation_id)
        elif directive == "SETTLE_CANCELLED":
            self._mutate(logical_generation_id, lambda r: setattr(r, "phase", "CANCELLED"))
            return self.snapshot(logical_generation_id)
        else:
            fail("GEN_FACADE_RUNTIME_ADVANCE_NOT_ALLOWED", directive)

        rh = self._receipt_hash(receipt)
        a21 = self.contract.get(logical_generation_id)
        rec = self._get_record(logical_generation_id)
        self._assert_identity(rec, a21)

        def update(r):
            r.last_runtime_receipt_sha256 = rh
            lifecycle = getattr(a21, "lifecycle_state", None)
            execution = getattr(a21, "execution_state", None)
            if r.cancellation_requested or getattr(a21, "logical_cancelled", False):
                if lifecycle == "cancelled":
                    r.phase = "CANCELLED"
                else:
                    r.phase = "CANCEL_PENDING"
                return
            if execution == "bound" and lifecycle == "ready":
                r.phase = "RUNTIME_READY"
            elif execution == "bound" and lifecycle in {"starting", "generating", "unknown"}:
                r.phase = "RUNTIME_RUNNING"
            elif execution == "confirmed_absent" or lifecycle == "failed":
                r.phase = "FAILED"
            elif execution in {"in_flight", "ambiguous"}:
                r.phase = "START_UNKNOWN"
            else:
                fail("GEN_FACADE_A21_RUNTIME_STATE_INVALID")
        self._mutate(logical_generation_id, update)
        return self.snapshot(logical_generation_id)

    def finalize_mix(
        self,
        *,
        logical_generation_id: str,
        alignment_evidence_sha256: str,
        normalized_path: str | Path | None = None,
        normalization_receipt: Any | None = None,
    ) -> dict[str, Any]:
        align = _sha(alignment_evidence_sha256, "alignment_evidence_sha256")
        rec = self._get_record(logical_generation_id)
        a21 = self.contract.get(logical_generation_id)
        self._assert_identity(rec, a21)
        if rec.cancellation_requested or getattr(a21, "logical_cancelled", False):
            fail("GEN_FACADE_MIX_AFTER_CANCEL_FORBIDDEN")
        if getattr(a21, "execution_state", None) != "bound" or getattr(a21, "lifecycle_state", None) != "ready":
            fail("GEN_FACADE_RUNTIME_NOT_READY")
        output_sha = _sha(getattr(a21, "output_sha256", None), "output_sha256")
        if getattr(a21, "output_role", None) != rec.target_role:
            fail("GEN_FACADE_OUTPUT_ROLE_MISMATCH")

        raw_path = a22_output_path(self.runtime.project_output_root, logical_generation_id, rec.target_role)
        if raw_path.is_symlink() or not raw_path.is_file():
            fail("GEN_FACADE_A22_OUTPUT_MISSING")
        from generated_stem_mix_compatibility import file_sha256
        if file_sha256(raw_path) != output_sha:
            fail("GEN_FACADE_A22_OUTPUT_MUTATED")

        self._mutate(logical_generation_id, lambda r: setattr(r, "phase", "MIX_COMMIT_IN_FLIGHT"))
        result = self.mix_gateway.finalize(
            facade_record=rec,
            raw_output_path=raw_path,
            alignment_evidence_sha256=align,
            normalized_path=normalized_path,
            normalization_receipt=normalization_receipt,
        )
        state = result.get("state")
        plan_sha = _sha(result.get("plan_sha256"), "mix_plan_sha256")
        if state == "NORMALIZATION_REQUIRED":
            def need_norm(r):
                r.phase = "NORMALIZATION_REQUIRED"
                r.mix_plan_sha256 = plan_sha
            self._mutate(logical_generation_id, need_norm)
            return self.snapshot(logical_generation_id)
        if state != "ACTIVE":
            fail("GEN_FACADE_A23_RESULT_INVALID")
        mix_sha = _sha(result.get("mix_ready_receipt_sha256"), "mix_ready_receipt_sha256")
        artifact_sha = _sha(result.get("artifact_sha256"), "artifact_sha256")
        def active(r):
            r.phase = "VARIANT_ACTIVE"
            r.mix_plan_sha256 = plan_sha
            r.mix_ready_receipt_sha256 = mix_sha
            r.active_artifact_sha256 = artifact_sha
        self._mutate(logical_generation_id, active)
        self._register_retention(logical_generation_id)
        return self.snapshot(logical_generation_id)

    def _register_retention(self, logical_generation_id: str):
        rec = self._get_record(logical_generation_id)
        if rec.phase not in {"VARIANT_ACTIVE", "RETENTION_REGISTERED"}:
            fail("GEN_FACADE_RETENTION_ORDER_INVALID")
        registered = self.retention.register_variant(
            generation_ref_hash_value=rec.generation_ref_hash,
            variant_index=rec.variant_index,
        )
        if (
            getattr(registered, "generation_ref_hash", None) != rec.generation_ref_hash
            or getattr(registered, "artifact_sha256", None) != rec.active_artifact_sha256
        ):
            fail("GEN_FACADE_RETENTION_IDENTITY_MISMATCH")
        self._mutate(logical_generation_id, lambda r: setattr(r, "phase", "READY"))

    def advance_local(self, logical_generation_id: str) -> dict[str, Any]:
        directive = self.directive(logical_generation_id)
        if directive == "REGISTER_RETENTION":
            self._register_retention(logical_generation_id)
            return self.snapshot(logical_generation_id)
        fail("GEN_FACADE_LOCAL_ADVANCE_NOT_ALLOWED", directive)

    def cancel(self, *, logical_generation_id: str) -> dict[str, Any]:
        rec = self._get_record(logical_generation_id)
        if rec.phase == "READY":
            fail("GEN_FACADE_CANCEL_AFTER_READY_FORBIDDEN")
        if rec.cancellation_requested:
            return self.snapshot(logical_generation_id)
        def intent(r):
            r.cancellation_requested = True
            r.phase = "CANCEL_CALL_IN_FLIGHT"
        self._mutate(logical_generation_id, intent)
        self.contract.request_cancel(
            logical_generation_id,
            upstream_cancel_supported=bool(getattr(self.runtime.descriptor, "supports_cancel", False)),
        )
        try:
            receipt = self.runtime.cancel(logical_generation_id=logical_generation_id)
        except Exception:
            raise
        rh = self._receipt_hash(receipt)
        a21 = self.contract.get(logical_generation_id)
        def after(r):
            r.last_runtime_receipt_sha256 = rh
            r.phase = "CANCELLED" if getattr(a21, "lifecycle_state", None) == "cancelled" else "CANCEL_PENDING"
        self._mutate(logical_generation_id, after)
        return self.snapshot(logical_generation_id)

    def request_delete(
        self,
        *,
        logical_generation_id: str,
        reason: str,
        runtime_delete=None,
        binding_store_path=None,
    ) -> dict[str, Any]:
        rec = self._get_record(logical_generation_id)
        if rec.phase not in {"READY", "VARIANT_ACTIVE", "RETENTION_REGISTERED", "DELETED_ASSOCIATION"}:
            fail("GEN_FACADE_DELETE_BEFORE_VARIANT_FORBIDDEN")
        reason_n = _safe(reason, "reason").upper()
        def intent(r):
            r.delete_requested = True
            r.phase = "DELETE_CALL_IN_FLIGHT"
        if not rec.delete_requested:
            self._mutate(logical_generation_id, intent)
        snap = self.retention.request_delete(
            generation_ref_hash_value=rec.generation_ref_hash,
            variant_index=rec.variant_index,
            reason=reason_n,
            runtime_delete=runtime_delete,
            binding_store_path=binding_store_path,
        )
        if snap.get("generation_ref_hash") != rec.generation_ref_hash or snap.get("variant_index") != rec.variant_index:
            fail("GEN_FACADE_DELETE_RECEIPT_IDENTITY_MISMATCH")
        if snap.get("association_delete_confirmed") is True:
            self._mutate(logical_generation_id, lambda r: setattr(r, "phase", "DELETED_ASSOCIATION"))
        return self.snapshot(logical_generation_id)

    def snapshot(self, logical_generation_id: str) -> dict[str, Any]:
        rec = self._get_record(logical_generation_id)
        directive = self.directive(logical_generation_id)
        payload = {
            "schema_version": SCHEMA_VERSION,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "parity_claim": "NONE",
            "generation_ref_hash": rec.generation_ref_hash,
            "request_fingerprint": rec.request_fingerprint,
            "project_ref_hash": rec.project_ref_hash,
            "source_sha256": rec.source_sha256,
            "source_format": {
                "sample_rate": rec.source_sample_rate,
                "channels": rec.source_channels,
                "audio_format": rec.source_audio_format,
                "bits_per_sample": rec.source_bits_per_sample,
                "frame_count": rec.source_frame_count,
            },
            "target_role": rec.target_role,
            "variant_index": rec.variant_index,
            "runtime_descriptor_sha256": rec.runtime_descriptor_sha256,
            "mix_policy_sha256": rec.mix_policy_sha256,
            "retention_policy_sha256": rec.retention_policy_sha256,
            "phase": rec.phase,
            "directive": directive,
            "start_receipt_sha256": rec.start_receipt_sha256,
            "last_runtime_receipt_sha256": rec.last_runtime_receipt_sha256,
            "mix_plan_sha256": rec.mix_plan_sha256,
            "mix_ready_receipt_sha256": rec.mix_ready_receipt_sha256,
            "active_artifact_sha256": rec.active_artifact_sha256,
            "cancellation_requested": rec.cancellation_requested,
            "delete_requested": rec.delete_requested,
            "stable_error_code": rec.stable_error_code,
            "privacy": {
                "raw_logical_generation_id_emitted": False,
                "source_path_emitted": False,
                "runtime_output_path_emitted": False,
                "raw_prompt_emitted": False,
                "raw_execution_id_emitted": False,
                "credential_values_emitted": False,
                "raw_audio_emitted": False,
            },
        }
        payload["facade_evidence_sha256"] = canonical_sha({"domain": "l1-a25-facade-evidence-v1", **payload})
        return payload
