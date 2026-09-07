"""L1-A22 AI stem generation live evaluation gate (NON-PARITY)."""
from __future__ import annotations
import hashlib, json, math, re
from pathlib import Path
from typing import Any, Mapping

TOOL_VERSION='L1-A22-LIVE-v1'; EVIDENCE_STATE='NON_PARITY_EVIDENCE_ONLY'
HEX64=re.compile(r'^[0-9a-f]{64}$'); SAFE=re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$')
TIERS={'FREE','PREMIUM','PRO'}
REQUIRED_RECOVERY={'AMBIGUOUS_START_RECONCILIATION','RELAUNCH_BOUND_EXECUTION','CANCEL_DURING_GENERATION','CREDIT_EXHAUSTION'}

class GenerationLiveGateError(ValueError):
    def __init__(self,code,message='AI stem generation live-gate failure'): self.code=code; self.message=message; super().__init__(f'{code}: {message}')
def fail(code,msg='AI stem generation live-gate failure'): raise GenerationLiveGateError(code,msg)
def sha(v,f):
    if not isinstance(v,str): fail('GENLIVE_SHA_INVALID',f)
    x=v.strip().lower().removeprefix('sha256:')
    if not HEX64.fullmatch(x): fail('GENLIVE_SHA_INVALID',f)
    return x
def safe(v,f):
    if not isinstance(v,str) or not SAFE.fullmatch(v.strip()): fail('GENLIVE_SAFE_ID_INVALID',f)
    return v.strip()
def boolean(v,f):
    if not isinstance(v,bool): fail('GENLIVE_BOOL_INVALID',f)
    return v
def number(v,f,lo=None,hi=None):
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(float(v)): fail('GENLIVE_NUMBER_INVALID',f)
    x=float(v)
    if lo is not None and x<lo or hi is not None and x>hi: fail('GENLIVE_NUMBER_RANGE',f)
    return x
def integer(v,f,lo=0):
    if isinstance(v,bool) or not isinstance(v,int) or v<lo: fail('GENLIVE_INTEGER_INVALID',f)
    return v
def csha(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def fsha(p):
    h=hashlib.sha256()
    try:
        with Path(p).open('rb') as f:
            for b in iter(lambda:f.read(1048576),b''): h.update(b)
    except OSError as e: raise GenerationLiveGateError('GENLIVE_FILE_UNREADABLE',str(p)) from e
    return h.hexdigest()

def normalized_plan(r):
    if r.get('schema_version')!=1 or r.get('evidence_state')!=EVIDENCE_STATE or r.get('parity_claim')!='NONE': fail('GENLIVE_PLAN_SCHEMA')
    p=r.get('policy')
    if not isinstance(p,Mapping) or p.get('engineering_policy_not_reference_fact') is not True: fail('GENLIVE_POLICY_REFERENCE_FACT_PROHIBITED')
    tiers=sorted({safe(x,'required_tier').upper() for x in p.get('required_tiers',[])})
    if not tiers or set(tiers)-TIERS: fail('GENLIVE_REQUIRED_TIERS_INVALID')
    return {'plan_id':safe(r.get('plan_id'),'plan_id'),'policy':{
        'minimum_successful_runs_per_role_mode':integer(p.get('minimum_successful_runs_per_role_mode'),'minruns',1),
        'maximum_failure_fraction':number(p.get('maximum_failure_fraction'),'fail',0,1),
        'maximum_retry_fraction':number(p.get('maximum_retry_fraction'),'retry',0,1),
        'maximum_mean_latency_ms':number(p.get('maximum_mean_latency_ms'),'latency',1),
        'minimum_mean_usability_delta_project_minus_reference':number(p.get('minimum_mean_usability_delta_project_minus_reference'),'delta',-4,4),
        'maximum_material_inferiority_fraction':number(p.get('maximum_material_inferiority_fraction'),'material',0,1),
        'required_tiers':tiers,'engineering_policy_not_reference_fact':True}}

def capability(r):
    if r.get('schema_version')!=1 or r.get('evidence_state')!=EVIDENCE_STATE: fail('GENLIVE_CAPABILITY_SCHEMA')
    roles=sorted({safe(x,'role').lower() for x in r.get('allowed_roles',[])})
    modes=sorted({safe(x,'mode').upper() for x in r.get('supported_modes',[])})
    tiers=sorted({safe(x,'tier').upper() for x in r.get('allowed_tiers',[])})
    if not roles or not modes or not tiers or set(tiers)-TIERS: fail('GENLIVE_CAPABILITY_EMPTY')
    return {'confidence':safe(r.get('reference_confidence'),'confidence').upper(),'roles':roles,'modes':modes,'tiers':tiers,'snapshot_sha256':sha(r.get('snapshot_sha256'),'capsha'),'source_evidence_sha256':sha(r.get('source_evidence_sha256'),'capsrc')}

def surface_digest(r):
    x=dict(r); x.pop('surface_sha256',None); x['schema_version']=1; x['evidence_kind']='AI_STEM_GENERATION_CURRENT_IPHONE_SURFACE'; x['evidence_state']=EVIDENCE_STATE; x['platform']='CURRENT_IPHONE_MOISES'; x['capability_snapshot_sha256']=sha(x.get('capability_snapshot_sha256'),'cap')
    rows=x.get('role_mode_pairs')
    if not isinstance(rows,list) or not rows: fail('GENLIVE_SURFACE_PAIR_SET_EMPTY')
    pairs=[(safe(z.get('role'),'role').lower(),safe(z.get('mode'),'mode').upper()) for z in rows if isinstance(z,Mapping)]
    if len(pairs)!=len(rows) or len(set(pairs))!=len(pairs): fail('GENLIVE_SURFACE_PAIR_DUPLICATE')
    x['role_mode_pairs']=[{'role':a,'mode':b} for a,b in sorted(pairs)]; x['observed_tiers']=sorted({safe(v,'tier').upper() for v in x.get('observed_tiers',[])})
    x['source_evidence_sha256']=sha(x.get('source_evidence_sha256'),'src')
    return csha({'domain':'l1-a22-current-iphone-surface-v1',**x})

def surface(r,cap):
    if r.get('schema_version')!=1 or r.get('evidence_kind')!='AI_STEM_GENERATION_CURRENT_IPHONE_SURFACE' or r.get('evidence_state')!=EVIDENCE_STATE or r.get('platform')!='CURRENT_IPHONE_MOISES': fail('GENLIVE_SURFACE_SCHEMA')
    if sha(r.get('capability_snapshot_sha256'),'surface cap')!=cap['snapshot_sha256']: fail('GENLIVE_SURFACE_CAPABILITY_MISMATCH')
    rows=r.get('role_mode_pairs')
    if not isinstance(rows,list) or not rows: fail('GENLIVE_SURFACE_PAIR_SET_EMPTY')
    pairs=[]
    for z in rows:
        if not isinstance(z,Mapping): fail('GENLIVE_SURFACE_PAIR_SCHEMA')
        a,b=safe(z.get('role'),'role').lower(),safe(z.get('mode'),'mode').upper()
        if a not in cap['roles'] or b not in cap['modes']: fail('GENLIVE_SURFACE_PAIR_NOT_CAPABILITY')
        pairs.append((a,b))
    if len(set(pairs))!=len(pairs): fail('GENLIVE_SURFACE_PAIR_DUPLICATE')
    tiers=sorted({safe(v,'tier').upper() for v in r.get('observed_tiers',[])})
    if not tiers or set(tiers)-set(cap['tiers']): fail('GENLIVE_SURFACE_TIER_INVALID')
    lock=sha(r.get('surface_sha256'),'surface lock')
    if surface_digest(r)!=lock: fail('GENLIVE_SURFACE_LOCK_MISMATCH')
    return {'pairs':sorted(pairs),'tiers':tiers,'surface_sha256':lock,'source_evidence_sha256':sha(r.get('source_evidence_sha256'),'src')}

def runtime(r,capsha):
    if r.get('schema_version')!=1 or r.get('evidence_state')!=EVIDENCE_STATE: fail('GENLIVE_RUNTIME_SCHEMA')
    if sha(r.get('capability_snapshot_sha256'),'runtime cap')!=capsha: fail('GENLIVE_RUNTIME_CAPABILITY_MISMATCH')
    return {'runtime_id':safe(r.get('runtime_id'),'runtime'),'authority_kind':safe(r.get('authority_kind'),'authority').upper(),'runtime_identity_sha256':sha(r.get('runtime_identity_sha256'),'runtime sha'),'descriptor_sha256':sha(r.get('descriptor_sha256'),'descriptor')}

def entitlements(rows,cap,required):
    seen={}
    for r in rows:
        if r.get('schema_version')!=1 or r.get('evidence_state')!=EVIDENCE_STATE: fail('GENLIVE_ENTITLEMENT_SCHEMA')
        t=safe(r.get('plan_tier'),'tier').upper()
        if t in seen: fail('GENLIVE_DUPLICATE_ENTITLEMENT_TIER')
        if t not in cap['tiers'] or sha(r.get('capability_snapshot_sha256'),'ent cap')!=cap['snapshot_sha256'] or r.get('generation_enabled') is not True: fail('GENLIVE_ENTITLEMENT_INVALID')
        seen[t]=sha(r.get('source_evidence_sha256'),'ent source')
    if not set(required)<=set(seen): fail('GENLIVE_ENTITLEMENT_TIER_MISSING')
    return seen

def run(r,cap,rt):
    if r.get('schema_version')!=1 or r.get('evidence_kind')!='AI_STEM_GENERATION_LIVE_RUN' or r.get('evidence_state')!=EVIDENCE_STATE or r.get('source_class')!='RIGHTS_CLEARED_REAL': fail('GENLIVE_RUN_SCHEMA')
    if r.get('parity_claim')!='NONE' or sha(r.get('runtime_descriptor_sha256'),'runtime descriptor')!=rt['descriptor_sha256'] or sha(r.get('capability_snapshot_sha256'),'cap')!=cap['snapshot_sha256']: fail('GENLIVE_RUN_BINDING')
    role,mode=safe(r.get('target_role'),'role').lower(),safe(r.get('generation_mode'),'mode').upper()
    if role not in cap['roles'] or mode not in cap['modes']: fail('GENLIVE_RUN_SURFACE_INVALID')
    terminal=safe(r.get('terminal_state'),'terminal').upper()
    if terminal not in {'READY','FAILED','CANCELLED'}: fail('GENLIVE_RUN_TERMINAL')
    dup=boolean(r.get('duplicate_execution_detected'),'duplicate')
    credit=boolean(r.get('credit_accounting_consistent'),'credit'); cancel=boolean(r.get('cancel_truthful'),'cancel')
    if dup or not credit or not cancel: fail('GENLIVE_RUN_SAFETY')
    success=terminal=='READY'
    if success:
        sha(r.get('output_sha256'),'output')
        if r.get('project_controlled_output') is not True or r.get('integrity_verified') is not True: fail('GENLIVE_RUN_OUTPUT_UNVERIFIED')
    elif r.get('output_sha256') is not None or r.get('project_controlled_output') or r.get('integrity_verified'):
        fail('GENLIVE_NONREADY_OUTPUT_PRESENT')
    return {'run_id':safe(r.get('run_id'),'run'),'role':role,'mode':mode,'source_sha256':sha(r.get('source_sha256'),'source'),'settings_sha256':sha(r.get('settings_sha256'),'settings'),'success':success,'retry_count':integer(r.get('retry_count'),'retry'),'latency_ms':number(r.get('latency_ms'),'latency',0),'receipt_sha256':sha(r.get('runtime_receipt_sha256'),'receipt')}

def differential(r,runs):
    if r.get('schema_version')!=1 or r.get('evidence_kind')!='AI_STEM_GENERATION_DIFFERENTIAL' or r.get('reference_platform')!='CURRENT_IPHONE_MOISES' or r.get('blind_review') is not True: fail('GENLIVE_DIFFERENTIAL_SCHEMA')
    rid=safe(r.get('project_run_id'),'run'); rr=runs.get(rid)
    if not rr or not rr['success']: fail('GENLIVE_DIFFERENTIAL_RUN_INVALID')
    if sha(r.get('source_sha256'),'source')!=rr['source_sha256'] or sha(r.get('settings_sha256'),'settings')!=rr['settings_sha256'] or safe(r.get('target_role'),'role').lower()!=rr['role'] or safe(r.get('generation_mode'),'mode').upper()!=rr['mode']: fail('GENLIVE_DIFFERENTIAL_INPUT_MISMATCH')
    return {'run_id':rid,'delta':number(r.get('usability_delta_project_minus_reference'),'delta',-4,4),'material':boolean(r.get('material_inferiority_detected'),'material'),'review_evidence_sha256':sha(r.get('review_evidence_sha256'),'review')}

def recovery(r,rt):
    if r.get('schema_version')!=1 or r.get('evidence_kind')!='AI_STEM_GENERATION_RECOVERY_SCENARIO': fail('GENLIVE_RECOVERY_SCHEMA')
    k=safe(r.get('scenario_kind'),'kind').upper()
    if k not in REQUIRED_RECOVERY or sha(r.get('runtime_descriptor_sha256'),'runtime descriptor')!=rt['descriptor_sha256'] or r.get('passed') is not True or r.get('duplicate_execution_detected') is not False or r.get('project_corruption_detected') is not False or r.get('credit_accounting_consistent') is not True or r.get('cancel_truthful') is not True: fail('GENLIVE_RECOVERY_FAILED')
    return {'kind':k,'authority_evidence_sha256':sha(r.get('authority_evidence_sha256'),'authority'),'fault_injection_evidence_sha256':sha(r.get('fault_provenance_sha256'),'fault')}

def evaluate_live_gate(*,plan,capability:Mapping[str,Any],current_iphone_surface,runtime_descriptor,entitlement_observations,runs,differentials,recovery_scenarios):
    pn=normalized_plan(plan); p=pn['policy']; cap=globals()['capability'](capability); sf=surface(current_iphone_surface,cap); rt=runtime(runtime_descriptor,cap['snapshot_sha256'])
    if not set(p['required_tiers'])<=set(sf['tiers']): fail('GENLIVE_PLAN_TIER_NOT_CAPTURED')
    ent=entitlements(entitlement_observations,cap,p['required_tiers']); rr=[run(x,cap,rt) for x in runs]
    if len({x['run_id'] for x in rr})!=len(rr): fail('GENLIVE_DUPLICATE_RUN_ID')
    runmap={x['run_id']:x for x in rr}; dd=[differential(x,runmap) for x in differentials]
    if len({x['run_id'] for x in dd})!=len(dd): fail('GENLIVE_DUPLICATE_DIFFERENTIAL')
    rec=[recovery(x,rt) for x in recovery_scenarios]
    if {x['kind'] for x in rec}!=REQUIRED_RECOVERY or len(rec)!=4: fail('GENLIVE_RECOVERY_COVERAGE_MISSING')
    pairs=set(sf['pairs']); counts={x:0 for x in pairs}
    for x in rr:
        if x['success'] and (x['role'],x['mode']) in counts: counts[(x['role'],x['mode'])]+=1
    coverage=all(v>=p['minimum_successful_runs_per_role_mode'] for v in counts.values())
    failures=sum(not x['success'] for x in rr); ff=failures/len(rr) if rr else 1.0; retry=sum(x['retry_count']>0 for x in rr)/len(rr) if rr else 1.0
    lat=[x['latency_ms'] for x in rr if x['success']]; ml=sum(lat)/len(lat) if lat else None
    diffmap={x['run_id']:x for x in dd}; successids={x['run_id'] for x in rr if x['success']}; diffcov=successids<=set(diffmap)
    deltas=[x['delta'] for x in dd]; md=sum(deltas)/len(deltas) if deltas else None; mf=sum(x['material'] for x in dd)/len(dd) if dd else 1.0
    state='READY_FOR_HQ_P025_LIVE_REVIEW'; reasons=[]
    if cap['confidence']!='CURRENT_IPHONE_CAPTURED': state='WAITING_CURRENT_IPHONE_REFERENCE'; reasons.append('current-iPhone capability capture missing')
    if not rr or not coverage or not diffcov:
        if state!='WAITING_CURRENT_IPHONE_REFERENCE': state='WAITING_EXTERNAL_EVIDENCE'
        reasons.append('role/mode run or differential coverage incomplete')
    hard=ff>p['maximum_failure_fraction'] or retry>p['maximum_retry_fraction'] or ml is None or (ml is not None and ml>p['maximum_mean_latency_ms']) or md is None or (md is not None and md<p['minimum_mean_usability_delta_project_minus_reference']) or mf>p['maximum_material_inferiority_fraction']
    if hard and rr and dd: state='LIVE_EVALUATION_REJECTED'; reasons.append('quality/latency/reliability threshold failed')
    binding={'plan_sha256':csha(pn),'capability_snapshot_sha256':cap['snapshot_sha256'],'current_iphone_surface_sha256':sf['surface_sha256'],'runtime_descriptor_sha256':rt['descriptor_sha256'],'runtime_identity_sha256':rt['runtime_identity_sha256'],'entitlement_source_sha256':ent,'run_receipts':{x['run_id']:x['receipt_sha256'] for x in sorted(rr,key=lambda z:z['run_id'])},'differential_review_sha256':{x['run_id']:x['review_evidence_sha256'] for x in sorted(dd,key=lambda z:z['run_id'])},'recovery_authority_sha256':{x['kind']:x['authority_evidence_sha256'] for x in sorted(rec,key=lambda z:z['kind'])}}
    metrics={'required_role_mode_pairs':len(pairs),'successful_role_mode_pairs':sum(v>=p['minimum_successful_runs_per_role_mode'] for v in counts.values()),'run_count':len(rr),'successful_run_count':len(lat),'failure_fraction':ff,'retry_fraction':retry,'mean_latency_ms':ml,'differential_count':len(dd),'mean_usability_delta_project_minus_reference':md,'material_inferiority_fraction':mf,'recovery_scenario_count':len(rec)}
    checks={'current_iphone_capability_captured':cap['confidence']=='CURRENT_IPHONE_CAPTURED','required_tiers_observed':set(p['required_tiers'])<=set(ent),'role_mode_coverage':coverage,'successful_runs_have_blind_differential':diffcov,'recovery_coverage_complete':{x['kind'] for x in rec}==REQUIRED_RECOVERY,'no_duplicate_execution':True,'credit_accounting_consistent':True,'cancel_truthful':True,'rights_cleared_real_source_only':True}
    out={'schema_version':1,'tool_version':TOOL_VERSION,'evidence_kind':'AI_STEM_GENERATION_LIVE_GATE','evidence_state':EVIDENCE_STATE,'parity_claim':'NONE','gate_state':state,'plan_id':pn['plan_id'],'runtime':rt,'capability':cap,'current_iphone_surface':sf,'metrics':metrics,'checks':checks,'reasons':reasons,'evidence_binding':binding,'privacy':{'raw_prompt_emitted':False,'raw_account_id_emitted':False,'raw_execution_id_emitted':False,'private_path_emitted':False,'raw_audio_emitted':False,'reference_audio_copied':False,'raw_reviewer_id_emitted':False,'credential_values_emitted':False},'parity_reason':'A22 qualifies evidence for HQ review only; integrated current-iPhone workflow/UX/device evidence remains mandatory.'}
    out['a22_live_gate_lock_sha256']=csha({'domain':'l1-a22-live-gate-v1','state':state,'policy':p,'binding':binding,'metrics':metrics,'checks':checks}); return out

def private_roots(repo,private):
    r=Path(repo).resolve(); p=Path(private).resolve()
    try:p.relative_to(r)
    except ValueError:return r,p
    fail('GENLIVE_PRIVATE_ROOT_INSIDE_REPOSITORY')
def private_file(repo,private,entry,field):
    _,root=private_roots(repo,private); rel=Path(safe(entry.get('path'),field+'.path'))
    if rel.is_absolute() or '..' in rel.parts: fail('GENLIVE_PRIVATE_PATH_UNSAFE',field)
    cur=root
    for part in rel.parts:
        cur/=part
        if cur.is_symlink(): fail('GENLIVE_PRIVATE_PATH_SYMLINK',field)
    p=(root/rel).resolve()
    try:p.relative_to(root)
    except ValueError: fail('GENLIVE_PRIVATE_PATH_ESCAPE',field)
    if not p.is_file() or fsha(p)!=sha(entry.get('sha256'),field+'.sha256'): fail('GENLIVE_PRIVATE_FILE_SHA_MISMATCH',field)
    return p,fsha(p)
def evaluate_private_campaign(*,repo_root,private_root,index):
    if index.get('schema_version')!=1 or index.get('private') is not True: fail('GENLIVE_PRIVATE_INDEX_SCHEMA')
    docs={}; physical={}
    for k in ('plan','capability','current_iphone_surface','runtime_descriptor'):
        if not isinstance(index.get(k),Mapping): fail('GENLIVE_PRIVATE_INDEX_ENTRY',k)
        p,h=private_file(repo_root,private_root,index[k],k); docs[k]=json.loads(p.read_text()); physical[k]=h
    for k in ('entitlement_observations','runs','differentials','recovery_scenarios'):
        if not isinstance(index.get(k),list): fail('GENLIVE_PRIVATE_INDEX_LIST',k)
        docs[k]=[]; physical[k]=[]
        for i,e in enumerate(index[k]):
            p,h=private_file(repo_root,private_root,e,f'{k}[{i}]'); docs[k].append(json.loads(p.read_text())); physical[k].append(h)
    out=evaluate_live_gate(**docs); out['campaign_source_file_sha256']=physical; out['a22_live_gate_lock_sha256']=csha({'domain':'l1-a22-live-gate-private-v1','semantic_lock':out['a22_live_gate_lock_sha256'],'source_file_sha256':physical}); return out

surface_template_digest = surface_digest
canonical_sha = csha
