"""Privacy-safe observability/evidence telemetry for Lane 1 separation processing.

NON-PARITY infrastructure. Only bounded allowlisted scalars/hashes are persisted. Arbitrary
metadata, raw media, paths, filenames, signed URLs, credentials and provider operational IDs
are intentionally unsupported.
"""
from __future__ import annotations
import hashlib, json, math, os, re
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

SCHEMA_VERSION=1
_JOB=re.compile(r"^[0-9a-f]{32}$"); _SHA=re.compile(r"^[0-9a-f]{64}$")
_ID=re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,95}$"); _CODE=re.compile(r"^[A-Z0-9_.:-]{1,160}$")
_CUR=re.compile(r"^[A-Z]{3}$"); _ROLE=re.compile(r"^[a-z][a-z0-9_]{0,63}$")
PHASES=frozenset({"intent","storage_preflight","upload","provider_create","poll","output_download","artifact_validate","staging","promotion","ledger_commit","recover","delete"})
TERMINAL=frozenset({"active","ready","cancelled","failed","deleted","unknown"})
_FORBIDDEN_KEYS=("api_key","apikey","secret","token","authorization","filename","file_name","filepath","file_path","signed_url","download_url","output_url","source_path","raw_audio","audio_bytes","provider_task_id","provider_asset_id","idempotency_key","logical_job_id")
_FORBIDDEN_VALUES=("http://","https://","file://","bearer ","-----begin ","x-amz-signature=","x-amz-credential=","token=","api_key=","apikey=")

class ObservabilityError(RuntimeError):
    def __init__(self,code:str,*,retryable:bool=False): self.code=code; self.retryable=retryable; super().__init__(code)

@dataclass
class PhaseAggregate:
    attempts:int=0; retry_count:int=0; elapsed_milliseconds:int=0; bytes_transferred:int=0
    failure_count:int=0; last_error_code:str|None=None

@dataclass
class ArtifactEvidence:
    role:str; sha256:str; byte_count:int

@dataclass
class EvidenceRecord:
    job_ref_hash:str; profile_id:str; target_count:int; provider_kind:str; model_name:str; model_version:str
    currency:str; estimated_cost:str; actual_cost:str|None; duration_milliseconds:int; source_bytes:int
    created_at_epoch:int; updated_at_epoch:int; terminal_state:str="active"; stable_error_code:str|None=None
    phase_stats:dict[str,PhaseAggregate]=field(default_factory=dict)
    artifacts:dict[str,ArtifactEvidence]=field(default_factory=dict)

def _job_ref(v):
    if not isinstance(v,str) or not _JOB.fullmatch(v): raise ObservabilityError("SEP_OBS_LOGICAL_JOB_ID_INVALID")
    return hashlib.sha256(("lane1-observability:"+v).encode()).hexdigest()
def _id(v,code):
    if not isinstance(v,str) or not _ID.fullmatch(v): raise ObservabilityError(code)
    return v
def _code(v):
    if not isinstance(v,str) or not _CODE.fullmatch(v): raise ObservabilityError("SEP_OBS_ERROR_CODE_INVALID")
    return v
def _nn(v,code):
    if isinstance(v,bool) or not isinstance(v,int) or v<0: raise ObservabilityError(code)
    return v
def _pos(v,code):
    v=_nn(v,code)
    if v<=0: raise ObservabilityError(code)
    return v
def _money(v,code):
    try:
        d=Decimal(str(v))
        if not d.is_finite() or d<0: raise InvalidOperation
        d=d.quantize(Decimal("0.000001")).normalize()
    except (InvalidOperation,ValueError,TypeError) as e: raise ObservabilityError(code) from e
    s=format(d,"f"); return "0" if s in {"","-0"} else s
def _phase(v):
    if v not in PHASES: raise ObservabilityError("SEP_OBS_PHASE_INVALID")
    return v

def _validate(r:EvidenceRecord):
    if not _SHA.fullmatch(r.job_ref_hash): raise ObservabilityError("SEP_OBS_JOB_REF_INVALID")
    _id(r.profile_id,"SEP_OBS_PROFILE_INVALID"); _pos(r.target_count,"SEP_OBS_TARGET_COUNT_INVALID")
    _id(r.provider_kind,"SEP_OBS_PROVIDER_INVALID"); _id(r.model_name,"SEP_OBS_MODEL_INVALID"); _id(r.model_version,"SEP_OBS_MODEL_VERSION_INVALID")
    if not _CUR.fullmatch(r.currency): raise ObservabilityError("SEP_OBS_CURRENCY_INVALID")
    _money(r.estimated_cost,"SEP_OBS_ESTIMATED_COST_INVALID")
    if r.actual_cost is not None: _money(r.actual_cost,"SEP_OBS_ACTUAL_COST_INVALID")
    _pos(r.duration_milliseconds,"SEP_OBS_DURATION_INVALID"); _pos(r.source_bytes,"SEP_OBS_SOURCE_BYTES_INVALID")
    _pos(r.created_at_epoch,"SEP_OBS_EPOCH_INVALID"); _pos(r.updated_at_epoch,"SEP_OBS_EPOCH_INVALID")
    if r.updated_at_epoch<r.created_at_epoch: raise ObservabilityError("SEP_OBS_EPOCH_ORDER_INVALID")
    if r.terminal_state not in TERMINAL: raise ObservabilityError("SEP_OBS_TERMINAL_STATE_INVALID")
    if r.stable_error_code is not None: _code(r.stable_error_code)
    if set(r.phase_stats)-PHASES: raise ObservabilityError("SEP_OBS_PHASE_INVALID")
    for k,s in r.phase_stats.items():
        _phase(k)
        for v in (s.attempts,s.retry_count,s.elapsed_milliseconds,s.bytes_transferred,s.failure_count): _nn(v,"SEP_OBS_PHASE_METRIC_INVALID")
        if s.retry_count>s.attempts: raise ObservabilityError("SEP_OBS_RETRY_COUNT_INVALID")
        if s.failure_count>s.attempts: raise ObservabilityError("SEP_OBS_FAILURE_COUNT_INVALID")
        if s.last_error_code is not None: _code(s.last_error_code)
    if len(r.artifacts)>64: raise ObservabilityError("SEP_OBS_ARTIFACT_COUNT_INVALID")
    for role,a in r.artifacts.items():
        if not _ROLE.fullmatch(role) or a.role!=role: raise ObservabilityError("SEP_OBS_ARTIFACT_ROLE_INVALID")
        if not _SHA.fullmatch(a.sha256): raise ObservabilityError("SEP_OBS_ARTIFACT_HASH_INVALID")
        _pos(a.byte_count,"SEP_OBS_ARTIFACT_BYTES_INVALID")

def assert_privacy_safe_payload(payload:Any)->None:
    def walk(v):
        if isinstance(v,dict):
            for k,x in v.items():
                if not isinstance(k,str): raise ObservabilityError("SEP_OBS_PRIVACY_KEY_INVALID")
                if any(p in k.lower() for p in _FORBIDDEN_KEYS): raise ObservabilityError("SEP_OBS_PRIVACY_FORBIDDEN_KEY")
                walk(x)
        elif isinstance(v,list):
            for x in v: walk(x)
        elif isinstance(v,str):
            q=v.lower()
            if any(p in q for p in _FORBIDDEN_VALUES) or "\n" in v or "\r" in v: raise ObservabilityError("SEP_OBS_PRIVACY_FORBIDDEN_VALUE")
        elif v is None or isinstance(v,(int,float,bool)):
            if isinstance(v,float) and not math.isfinite(v): raise ObservabilityError("SEP_OBS_PRIVACY_NONFINITE_VALUE")
        else: raise ObservabilityError("SEP_OBS_PRIVACY_VALUE_TYPE_FORBIDDEN")
    walk(payload)

class AtomicObservabilityStore:
    def __init__(self,path):
        self.path=Path(path); self.path.parent.mkdir(parents=True,exist_ok=True); self.lock_path=self.path.with_suffix(self.path.suffix+".lock")
    @contextmanager
    def locked(self):
        with self.lock_path.open("a+b") as h:
            try:
                import fcntl; fcntl.flock(h.fileno(),fcntl.LOCK_EX)
            except ImportError as e: raise ObservabilityError("SEP_OBS_LOCK_UNAVAILABLE",retryable=True) from e
            try: yield self._load()
            finally: fcntl.flock(h.fileno(),fcntl.LOCK_UN)
    def _load(self):
        if not self.path.exists(): return {}
        try: raw=json.loads(self.path.read_text())
        except (OSError,UnicodeDecodeError,json.JSONDecodeError) as e: raise ObservabilityError("SEP_OBS_STORE_CORRUPT") from e
        if not isinstance(raw,dict) or raw.get("schema_version")!=SCHEMA_VERSION: raise ObservabilityError("SEP_OBS_STORE_SCHEMA_INVALID")
        jobs=raw.get("jobs")
        if not isinstance(jobs,dict): raise ObservabilityError("SEP_OBS_STORE_JOBS_INVALID")
        out={}
        try:
            for key,val0 in jobs.items():
                if not isinstance(key,str) or not isinstance(val0,dict): raise TypeError
                val=dict(val0); ps=val.pop("phase_stats",{}); arts=val.pop("artifacts",{})
                r=EvidenceRecord(**val,phase_stats={k:PhaseAggregate(**v) for k,v in ps.items()},artifacts={k:ArtifactEvidence(**v) for k,v in arts.items()})
                if r.job_ref_hash!=key: raise ValueError
                _validate(r); out[key]=r
        except (TypeError,ValueError,KeyError,ObservabilityError) as e: raise ObservabilityError("SEP_OBS_STORE_RECORD_INVALID") from e
        return out
    def save(self,records):
        jobs={}
        for key,r in sorted(records.items()):
            _validate(r)
            if key!=r.job_ref_hash: raise ObservabilityError("SEP_OBS_STORE_KEY_MISMATCH")
            jobs[key]=asdict(r)
        payload={"schema_version":SCHEMA_VERSION,"jobs":jobs}; assert_privacy_safe_payload(payload)
        tmp=self.path.with_name(self.path.name+".tmp")
        try:
            with tmp.open("w") as h: h.write(json.dumps(payload,indent=2,sort_keys=True)+"\n"); h.flush(); os.fsync(h.fileno())
            os.replace(tmp,self.path)
        except OSError as e:
            try: tmp.unlink(missing_ok=True)
            except OSError: pass
            raise ObservabilityError("SEP_OBS_STORE_WRITE_FAILED",retryable=True) from e

class PrivacySafeObservability:
    def __init__(self,path,*,now_epoch=None): self.store=AtomicObservabilityStore(path); self.now_epoch=now_epoch or (lambda:int(__import__("time").time()))
    def register_job(self,*,logical_job_id,profile_id,target_count,provider_kind,model_name,model_version,currency,estimated_cost,duration_milliseconds,source_bytes):
        ref=_job_ref(logical_job_id); now=_pos(self.now_epoch(),"SEP_OBS_EPOCH_INVALID")
        c=EvidenceRecord(ref,_id(profile_id,"SEP_OBS_PROFILE_INVALID"),_pos(target_count,"SEP_OBS_TARGET_COUNT_INVALID"),_id(provider_kind,"SEP_OBS_PROVIDER_INVALID"),_id(model_name,"SEP_OBS_MODEL_INVALID"),_id(model_version,"SEP_OBS_MODEL_VERSION_INVALID"),currency,_money(estimated_cost,"SEP_OBS_ESTIMATED_COST_INVALID"),None,_pos(duration_milliseconds,"SEP_OBS_DURATION_INVALID"),_pos(source_bytes,"SEP_OBS_SOURCE_BYTES_INVALID"),now,now)
        _validate(c)
        with self.store.locked() as rs:
            old=rs.get(ref)
            if old:
                if self._identity(old)!=self._identity(c): raise ObservabilityError("SEP_OBS_REGISTRATION_CONFLICT")
                return old
            rs[ref]=c; self.store.save(rs); return c
    def record_phase(self,logical_job_id,*,phase,elapsed_milliseconds,bytes_transferred=0,retry_count_delta=0,failed=False,stable_error_code=None):
        phase=_phase(phase); elapsed=_nn(elapsed_milliseconds,"SEP_OBS_PHASE_METRIC_INVALID"); b=_nn(bytes_transferred,"SEP_OBS_PHASE_METRIC_INVALID"); rd=_nn(retry_count_delta,"SEP_OBS_PHASE_METRIC_INVALID")
        if failed and stable_error_code is None: raise ObservabilityError("SEP_OBS_FAILED_PHASE_ERROR_REQUIRED")
        if stable_error_code is not None: stable_error_code=_code(stable_error_code)
        with self.store.locked() as rs:
            r=self._require(rs,logical_job_id); s=r.phase_stats.get(phase) or PhaseAggregate()
            s.attempts+=1; s.retry_count+=rd; s.elapsed_milliseconds+=elapsed; s.bytes_transferred+=b
            if failed: s.failure_count+=1; s.last_error_code=stable_error_code; r.stable_error_code=stable_error_code
            elif stable_error_code is not None: s.last_error_code=stable_error_code
            if s.retry_count>s.attempts: raise ObservabilityError("SEP_OBS_RETRY_COUNT_INVALID")
            r.phase_stats[phase]=s; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs); return r
    def record_cost_actual(self,logical_job_id,*,actual_cost):
        amt=_money(actual_cost,"SEP_OBS_ACTUAL_COST_INVALID")
        with self.store.locked() as rs:
            r=self._require(rs,logical_job_id)
            if r.actual_cost not in {None,amt}: raise ObservabilityError("SEP_OBS_ACTUAL_COST_CONFLICT")
            r.actual_cost=amt; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs); return r
    def record_artifact(self,logical_job_id,*,role,sha256,byte_count):
        if not isinstance(role,str) or not _ROLE.fullmatch(role): raise ObservabilityError("SEP_OBS_ARTIFACT_ROLE_INVALID")
        if not isinstance(sha256,str) or not _SHA.fullmatch(sha256.lower()): raise ObservabilityError("SEP_OBS_ARTIFACT_HASH_INVALID")
        c=ArtifactEvidence(role,sha256.lower(),_pos(byte_count,"SEP_OBS_ARTIFACT_BYTES_INVALID"))
        with self.store.locked() as rs:
            r=self._require(rs,logical_job_id); old=r.artifacts.get(role)
            if old is not None and old!=c: raise ObservabilityError("SEP_OBS_ARTIFACT_CONFLICT")
            r.artifacts[role]=c; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs); return r
    def finalize(self,logical_job_id,*,terminal_state,stable_error_code=None):
        if terminal_state not in TERMINAL-{"active"}: raise ObservabilityError("SEP_OBS_TERMINAL_STATE_INVALID")
        if terminal_state in {"failed","unknown"} and stable_error_code is None: raise ObservabilityError("SEP_OBS_TERMINAL_ERROR_REQUIRED")
        if stable_error_code is not None: stable_error_code=_code(stable_error_code)
        with self.store.locked() as rs:
            r=self._require(rs,logical_job_id)
            if r.terminal_state not in {"active",terminal_state}: raise ObservabilityError("SEP_OBS_TERMINAL_STATE_CONFLICT")
            r.terminal_state=terminal_state; r.stable_error_code=stable_error_code; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs); return r
    def evidence(self,logical_job_id):
        with self.store.locked() as rs:
            r=self._require(rs,logical_job_id); p={"schema_version":SCHEMA_VERSION,"parity_state":"NON_PARITY_EVIDENCE_ONLY",**asdict(r)}; assert_privacy_safe_payload(p); return p
    def capture_long_track_summary(self,logical_job_id,telemetry):
        r=self._get(logical_job_id)
        um=_nn(getattr(telemetry,"upload_milliseconds",0),"SEP_OBS_PHASE_METRIC_INVALID"); ub=_nn(getattr(telemetry,"upload_bytes",0),"SEP_OBS_PHASE_METRIC_INVALID")
        dm=_nn(getattr(telemetry,"download_milliseconds",0),"SEP_OBS_PHASE_METRIC_INVALID"); db=_nn(getattr(telemetry,"download_bytes",0),"SEP_OBS_PHASE_METRIC_INVALID")
        if um or ub: r=self.record_phase(logical_job_id,phase="upload",elapsed_milliseconds=um,bytes_transferred=ub)
        if dm or db: r=self.record_phase(logical_job_id,phase="output_download",elapsed_milliseconds=dm,bytes_transferred=db)
        code=getattr(telemetry,"stable_error_code",None)
        if code is not None:
            code=_code(code)
            with self.store.locked() as rs: r=self._require(rs,logical_job_id); r.stable_error_code=code; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs)
        return r
    def capture_cost_evidence(self,logical_job_id,evidence):
        if not isinstance(evidence,dict): raise ObservabilityError("SEP_OBS_COST_EVIDENCE_INVALID")
        return self.record_cost_actual(logical_job_id,actual_cost=evidence["actual_cost"]) if evidence.get("actual_cost") is not None else self._get(logical_job_id)
    def capture_fault(self,logical_job_id,disposition,*,phase,elapsed_milliseconds=0):
        return self.record_phase(logical_job_id,phase=phase,elapsed_milliseconds=elapsed_milliseconds,failed=True,stable_error_code=_code(getattr(disposition,"stable_error_code",None)))
    def capture_orchestrator_record(self,logical_job_id,record):
        r=self._get(logical_job_id); code=getattr(record,"stable_error_code",None)
        if code is not None:
            code=_code(code)
            with self.store.locked() as rs: r=self._require(rs,logical_job_id); r.stable_error_code=code; r.updated_at_epoch=self._now(r.updated_at_epoch); self.store.save(rs)
        outputs=getattr(record,"outputs",()) or ()
        if not isinstance(outputs,(list,tuple)): raise ObservabilityError("SEP_OBS_OUTPUT_EVIDENCE_INVALID")
        for x in outputs:
            if not isinstance(x,dict): raise ObservabilityError("SEP_OBS_OUTPUT_EVIDENCE_INVALID")
            r=self.record_artifact(logical_job_id,role=x.get("model"),sha256=x.get("sha256"),byte_count=x.get("bytes"))
        return r
    @staticmethod
    def machine_schema():
        return {"schema_version":1,"record":{"job_ref_hash":"sha256","profile_id":"safe_identifier","target_count":"positive_integer","provider_kind":"safe_identifier","model_name":"safe_identifier","model_version":"safe_identifier","currency":"3_uppercase","estimated_cost":"nonnegative_decimal_string","actual_cost":"nonnegative_decimal_string|null","duration_milliseconds":"positive_integer","source_bytes":"positive_integer","terminal_state":sorted(TERMINAL),"stable_error_code":"stable_code|null","phase_stats":{"keys":sorted(PHASES),"metrics":["attempts","retry_count","elapsed_milliseconds","bytes_transferred","failure_count","last_error_code"]},"artifacts":{"key":"canonical_role","fields":["role","sha256","byte_count"],"max_items":64}},"forbidden":{"arbitrary_metadata":True,"api_key_or_secret":True,"raw_audio_or_bytes":True,"user_filename_or_path":True,"signed_or_download_url":True,"raw_provider_operational_ids":True,"raw_idempotency_key":True,"free_text_error_message":True},"parity_state":"NON_PARITY_EVIDENCE_ONLY"}
    @staticmethod
    def _identity(r): return (r.profile_id,r.target_count,r.provider_kind,r.model_name,r.model_version,r.currency,r.estimated_cost,r.duration_milliseconds,r.source_bytes)
    def _require(self,rs,job):
        ref=_job_ref(job)
        if ref not in rs: raise ObservabilityError("SEP_OBS_RECORD_NOT_FOUND")
        return rs[ref]
    def _get(self,job):
        with self.store.locked() as rs: return self._require(rs,job)
    def _now(self,previous): return max(previous,_pos(self.now_epoch(),"SEP_OBS_EPOCH_INVALID"))
