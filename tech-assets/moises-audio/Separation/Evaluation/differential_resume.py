from __future__ import annotations
import hashlib, json, os, threading
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION=1; TOOL_VERSION='L1-A20-v1'; EVIDENCE_STATE='NON_PARITY_EVIDENCE_ONLY'; EXIT_EXTERNAL_INPUT_REQUIRED=3
STATES={'ACTIVE','WAITING_REFERENCE','WAITING_REVIEWER_ROSTER','WAITING_REVIEW','ACCEPTANCE_READY','COMPLETE'}
REASONS={'UNAVAILABLE','CONFLICT_OF_INTEREST','INVALID_REVIEW','COORDINATOR_CORRECTION'}

class ResumeError(ValueError):
    def __init__(self,code:str,message:str,*,exit_code:int=2): super().__init__(f'{code}: {message}'); self.code=code; self.message=message; self.exit_code=exit_code

def canon(v:Any)->bytes:
    try:return json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()
    except (TypeError,ValueError) as e: raise ResumeError('L1A20_CANONICAL_JSON_INVALID','value is not canonical JSON') from e

def sha_json(v:Any)->str:return hashlib.sha256(canon(v)).hexdigest()
def sha_file(p:Path)->str:
    h=hashlib.sha256()
    try:
        with p.open('rb') as f:
            for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    except OSError as e:raise ResumeError('L1A20_ARTIFACT_UNREADABLE','cannot hash evidence') from e
    return h.hexdigest()
def rel(root:Path,p:Path)->str:
    try:return p.resolve().relative_to(root.resolve()).as_posix()
    except ValueError as e:raise ResumeError('L1A20_ARTIFACT_OUTSIDE_ROOT','artifact escapes root') from e
def req(v:Any,f:str)->str:
    if not isinstance(v,str) or not v.strip():raise ResumeError('L1A20_SCHEMA_REQUIRED',f'{f} required')
    return v.strip()
def norm_sha(v:Any,f:str,none=False):
    if v is None and none:return None
    if not isinstance(v,str):raise ResumeError('L1A20_SHA_INVALID',f'{f} invalid')
    s=v.lower().removeprefix('sha256:')
    if len(s)!=64 or any(c not in '0123456789abcdef' for c in s):raise ResumeError('L1A20_SHA_INVALID',f'{f} invalid')
    return s

def semantic(config:Mapping[str,Any],root:Path,golden=None,toolchain:Sequence[Path]=()):
    cases=[]
    for c in config.get('cases',[]):
        fp=Path(c['fixture_path'])
        if not fp.is_file():raise ResumeError('L1A20_FIXTURE_MISSING',f"fixture missing {c.get('case_id')}")
        cases.append({'case_id':req(c.get('case_id'),'case_id'),'genre':req(c.get('genre'),'genre').lower(),'duration_bucket':req(c.get('duration_bucket'),'duration_bucket').lower(),'target_roles':sorted(req(x,'role').lower() for x in c.get('target_roles',[])),'fixture_manifest':rel(root,fp),'fixture_manifest_sha256':sha_file(fp),'project_run_manifest':rel(root,Path(c['project_run_path'])),'reference_run_manifest':rel(root,Path(c['reference_run_path']))})
    if not cases:raise ResumeError('L1A20_CASES_EMPTY','no cases')
    tc=[]
    for p in sorted((Path(x).resolve() for x in toolchain),key=lambda x:x.name):
        if not p.is_file():raise ResumeError('L1A20_TOOLCHAIN_MISSING',f'toolchain missing {p.name}')
        tc.append({'name':p.name,'sha256':sha_file(p)})
    return {'schema_version':1,'batch_id':req(config.get('batch_id'),'batch_id'),'purpose':req(config.get('purpose'),'purpose'),'command_template':list(config.get('command',[])),'max_attempts':int(config.get('max_attempts',0)),'timeout_seconds':float(config.get('timeout_seconds',0)),'credential_env_names':sorted(str(x) for x in config.get('credential_env_names',[])),'legal_gate':dict(config.get('legal_gate',{})),'acceptance_policy':dict(config.get('policy',{})),'golden_corpus_lock_sha256':norm_sha(golden,'golden',none=True),'toolchain':tc,'cases':sorted(cases,key=lambda x:x['case_id'])}

def aid(batch,case,stem,blind,reviewer,replaces=None):return sha_json({'d':'a20-review-v1','b':batch,'c':case,'s':stem,'x':blind,'r':reviewer,'replaces':replaces})
def idem_hash(batch,case):
    k='l1m04-'+hashlib.sha256(f'{batch}:{case}'.encode()).hexdigest()[:32]
    return hashlib.sha256(('a20-idem:'+k).encode()).hexdigest()

_LOCKS={}; _LG=threading.Lock()
def _lock_for(p:Path):
    with _LG:return _LOCKS.setdefault(str(p.resolve()),threading.RLock())

class DifferentialResumeLedger:
    def __init__(self,root:Path,out:Path,config:Mapping[str,Any],*,golden_corpus_lock_sha256=None,toolchain_paths:Sequence[Path]=()):
        self.root=root.resolve();self.output_dir=out.resolve();rel(self.root,self.output_dir);self.output_dir.mkdir(parents=True,exist_ok=True)
        self.path=self.output_dir/'differential-resume-ledger.json';self.lock_path=self.output_dir/'.differential-resume.lock';self.config=config
        self.semantic=semantic(config,self.root,golden_corpus_lock_sha256,toolchain_paths);self.batch_identity_sha256=sha_json({'d':'a20-batch-v1','s':self.semantic});self.policy_sha256=sha_json(self.semantic['acceptance_policy']);self._data=self._load()
    @contextmanager
    def _locked(self):
        with _lock_for(self.lock_path):
            h=self.lock_path.open('a+')
            try:
                try:import fcntl;fcntl.flock(h.fileno(),fcntl.LOCK_EX)
                except (ImportError,OSError):pass
                yield
            finally:
                try:import fcntl;fcntl.flock(h.fileno(),fcntl.LOCK_UN)
                except (ImportError,OSError):pass
                h.close()
    def _initial(self):
        cs={}
        for c in self.semantic['cases']:
            cid=c['case_id'];cs[cid]={'case_identity_sha256':sha_json({'d':'a20-case-v1','b':self.batch_identity_sha256,'c':c}),'fixture_manifest_sha256':c['fixture_manifest_sha256'],'idempotency_key_sha256':idem_hash(self.semantic['batch_id'],cid),'phase':'PENDING','project_source':None,'attempts':[],'artifacts':{}}
        return {'schema_version':1,'tool_version':TOOL_VERSION,'evidence_state':EVIDENCE_STATE,'batch_id':self.semantic['batch_id'],'batch_identity_sha256':self.batch_identity_sha256,'acceptance_policy_sha256':self.policy_sha256,'golden_corpus_lock_sha256':self.semantic['golden_corpus_lock_sha256'],'state':'ACTIVE','case_order':[c['case_id'] for c in self.semantic['cases']],'cases':cs,'global_artifacts':{},'review':{'roster_sha256':None,'assignments_sha256':None,'replacements_sha256':None,'scores_sha256':None,'active_assignment_sha256':None,'missing_assignment_ids':[]},'acceptance':None,'evidence_chain_sha256':None}
    def _write(self,d):
        t=self.path.with_name('.'+self.path.name+'.tmp')
        try:
            with t.open('w',encoding='utf-8') as f:json.dump(d,f,indent=2,sort_keys=True,ensure_ascii=False,allow_nan=False);f.write('\n');f.flush();os.fsync(f.fileno())
            os.replace(t,self.path)
        except OSError as e:
            try:t.unlink(missing_ok=True)
            except OSError:pass
            raise ResumeError('L1A20_LEDGER_WRITE_FAILED','cannot persist ledger') from e
    def _load(self):
        with self._locked():
            if not self.path.exists():d=self._initial();self._write(d);return d
            try:d=json.loads(self.path.read_text())
            except (OSError,json.JSONDecodeError) as e:raise ResumeError('L1A20_LEDGER_CORRUPT','cannot decode ledger') from e
            if d.get('schema_version')!=1 or d.get('tool_version')!=TOOL_VERSION:raise ResumeError('L1A20_LEDGER_SCHEMA_UNSUPPORTED','ledger schema mismatch')
            if d.get('batch_identity_sha256')!=self.batch_identity_sha256:raise ResumeError('L1A20_BATCH_IDENTITY_MISMATCH','batch semantics changed')
            if d.get('acceptance_policy_sha256')!=self.policy_sha256:raise ResumeError('L1A20_POLICY_IDENTITY_MISMATCH','policy changed')
            if d.get('state') not in STATES:raise ResumeError('L1A20_LEDGER_STATE_INVALID','bad state')
            return d
    def _save(self):
        with self._locked():self._write(self._data)
    @property
    def data(self):return self._data
    def set_state(self,s):
        if s not in STATES:raise ResumeError('L1A20_LEDGER_STATE_INVALID','bad state')
        if self._data['state']=='COMPLETE' and s!='COMPLETE':raise ResumeError('L1A20_COMPLETE_STATE_IMMUTABLE','complete ledger cannot reopen')
        self._data['state']=s;self._save()
    def case_entry(self,c):
        try:return self._data['cases'][c]
        except KeyError as e:raise ResumeError('L1A20_CASE_UNKNOWN',f'unknown case {c}') from e
    def verify_case_inputs(self):
        for c in self.semantic['cases']:
            if sha_file(self.root/c['fixture_manifest'])!=c['fixture_manifest_sha256']:raise ResumeError('L1A20_FIXTURE_MUTATED',f"fixture changed {c['case_id']}")
    def _record(self,p):
        if not p.is_file():raise ResumeError('L1A20_ARTIFACT_MISSING','artifact missing')
        return {'relative_path':rel(self.root,p),'sha256':sha_file(p),'byte_count':p.stat().st_size}
    def bind_case_artifact(self,c,k,p):
        r=self._record(p);a=self.case_entry(c)['artifacts'];old=a.get(k)
        if old is not None and old!=r:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'case artifact changed {c}:{k}')
        a[k]=r;self._save();return r
    def trusted_case_artifact(self,c,k,p):
        old=self.case_entry(c)['artifacts'].get(k)
        if old is None:return False
        if self._record(p)!=old:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'case artifact changed {c}:{k}')
        return True
    def bind_global_artifact(self,k,p):
        r=self._record(p);a=self._data['global_artifacts'];old=a.get(k)
        if old is not None and old!=r:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'global artifact changed {k}')
        a[k]=r;self._save();return r
    def trusted_global_artifact(self,k,p):
        old=self._data['global_artifacts'].get(k)
        if old is None:return False
        if self._record(p)!=old:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'global artifact changed {k}')
        return True
    def recover_started_attempt(self,c,*,output_recovered):
        a=self.case_entry(c)['attempts']
        if a and a[-1]['status']=='STARTED':a[-1].update(status='RECOVERED_OUTPUT' if output_recovered else 'INTERRUPTED',exit_code=None,wall_time_ms=None,stable_error_code=None if output_recovered else 'PROCESS_TERMINATED_DURING_ATTEMPT');self._save()
    def begin_attempt(self,c):
        a=self.case_entry(c)['attempts']
        if a and a[-1]['status']=='STARTED':raise ResumeError('L1A20_ATTEMPT_ALREADY_STARTED','unfinished attempt exists')
        n=len(a)+1;a.append({'attempt':n,'status':'STARTED','exit_code':None,'wall_time_ms':None,'stable_error_code':None});self._save();return n
    def finish_attempt(self,c,n,*,status,exit_code,wall_time_ms,stable_error_code):
        a=self.case_entry(c)['attempts']
        if status not in {'PASS','FAIL','TIMEOUT'}:raise ResumeError('L1A20_ATTEMPT_STATE_INVALID','bad attempt state')
        if not a or a[-1]['attempt']!=n or a[-1]['status']!='STARTED':raise ResumeError('L1A20_ATTEMPT_SEQUENCE_INVALID','attempt sequence mismatch')
        a[-1].update(status=status,exit_code=exit_code,wall_time_ms=None if wall_time_ms is None else round(float(wall_time_ms),3),stable_error_code=stable_error_code);self._save()
    def attempt_count(self,c):return len(self.case_entry(c)['attempts'])
    def mark_project_ready(self,c,p,*,source):
        if source not in {'EXECUTED','REUSED_PREEXISTING','RECOVERED_AFTER_TERMINATION'}:raise ResumeError('L1A20_PROJECT_SOURCE_INVALID','bad project source')
        self.bind_case_artifact(c,'project_run_manifest',p);e=self.case_entry(c);e['phase']='PROJECT_READY';e['project_source']=source;self._save()
    def mark_reference_ready(self,c,p):self.bind_case_artifact(c,'reference_run_manifest',p);self.case_entry(c).__setitem__('phase','REFERENCE_READY');self._save()
    def mark_evaluated(self,c,p,r):self.bind_case_artifact(c,'project_evaluation',p);self.bind_case_artifact(c,'reference_evaluation',r);self.case_entry(c).__setitem__('phase','EVALUATED');self._save()
    def execution_document(self):
        cases=[];attempts=[]
        for cid in self._data['case_order']:
            e=self.case_entry(cid);aa=e['attempts'];success='project_run_manifest' in e['artifacts'];err=next((x['stable_error_code'] for x in reversed(aa) if x.get('stable_error_code')),None)
            cases.append({'case_id':cid,'success':success,'attempts':len(aa),'resumed':bool(aa) or e.get('project_source') in {'REUSED_PREEXISTING','RECOVERED_AFTER_TERMINATION'},'project_source':e.get('project_source'),'stable_error_code':None if success else err,'project_run_manifest':e['artifacts'].get('project_run_manifest',{}).get('relative_path')})
            attempts += [{'case_id':cid,**x,'idempotency_key_sha256':e['idempotency_key_sha256']} for x in aa]
        return {'schema_version':2,'evidence_state':EVIDENCE_STATE,'batch_id':self.semantic['batch_id'],'batch_identity_sha256':self.batch_identity_sha256,'cases':cases,'attempts':attempts}
    def verify_bound_artifacts(self):
        for cid,e in self._data['cases'].items():
            for k,r in e['artifacts'].items():
                if self._record(self.root/r['relative_path'])!=r:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'case artifact changed {cid}:{k}')
        for k,r in self._data['global_artifacts'].items():
            if self._record(self.root/r['relative_path'])!=r:raise ResumeError('L1A20_EVIDENCE_MUTATED',f'global artifact changed {k}')
    def set_review_hashes(self,*,roster_sha256,assignments_sha256,replacements_sha256,scores_sha256,active_assignment_sha256,missing_assignment_ids):
        vals={k:norm_sha(v,k) for k,v in {'roster_sha256':roster_sha256,'assignments_sha256':assignments_sha256,'replacements_sha256':replacements_sha256,'scores_sha256':scores_sha256,'active_assignment_sha256':active_assignment_sha256}.items()};rv=self._data['review']
        for k in ('roster_sha256','assignments_sha256'):
            if rv.get(k) is not None and rv[k]!=vals[k]:raise ResumeError('L1A20_REVIEW_ASSIGNMENT_MUTATED','reviewer roster/base assignments changed')
        if self._data['state']=='COMPLETE' and any(rv.get(k)!=v for k,v in vals.items()):raise ResumeError('L1A20_COMPLETE_REVIEW_MUTATED','completed review evidence changed')
        rv.update(vals);rv['missing_assignment_ids']=sorted(set(map(str,missing_assignment_ids)));self._save()
    def audit_fragment(self):return {'schema_version':1,'tool_version':TOOL_VERSION,'batch_identity_sha256':self.batch_identity_sha256,'acceptance_policy_sha256':self.policy_sha256,'acceptance_policy':self.semantic['acceptance_policy'],'golden_corpus_lock_sha256':self.semantic['golden_corpus_lock_sha256'],'toolchain':self.semantic['toolchain'],'review':dict(self._data['review']),'evidence_chain_sha256':self._data.get('evidence_chain_sha256'),'parity_state':EVIDENCE_STATE}
    def finalize(self,p):
        if self._data['review']['missing_assignment_ids']:raise ResumeError('L1A20_REVIEW_ASSIGNMENTS_INCOMPLETE','missing reviews',exit_code=3)
        self.verify_bound_artifacts();r=self._record(p);old=self._data.get('acceptance')
        if old is not None and old!=r:raise ResumeError('L1A20_ACCEPTANCE_MUTATED','acceptance changed')
        self._data['acceptance']=r;items=[]
        for cid in sorted(self._data['cases']):
            for k,v in sorted(self._data['cases'][cid]['artifacts'].items()):items.append({'scope':cid,'kind':k,**v})
        for k,v in sorted(self._data['global_artifacts'].items()):items.append({'scope':'GLOBAL','kind':k,**v})
        chain={'d':'a20-chain-v1','batch':self.batch_identity_sha256,'policy':self.policy_sha256,'golden':self.semantic['golden_corpus_lock_sha256'],'review':{k:self._data['review'].get(k) for k in ('roster_sha256','assignments_sha256','replacements_sha256','scores_sha256','active_assignment_sha256')},'artifacts':items+[{'scope':'GLOBAL','kind':'acceptance',**r}]}
        self._data['evidence_chain_sha256']=sha_json(chain);self._data['state']='COMPLETE';self._save();return self.audit_fragment()

canonical_json_bytes=canon;sha256_json=sha_json;sha256_file=sha_file;semantic_batch_payload=semantic

def load_reviewer_roster(p:Path,*,min_reviewers:int):
    if not p.is_file():raise ResumeError('L1A20_REVIEWER_ROSTER_REQUIRED','reviewer roster required',exit_code=3)
    try:v=json.loads(p.read_text())
    except (OSError,json.JSONDecodeError) as e:raise ResumeError('L1A20_REVIEWER_ROSTER_INVALID','cannot decode roster') from e
    if not isinstance(v,Mapping) or v.get('schema_version')!=1 or set(v)-{'schema_version','reviewer_ids'}:raise ResumeError('L1A20_REVIEWER_ROSTER_INVALID','roster schema invalid')
    raw=v.get('reviewer_ids')
    if not isinstance(raw,list):raise ResumeError('L1A20_REVIEWER_ROSTER_INVALID','reviewer_ids must be array')
    ids=sorted({req(x,'reviewer_id') for x in raw})
    if len(ids)!=len(raw):raise ResumeError('L1A20_REVIEWER_ROSTER_DUPLICATE','duplicate reviewer')
    if len(ids)<min_reviewers:raise ResumeError('L1A20_REVIEWER_ROSTER_INSUFFICIENT','not enough reviewers',exit_code=3)
    return ids

def build_reviewer_assignments(config,batch,reviewer_ids,*,min_reviewers):
    rr=sorted(set(map(str,reviewer_ids)))
    if len(rr)<min_reviewers:raise ResumeError('L1A20_REVIEWER_ROSTER_INSUFFICIENT','not enough reviewers',exit_code=3)
    out=[]
    for c in sorted(config.get('cases',[]),key=lambda x:str(x['case_id'])):
        for stem in sorted(map(str.lower,c['target_roles'])):
            for blind in ('A','B'):
                seed=int(hashlib.sha256(f"{batch}:{c['case_id']}:{stem}:{blind}".encode()).hexdigest()[:8],16)
                for i in range(min_reviewers):
                    r=rr[(seed+i)%len(rr)];out.append({'assignment_id':aid(batch,str(c['case_id']),stem,blind,r),'case_id':str(c['case_id']),'stem':stem,'system_blind_id':blind,'reviewer_id':r,'replaces_assignment_id':None})
    return sorted(out,key=lambda x:x['assignment_id'])

def load_replacements(p:Path):
    if not p.is_file():return []
    try:v=json.loads(p.read_text())
    except (OSError,json.JSONDecodeError) as e:raise ResumeError('L1A20_REPLACEMENTS_INVALID','cannot decode replacements') from e
    if not isinstance(v,Mapping) or v.get('schema_version')!=1 or set(v)-{'schema_version','replacements'} or not isinstance(v.get('replacements'),list):raise ResumeError('L1A20_REPLACEMENTS_INVALID','replacement schema invalid')
    out=[];seen=set()
    for x in v['replacements']:
        if not isinstance(x,Mapping) or set(x)!={'from_assignment_id','to_reviewer_id','reason_code'}:raise ResumeError('L1A20_REPLACEMENTS_INVALID','replacement entry invalid')
        src=req(x['from_assignment_id'],'from_assignment_id');reason=req(x['reason_code'],'reason_code')
        if src in seen:raise ResumeError('L1A20_REPLACEMENT_DUPLICATE','assignment replaced twice')
        if reason not in REASONS:raise ResumeError('L1A20_REPLACEMENT_REASON_INVALID','bad replacement reason')
        seen.add(src);out.append({'from_assignment_id':src,'to_reviewer_id':req(x['to_reviewer_id'],'to_reviewer_id'),'reason_code':reason})
    return out

def apply_replacements(assignments,replacements,batch):
    active={str(x['assignment_id']):dict(x) for x in assignments};hist=[];allids=set(active)
    for a in replacements:
        src=str(a['from_assignment_id'])
        if src not in active:raise ResumeError('L1A20_REPLACEMENT_SOURCE_INACTIVE','source inactive')
        old=active.pop(src);r=str(a['to_reviewer_id'])
        if any(x['case_id']==old['case_id'] and x['stem']==old['stem'] and x['system_blind_id']==old['system_blind_id'] and x['reviewer_id']==r for x in active.values()):raise ResumeError('L1A20_REPLACEMENT_REVIEWER_CONFLICT','reviewer already assigned')
        nid=aid(batch,old['case_id'],old['stem'],old['system_blind_id'],r,src)
        if nid in allids:raise ResumeError('L1A20_REPLACEMENT_ID_COLLISION','replacement id collision')
        new={'assignment_id':nid,'case_id':old['case_id'],'stem':old['stem'],'system_blind_id':old['system_blind_id'],'reviewer_id':r,'replaces_assignment_id':src};active[nid]=new;allids.add(nid);hist.append({'superseded':old,'replacement':new,'reason_code':a['reason_code']})
    return sorted(active.values(),key=lambda x:x['assignment_id']),hist

def filter_reviews_for_active_assignments(reviews,base,active,hist):
    ever={(str(a['case_id']),str(a['stem']),str(a['system_blind_id']),str(a['reviewer_id'])):str(a['assignment_id']) for a in base};sup=set()
    for h in hist:
        sup.add(str(h['superseded']['assignment_id']));a=h['replacement'];ever[(a['case_id'],a['stem'],a['system_blind_id'],a['reviewer_id'])]=a['assignment_id']
    active_t={(str(a['case_id']),str(a['stem']),str(a['system_blind_id']),str(a['reviewer_id'])):str(a['assignment_id']) for a in active};done=set();out=[];supreviews=0
    for r in reviews:
        k=(str(r['case_id']),str(r['stem']),str(r['system_blind_id']),str(r['listener_id']))
        if k not in ever:raise ResumeError('L1A20_UNASSIGNED_REVIEW','reviewer not assigned')
        if k not in active_t:supreviews+=1;continue
        done.add(active_t[k]);out.append(r)
    missing=sorted({str(a['assignment_id']) for a in active}-done)
    return out,missing,{'active_assignment_count':len(active),'completed_active_count':len(done),'missing_assignment_count':len(missing),'superseded_review_count':supreviews,'superseded_assignment_ids':sorted(sup)}

def reviewer_assignment_document(batch_id,batch_identity_sha256,assignments,replacement_history):return {'schema_version':1,'tool_version':TOOL_VERSION,'evidence_state':EVIDENCE_STATE,'batch_id':batch_id,'batch_identity_sha256':batch_identity_sha256,'blind_only':True,'active_assignments':list(assignments),'replacement_history':list(replacement_history)}
