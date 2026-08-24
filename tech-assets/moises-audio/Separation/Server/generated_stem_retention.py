"""L1-A24 generated-stem retention/delete/refund/orphan recovery (NON-PARITY)."""
from __future__ import annotations
import hashlib, json, os, re, time
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Callable

SCHEMA_VERSION=1
TOOL_VERSION='L1-A24-v1'
EVIDENCE_STATE='NON_PARITY_EVIDENCE_ONLY'
HEX64=re.compile(r'^[0-9a-f]{64}$')
ID32=re.compile(r'^[0-9a-f]{32}$')
SAFE=re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$')
DELETE_REASONS={'USER_DELETE','PROJECT_DELETE','CANCEL_CLEANUP','SUPERSEDED_RETENTION','ORPHAN_ABANDONED'}
RUNTIME_RECEIPTS={'accepted','confirmed','not_found'}

class GeneratedRetentionError(RuntimeError):
    def __init__(self,code,message='generated stem retention failure',retryable=False):
        self.code=code;self.message=message;self.retryable=retryable;super().__init__(f'{code}: {message}')
def fail(code,msg='generated stem retention failure',retryable=False): raise GeneratedRetentionError(code,msg,retryable)
def _sha(v,f):
    if not isinstance(v,str): fail('GEN_RET_SHA_INVALID',f)
    x=v.strip().lower().removeprefix('sha256:')
    if not HEX64.fullmatch(x): fail('GEN_RET_SHA_INVALID',f)
    return x
def _safe(v,f):
    if not isinstance(v,str) or not SAFE.fullmatch(v.strip()): fail('GEN_RET_SAFE_ID_INVALID',f)
    return v.strip()
def _int(v,f,lo=0):
    if isinstance(v,bool) or not isinstance(v,int) or v<lo: fail('GEN_RET_INTEGER_INVALID',f)
    return v
def canonical_sha(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def generation_ref_hash(logical_generation_id):
    if not isinstance(logical_generation_id,str) or not ID32.fullmatch(logical_generation_id): fail('GEN_RET_LOGICAL_ID_INVALID')
    return hashlib.sha256(('l1-a21-generation-ref-v1:'+logical_generation_id).encode()).hexdigest()
def execution_ref_hash(execution_id):
    if not isinstance(execution_id,str) or not execution_id: fail('GEN_RET_EXECUTION_ID_INVALID')
    return hashlib.sha256(('l1-a21-execution-v1:'+execution_id).encode()).hexdigest()
def file_sha256(p,chunk=1024*1024):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        while True:
            b=f.read(chunk)
            if not b: break
            h.update(b)
    return h.hexdigest()
def _fsync_dir(p):
    fd=os.open(str(p),os.O_RDONLY)
    try: os.fsync(fd)
    finally: os.close(fd)
def _atomic_json(path,payload):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True);tmp=path.with_suffix(path.suffix+'.tmp')
    try:
        with tmp.open('w',encoding='utf-8') as f:
            json.dump(payload,f,sort_keys=True,separators=(',',':'));f.write('\n');f.flush();os.fsync(f.fileno())
        os.replace(tmp,path);_fsync_dir(path.parent)
    except OSError as e:
        tmp.unlink(missing_ok=True);raise GeneratedRetentionError('GEN_RET_ATOMIC_WRITE_FAILED',retryable=True) from e

def _load_json(path,code):
    try:return json.loads(Path(path).read_text(encoding='utf-8'))
    except Exception as e: raise GeneratedRetentionError(code) from e

@dataclass
class VariantRetentionRecord:
    record_key:str
    project_ref_hash:str
    role:str
    generation_ref_hash:str
    variant_index:int
    artifact_sha256:str
    mix_ready_receipt_sha256:str
    manifest_sha256:str
    registered_at_epoch:int
    last_active_at_epoch:int|None=None
    superseded_at_epoch:int|None=None
    delete_requested:bool=False
    delete_reason:str|None=None
    delete_requested_at_epoch:int|None=None
    active_pointer_removed:bool=False
    manifest_removed:bool=False
    association_delete_confirmed:bool=False
    physical_artifact_state:str='not_attempted'
    runtime_delete_state:str='not_requested'
    refund_state:str='not_checked'
    refund_evidence_sha256:str|None=None
    runtime_erasure_evidence_sha256:str|None=None
    abandonment_evidence_sha256:str|None=None

    def validate(self):
        if self.record_key!=f'{self.generation_ref_hash}.v{self.variant_index}': fail('GEN_RET_RECORD_KEY_INVALID')
        for f in ('project_ref_hash','generation_ref_hash','artifact_sha256','mix_ready_receipt_sha256','manifest_sha256'):_sha(getattr(self,f),f)
        _safe(self.role,'role');_int(self.variant_index,'variant_index');_int(self.registered_at_epoch,'registered_at_epoch',1)
        if self.last_active_at_epoch is not None:_int(self.last_active_at_epoch,'last_active_at_epoch',1)
        if self.superseded_at_epoch is not None:_int(self.superseded_at_epoch,'superseded_at_epoch',1)
        if self.delete_requested_at_epoch is not None:_int(self.delete_requested_at_epoch,'delete_requested_at_epoch',1)
        if self.delete_reason is not None and self.delete_reason not in DELETE_REASONS:fail('GEN_RET_DELETE_REASON_INVALID')
        if self.physical_artifact_state not in {'not_attempted','confirmed_erased','retained_shared_reference','missing_before_delete','unknown_after_error'}:fail('GEN_RET_PHYSICAL_STATE_INVALID')
        if self.runtime_delete_state not in {'not_requested','not_applicable','unsupported','identifier_unavailable','accepted','confirmed','not_found','unknown_after_error','unknown_invalid_receipt'}:fail('GEN_RET_RUNTIME_DELETE_STATE_INVALID')
        if self.refund_state not in {'not_checked','released_no_charge','reserved_unsettled','not_eligible','eligible_not_requested','pending_authority','confirmed','state_unknown'}:fail('GEN_RET_REFUND_STATE_INVALID')
        if self.refund_evidence_sha256 is not None:_sha(self.refund_evidence_sha256,'refund_evidence_sha256')
        if self.runtime_erasure_evidence_sha256 is not None:_sha(self.runtime_erasure_evidence_sha256,'runtime_erasure_evidence_sha256')
        if self.abandonment_evidence_sha256 is not None:_sha(self.abandonment_evidence_sha256,'abandonment_evidence_sha256')

@dataclass
class OrphanObservation:
    artifact_sha256:str
    first_seen_epoch:int
    last_seen_epoch:int
    observations:int=1
    delete_intent_at_epoch:int|None=None
    def validate(self):
        _sha(self.artifact_sha256,'artifact_sha256');_int(self.first_seen_epoch,'first_seen_epoch',1);_int(self.last_seen_epoch,'last_seen_epoch',1);_int(self.observations,'observations',1)
        if self.delete_intent_at_epoch is not None:_int(self.delete_intent_at_epoch,'delete_intent_at_epoch',1)

class AtomicRetentionRegistry:
    def __init__(self,path,policy_sha256):self.path=Path(path);self.path.parent.mkdir(parents=True,exist_ok=True);self.lock_path=self.path.with_suffix(self.path.suffix+'.lock');self.policy_sha256=_sha(policy_sha256,'policy_sha256')
    @contextmanager
    def locked(self):
        with self.lock_path.open('a+b') as h:
            try:
                import fcntl;fcntl.flock(h.fileno(),fcntl.LOCK_EX)
            except ImportError as e:raise GeneratedRetentionError('GEN_RET_REGISTRY_LOCK_UNAVAILABLE') from e
            try:yield self.load()
            finally:fcntl.flock(h.fileno(),fcntl.LOCK_UN)
    def load(self):
        if not self.path.exists():return {'records':{},'orphans':{}}
        raw=_load_json(self.path,'GEN_RET_REGISTRY_CORRUPT')
        if raw.get('schema_version')!=1 or not isinstance(raw.get('records'),dict) or not isinstance(raw.get('orphans'),dict):fail('GEN_RET_REGISTRY_SCHEMA_INVALID')
        if raw.get('policy_sha256')!=self.policy_sha256:fail('GEN_RET_POLICY_MISMATCH')
        recs={};orph={}
        try:
            for k,v in raw['records'].items():
                r=VariantRetentionRecord(**v);r.validate()
                if k!=r.record_key:raise ValueError('key')
                recs[k]=r
            for k,v in raw['orphans'].items():
                o=OrphanObservation(**v);o.validate()
                if k!=o.artifact_sha256:raise ValueError('orphan key')
                orph[k]=o
        except Exception as e:
            if isinstance(e,GeneratedRetentionError):raise
            raise GeneratedRetentionError('GEN_RET_REGISTRY_RECORD_INVALID') from e
        return {'records':recs,'orphans':orph}
    def save(self,state):
        for r in state['records'].values():r.validate()
        for o in state['orphans'].values():o.validate()
        _atomic_json(self.path,{'schema_version':1,'policy_sha256':self.policy_sha256,'records':{k:asdict(v) for k,v in sorted(state['records'].items())},'orphans':{k:asdict(v) for k,v in sorted(state['orphans'].items())}})

class GeneratedStemRetentionService:
    def __init__(self,*,store_root,registry_path=None,now_epoch:Callable[[],int]|None=None,orphan_grace_seconds=3600,superseded_grace_seconds=86400):
        self.root=Path(store_root);self.objects=self.root/'objects';self.manifests=self.root/'manifests';self.active=self.root/'active';self.store_lock=self.root/'.lock'
        for p in (self.objects,self.manifests,self.active):p.mkdir(parents=True,exist_ok=True)
        self.orphan_grace_seconds=_int(orphan_grace_seconds,'orphan_grace_seconds',1);self.superseded_grace_seconds=_int(superseded_grace_seconds,'superseded_grace_seconds',1)
        self.retention_policy_sha256=canonical_sha({'domain':'l1-a24-retention-policy-v1','orphan_grace_seconds':self.orphan_grace_seconds,'superseded_grace_seconds':self.superseded_grace_seconds})
        self.registry=AtomicRetentionRegistry(registry_path or self.root/'retention'/'registry.json',self.retention_policy_sha256)
        self.now=now_epoch or (lambda:int(time.time()))
    @contextmanager
    def _store_locked(self):
        self.root.mkdir(parents=True,exist_ok=True)
        with self.store_lock.open('a+b') as h:
            try:
                import fcntl;fcntl.flock(h.fileno(),fcntl.LOCK_EX)
            except ImportError as e:raise GeneratedRetentionError('GEN_RET_STORE_LOCK_UNAVAILABLE') from e
            try:yield
            finally:fcntl.flock(h.fileno(),fcntl.LOCK_UN)
    def _manifest_path(self,generation_hash,variant):return self.manifests/f'{_sha(generation_hash,"generation_ref_hash")}.v{_int(variant,"variant_index")}.json'
    def _active_path(self,project_hash,role):return self.active/f'{_sha(project_hash,"project_ref_hash")}.{_safe(role,"role").lower()}.json'
    def _load_manifest(self,path):
        raw=_load_json(path,'GEN_RET_MANIFEST_CORRUPT')
        req=('project_ref_hash','role','generation_ref_hash','variant_index','artifact_sha256','mix_ready_receipt_sha256')
        if any(k not in raw for k in req):fail('GEN_RET_MANIFEST_SCHEMA_INVALID')
        for f in ('project_ref_hash','generation_ref_hash','artifact_sha256','mix_ready_receipt_sha256'):_sha(raw[f],f)
        _safe(raw['role'],'role');_int(raw['variant_index'],'variant_index')
        return raw
    def register_variant(self,*,generation_ref_hash_value,variant_index):
        gh=_sha(generation_ref_hash_value,'generation_ref_hash');vi=_int(variant_index,'variant_index');mp=self._manifest_path(gh,vi)
        with self._store_locked():
            if not mp.is_file() or mp.is_symlink():fail('GEN_RET_MANIFEST_MISSING')
            raw=self._load_manifest(mp)
            if raw['generation_ref_hash']!=gh or raw['variant_index']!=vi:fail('GEN_RET_MANIFEST_IDENTITY_MISMATCH')
            msha=file_sha256(mp);now=self.now();key=f'{gh}.v{vi}'
            with self.registry.locked() as st:
                old=st['records'].get(key)
                rec=VariantRetentionRecord(key,raw['project_ref_hash'],raw['role'].lower(),gh,vi,raw['artifact_sha256'],raw['mix_ready_receipt_sha256'],msha,now)
                ap=self._active_path(rec.project_ref_hash,rec.role)
                if ap.exists():
                    if ap.is_symlink():fail('GEN_RET_ACTIVE_SYMLINK_FORBIDDEN')
                    a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT')
                    if a.get('generation_ref_hash')==gh and a.get('variant_index')==vi:
                        rec.last_active_at_epoch=now
                        for other in st['records'].values():
                            if other.record_key!=key and other.project_ref_hash==rec.project_ref_hash and other.role==rec.role and other.superseded_at_epoch is None and not other.delete_requested:
                                other.superseded_at_epoch=now
                if old:
                    immutable=('project_ref_hash','role','generation_ref_hash','variant_index','artifact_sha256','mix_ready_receipt_sha256','manifest_sha256')
                    if any(getattr(old,f)!=getattr(rec,f) for f in immutable):fail('GEN_RET_REGISTRATION_CONFLICT')
                    if rec.last_active_at_epoch is not None:old.last_active_at_epoch=rec.last_active_at_epoch
                    self.registry.save(st);return old
                st['records'][key]=rec;self.registry.save(st);return rec
    def _find_a21_record(self,ledger_path,generation_hash):
        raw=_load_json(ledger_path,'GEN_RET_A21_LEDGER_CORRUPT')
        if raw.get('schema_version')!=1 or not isinstance(raw.get('records'),dict):fail('GEN_RET_A21_LEDGER_SCHEMA_INVALID')
        matches=[]
        for logical,v in raw['records'].items():
            if generation_ref_hash(logical)==generation_hash:matches.append(v)
        if len(matches)>1:fail('GEN_RET_A21_DUPLICATE_GENERATION')
        return matches[0] if matches else None
    def sync_refund_from_a21(self,*,generation_ref_hash_value,variant_index,a21_ledger_path):
        key=f'{_sha(generation_ref_hash_value,"generation_ref_hash")}.v{_int(variant_index,"variant_index")}'
        with self.registry.locked() as st:
            rec=st['records'].get(key)
            if not rec:fail('GEN_RET_RECORD_NOT_FOUND')
            a=self._find_a21_record(a21_ledger_path,rec.generation_ref_hash)
            if a is None:rec.refund_state='state_unknown';rec.refund_evidence_sha256=None
            else:
                cs=a.get('credit_state');cancel=bool(a.get('logical_cancelled'))
                if cs=='released':rec.refund_state='released_no_charge';rec.refund_evidence_sha256=None
                elif cs=='reserved':rec.refund_state='reserved_unsettled';rec.refund_evidence_sha256=None
                elif cs=='refunded':
                    ev=a.get('refund_evidence_sha256');_sha(ev,'refund_evidence_sha256');rec.refund_state='confirmed';rec.refund_evidence_sha256=ev
                elif cs=='refund_pending':rec.refund_state='pending_authority';rec.refund_evidence_sha256=None
                elif cs=='committed' and cancel:rec.refund_state='eligible_not_requested';rec.refund_evidence_sha256=None
                elif cs=='committed':rec.refund_state='not_eligible';rec.refund_evidence_sha256=None
                else:rec.refund_state='state_unknown';rec.refund_evidence_sha256=None
            self.registry.save(st);return rec
    def _find_execution(self,binding_path,generation_hash):
        raw=_load_json(binding_path,'GEN_RET_BINDING_STORE_CORRUPT')
        if raw.get('schema_version')!=1 or not isinstance(raw.get('records'),dict):fail('GEN_RET_BINDING_STORE_SCHEMA_INVALID')
        matches=[]
        for logical,v in raw['records'].items():
            if generation_ref_hash(logical)==generation_hash:matches.append(v)
        if len(matches)>1:fail('GEN_RET_BINDING_DUPLICATE_GENERATION')
        return matches[0] if matches else None
    def _remove_active_if_target(self,rec,reason):
        ap=self._active_path(rec.project_ref_hash,rec.role)
        if not ap.exists():return False
        if ap.is_symlink():fail('GEN_RET_ACTIVE_SYMLINK_FORBIDDEN')
        a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT')
        is_target=a.get('generation_ref_hash')==rec.generation_ref_hash and a.get('variant_index')==rec.variant_index
        if not is_target:return False
        if reason in {'SUPERSEDED_RETENTION','ORPHAN_ABANDONED'}:fail('GEN_RET_ACTIVE_DELETE_FORBIDDEN')
        ap.unlink();_fsync_dir(self.active);return True
    def _artifact_references(self,artifact_sha):
        refs=[]
        for mp in self.manifests.glob('*.json'):
            if mp.is_symlink():fail('GEN_RET_MANIFEST_SYMLINK_FORBIDDEN')
            raw=self._load_manifest(mp)
            if raw['artifact_sha256']==artifact_sha:refs.append('manifest:'+mp.name)
        for ap in self.active.glob('*.json'):
            if ap.is_symlink():fail('GEN_RET_ACTIVE_SYMLINK_FORBIDDEN')
            a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT')
            if a.get('artifact_sha256')==artifact_sha:refs.append('active:'+ap.name)
        return refs
    def request_delete(self,*,generation_ref_hash_value,variant_index,reason,runtime_delete:Callable[[str],str]|None=None,binding_store_path=None):
        gh=_sha(generation_ref_hash_value,'generation_ref_hash');vi=_int(variant_index,'variant_index');reason=_safe(reason,'reason').upper()
        if reason not in DELETE_REASONS:fail('GEN_RET_DELETE_REASON_INVALID')
        key=f'{gh}.v{vi}';now=self.now()
        with self.registry.locked() as st:
            rec=st['records'].get(key)
            if not rec:fail('GEN_RET_RECORD_NOT_FOUND')
            if not rec.delete_requested:
                rec.delete_requested=True;rec.delete_reason=reason;rec.delete_requested_at_epoch=now;self.registry.save(st)
            elif rec.delete_reason!=reason:fail('GEN_RET_DELETE_REASON_CONFLICT')
        with self._store_locked():
            with self.registry.locked() as st:
                rec=st['records'][key]
                if self._remove_active_if_target(rec,reason):rec.active_pointer_removed=True;self.registry.save(st)
                mp=self._manifest_path(rec.generation_ref_hash,rec.variant_index)
                if mp.exists():
                    if mp.is_symlink():fail('GEN_RET_MANIFEST_SYMLINK_FORBIDDEN')
                    raw=self._load_manifest(mp)
                    if raw.get('artifact_sha256')!=rec.artifact_sha256 or file_sha256(mp)!=rec.manifest_sha256:fail('GEN_RET_MANIFEST_MUTATED')
                    mp.unlink();_fsync_dir(self.manifests);rec.manifest_removed=True;self.registry.save(st)
                else:rec.manifest_removed=True
                refs=self._artifact_references(rec.artifact_sha256)
                obj=self.objects/f'{rec.artifact_sha256}.wav'
                if refs:
                    rec.physical_artifact_state='retained_shared_reference'
                elif not obj.exists():rec.physical_artifact_state='missing_before_delete'
                else:
                    if obj.is_symlink():fail('GEN_RET_OBJECT_SYMLINK_FORBIDDEN')
                    if file_sha256(obj)!=rec.artifact_sha256:fail('GEN_RET_OBJECT_MUTATED')
                    obj.unlink();_fsync_dir(self.objects);rec.physical_artifact_state='confirmed_erased'
                ap=self._active_path(rec.project_ref_hash,rec.role)
                target_active=False
                if ap.exists():
                    a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT');target_active=a.get('generation_ref_hash')==rec.generation_ref_hash and a.get('variant_index')==rec.variant_index
                rec.association_delete_confirmed=(not target_active and not mp.exists())
                self.registry.save(st)
        if runtime_delete is not None:
            with self.registry.locked() as st:
                prior=st['records'][key].runtime_delete_state
            if prior=='not_requested':
                if binding_store_path is None:state='identifier_unavailable'
                else:
                    b=self._find_execution(binding_store_path,gh)
                    if b is None:state='identifier_unavailable'
                    else:
                        execution_id=b.get('execution_id');expected=b.get('execution_ref_hash')
                        if execution_ref_hash(execution_id)!=expected:fail('GEN_RET_BINDING_IDENTITY_MISMATCH')
                        try:receipt=runtime_delete(execution_id)
                        except Exception:state='unknown_after_error'
                        else:state=receipt if receipt in RUNTIME_RECEIPTS else 'unknown_invalid_receipt'
                with self.registry.locked() as st:
                    st['records'][key].runtime_delete_state=state;self.registry.save(st)
        return self.snapshot(generation_ref_hash_value=gh,variant_index=vi)
    def request_project_delete(self,*,project_ref_hash_value):
        project=_sha(project_ref_hash_value,'project_ref_hash')
        with self._store_locked():
            with self.registry.locked() as st:
                registered={(r.generation_ref_hash,r.variant_index) for r in st['records'].values() if r.project_ref_hash==project}
            discovered=set()
            for mp in self.manifests.glob('*.json'):
                raw=self._load_manifest(mp)
                if raw['project_ref_hash']==project:discovered.add((raw['generation_ref_hash'],raw['variant_index']))
            missing=discovered-registered
            if missing:fail('GEN_RET_PROJECT_DELETE_UNREGISTERED_VARIANT')
            targets=sorted(registered)
        return tuple(self.request_delete(generation_ref_hash_value=gh,variant_index=vi,reason='PROJECT_DELETE') for gh,vi in targets)

    def reconcile_runtime_erasure(self,*,generation_ref_hash_value,variant_index,receipt,authority_evidence_sha256):
        key=f'{_sha(generation_ref_hash_value,"generation_ref_hash")}.v{_int(variant_index,"variant_index")}'
        ev=_sha(authority_evidence_sha256,'authority_evidence_sha256')
        if receipt not in {'confirmed','not_found'}:fail('GEN_RET_RUNTIME_RECONCILE_RECEIPT_INVALID')
        with self.registry.locked() as st:
            r=st['records'].get(key)
            if not r:fail('GEN_RET_RECORD_NOT_FOUND')
            if r.runtime_delete_state not in {'accepted','unknown_after_error','identifier_unavailable','unknown_invalid_receipt',receipt}:fail('GEN_RET_RUNTIME_RECONCILE_STATE_INVALID')
            r.runtime_delete_state=receipt;r.runtime_erasure_evidence_sha256=ev;self.registry.save(st);return r

    def mark_runtime_storage_not_applicable(self,*,generation_ref_hash_value,variant_index,authority_evidence_sha256):
        key=f'{_sha(generation_ref_hash_value,"generation_ref_hash")}.v{_int(variant_index,"variant_index")}'
        ev=_sha(authority_evidence_sha256,'authority_evidence_sha256')
        with self.registry.locked() as st:
            r=st['records'].get(key)
            if not r:fail('GEN_RET_RECORD_NOT_FOUND')
            if r.runtime_delete_state not in {'not_requested','not_applicable'}:fail('GEN_RET_RUNTIME_NOT_APPLICABLE_CONFLICT')
            r.runtime_delete_state='not_applicable';r.runtime_erasure_evidence_sha256=ev;self.registry.save(st);return r

    def observe_runtime_unsupported(self,*,generation_ref_hash_value,variant_index):
        key=f'{_sha(generation_ref_hash_value,"generation_ref_hash")}.v{_int(variant_index,"variant_index")}'
        with self.registry.locked() as st:
            r=st['records'].get(key)
            if not r:fail('GEN_RET_RECORD_NOT_FOUND')
            if r.runtime_delete_state=='not_requested':r.runtime_delete_state='unsupported'
            self.registry.save(st);return r
    def sweep_orphan_objects(self):
        now=self.now();deleted=[];observed=[]
        with self._store_locked():
            refs=set()
            for mp in self.manifests.glob('*.json'):
                if mp.is_symlink():fail('GEN_RET_MANIFEST_SYMLINK_FORBIDDEN')
                refs.add(self._load_manifest(mp)['artifact_sha256'])
            for ap in self.active.glob('*.json'):
                if ap.is_symlink():fail('GEN_RET_ACTIVE_SYMLINK_FORBIDDEN')
                a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT')
                ash=a.get('artifact_sha256')
                if isinstance(ash,str) and HEX64.fullmatch(ash):refs.add(ash)
                else:fail('GEN_RET_ACTIVE_POINTER_SCHEMA_INVALID')
            with self.registry.locked() as st:
                present=set()
                for obj in self.objects.glob('*.wav'):
                    if obj.is_symlink():fail('GEN_RET_OBJECT_SYMLINK_FORBIDDEN')
                    sha=obj.stem
                    if not HEX64.fullmatch(sha):continue
                    if sha in refs:
                        st['orphans'].pop(sha,None);continue
                    if file_sha256(obj)!=sha:fail('GEN_RET_OBJECT_MUTATED')
                    present.add(sha);observed.append(sha)
                    old=st['orphans'].get(sha)
                    if old is None:st['orphans'][sha]=OrphanObservation(sha,now,now,1,None)
                    else:
                        old.last_seen_epoch=now;old.observations+=1
                        if old.observations>=2 and now-old.first_seen_epoch>=self.orphan_grace_seconds:
                            if old.delete_intent_at_epoch is None:
                                old.delete_intent_at_epoch=now;self.registry.save(st)
                            obj.unlink();_fsync_dir(self.objects);deleted.append(sha);st['orphans'].pop(sha,None)
                for sha in list(st['orphans']):
                    if sha not in present and not (self.objects/f'{sha}.wav').exists():st['orphans'].pop(sha,None)
                self.registry.save(st)
        return {'observed':tuple(sorted(observed)),'deleted':tuple(sorted(deleted))}
    def sweep_superseded(self):
        now=self.now()
        with self.registry.locked() as st:
            candidates=[(r.generation_ref_hash,r.variant_index) for r in st['records'].values() if r.superseded_at_epoch is not None and not r.delete_requested and now-r.superseded_at_epoch>=self.superseded_grace_seconds]
        deleted=[]
        for gh,vi in candidates:
            self.request_delete(generation_ref_hash_value=gh,variant_index=vi,reason='SUPERSEDED_RETENTION')
            deleted.append(f'{gh}.v{vi}')
        return tuple(sorted(deleted))

    def inactive_unregistered_manifests(self):
        with self._store_locked():
            active_keys=set()
            for ap in self.active.glob('*.json'):
                if ap.is_symlink():fail('GEN_RET_ACTIVE_SYMLINK_FORBIDDEN')
                a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT');active_keys.add(f"{a.get('generation_ref_hash')}.v{a.get('variant_index')}")
            with self.registry.locked() as st:registered=set(st['records'])
            out=[]
            for mp in self.manifests.glob('*.json'):
                raw=self._load_manifest(mp);key=f"{raw['generation_ref_hash']}.v{raw['variant_index']}"
                if key not in active_keys and key not in registered:out.append((key,file_sha256(mp)))
            return tuple(sorted(out))
    def adopt_abandoned_manifest(self,*,generation_ref_hash_value,variant_index,abandonment_evidence_sha256):
        ev=_sha(abandonment_evidence_sha256,'abandonment_evidence_sha256')
        rec=self.register_variant(generation_ref_hash_value=generation_ref_hash_value,variant_index=variant_index)
        ap=self._active_path(rec.project_ref_hash,rec.role)
        if ap.exists():
            a=_load_json(ap,'GEN_RET_ACTIVE_POINTER_CORRUPT')
            if a.get('generation_ref_hash')==rec.generation_ref_hash and a.get('variant_index')==rec.variant_index:fail('GEN_RET_ACTIVE_ABANDON_FORBIDDEN')
        with self.registry.locked() as st:
            st['records'][rec.record_key].abandonment_evidence_sha256=ev;self.registry.save(st)
        return self.request_delete(generation_ref_hash_value=rec.generation_ref_hash,variant_index=rec.variant_index,reason='ORPHAN_ABANDONED')
    def snapshot(self,*,generation_ref_hash_value,variant_index):
        key=f'{_sha(generation_ref_hash_value,"generation_ref_hash")}.v{_int(variant_index,"variant_index")}'
        with self.registry.locked() as st:
            r=st['records'].get(key)
            if not r:fail('GEN_RET_RECORD_NOT_FOUND')
            r.validate();runtime_erasure=(r.runtime_delete_state in {'confirmed','not_found','not_applicable'} and r.runtime_erasure_evidence_sha256 is not None)
            physical_erasure=r.physical_artifact_state in {'confirmed_erased','missing_before_delete'}
            return {
                'schema_version':1,'tool_version':TOOL_VERSION,'evidence_state':EVIDENCE_STATE,'retention_policy_sha256':self.retention_policy_sha256,
                'project_ref_hash':r.project_ref_hash,'role':r.role,'generation_ref_hash':r.generation_ref_hash,'variant_index':r.variant_index,
                'artifact_sha256':r.artifact_sha256,'mix_ready_receipt_sha256':r.mix_ready_receipt_sha256,
                'delete_requested':r.delete_requested,'delete_reason':r.delete_reason,'association_delete_confirmed':r.association_delete_confirmed,
                'physical_artifact_state':r.physical_artifact_state,'runtime_delete_state':r.runtime_delete_state,'runtime_erasure_confirmed':runtime_erasure,
                'refund_state':r.refund_state,'refund_evidence_sha256':r.refund_evidence_sha256,'runtime_erasure_evidence_sha256':r.runtime_erasure_evidence_sha256,
                'privacy_erasure_complete':bool(r.association_delete_confirmed and physical_erasure and runtime_erasure),
                'raw_logical_generation_id_emitted':False,'raw_execution_id_emitted':False,'path_emitted':False,'raw_audio_emitted':False,'parity_claim':'NONE'
            }
