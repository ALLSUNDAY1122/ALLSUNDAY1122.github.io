"""L1-A25 durable delete-intent resume adapter for GeneratedStemProcessingFacade."""
from __future__ import annotations
import json, os
from contextlib import contextmanager
from pathlib import Path

from ai_stem_generation_processing_facade import GenerationFacadeError, _safe, fail, _fsync_dir

class DeleteIntentJournal:
    def __init__(self,path):
        self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True);self.lock=self.path.with_suffix(self.path.suffix+".lock")
    @contextmanager
    def locked(self):
        with self.lock.open("a+b") as h:
            try:
                import fcntl;fcntl.flock(h.fileno(),fcntl.LOCK_EX)
            except ImportError as e: raise GenerationFacadeError("GEN_FACADE_DELETE_LOCK_UNAVAILABLE") from e
            try: yield self._load()
            finally: fcntl.flock(h.fileno(),fcntl.LOCK_UN)
    def _load(self):
        if not self.path.exists(): return {}
        try: raw=json.loads(self.path.read_text())
        except Exception as e: raise GenerationFacadeError("GEN_FACADE_DELETE_JOURNAL_CORRUPT") from e
        if raw.get("schema_version")!=1 or not isinstance(raw.get("records"),dict): fail("GEN_FACADE_DELETE_JOURNAL_SCHEMA")
        return raw["records"]
    def save(self,records):
        tmp=self.path.with_suffix(self.path.suffix+".tmp")
        try:
            with tmp.open("w",encoding="utf-8") as f:
                json.dump({"schema_version":1,"records":records},f,sort_keys=True,separators=(",",":"));f.write("\n");f.flush();os.fsync(f.fileno())
            os.replace(tmp,self.path);_fsync_dir(self.path.parent)
        except OSError as e:
            tmp.unlink(missing_ok=True);raise GenerationFacadeError("GEN_FACADE_DELETE_JOURNAL_WRITE_FAILED",retryable=True) from e

class DeleteResumableGenerationFacade:
    """Adds durable delete reason and same-operation replay over the A25 base facade."""
    def __init__(self,*,facade,journal_path):
        self.facade=facade;self.journal=DeleteIntentJournal(journal_path)

    def _intent(self,gid,reason=None):
        with self.journal.locked() as rs:
            old=rs.get(gid)
            if reason is None:
                if old is None: fail("GEN_FACADE_DELETE_INTENT_NOT_FOUND")
                return old
            r=_safe(reason,"reason").upper()
            if old is not None and old!=r: fail("GEN_FACADE_DELETE_REASON_CONFLICT")
            if old is None:
                rs[gid]=r;self.journal.save(rs)
            return r

    def request_delete(self,*,logical_generation_id,reason,runtime_delete=None,binding_store_path=None):
        reason_n=self._intent(logical_generation_id,reason)
        return self._execute(logical_generation_id,reason_n,runtime_delete,binding_store_path)

    def advance_delete(self,*,logical_generation_id,runtime_delete=None,binding_store_path=None):
        return self._execute(logical_generation_id,self._intent(logical_generation_id),runtime_delete,binding_store_path)

    def _execute(self,gid,reason,runtime_delete,binding_store_path):
        rec=self.facade._get_record(gid)
        allowed={"READY","VARIANT_ACTIVE","RETENTION_REGISTERED","DELETE_CALL_IN_FLIGHT","DELETED_ASSOCIATION"}
        if rec.phase not in allowed: fail("GEN_FACADE_DELETE_BEFORE_VARIANT_FORBIDDEN")
        if not rec.delete_requested:
            def mark(r):
                r.delete_requested=True;r.phase="DELETE_CALL_IN_FLIGHT"
            self.facade._mutate(gid,mark)
            rec=self.facade._get_record(gid)
        snap=self.facade.retention.request_delete(
            generation_ref_hash_value=rec.generation_ref_hash,
            variant_index=rec.variant_index,
            reason=reason,
            runtime_delete=runtime_delete,
            binding_store_path=binding_store_path,
        )
        if snap.get("generation_ref_hash")!=rec.generation_ref_hash or snap.get("variant_index")!=rec.variant_index:
            fail("GEN_FACADE_DELETE_RECEIPT_IDENTITY_MISMATCH")
        if snap.get("association_delete_confirmed") is True:
            self.facade._mutate(gid,lambda r:setattr(r,"phase","DELETED_ASSOCIATION"))
        out=self.facade.snapshot(gid)
        out["delete_reason_hash"] = __import__("hashlib").sha256(("l1-a25-delete-reason-v1:"+reason).encode()).hexdigest()
        out["delete_reason_emitted"]=False
        return out
