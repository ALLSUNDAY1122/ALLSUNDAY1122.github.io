"""L1-A24 generated-stem retention/delete/refund/orphan recovery (NON-PARITY)."""
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
TOOL_VERSION = "L1-A24-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
REFUND_STATES = {"NOT_APPLICABLE", "NOT_REQUESTED", "PENDING", "CONFIRMED", "DENIED", "UNKNOWN"}
RUNTIME_DELETE_STATES = {"NOT_APPLICABLE", "NOT_REQUESTED", "PENDING", "CONFIRMED", "NOT_FOUND", "UNSUPPORTED", "UNKNOWN"}

class GeneratedStemRetentionError(RuntimeError):
    def __init__(self, code: str, message: str = "generated stem retention failure", *, retryable: bool = False):
        self.code = code
        self.message = message
        self.retryable = retryable
        super().__init__(f"{code}: {message}")

def fail(code: str, message: str = "generated stem retention failure", *, retryable: bool = False):
    raise GeneratedStemRetentionError(code, message, retryable=retryable)

def _sha(v: Any, field: str) -> str:
    if not isinstance(v, str):
        fail("GENRET_SHA_INVALID", field)
    x = v.strip().lower().removeprefix("sha256:")
    if not HEX64.fullmatch(x):
        fail("GENRET_SHA_INVALID", field)
    return x

def _safe(v: Any, field: str) -> str:
    if not isinstance(v, str) or not SAFE.fullmatch(v.strip()):
        fail("GENRET_SAFE_ID_INVALID", field)
    return v.strip()

def _int(v: Any, field: str, lo: int = 0) -> int:
    if isinstance(v, bool) or not isinstance(v, int) or v < lo:
        fail("GENRET_INTEGER_INVALID", field)
    return v

def canonical_sha(value: Any) -> str:
    try:
        raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    except (TypeError, ValueError) as e:
        raise GeneratedStemRetentionError("GENRET_CANONICAL_JSON_INVALID") from e
    return hashlib.sha256(raw).hexdigest()

def file_sha256(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    try:
        with path.open("rb") as f:
            while True:
                b = f.read(chunk_size)
                if not b:
                    break
                h.update(b)
    except OSError as e:
        raise GeneratedStemRetentionError("GENRET_FILE_UNREADABLE") from e
    return h.hexdigest()

def _fsync_dir(path: Path):
    try:
        fd = os.open(str(path), os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except OSError as e:
        raise GeneratedStemRetentionError("GENRET_DIRECTORY_FSYNC_FAILED", retryable=True) from e

def _read_json_strict(path: Path, code: str) -> Mapping[str, Any]:
    if path.is_symlink():
        fail("GENRET_SYMLINK_FORBIDDEN")
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        raise GeneratedStemRetentionError(code) from e
    if not isinstance(raw, dict):
        fail(code)
    return raw

def _unlink_durable(path: Path):
    if path.is_symlink():
        fail("GENRET_SYMLINK_FORBIDDEN")
    try:
        path.unlink()
        _fsync_dir(path.parent)
    except FileNotFoundError:
        return
    except OSError as e:
        raise GeneratedStemRetentionError("GENRET_LOCAL_DELETE_FAILED", retryable=True) from e

@dataclass
class DeleteRecord:
    deletion_id: str
    project_ref_hash: str
    role: str
    generation_ref_hash: str
    variant_index: int
    artifact_sha256: str
    manifest_sha256: str
    request_reason: str
    delete_intent_evidence_sha256: str
    local_state: str = "DELETE_INTENT_DURABLE"
    active_pointer_removed: bool = False
    manifest_removed: bool = False
    object_removed: bool = False
    object_retained_due_to_reference: bool = False
    refund_state: str = "NOT_REQUESTED"
    refund_request_evidence_sha256: str | None = None
    refund_authority_evidence_sha256: str | None = None
    runtime_delete_state: str = "NOT_REQUESTED"
    runtime_delete_evidence_sha256: str | None = None
    local_delete_completed: bool = False

    def validate(self):
        _safe(self.deletion_id, "deletion_id")
        for f in ("project_ref_hash", "generation_ref_hash", "artifact_sha256", "manifest_sha256", "delete_intent_evidence_sha256"):
            _sha(getattr(self, f), f)
        _safe(self.role, "role")
        _int(self.variant_index, "variant_index", 0)
        if self.request_reason not in {"USER_DELETE", "PROJECT_DELETE", "ACCOUNT_DELETE", "CANCEL_CLEANUP", "RETENTION_EXPIRED", "REGENERATION_CLEANUP"}:
            fail("GENRET_DELETE_REASON_INVALID")
        if self.local_state not in {"DELETE_INTENT_DURABLE", "ACTIVE_DETACHED", "MANIFEST_REMOVED", "LOCAL_DELETED"}:
            fail("GENRET_LOCAL_STATE_INVALID")
        if self.refund_state not in REFUND_STATES:
            fail("GENRET_REFUND_STATE_INVALID")
        if self.runtime_delete_state not in RUNTIME_DELETE_STATES:
            fail("GENRET_RUNTIME_DELETE_STATE_INVALID")
        for f in ("refund_request_evidence_sha256", "refund_authority_evidence_sha256", "runtime_delete_evidence_sha256"):
            v = getattr(self, f)
            if v is not None:
                _sha(v, f)
        if self.refund_state == "PENDING" and self.refund_request_evidence_sha256 is None:
            fail("GENRET_REFUND_REQUEST_EVIDENCE_REQUIRED")
        if self.refund_state in {"CONFIRMED", "DENIED"} and self.refund_authority_evidence_sha256 is None:
            fail("GENRET_REFUND_AUTHORITY_EVIDENCE_REQUIRED")
        if self.runtime_delete_state in {"NOT_APPLICABLE", "PENDING", "CONFIRMED", "NOT_FOUND", "UNSUPPORTED", "UNKNOWN"} and self.runtime_delete_evidence_sha256 is None:
            fail("GENRET_RUNTIME_DELETE_EVIDENCE_REQUIRED")
        if self.local_delete_completed and self.local_state != "LOCAL_DELETED":
            fail("GENRET_COMPLETION_STATE_INVALID")

class DurableDeleteLedger:
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
                raise GeneratedStemRetentionError("GENRET_LOCK_UNAVAILABLE") from e
            try:
                yield self._load()
            finally:
                fcntl.flock(h.fileno(), fcntl.LOCK_UN)

    def _load(self) -> dict[str, DeleteRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception as e:
            raise GeneratedStemRetentionError("GENRET_LEDGER_CORRUPT") from e
        if not isinstance(raw, dict) or raw.get("schema_version") != 1 or not isinstance(raw.get("records"), dict):
            fail("GENRET_LEDGER_SCHEMA_INVALID")
        out = {}
        try:
            for k, v in raw["records"].items():
                r = DeleteRecord(**v)
                r.validate()
                if k != r.deletion_id:
                    raise ValueError("id")
                out[k] = r
        except GeneratedStemRetentionError:
            raise
        except Exception as e:
            raise GeneratedStemRetentionError("GENRET_LEDGER_RECORD_INVALID") from e
        return out

    def save(self, records: Mapping[str, DeleteRecord]):
        for r in records.values():
            r.validate()
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        payload = {"schema_version": 1, "records": {k: asdict(records[k]) for k in sorted(records)}}
        try:
            with tmp.open("w", encoding="utf-8") as f:
                json.dump(payload, f, sort_keys=True, separators=(",", ":"))
                f.write("\n")
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, self.path)
            _fsync_dir(self.path.parent)
        except OSError as e:
            tmp.unlink(missing_ok=True)
            raise GeneratedStemRetentionError("GENRET_LEDGER_WRITE_FAILED", retryable=True) from e

class GeneratedStemRetentionCoordinator:
    """Coordinates A23 local variants with A21 credit/refund truth.

    Local delete completion and credit refund are intentionally independent.
    """

    def __init__(self, store_root: str | Path, ledger_path: str | Path):
        self.root = Path(store_root)
        self.objects = self.root / "objects"
        self.manifests = self.root / "manifests"
        self.active = self.root / "active"
        self.store_lock_path = self.root / ".lock"
        for p in (self.objects, self.manifests, self.active):
            p.mkdir(parents=True, exist_ok=True)
        self.ledger = DurableDeleteLedger(ledger_path)

    @contextmanager
    def store_locked(self):
        self.root.mkdir(parents=True, exist_ok=True)
        with self.store_lock_path.open("a+b") as h:
            try:
                import fcntl
                fcntl.flock(h.fileno(), fcntl.LOCK_EX)
            except ImportError as e:
                raise GeneratedStemRetentionError("GENRET_STORE_LOCK_UNAVAILABLE") from e
            try:
                yield
            finally:
                fcntl.flock(h.fileno(), fcntl.LOCK_UN)

    @staticmethod
    def deletion_id(project_ref_hash: str, role: str, generation_ref_hash: str, variant_index: int) -> str:
        return canonical_sha({
            "domain": "l1-a24-delete-v1",
            "project_ref_hash": _sha(project_ref_hash, "project_ref_hash"),
            "role": _safe(role, "role").lower(),
            "generation_ref_hash": _sha(generation_ref_hash, "generation_ref_hash"),
            "variant_index": _int(variant_index, "variant_index", 0),
        })[:32]

    def _manifest_path(self, generation_ref_hash: str, variant_index: int) -> Path:
        return self.manifests / f"{_sha(generation_ref_hash, 'generation_ref_hash')}.v{_int(variant_index, 'variant_index', 0)}.json"

    def _active_path(self, project_ref_hash: str, role: str) -> Path:
        return self.active / f"{_sha(project_ref_hash, 'project_ref_hash')}.{_safe(role, 'role').lower()}.json"

    @staticmethod
    def _validate_variant_mapping(raw: Mapping[str, Any]) -> dict[str, Any]:
        required = {
            "schema_version", "project_ref_hash", "role", "generation_ref_hash", "variant_index",
            "artifact_sha256", "artifact_bytes", "sample_rate", "channels", "audio_format",
            "bits_per_sample", "frame_count", "mix_ready_receipt_sha256",
        }
        if set(raw) != required or raw.get("schema_version") != 1:
            fail("GENRET_VARIANT_MANIFEST_INVALID")
        out = dict(raw)
        out["project_ref_hash"] = _sha(out["project_ref_hash"], "project_ref_hash")
        out["role"] = _safe(out["role"], "role").lower()
        out["generation_ref_hash"] = _sha(out["generation_ref_hash"], "generation_ref_hash")
        out["variant_index"] = _int(out["variant_index"], "variant_index", 0)
        out["artifact_sha256"] = _sha(out["artifact_sha256"], "artifact_sha256")
        out["mix_ready_receipt_sha256"] = _sha(out["mix_ready_receipt_sha256"], "mix_ready_receipt_sha256")
        for f in ("artifact_bytes", "sample_rate", "channels", "audio_format", "bits_per_sample", "frame_count"):
            _int(out[f], f, 1)
        return out

    def begin_delete(
        self, *, project_ref_hash: str, role: str, generation_ref_hash: str, variant_index: int,
        request_reason: str, delete_intent_evidence_sha256: str,
    ) -> DeleteRecord:
        project = _sha(project_ref_hash, "project_ref_hash")
        role_n = _safe(role, "role").lower()
        gen = _sha(generation_ref_hash, "generation_ref_hash")
        vi = _int(variant_index, "variant_index", 0)
        evidence = _sha(delete_intent_evidence_sha256, "delete_intent_evidence_sha256")
        did = self.deletion_id(project, role_n, gen, vi)
        mpath = self._manifest_path(gen, vi)

        with self.store_locked():
            if not mpath.is_file() or mpath.is_symlink():
                fail("GENRET_MANIFEST_REQUIRED_FOR_DELETE")
            raw = self._validate_variant_mapping(_read_json_strict(mpath, "GENRET_VARIANT_MANIFEST_INVALID"))
            if raw["project_ref_hash"] != project or raw["role"] != role_n or raw["generation_ref_hash"] != gen or raw["variant_index"] != vi:
                fail("GENRET_DELETE_IDENTITY_MISMATCH")
            manifest_sha = file_sha256(mpath)
            artifact_sha = raw["artifact_sha256"]
            with self.ledger.locked() as records:
                old = records.get(did)
                if old:
                    expected = (project, role_n, gen, vi, artifact_sha, manifest_sha)
                    actual = (old.project_ref_hash, old.role, old.generation_ref_hash, old.variant_index, old.artifact_sha256, old.manifest_sha256)
                    if actual != expected or old.request_reason != request_reason or old.delete_intent_evidence_sha256 != evidence:
                        fail("GENRET_DELETE_INTENT_CONFLICT")
                    return old
                rec = DeleteRecord(did, project, role_n, gen, vi, artifact_sha, manifest_sha, request_reason, evidence)
                rec.validate()
                records[did] = rec
                self.ledger.save(records)
                return rec

    def get(self, deletion_id: str) -> DeleteRecord:
        did = _safe(deletion_id, "deletion_id")
        with self.ledger.locked() as records:
            if did not in records:
                fail("GENRET_DELETE_RECORD_NOT_FOUND")
            return records[did]

    def assert_generation_not_deleted(self, generation_ref_hash: str):
        gen = _sha(generation_ref_hash, "generation_ref_hash")
        with self.ledger.locked() as records:
            for r in records.values():
                if r.generation_ref_hash == gen:
                    fail("GENRET_GENERATION_TOMBSTONED")

    def _same_variant(self, raw: Mapping[str, Any], r: DeleteRecord) -> bool:
        v = self._validate_variant_mapping(raw)
        return v["project_ref_hash"] == r.project_ref_hash and v["role"] == r.role and v["generation_ref_hash"] == r.generation_ref_hash and v["variant_index"] == r.variant_index and v["artifact_sha256"] == r.artifact_sha256

    def execute_local_delete(self, deletion_id: str) -> DeleteRecord:
        did = _safe(deletion_id, "deletion_id")
        with self.store_locked():
            with self.ledger.locked() as records:
                if did not in records:
                    fail("GENRET_DELETE_RECORD_NOT_FOUND")
                r = records[did]
                if r.local_state == "LOCAL_DELETED":
                    return r
                apath = self._active_path(r.project_ref_hash, r.role)
                if apath.exists():
                    if apath.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                    araw = _read_json_strict(apath, "GENRET_ACTIVE_POINTER_CORRUPT")
                    if self._same_variant(araw, r):
                        _unlink_durable(apath); r.active_pointer_removed = True
                    else:
                        v = self._validate_variant_mapping(araw)
                        if v["project_ref_hash"] != r.project_ref_hash or v["role"] != r.role:
                            fail("GENRET_ACTIVE_POINTER_IDENTITY_INVALID")
                r.local_state = "ACTIVE_DETACHED"; self.ledger.save(records)
                mpath = self._manifest_path(r.generation_ref_hash, r.variant_index)
                if mpath.exists():
                    if mpath.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                    if file_sha256(mpath) != r.manifest_sha256: fail("GENRET_MANIFEST_MUTATED")
                    if not self._same_variant(_read_json_strict(mpath, "GENRET_VARIANT_MANIFEST_INVALID"), r): fail("GENRET_MANIFEST_IDENTITY_MISMATCH")
                    _unlink_durable(mpath)
                r.manifest_removed = True; r.local_state = "MANIFEST_REMOVED"; self.ledger.save(records)
                refs = self._collect_referenced_artifacts()
                opath = self.objects / f"{r.artifact_sha256}.wav"
                if r.artifact_sha256 in refs:
                    r.object_retained_due_to_reference = True; r.object_removed = False
                elif opath.exists():
                    if opath.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                    _unlink_durable(opath); r.object_removed = True; r.object_retained_due_to_reference = False
                else:
                    r.object_removed = True; r.object_retained_due_to_reference = False
                r.local_state = "LOCAL_DELETED"; r.local_delete_completed = True; self.ledger.save(records); return r

    def _collect_referenced_artifacts(self) -> set[str]:
        refs: set[str] = set()
        for directory, code in ((self.manifests, "GENRET_REFERENCE_MANIFEST_CORRUPT"), (self.active, "GENRET_REFERENCE_ACTIVE_CORRUPT")):
            for p in sorted(directory.glob("*.json")):
                if p.name.endswith(".tmp"): continue
                if p.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                try: v = self._validate_variant_mapping(_read_json_strict(p, code))
                except GeneratedStemRetentionError as e: raise GeneratedStemRetentionError(code) from e
                refs.add(v["artifact_sha256"])
        return refs

    def sweep_orphan_objects(self, *, minimum_age_seconds: int, now_epoch: int | None = None) -> tuple[str, ...]:
        age = _int(minimum_age_seconds, "minimum_age_seconds", 0)
        now = int(__import__("time").time()) if now_epoch is None else _int(now_epoch, "now_epoch", 0)
        removed = []
        with self.store_locked():
            refs = self._collect_referenced_artifacts()
            for p in sorted(self.objects.glob("*.wav")):
                if p.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                if not p.is_file(): continue
                stem = p.stem.lower()
                if not HEX64.fullmatch(stem): fail("GENRET_OBJECT_NAME_INVALID")
                try: st = p.stat()
                except OSError as e: raise GeneratedStemRetentionError("GENRET_OBJECT_STAT_FAILED", retryable=True) from e
                if stem in refs or now - int(st.st_mtime) < age: continue
                _unlink_durable(p); removed.append(stem)
        return tuple(removed)

    def sweep_stale_temp_files(self, *, minimum_age_seconds: int, now_epoch: int | None = None) -> tuple[str, ...]:
        age = _int(minimum_age_seconds, "minimum_age_seconds", 0)
        now = int(__import__("time").time()) if now_epoch is None else _int(now_epoch, "now_epoch", 0)
        removed = []
        with self.store_locked():
            self._collect_referenced_artifacts()
            for directory in (self.objects, self.manifests, self.active):
                for p in sorted(directory.glob("*.tmp")):
                    if p.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                    if not p.is_file(): continue
                    try: st = p.stat()
                    except OSError as e: raise GeneratedStemRetentionError("GENRET_TEMP_STAT_FAILED", retryable=True) from e
                    if now - int(st.st_mtime) < age: continue
                    _unlink_durable(p); removed.append(f"{directory.name}/{p.name}")
        return tuple(removed)

    def begin_abandoned_cleanup(self, *, generation_ref_hash: str, variant_index: int, a21_lifecycle_state: str, abandonment_evidence_sha256: str) -> DeleteRecord:
        gen = _sha(generation_ref_hash, "generation_ref_hash"); vi = _int(variant_index, "variant_index", 0)
        state = _safe(a21_lifecycle_state, "a21_lifecycle_state").lower()
        if state not in {"cancelled", "failed"}: fail("GENRET_ABANDONMENT_STATE_INVALID")
        ev = _sha(abandonment_evidence_sha256, "abandonment_evidence_sha256"); mpath = self._manifest_path(gen, vi)
        with self.store_locked():
            if not mpath.is_file() or mpath.is_symlink(): fail("GENRET_MANIFEST_REQUIRED_FOR_DELETE")
            raw = self._validate_variant_mapping(_read_json_strict(mpath, "GENRET_VARIANT_MANIFEST_INVALID")); apath = self._active_path(raw["project_ref_hash"], raw["role"])
            if apath.exists():
                if apath.is_symlink(): fail("GENRET_SYMLINK_FORBIDDEN")
                active = self._validate_variant_mapping(_read_json_strict(apath, "GENRET_ACTIVE_POINTER_CORRUPT"))
                if active["generation_ref_hash"] == gen and active["variant_index"] == vi and active["artifact_sha256"] == raw["artifact_sha256"]: fail("GENRET_ACTIVE_VARIANT_NOT_ABANDONED")
        return self.begin_delete(project_ref_hash=raw["project_ref_hash"], role=raw["role"], generation_ref_hash=gen, variant_index=vi, request_reason="CANCEL_CLEANUP", delete_intent_evidence_sha256=ev)

    def record_refund_requested(self, deletion_id: str, *, a21_credit_state: str, request_evidence_sha256: str) -> DeleteRecord:
        did = _safe(deletion_id, "deletion_id"); ev = _sha(request_evidence_sha256, "request_evidence_sha256")
        if a21_credit_state != "refund_pending": fail("GENRET_A21_REFUND_PENDING_REQUIRED")
        with self.ledger.locked() as records:
            r = records.get(did)
            if not r: fail("GENRET_DELETE_RECORD_NOT_FOUND")
            if r.refund_state == "CONFIRMED": return r
            if r.refund_state not in {"NOT_REQUESTED", "PENDING"}: fail("GENRET_REFUND_TRANSITION_INVALID")
            if r.refund_request_evidence_sha256 not in {None, ev}: fail("GENRET_REFUND_REQUEST_CONFLICT")
            r.refund_state = "PENDING"; r.refund_request_evidence_sha256 = ev; self.ledger.save(records); return r

    def record_refund_authority(self, deletion_id: str, *, a21_credit_state: str, outcome: str, authority_evidence_sha256: str) -> DeleteRecord:
        did = _safe(deletion_id, "deletion_id"); ev = _sha(authority_evidence_sha256, "authority_evidence_sha256"); out = _safe(outcome, "outcome").upper()
        if out not in {"CONFIRMED", "DENIED", "UNKNOWN"}: fail("GENRET_REFUND_OUTCOME_INVALID")
        if out == "CONFIRMED" and a21_credit_state != "refunded": fail("GENRET_A21_REFUNDED_REQUIRED")
        if out in {"DENIED", "UNKNOWN"} and a21_credit_state not in {"committed", "refund_pending"}: fail("GENRET_A21_CREDIT_STATE_INCONSISTENT")
        with self.ledger.locked() as records:
            r = records.get(did)
            if not r: fail("GENRET_DELETE_RECORD_NOT_FOUND")
            if out in {"CONFIRMED", "DENIED", "UNKNOWN"} and r.refund_state != "PENDING": fail("GENRET_REFUND_AUTHORITY_WITHOUT_REQUEST")
            if r.refund_state == "CONFIRMED":
                if out == "CONFIRMED" and r.refund_authority_evidence_sha256 == ev: return r
                fail("GENRET_REFUND_TERMINAL_CONFLICT")
            r.refund_state = out; r.refund_authority_evidence_sha256 = ev; self.ledger.save(records); return r

    def record_runtime_delete(self, deletion_id: str, *, outcome: str, authority_evidence_sha256: str) -> DeleteRecord:
        did = _safe(deletion_id, "deletion_id"); out = _safe(outcome, "outcome").upper()
        if out not in RUNTIME_DELETE_STATES - {"NOT_REQUESTED"}: fail("GENRET_RUNTIME_DELETE_OUTCOME_INVALID")
        ev = _sha(authority_evidence_sha256, "authority_evidence_sha256")
        with self.ledger.locked() as records:
            r = records.get(did)
            if not r: fail("GENRET_DELETE_RECORD_NOT_FOUND")
            if r.runtime_delete_state in {"CONFIRMED", "NOT_FOUND"}:
                if r.runtime_delete_state == out and r.runtime_delete_evidence_sha256 == ev: return r
                fail("GENRET_RUNTIME_DELETE_TERMINAL_CONFLICT")
            r.runtime_delete_state = out; r.runtime_delete_evidence_sha256 = ev; self.ledger.save(records); return r

    def privacy_safe_evidence(self, deletion_id: str) -> dict[str, Any]:
        r = self.get(deletion_id); r.validate(); provider_erasure = r.runtime_delete_state in {"CONFIRMED", "NOT_FOUND", "NOT_APPLICABLE"}
        return {"schema_version":1,"tool_version":TOOL_VERSION,"evidence_state":EVIDENCE_STATE,"deletion_id":r.deletion_id,"project_ref_hash":r.project_ref_hash,"role":r.role,"generation_ref_hash":r.generation_ref_hash,"variant_index":r.variant_index,"artifact_sha256":r.artifact_sha256,"delete_intent_evidence_sha256":r.delete_intent_evidence_sha256,"local_state":r.local_state,"active_pointer_removed":r.active_pointer_removed,"manifest_removed":r.manifest_removed,"object_removed":r.object_removed,"object_retained_due_to_reference":r.object_retained_due_to_reference,"refund_state":r.refund_state,"runtime_delete_state":r.runtime_delete_state,"local_deletion_complete":r.local_state=="LOCAL_DELETED","runtime_erasure_authoritatively_complete":provider_erasure,"overall_erasure_complete":r.local_state=="LOCAL_DELETED" and provider_erasure,"refund_confirmed":r.refund_state=="CONFIRMED","deletion_does_not_imply_refund":True,"path_emitted":False,"raw_audio_emitted":False,"raw_runtime_id_emitted":False,"raw_credit_or_billing_record_emitted":False,"parity_claim":"NONE"}
