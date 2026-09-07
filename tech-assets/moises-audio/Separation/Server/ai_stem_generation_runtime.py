"""L1-A22 provider-neutral AI stem generation runtime adapter (NON-PARITY)."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping

TOOL_VERSION = "L1-A22-v1"
PROTOCOL_VERSION = "L1-A22-GENERATION-RUNTIME-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
ID32 = re.compile(r"^[0-9a-f]{32}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
AUTHORITY_KINDS = {"HOSTED_PROVIDER_ACCOUNT", "LOCAL_RUNTIME", "PROJECT_OWNED_RUNTIME"}
CREDIT_EVENTS = {"COMMITTED", "NOT_COMMITTED", "UNKNOWN"}
START_OUTCOMES = {"STARTED", "REJECTED", "AMBIGUOUS"}
OBSERVE_STATES = {"QUEUED", "GENERATING", "READY", "FAILED", "CANCELLED"}


class GenerationRuntimeError(RuntimeError):
    def __init__(self, code: str, message: str = "generation runtime adapter failure", *, retryable: bool = False):
        self.code = code
        self.message = message
        self.retryable = retryable
        super().__init__(f"{code}: {message}")


def fail(code: str, message: str = "generation runtime adapter failure", *, retryable: bool = False):
    raise GenerationRuntimeError(code, message, retryable=retryable)


def _sha(v: Any, field: str) -> str:
    if not isinstance(v, str):
        fail("GENRT_SHA_INVALID", field)
    x = v.strip().lower().removeprefix("sha256:")
    if not HEX64.fullmatch(x):
        fail("GENRT_SHA_INVALID", field)
    return x


def _safe(v: Any, field: str) -> str:
    if not isinstance(v, str) or not SAFE.fullmatch(v.strip()):
        fail("GENRT_SAFE_ID_INVALID", field)
    return v.strip()


def _bool(v: Any, field: str) -> bool:
    if not isinstance(v, bool):
        fail("GENRT_BOOL_INVALID", field)
    return v


def canonical_sha(v: Any) -> str:
    return hashlib.sha256(
        json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    try:
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
    except OSError as e:
        raise GenerationRuntimeError("GENRT_FILE_UNREADABLE", str(path)) from e
    return h.hexdigest()


def _fsync_dir(path: Path):
    try:
        fd = os.open(str(path), os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except OSError as e:
        raise GenerationRuntimeError("GENRT_DIRECTORY_FSYNC_FAILED", str(path), retryable=True) from e


def _execution_hash(execution_id: str) -> str:
    return hashlib.sha256(("l1-a21-execution-v1:" + execution_id).encode()).hexdigest()


def _prompt_hash(prompt: str) -> str:
    return hashlib.sha256(("l1-a21-prompt-v1:" + prompt.strip()).encode()).hexdigest()


@dataclass(frozen=True)
class RuntimeDescriptor:
    runtime_id: str
    authority_kind: str
    runtime_identity_sha256: str
    driver_artifact_sha256: str
    capability_snapshot_sha256: str
    supports_cancel: bool
    supports_reconcile: bool
    credential_env_names: tuple[str, ...]
    descriptor_sha256: str

    @classmethod
    def from_mapping(cls, raw: Mapping[str, Any]) -> "RuntimeDescriptor":
        if raw.get("schema_version") != 1 or raw.get("evidence_state") != EVIDENCE_STATE:
            fail("GENRT_DESCRIPTOR_SCHEMA")
        if raw.get("protocol_version") != PROTOCOL_VERSION:
            fail("GENRT_PROTOCOL_MISMATCH")
        rid = _safe(raw.get("runtime_id"), "runtime_id")
        kind = _safe(raw.get("authority_kind"), "authority_kind").upper()
        if kind not in AUTHORITY_KINDS:
            fail("GENRT_AUTHORITY_KIND_INVALID")
        runtime_sha = _sha(raw.get("runtime_identity_sha256"), "runtime_identity_sha256")
        driver_sha = _sha(raw.get("driver_artifact_sha256"), "driver_artifact_sha256")
        cap = _sha(raw.get("capability_snapshot_sha256"), "capability_snapshot_sha256")
        cancel = _bool(raw.get("supports_cancel"), "supports_cancel")
        reconcile = _bool(raw.get("supports_reconcile"), "supports_reconcile")
        names = raw.get("credential_env_names")
        if not isinstance(names, list) or len(names) != len(set(names)):
            fail("GENRT_CREDENTIAL_ENV_INVALID")
        env_names = tuple(sorted(_safe(x, "credential_env_name") for x in names))
        sem = {
            "schema_version": 1,
            "evidence_state": EVIDENCE_STATE,
            "protocol_version": PROTOCOL_VERSION,
            "runtime_id": rid,
            "authority_kind": kind,
            "runtime_identity_sha256": runtime_sha,
            "driver_artifact_sha256": driver_sha,
            "capability_snapshot_sha256": cap,
            "supports_cancel": cancel,
            "supports_reconcile": reconcile,
            "credential_env_names": list(env_names),
        }
        lock = _sha(raw.get("descriptor_sha256"), "descriptor_sha256")
        if canonical_sha({"domain": "l1-a22-runtime-descriptor-v1", **sem}) != lock:
            fail("GENRT_DESCRIPTOR_LOCK_MISMATCH")
        return cls(rid, kind, runtime_sha, driver_sha, cap, cancel, reconcile, env_names, lock)


def descriptor_template_digest(raw: Mapping[str, Any]) -> str:
    x = dict(raw)
    x.pop("descriptor_sha256", None)
    x["schema_version"] = 1
    x["evidence_state"] = EVIDENCE_STATE
    x["protocol_version"] = PROTOCOL_VERSION
    x["runtime_id"] = _safe(x.get("runtime_id"), "runtime_id")
    x["authority_kind"] = _safe(x.get("authority_kind"), "authority_kind").upper()
    x["runtime_identity_sha256"] = _sha(x.get("runtime_identity_sha256"), "runtime_identity_sha256")
    x["driver_artifact_sha256"] = _sha(x.get("driver_artifact_sha256"), "driver_artifact_sha256")
    x["capability_snapshot_sha256"] = _sha(x.get("capability_snapshot_sha256"), "capability_snapshot_sha256")
    x["supports_cancel"] = _bool(x.get("supports_cancel"), "supports_cancel")
    x["supports_reconcile"] = _bool(x.get("supports_reconcile"), "supports_reconcile")
    names = x.get("credential_env_names")
    if not isinstance(names, list) or len(names) != len(set(names)):
        fail("GENRT_CREDENTIAL_ENV_INVALID")
    x["credential_env_names"] = sorted(_safe(v, "credential_env_name") for v in names)
    return canonical_sha({"domain": "l1-a22-runtime-descriptor-v1", **x})


@dataclass
class BindingRecord:
    logical_generation_id: str
    request_fingerprint: str
    runtime_descriptor_sha256: str
    execution_id: str
    execution_ref_hash: str


class PrivateBindingStore:
    """Stores raw runtime execution IDs in private server state, never public evidence."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")

    @contextmanager
    def locked(self):
        with self.lock_path.open("a+b") as h:
            try:
                import fcntl
                fcntl.flock(h.fileno(), fcntl.LOCK_EX)
            except ImportError as e:
                raise GenerationRuntimeError("GENRT_BINDING_LOCK_UNAVAILABLE") from e
            try:
                yield self._load()
            finally:
                fcntl.flock(h.fileno(), fcntl.LOCK_UN)

    def _load(self) -> dict[str, BindingRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception as e:
            raise GenerationRuntimeError("GENRT_BINDING_STORE_CORRUPT") from e
        if raw.get("schema_version") != 1 or not isinstance(raw.get("records"), dict):
            fail("GENRT_BINDING_STORE_SCHEMA")
        out: dict[str, BindingRecord] = {}
        try:
            for k, v in raw["records"].items():
                r = BindingRecord(**v)
                if not ID32.fullmatch(k) or r.logical_generation_id != k:
                    raise ValueError("id")
                _sha(r.request_fingerprint, "request_fingerprint")
                _sha(r.runtime_descriptor_sha256, "runtime_descriptor_sha256")
                if not isinstance(r.execution_id, str) or not r.execution_id:
                    raise ValueError("execution")
                if _execution_hash(r.execution_id) != r.execution_ref_hash:
                    raise ValueError("execution hash")
                out[k] = r
        except Exception as e:
            raise GenerationRuntimeError("GENRT_BINDING_RECORD_INVALID") from e
        return out

    def _save(self, records: Mapping[str, BindingRecord]):
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        payload = {
            "schema_version": 1,
            "records": {k: asdict(records[k]) for k in sorted(records)},
        }
        try:
            with tmp.open("w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2, sort_keys=True, ensure_ascii=False)
                f.write("\n")
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, self.path)
            _fsync_dir(self.path.parent)
        except OSError as e:
            tmp.unlink(missing_ok=True)
            raise GenerationRuntimeError("GENRT_BINDING_WRITE_FAILED", retryable=True) from e

    def bind(self, *, logical_generation_id: str, request_fingerprint: str, runtime_descriptor_sha256: str, execution_id: str):
        if not ID32.fullmatch(logical_generation_id):
            fail("GENRT_LOGICAL_ID_INVALID")
        rec = BindingRecord(
            logical_generation_id,
            _sha(request_fingerprint, "request_fingerprint"),
            _sha(runtime_descriptor_sha256, "runtime_descriptor_sha256"),
            execution_id,
            _execution_hash(execution_id),
        )
        with self.locked() as records:
            old = records.get(logical_generation_id)
            if old and asdict(old) != asdict(rec):
                fail("GENRT_BINDING_CONFLICT")
            records[logical_generation_id] = rec
            self._save(records)
        return rec

    def get(self, logical_generation_id: str) -> BindingRecord:
        with self.locked() as records:
            if logical_generation_id not in records:
                fail("GENRT_BINDING_NOT_FOUND")
            return records[logical_generation_id]


class CommandRuntimeTransport:
    """One-shot JSON stdin/stdout adapter. Secrets are supplied only through allowlisted environment variables."""

    def __init__(self, *, driver_path: str | Path, descriptor: RuntimeDescriptor, timeout_seconds: float = 30.0):
        raw_driver = Path(driver_path)
        if raw_driver.is_symlink():
            fail("GENRT_DRIVER_SYMLINK")
        self.driver_path = raw_driver.resolve()
        self.descriptor = descriptor
        self.timeout_seconds = float(timeout_seconds)
        if self.timeout_seconds <= 0:
            fail("GENRT_TIMEOUT_INVALID")
        if not self.driver_path.is_file() or self.driver_path.is_symlink():
            fail("GENRT_DRIVER_INVALID")
        if sha256_file(self.driver_path) != descriptor.driver_artifact_sha256:
            fail("GENRT_DRIVER_SHA_MISMATCH")
        missing = [n for n in descriptor.credential_env_names if n not in os.environ]
        if missing:
            fail("GENRT_CREDENTIAL_ENV_MISSING")

    def request(self, operation: str, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        op = _safe(operation, "operation")
        request = {
            "schema_version": 1,
            "protocol_version": PROTOCOL_VERSION,
            "operation": op,
            "runtime_id": self.descriptor.runtime_id,
            "runtime_identity_sha256": self.descriptor.runtime_identity_sha256,
            "payload": dict(payload),
        }
        env = {k: os.environ[k] for k in self.descriptor.credential_env_names}
        env["PYTHONIOENCODING"] = "utf-8"
        cmd = [sys.executable, str(self.driver_path)] if self.driver_path.suffix == ".py" else [str(self.driver_path)]
        try:
            cp = subprocess.run(
                cmd,
                input=json.dumps(request, separators=(",", ":"), ensure_ascii=False),
                text=True,
                capture_output=True,
                timeout=self.timeout_seconds,
                env=env,
                check=False,
            )
        except subprocess.TimeoutExpired as e:
            raise GenerationRuntimeError("GENRT_TRANSPORT_TIMEOUT", retryable=True) from e
        except OSError as e:
            raise GenerationRuntimeError("GENRT_TRANSPORT_IO", retryable=True) from e
        if cp.returncode != 0:
            raise GenerationRuntimeError("GENRT_DRIVER_NONZERO", retryable=False)
        try:
            out = json.loads(cp.stdout)
        except Exception as e:
            raise GenerationRuntimeError("GENRT_RESPONSE_JSON_INVALID") from e
        if not isinstance(out, dict):
            fail("GENRT_RESPONSE_SCHEMA")
        return out


class AIStemGenerationRuntimeAdapter:
    def __init__(
        self,
        *,
        contract: Any,
        descriptor: RuntimeDescriptor,
        transport: Any,
        binding_store_path: str | Path,
        project_output_root: str | Path,
        runtime_output_root: str | Path,
    ):
        self.contract = contract
        self.descriptor = descriptor
        self.transport = transport
        self.bindings = PrivateBindingStore(binding_store_path)
        self.project_output_root = Path(project_output_root).resolve()
        self.runtime_output_root = Path(runtime_output_root).resolve()
        self.project_output_root.mkdir(parents=True, exist_ok=True)
        self.runtime_output_root.mkdir(parents=True, exist_ok=True)
        self._assert_contract_surface()

    def _assert_contract_surface(self):
        required = (
            "reserve", "authorize_start", "mark_start_ambiguous", "bind_execution",
            "confirm_no_execution", "release_credit_if_no_execution", "commit_credit_usage",
            "update_progress", "request_cancel", "confirm_upstream_cancelled",
            "publish_output", "mark_failed", "get", "privacy_safe_evidence",
        )
        missing = [x for x in required if not callable(getattr(self.contract, x, None))]
        if missing:
            fail("GENRT_A21_CONTRACT_SURFACE_MISSING")

    def _verify_descriptor_binding(self, intent: Any, entitlement: Any):
        if getattr(intent, "request_fingerprint", None) is None:
            fail("GENRT_INTENT_INVALID")
        if getattr(entitlement, "capability_snapshot_sha256", None) != self.descriptor.capability_snapshot_sha256:
            fail("GENRT_ENTITLEMENT_CAPABILITY_MISMATCH")

    def _verify_private_inputs(self, *, intent: Any, source_path: str | Path, prompt: str | None, reference_audio_path: str | Path | None):
        raw_src = Path(source_path)
        if raw_src.is_symlink():
            fail("GENRT_SOURCE_INVALID")
        src = raw_src.resolve()
        if not src.is_file():
            fail("GENRT_SOURCE_INVALID")
        if sha256_file(src) != getattr(intent, "source_sha256", None):
            fail("GENRT_SOURCE_SHA_MISMATCH")
        prompt_sha = getattr(intent, "prompt_sha256", None)
        if prompt_sha is None:
            if prompt is not None:
                fail("GENRT_PROMPT_UNEXPECTED")
        else:
            if not isinstance(prompt, str) or _prompt_hash(prompt) != prompt_sha:
                fail("GENRT_PROMPT_SHA_MISMATCH")
        ref_sha = getattr(intent, "reference_audio_sha256", None)
        if ref_sha is None:
            if reference_audio_path is not None:
                fail("GENRT_REFERENCE_AUDIO_UNEXPECTED")
        else:
            if reference_audio_path is None:
                fail("GENRT_REFERENCE_AUDIO_REQUIRED")
            raw_rp = Path(reference_audio_path)
            if raw_rp.is_symlink():
                fail("GENRT_REFERENCE_AUDIO_SHA_MISMATCH")
            rp = raw_rp.resolve()
            if not rp.is_file() or sha256_file(rp) != ref_sha:
                fail("GENRT_REFERENCE_AUDIO_SHA_MISMATCH")
        return src

    def _base_payload(self, intent: Any) -> dict[str, Any]:
        return {
            "request_fingerprint": intent.request_fingerprint,
            "source_sha256": intent.source_sha256,
            "source_duration_seconds": intent.source_duration_seconds,
            "target_role": intent.target_role,
            "generation_mode": intent.generation_mode,
            "preset_id": intent.preset_id,
            "prompt_sha256": intent.prompt_sha256,
            "reference_audio_sha256": intent.reference_audio_sha256,
            "variant_index": intent.variant_index,
            "capability_snapshot_sha256": self.descriptor.capability_snapshot_sha256,
        }

    def _validate_response(self, response: Mapping[str, Any], operation: str, request_fingerprint: str) -> dict[str, Any]:
        if not isinstance(response, Mapping):
            fail("GENRT_RESPONSE_SCHEMA")
        if response.get("schema_version") != 1 or response.get("protocol_version") != PROTOCOL_VERSION:
            fail("GENRT_RESPONSE_PROTOCOL")
        if response.get("operation") != operation:
            fail("GENRT_RESPONSE_OPERATION_MISMATCH")
        if response.get("runtime_id") != self.descriptor.runtime_id:
            fail("GENRT_RESPONSE_RUNTIME_MISMATCH")
        if _sha(response.get("runtime_identity_sha256"), "runtime_identity_sha256") != self.descriptor.runtime_identity_sha256:
            fail("GENRT_RESPONSE_RUNTIME_IDENTITY_MISMATCH")
        if _sha(response.get("request_fingerprint"), "request_fingerprint") != request_fingerprint:
            fail("GENRT_RESPONSE_REQUEST_MISMATCH")
        _sha(response.get("authority_evidence_sha256"), "authority_evidence_sha256")
        return dict(response)

    def _commit_usage_if_reported(self, gid: str, response: Mapping[str, Any]):
        event = _safe(response.get("credit_event"), "credit_event").upper()
        if event not in CREDIT_EVENTS:
            fail("GENRT_CREDIT_EVENT_INVALID")
        if event == "COMMITTED":
            self.contract.commit_credit_usage(
                gid, authority_evidence_sha256=response["authority_evidence_sha256"]
            )

    def start(self, *, intent: Any, entitlement: Any, source_path: str | Path, prompt: str | None = None, reference_audio_path: str | Path | None = None):
        self._verify_descriptor_binding(intent, entitlement)
        src = self._verify_private_inputs(
            intent=intent, source_path=source_path, prompt=prompt, reference_audio_path=reference_audio_path
        )
        self.contract.reserve(intent=intent, entitlement=entitlement)
        self.contract.authorize_start(intent.logical_generation_id)
        payload = self._base_payload(intent)
        payload.update({
            "source_path": str(src),
            "prompt": prompt,
            "reference_audio_path": None if reference_audio_path is None else str(Path(reference_audio_path).resolve()),
        })
        try:
            raw = self.transport.request("start", payload)
        except GenerationRuntimeError as e:
            if e.code in {"GENRT_TRANSPORT_TIMEOUT", "GENRT_TRANSPORT_IO"}:
                self.contract.mark_start_ambiguous(intent.logical_generation_id, stable_error_code=e.code)
            raise
        response = self._validate_response(raw, "start", intent.request_fingerprint)
        outcome = _safe(response.get("outcome"), "outcome").upper()
        if outcome not in START_OUTCOMES:
            fail("GENRT_START_OUTCOME_INVALID")
        if outcome == "AMBIGUOUS":
            self.contract.mark_start_ambiguous(intent.logical_generation_id, stable_error_code="GEN_RUNTIME_START_AMBIGUOUS")
            self._commit_usage_if_reported(intent.logical_generation_id, response)
            return self.sanitized_receipt(intent.logical_generation_id, operation="start", operation_state="AMBIGUOUS")
        if outcome == "REJECTED":
            if _safe(response.get("credit_event"), "credit_event").upper() != "NOT_COMMITTED":
                fail("GENRT_REJECTED_CREDIT_CONTRADICTION")
            if response.get("execution_definitely_absent") is not True:
                self.contract.mark_start_ambiguous(intent.logical_generation_id, stable_error_code="GEN_RUNTIME_REJECTED_UNCERTAIN")
                fail("GENRT_REJECTED_WITHOUT_ABSENCE_PROOF")
            self.contract.confirm_no_execution(
                intent.logical_generation_id,
                reconciliation_evidence_sha256=response["authority_evidence_sha256"],
            )
            self.contract.release_credit_if_no_execution(
                intent.logical_generation_id, release_reason="RUNTIME_START_REJECTED_CONFIRMED_ABSENT"
            )
            return self.sanitized_receipt(intent.logical_generation_id, operation="start", operation_state="REJECTED")
        execution_id = response.get("execution_id")
        if not isinstance(execution_id, str) or not execution_id:
            fail("GENRT_EXECUTION_ID_MISSING")
        rec = self.contract.bind_execution(intent.logical_generation_id, execution_id=execution_id)
        binding = self.bindings.bind(
            logical_generation_id=intent.logical_generation_id,
            request_fingerprint=intent.request_fingerprint,
            runtime_descriptor_sha256=self.descriptor.descriptor_sha256,
            execution_id=execution_id,
        )
        if getattr(rec, "execution_ref_hash", None) != binding.execution_ref_hash:
            fail("GENRT_A21_BINDING_HASH_MISMATCH")
        self._commit_usage_if_reported(intent.logical_generation_id, response)
        return self.sanitized_receipt(intent.logical_generation_id, operation="start", operation_state="STARTED")

    def reconcile(self, *, logical_generation_id: str):
        if not self.descriptor.supports_reconcile:
            fail("GENRT_RECONCILIATION_UNSUPPORTED")
        record = self.contract.get(logical_generation_id)
        raw = self.transport.request(
            "reconcile",
            {
                "request_fingerprint": record.request_fingerprint,
                "capability_snapshot_sha256": self.descriptor.capability_snapshot_sha256,
            },
        )
        response = self._validate_response(raw, "reconcile", record.request_fingerprint)
        matches = response.get("execution_ids")
        if not isinstance(matches, list) or any(not isinstance(x, str) or not x for x in matches):
            fail("GENRT_RECONCILE_MATCH_SET_INVALID")
        if len(matches) > 1:
            fail("GENRT_DUPLICATE_EXECUTIONS_DETECTED")
        if not matches:
            if _safe(response.get("credit_event"), "credit_event").upper() != "NOT_COMMITTED":
                fail("GENRT_RECONCILE_ABSENT_CREDIT_CONTRADICTION")
            self.contract.confirm_no_execution(
                logical_generation_id,
                reconciliation_evidence_sha256=response["authority_evidence_sha256"],
            )
            self.contract.release_credit_if_no_execution(
                logical_generation_id, release_reason="RUNTIME_RECONCILIATION_CONFIRMED_ABSENT"
            )
            return self.sanitized_receipt(logical_generation_id, operation="reconcile", operation_state="ABSENT")
        execution_id = matches[0]
        rec = self.contract.bind_execution(logical_generation_id, execution_id=execution_id)
        binding = self.bindings.bind(
            logical_generation_id=logical_generation_id,
            request_fingerprint=record.request_fingerprint,
            runtime_descriptor_sha256=self.descriptor.descriptor_sha256,
            execution_id=execution_id,
        )
        if getattr(rec, "execution_ref_hash", None) != binding.execution_ref_hash:
            fail("GENRT_A21_BINDING_HASH_MISMATCH")
        self._commit_usage_if_reported(logical_generation_id, response)
        return self.sanitized_receipt(logical_generation_id, operation="reconcile", operation_state="BOUND")

    def _binding_for(self, logical_generation_id: str) -> BindingRecord:
        b = self.bindings.get(logical_generation_id)
        r = self.contract.get(logical_generation_id)
        if b.request_fingerprint != r.request_fingerprint or b.runtime_descriptor_sha256 != self.descriptor.descriptor_sha256:
            fail("GENRT_BINDING_STALE")
        if getattr(r, "execution_ref_hash", None) != b.execution_ref_hash:
            fail("GENRT_BINDING_A21_MISMATCH")
        return b

    def observe(self, *, logical_generation_id: str):
        b = self._binding_for(logical_generation_id)
        r = self.contract.get(logical_generation_id)
        raw = self.transport.request(
            "observe",
            {"request_fingerprint": r.request_fingerprint, "execution_id": b.execution_id},
        )
        response = self._validate_response(raw, "observe", r.request_fingerprint)
        state = _safe(response.get("state"), "state").upper()
        if state not in OBSERVE_STATES:
            fail("GENRT_OBSERVE_STATE_INVALID")
        progress = response.get("progress_percent")
        if not isinstance(progress, int) or isinstance(progress, bool) or not 0 <= progress <= 100:
            fail("GENRT_PROGRESS_INVALID")
        current = self.contract.get(logical_generation_id)
        if not getattr(current, "logical_cancelled", False):
            if progress < getattr(current, "progress_percent", 0):
                fail("GENRT_PROGRESS_REGRESSION")
            self.contract.update_progress(logical_generation_id, progress_percent=progress)
        self._commit_usage_if_reported(logical_generation_id, response)
        if state == "FAILED":
            self.contract.mark_failed(logical_generation_id, stable_error_code=_safe(response.get("stable_error_code"), "stable_error_code"))
        elif state == "CANCELLED":
            if getattr(self.contract.get(logical_generation_id), "logical_cancelled", False):
                self.contract.confirm_upstream_cancelled(
                    logical_generation_id, authority_evidence_sha256=response["authority_evidence_sha256"]
                )
            else:
                self.contract.mark_failed(logical_generation_id, stable_error_code="GEN_RUNTIME_CANCELLED_EXTERNALLY")
        elif state == "READY":
            if getattr(self.contract.get(logical_generation_id), "logical_cancelled", False):
                return self.sanitized_receipt(logical_generation_id, operation="observe", operation_state="READY_DISCARDED_AFTER_CANCEL")
            if _safe(response.get("credit_event"), "credit_event").upper() != "COMMITTED":
                fail("GENRT_READY_WITHOUT_USAGE_COMMIT")
            output = response.get("output")
            if not isinstance(output, Mapping):
                fail("GENRT_READY_OUTPUT_MISSING")
            final = self._promote_output(logical_generation_id, output)
            self.contract.publish_output(
                logical_generation_id,
                role=output.get("role"),
                artifact_sha256=sha256_file(final),
                artifact_bytes=final.stat().st_size,
                project_controlled=True,
                integrity_verified=True,
            )
        return self.sanitized_receipt(logical_generation_id, operation="observe", operation_state=state)

    def _promote_output(self, logical_generation_id: str, output: Mapping[str, Any]) -> Path:
        role = _safe(output.get("role"), "output.role").lower()
        expected_sha = _sha(output.get("sha256"), "output.sha256")
        expected_bytes = output.get("bytes")
        if not isinstance(expected_bytes, int) or isinstance(expected_bytes, bool) or expected_bytes <= 0:
            fail("GENRT_OUTPUT_BYTES_INVALID")
        raw_path = output.get("path")
        if not isinstance(raw_path, str):
            fail("GENRT_OUTPUT_PATH_INVALID")
        src = Path(raw_path).resolve()
        try:
            src.relative_to(self.runtime_output_root)
        except ValueError:
            fail("GENRT_OUTPUT_OUTSIDE_RUNTIME_ROOT")
        if not src.is_file() or src.is_symlink():
            fail("GENRT_OUTPUT_FILE_INVALID")
        if src.stat().st_size != expected_bytes or sha256_file(src) != expected_sha:
            fail("GENRT_OUTPUT_INTEGRITY_MISMATCH")
        try:
            import wave
            with wave.open(str(src), "rb") as wf:
                if wf.getnchannels() not in (1, 2) or wf.getframerate() <= 0 or wf.getnframes() <= 0 or wf.getsampwidth() not in (1, 2, 3, 4):
                    fail("GENRT_OUTPUT_WAV_INVALID")
        except GenerationRuntimeError:
            raise
        except Exception as e:
            raise GenerationRuntimeError("GENRT_OUTPUT_WAV_INVALID") from e
        generation_ref = hashlib.sha256(("l1-a22-output-v1:" + logical_generation_id).encode()).hexdigest()[:24]
        final = self.project_output_root / f"{generation_ref}-{role}.wav"
        if final.exists():
            if final.is_symlink() or final.stat().st_size != expected_bytes or sha256_file(final) != expected_sha:
                fail("GENRT_OUTPUT_REPLACEMENT_CONFLICT")
            return final
        tmp = final.with_suffix(".wav.tmp")
        try:
            h = hashlib.sha256()
            total = 0
            with src.open("rb") as r, tmp.open("wb") as w:
                for chunk in iter(lambda: r.read(1024 * 1024), b""):
                    total += len(chunk)
                    if total > expected_bytes:
                        fail("GENRT_OUTPUT_RUNTIME_CAP_EXCEEDED")
                    h.update(chunk)
                    w.write(chunk)
                w.flush()
                os.fsync(w.fileno())
            if total != expected_bytes or h.hexdigest() != expected_sha:
                fail("GENRT_OUTPUT_COPY_MISMATCH")
            os.replace(tmp, final)
            _fsync_dir(final.parent)
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
        return final

    def cancel(self, *, logical_generation_id: str):
        self.contract.request_cancel(
            logical_generation_id, upstream_cancel_supported=self.descriptor.supports_cancel
        )
        if not self.descriptor.supports_cancel:
            return self.sanitized_receipt(logical_generation_id, operation="cancel", operation_state="UNSUPPORTED")
        try:
            b = self._binding_for(logical_generation_id)
        except GenerationRuntimeError as e:
            if e.code == "GENRT_BINDING_NOT_FOUND":
                return self.sanitized_receipt(logical_generation_id, operation="cancel", operation_state="LOGICAL_ONLY")
            raise
        r = self.contract.get(logical_generation_id)
        raw = self.transport.request(
            "cancel", {"request_fingerprint": r.request_fingerprint, "execution_id": b.execution_id}
        )
        response = self._validate_response(raw, "cancel", r.request_fingerprint)
        state = _safe(response.get("cancel_state"), "cancel_state").upper()
        if state == "CONFIRMED":
            self.contract.confirm_upstream_cancelled(
                logical_generation_id, authority_evidence_sha256=response["authority_evidence_sha256"]
            )
        elif state not in {"REQUEST_ACCEPTED", "UNKNOWN"}:
            fail("GENRT_CANCEL_STATE_INVALID")
        return self.sanitized_receipt(logical_generation_id, operation="cancel", operation_state=state)

    def sanitized_receipt(self, logical_generation_id: str, *, operation: str, operation_state: str) -> dict[str, Any]:
        a21 = self.contract.privacy_safe_evidence(logical_generation_id)
        payload = {
            "schema_version": 1,
            "tool_version": TOOL_VERSION,
            "evidence_kind": "AI_STEM_GENERATION_RUNTIME_RECEIPT",
            "evidence_state": EVIDENCE_STATE,
            "parity_claim": "NONE",
            "runtime_id": self.descriptor.runtime_id,
            "authority_kind": self.descriptor.authority_kind,
            "runtime_identity_sha256": self.descriptor.runtime_identity_sha256,
            "runtime_descriptor_sha256": self.descriptor.descriptor_sha256,
            "capability_snapshot_sha256": self.descriptor.capability_snapshot_sha256,
            "operation": _safe(operation, "operation"),
            "operation_state": _safe(operation_state, "operation_state"),
            "generation": a21,
            "privacy": {
                "raw_prompt_emitted": False,
                "raw_account_id_emitted": False,
                "raw_project_id_emitted": False,
                "raw_execution_id_emitted": False,
                "source_path_emitted": False,
                "runtime_output_path_emitted": False,
                "credential_values_emitted": False,
                "signed_url_emitted": False,
                "raw_audio_emitted": False,
            },
        }
        payload["receipt_sha256"] = canonical_sha({"domain": "l1-a22-runtime-receipt-v1", **payload})
        return payload
