"""L1-E09 Generic Route Decision Integration.

Combines legacy hosted E06 route-decision evidence with E07+E08 fallback-runtime
evidence. Evidence-only engineering gate; never product PARITY.
"""
from __future__ import annotations
import hashlib, json, math, os, re
from pathlib import Path
from typing import Any, Mapping

V=1; TOOL='L1-E09-v1'; NON='NON_PARITY_EVIDENCE_ONLY'
LEGACY='LEGACY_E06_HOSTED'; GENERIC='GENERIC_E07_E08'
FALLBACK=['LICENSED_LOCAL_INFERENCE_SDK','ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER','PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE']
AUTH={'LICENSED_LOCAL_INFERENCE_SDK':'LOCAL_RUNTIME','ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER':'HOSTED_PROVIDER_ACCOUNT','PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE':'PROJECT_OWNED_RUNTIME'}
HEX=re.compile(r'^[0-9a-f]{64}$'); SAFE=re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$')
CAP={'ADEQUATE','INSUFFICIENT','UNKNOWN'}
EVIDENCE_STATE=NON; PATH_LEGACY=LEGACY; PATH_GENERIC=GENERIC; ROUTE_AUTHORITY=AUTH; FALLBACK_ORDER=FALLBACK
CANCEL={'CANCEL_PRE_START','CANCEL_EXECUTING','CANCEL_FINALIZING'}
E08_KINDS={'INPUT_INTERRUPTION','CANCEL_PRE_START','CANCEL_EXECUTING','CANCEL_FINALIZING','AMBIGUOUS_START_RETRY','RELAUNCH','OUTPUT_AVAILABILITY_LOSS','CAPACITY_LIMIT','LONG_TRACK','STORAGE_PRESSURE'}

class RouteDecisionError(ValueError):
    def __init__(self, code, message='generic route decision validation failed'):
        super().__init__(f'{code}: {message}'); self.code=code; self.message=message

def fail(code,msg='generic route decision validation failed'): raise RouteDecisionError(code,msg)
def mp(v,f):
    if not isinstance(v,Mapping): fail('L1E09_SCHEMA_TYPE',f)
    return v
def ls(v,f):
    if not isinstance(v,list): fail('L1E09_SCHEMA_TYPE',f)
    return v
def st(v,f):
    if not isinstance(v,str) or not v.strip(): fail('L1E09_SCHEMA_REQUIRED',f)
    return v.strip()
def bl(v,f):
    if not isinstance(v,bool): fail('L1E09_SCHEMA_TYPE',f)
    return v
def num(v,f,lo=None):
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(float(v)): fail('L1E09_SCHEMA_NUMBER',f)
    x=float(v)
    if lo is not None and x<lo: fail('L1E09_SCHEMA_RANGE',f)
    return x
def integer(v,f,lo=0):
    if isinstance(v,bool) or not isinstance(v,int) or v<lo: fail('L1E09_SCHEMA_INTEGER',f)
    return v
def sha(v,f):
    x=st(v,f).lower().removeprefix('sha256:')
    if not HEX.fullmatch(x): fail('L1E09_SHA_INVALID',f)
    return x
def csha(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def fsha(p):
    h=hashlib.sha256()
    try:
        with p.open('rb') as f:
            for b in iter(lambda:f.read(1048576),b''): h.update(b)
    except OSError as e: raise RouteDecisionError('L1E09_FILE_UNREADABLE',str(p)) from e
    return h.hexdigest()

sha256_file=fsha

def private_roots(repo,private):
    r=Path(repo).resolve(); p=Path(private).resolve()
    try:p.relative_to(r)
    except ValueError:return r,p
    fail('L1E09_PRIVATE_ROOT_INSIDE_REPOSITORY')
def private_path(repo,private,raw,field):
    _,root=private_roots(repo,private); rel=Path(st(raw,field))
    if rel.is_absolute() or '..' in rel.parts: fail('L1E09_PRIVATE_PATH_UNSAFE',field)
    cur=root
    for part in rel.parts:
        cur/=part
        if cur.is_symlink(): fail('L1E09_PRIVATE_PATH_SYMLINK',field)
    p=(root/rel).resolve()
    try:p.relative_to(root)
    except ValueError as e: raise RouteDecisionError('L1E09_PRIVATE_PATH_ESCAPE',field) from e
    if not p.is_file(): fail('L1E09_PRIVATE_FILE_MISSING',field)
    return p
def load(p):
    try:return mp(json.loads(Path(p).read_text(encoding='utf-8')),str(p))
    except RouteDecisionError: raise
    except Exception as e: raise RouteDecisionError('L1E09_JSON_INVALID',str(p)) from e

def policy_doc(d):
    if d.get('schema_version')!=1 or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_PLAN_SCHEMA')
    did=st(d.get('decision_id'),'decision_id'); p=mp(d.get('policy'),'policy')
    if not SAFE.fullmatch(did) or p.get('engineering_policy_not_reference_fact') is not True: fail('L1E09_POLICY_REFERENCE_FACT_PROHIBITED')
    modes=sorted(set(st(x,'mode') for x in ls(p.get('required_mode_classes'),'modes'))); sr=sorted(set(st(x,'service') for x in ls(p.get('allowed_service_regions'),'service'))); dr=sorted(set(st(x,'data') for x in ls(p.get('allowed_data_regions'),'data')))
    if not modes or not sr or not dr: fail('L1E09_PLAN_EMPTY_SET')
    w0=mp(p.get('ranking_weights'),'weights'); w={k:num(w0.get(k),k,0) for k in ('quality','latency','reliability','cost')}; total=sum(w.values())
    if total<=0: fail('L1E09_RANKING_WEIGHTS_EMPTY')
    ff=num(p.get('maximum_final_failure_fraction'),'ff',0); rr=num(p.get('maximum_retry_fraction'),'retry',0); dg=num(p.get('maximum_non_cancel_degraded_fraction'),'degraded',0)
    if max(ff,rr,dg)>1: fail('L1E09_SCHEMA_RANGE','fraction')
    delta=num(p.get('minimum_overall_usability_delta'),'delta')
    if not -4<=delta<=4: fail('L1E09_SCHEMA_RANGE','delta')
    return {'decision_id':did,'policy':{'required_mode_classes':modes,'allowed_service_regions':sr,'allowed_data_regions':dr,'maximum_mean_execution_total_ms':num(p.get('maximum_mean_execution_total_ms'),'lat',1),'maximum_final_failure_fraction':ff,'maximum_retry_fraction':rr,'cost_currency':st(p.get('cost_currency'),'currency').upper(),'maximum_mean_cost_per_successful_run':num(p.get('maximum_mean_cost_per_successful_run'),'cost',0),'maximum_non_cancel_degraded_fraction':dg,'maximum_uploaded_asset_retention_seconds':num(p.get('maximum_uploaded_asset_retention_seconds'),'retention',0),'require_deletion_control':bl(p.get('require_deletion_control'),'deletion'),'require_capacity_attestation':bl(p.get('require_capacity_attestation'),'capacity'),'minimum_overall_usability_delta':delta,'minimum_primary_score_margin':num(p.get('minimum_primary_score_margin'),'margin',0),'ranking_weights':{k:v/total for k,v in w.items()},'engineering_policy_not_reference_fact':True}}

normalized_policy = policy_doc

def e07_doc(d,physical):
    if d.get('schema_version')!=1 or d.get('evidence_kind')!='PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE' or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_E07_INVALID')
    kind=st(d.get('route_kind'),'e07.kind').upper(); rid=st(d.get('route_id'),'e07.route'); auth=mp(d.get('capacity_authority'),'e07.auth'); runtime=mp(d.get('runtime'),'e07.runtime')
    if kind not in AUTH or st(auth.get('kind'),'auth.kind').upper()!=AUTH[kind]: fail('L1E09_E07_AUTHORITY_MISMATCH')
    compat=mp(d.get('compatibility'),'compatibility')
    if compat.get('shared_app_contract_changed') is not False or compat.get('provider_neutral_publication_contract_preserved') is not True: fail('L1E09_E07_CONTRACT_FAIL')
    identity=sha(d.get('substitution_identity_sha256'),'e07.identity'); lock=sha(d.get('e07_substitution_lock_sha256'),'e07.lock'); body=dict(d); body.pop('e07_substitution_lock_sha256',None)
    if csha({'identity':identity,'report':body})!=lock: fail('L1E09_E07_LOCK_MISMATCH')
    return {'route_id':rid,'route_kind':kind,'authority_kind':AUTH[kind],'authority_sha':sha(auth.get('provenance_sha256'),'e07.auth.sha'),'runtime_sha':sha(runtime.get('artifact_sha256'),'e07.runtime.sha'),'runtime':{'runtime_id':st(runtime.get('runtime_id'),'runtime_id'),'model_name':st(runtime.get('model_name'),'model'),'model_version':st(runtime.get('model_version'),'version'),'quality_profile':st(runtime.get('quality_profile'),'profile')},'lock':lock,'physical':sha(physical,'e07 physical')}

def e08_doc(d,e7,e07physical):
    if d.get('schema_version')!=1 or d.get('evidence_kind')!='RUNTIME_AUTHORITY_LIVE_GATE' or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_E08_INVALID')
    if st(d.get('route_id'),'e08.route')!=e7['route_id'] or st(d.get('route_kind'),'e08.kind').upper()!=e7['route_kind'] or sha(d.get('runtime_artifact_sha256'),'e08.runtime')!=e7['runtime_sha']: fail('L1E09_E08_RUNTIME_MISMATCH')
    a=mp(d.get('authority'),'e08.authority'); src=mp(d.get('source_evidence'),'e08.source')
    if st(a.get('kind'),'a.kind').upper()!=e7['authority_kind'] or sha(a.get('provenance_sha256'),'a.sha')!=e7['authority_sha'] or sha(src.get('e07_evidence_sha256'),'src.e07')!=e07physical or sha(src.get('e07_substitution_lock_sha256'),'src.lock')!=e7['lock']: fail('L1E09_E08_E07_BINDING_MISMATCH')
    rows=ls(d.get('scenarios'),'e08.scenarios'); kinds={st(mp(x,'row').get('scenario_kind'),'kind') for x in rows}
    if kinds!=E08_KINDS or len(rows)!=10: fail('L1E09_E08_SCENARIO_SET')
    checks=mp(d.get('checks'),'e08.checks'); sm=mp(d.get('summary'),'e08.summary'); cap0=mp(sm.get('capacity'),'e08.capacity'); cap={}
    for k in ('execution_capacity_status','cost_headroom_status','throughput_headroom_status'):
        v=st(cap0.get(k),k).upper()
        if v not in CAP: fail('L1E09_E08_CAPACITY_STATUS')
        cap[k]=v
    non=[mp(x,'row') for x in rows if st(mp(x,'row').get('scenario_kind'),'kind') not in CANCEL]; degraded=sum(st(x.get('project_state_after'),'state') in {'recoverable','failed_closed'} for x in non)/len(non)
    if abs(num(sm.get('non_cancel_degraded_fraction'),'summary degraded')-degraded)>1e-12: fail('L1E09_E08_DEGRADED_MISMATCH')
    ce=mp(d.get('capacity_evidence'),'capacity_evidence'); reconstructed={**cap,'authority_provenance_sha256':sha(ce.get('authority_provenance_sha256'),'cap auth'),'measurement_sha256':sha(ce.get('measurement_sha256'),'cap measurement'),'unknown':any(v=='UNKNOWN' for v in cap.values()),'insufficient':any(v=='INSUFFICIENT' for v in cap.values())}
    lock_payload={'domain':'l1-e08-runtime-authority-live-gate-v1','gate_id':st(d.get('gate_id'),'gate_id'),'route_id':e7['route_id'],'route_kind':e7['route_kind'],'authority_kind':e7['authority_kind'],'e07_source_sha256':e07physical,'e07_substitution_lock_sha256':e7['lock'],'runtime_artifact_sha256':e7['runtime_sha'],'authority_provenance_sha256':e7['authority_sha'],'rows':rows,'capacity':reconstructed,'checks':checks,'gate_state':st(d.get('gate_state'),'gate_state')}
    lock=sha(d.get('e08_live_authority_lock_sha256'),'e08.lock')
    if csha(lock_payload)!=lock: fail('L1E09_E08_LOCK_MISMATCH')
    expected='LIVE_AUTHORITY_REJECTED' if reconstructed['insufficient'] or not all(v is True for v in checks.values()) else 'PENDING_EXTERNAL_EVIDENCE' if reconstructed['unknown'] else 'READY_FOR_HQ_E08_LIVE_REVIEW'
    if d.get('gate_state')!=expected: fail('L1E09_E08_STATE_INCONSISTENT')
    return {'state':expected,'lock':lock,'degraded':degraded,'capacity':cap,'cancel':checks.get('cancel_claims_truthful') is True,'checks':all(v is True for v in checks.values()),'long':checks.get('bounded_long_track_streaming') is True,'storage':checks.get('storage_preflight_observed') is True}

def measurement(repo,private,entry,kind,rid,rkind,runtime_sha,expected):
    key={'GENERIC_ROUTE_OPERATIONAL_MEASUREMENT':'operational','GENERIC_ROUTE_BENCHMARK_MEASUREMENT':'benchmark','GENERIC_ROUTE_DIFFERENTIAL_MEASUREMENT':'differential'}[kind]
    e=mp(entry.get(key),kind); p=private_path(repo,private,e.get('path'),kind); physical=fsha(p)
    if physical!=sha(e.get('sha256'),kind+'.sha'): fail('L1E09_PRIVATE_FILE_SHA_MISMATCH',kind)
    d=load(p)
    if d.get('schema_version')!=1 or d.get('evidence_kind')!=kind or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_MEASUREMENT_SCHEMA',kind)
    if st(d.get('route_id'),'measurement route')!=rid or st(d.get('route_kind'),'measurement kind').upper()!=rkind or sha(d.get('runtime_artifact_sha256'),'measurement runtime')!=runtime_sha: fail('L1E09_MEASUREMENT_ROUTE_MISMATCH',kind)
    m=mp(d.get('measurement'),'measurement')
    if dict(m)!=dict(expected): fail('L1E09_MEASUREMENT_SUMMARY_MISMATCH',kind)
    return physical

def evaluation_doc(d,e7,e8,e07sha,e08sha,evaluation_sha,repo,private):
    if d.get('schema_version')!=1 or d.get('evidence_kind')!='GENERIC_ROUTE_LIVE_EVALUATION' or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_EVALUATION_INVALID')
    if st(d.get('evaluation_state'),'evaluation_state') not in {'READY_FOR_HQ_E09_ROUTE_EVALUATION','WAITING_REVIEW','WAITING_HUMAN_REVIEW','LIVE_EVALUATION_FAILED'}: fail('L1E09_EVALUATION_STATE')
    runtime=mp(d.get('runtime'),'evaluation.runtime')
    if st(d.get('route_id'),'route')!=e7['route_id'] or st(d.get('route_kind'),'kind').upper()!=e7['route_kind'] or sha(runtime.get('artifact_sha256'),'runtime')!=e7['runtime_sha']: fail('L1E09_EVALUATION_RUNTIME_MISMATCH')
    src=mp(d.get('source_evidence'),'source')
    if sha(src.get('e07_evidence_sha256'),'e07sha')!=e07sha or sha(src.get('e07_substitution_lock_sha256'),'e07lock')!=e7['lock'] or sha(src.get('e08_evidence_sha256'),'e08sha')!=e08sha or sha(src.get('e08_live_authority_lock_sha256'),'e08lock')!=e8['lock']: fail('L1E09_EVALUATION_SOURCE_MISMATCH')
    op=mp(d.get('operational'),'operational'); bm=mp(d.get('benchmark'),'benchmark'); diff=mp(d.get('differential'),'differential')
    privacy=mp(d.get('privacy'),'privacy')
    if any(privacy.get(k) is not False for k in ('credential_values_emitted','authority_ids_emitted','private_paths_emitted','raw_billing_records_emitted','raw_reviewer_ids_emitted','raw_audio_emitted')): fail('L1E09_EVALUATION_PRIVACY')
    prov=mp(d.get('provenance'),'provenance')
    p1=measurement(repo,private,prov,'GENERIC_ROUTE_OPERATIONAL_MEASUREMENT',e7['route_id'],e7['route_kind'],e7['runtime_sha'],op)
    p2=measurement(repo,private,prov,'GENERIC_ROUTE_BENCHMARK_MEASUREMENT',e7['route_id'],e7['route_kind'],e7['runtime_sha'],bm)
    p3=measurement(repo,private,prov,'GENERIC_ROUTE_DIFFERENTIAL_MEASUREMENT',e7['route_id'],e7['route_kind'],e7['runtime_sha'],diff)
    modes=sorted(set(st(x,'mode') for x in ls(bm.get('mode_classes'),'mode_classes')))
    return {'state':d['evaluation_state'],'physical':evaluation_sha,'operational':op,'benchmark':bm,'differential':diff,'modes':modes,'prov':[p1,p2,p3]}

def compatible_legacy_policy(e06,e09):
    q=mp(e06,'e06 policy'); pairs=[('maximum_final_failure_fraction','maximum_final_failure_fraction'),('maximum_retry_fraction','maximum_retry_fraction'),('cost_currency','cost_currency'),('maximum_mean_cost_per_successful_run','maximum_mean_cost_per_successful_run'),('maximum_non_cancel_degraded_fraction','maximum_non_cancel_degraded_fraction'),('maximum_uploaded_asset_retention_seconds','maximum_uploaded_asset_retention_seconds'),('minimum_overall_usability_delta','minimum_overall_usability_delta'),('minimum_primary_score_margin','minimum_primary_score_margin')]
    for a,b in pairs:
        if q.get(a)!=e09.get(b): return False
    return q.get('maximum_mean_provider_total_ms')==e09['maximum_mean_execution_total_ms'] and q.get('require_delete_api')==e09['require_deletion_control'] and q.get('require_capacity_attestation')==e09['require_capacity_attestation'] and sorted(q.get('required_mode_classes',[]))==e09['required_mode_classes'] and sorted(q.get('allowed_service_regions',[]))==e09['allowed_service_regions'] and sorted(q.get('allowed_data_regions',[]))==e09['allowed_data_regions'] and q.get('ranking_weights')==e09['ranking_weights']

def legacy_route(route_id,d,physical,p):
    if d.get('schema_version')!=1 or d.get('evidence_kind')!='PROVIDER_ROUTE_DECISION' or d.get('evidence_state')!=NON or d.get('parity_claim')!='NONE': fail('L1E09_LEGACY_E06_INVALID')
    if not compatible_legacy_policy(mp(d.get('policy'),'e06.policy'),p): fail('L1E09_LEGACY_POLICY_MISMATCH')
    rows=ls(d.get('routes'),'e06.routes'); outcomes={st(mp(r,'r').get('route_id'),'rid'):mp(r,'r').get('decision') for r in rows}; binding={st(mp(r,'r').get('route_id'),'rid'):{k:mp(mp(r,'r').get('source_sha256'),'src').get(k) for k in ('e01','e03','e04','e05','capacity')} for r in rows}
    ident=csha({'domain':'l1-e06-provider-route-decision-v1','decision_id':d.get('decision_id'),'policy':d.get('policy'),'evidence_binding':binding,'route_outcomes':outcomes})
    if sha(d.get('decision_identity_sha256'),'e06 ident')!=ident or sha(d.get('decision_lock_sha256'),'e06 lock')!=csha({'identity':ident,'routes':rows,'policy':d.get('policy')}): fail('L1E09_LEGACY_LOCK_MISMATCH')
    row=next((mp(r,'r') for r in rows if r.get('route_id')==route_id),None)
    if row is None: fail('L1E09_LEGACY_ROUTE_MISSING')
    out=json.loads(json.dumps(row)); out['evidence_path_kind']=LEGACY; out['source_sha256']={'e06':physical}; out['source_locks']={'e06_decision_lock_sha256':d['decision_lock_sha256']}; out['execution']={'kind':'HOSTED_PROVIDER_ACCOUNT','runtime_artifact_sha256':None}
    m=mp(out.get('metrics'),'metrics'); m['mean_execution_total_ms']=m.pop('mean_provider_total_ms')
    # Never preserve an old primary outside its original candidate set.
    if out.get('eligible') is True: out['decision']='ACCEPT_WITH_LIMITS'; out['reasons']=['eligible legacy route; primary ranking reset for E09 union']
    out['score']=None; return out

def pending(r,path,missing,src,locks,execution=None,metrics=None): return {'route_id':r,'evidence_path_kind':path,'decision':'PENDING_EXTERNAL_EVIDENCE','eligible':False,'reasons':['missing or incomplete live evidence: '+','.join(sorted(missing))],'execution':execution,'metrics':metrics,'source_sha256':src,'source_locks':locks,'score':None}

def generic_route(r,e7d,e7sha,e8d,e8sha,evd,evsha,p,repo,private):
    e7=e07_doc(e7d,e7sha)
    if e7['route_id']!=r: fail('L1E09_GENERIC_ROUTE_ID_MISMATCH')
    e8=e08_doc(e8d,e7,e7sha); ev=evaluation_doc(evd,e7,e8,e7sha,e8sha,evsha,repo,private)
    op,bm,diff=ev['operational'],ev['benchmark'],ev['differential']; cap=e8['capacity']; src={'e07':e7sha,'e08':e8sha,'evaluation':evsha}; locks={'e07_substitution_lock_sha256':e7['lock'],'e08_live_authority_lock_sha256':e8['lock']}; execution={'kind':e7['authority_kind'],'runtime_artifact_sha256':e7['runtime_sha'],'runtime':e7['runtime']}
    metrics={'mode_classes':ev['modes'],'g1_objective_run_count':integer(bm.get('g1_objective_run_count'),'g1'),'g1_objective_floor_pass':bl(bm.get('g1_objective_floor_pass'),'g1 floor'),'final_failure_fraction':num(bm.get('final_failure_fraction'),'fail',0),'retry_fraction':num(bm.get('retry_fraction'),'retry',0),'mean_execution_total_ms':num(bm.get('mean_execution_total_ms'),'lat',0),'mean_cost_per_successful_run':num(bm.get('mean_cost_per_successful_run'),'cost',0),'cost_currency':st(bm.get('cost_currency'),'currency').upper(),'successful_run_count':integer(bm.get('successful_run_count'),'success'),'overall_usability_delta_project_minus_reference':diff.get('overall_usability_delta_project_minus_reference'),'material_inferiority_detected':bl(diff.get('material_inferiority_detected'),'inferior'),'non_cancel_degraded_fraction':e8['degraded'],'long_track_streaming_observed':e8['long'],'storage_preflight_observed':e8['storage'],'capacity':cap}
    decision=None; reasons=[]
    commercial=all(op.get(k) is True for k in ('commercial_use_allowed','input_confidential','output_commercial_use_allowed','output_export_allowed'))
    privacy_ok=commercial and op.get('training_on_user_content_allowed') is False and st(op.get('service_region'),'service') in p['allowed_service_regions'] and st(op.get('data_region'),'data') in p['allowed_data_regions'] and num(op.get('uploaded_asset_retention_seconds'),'retention',0)<=p['maximum_uploaded_asset_retention_seconds'] and (not p['require_deletion_control'] or op.get('deletion_control_available') is True)
    if not privacy_ok: decision='REJECT_PRIVACY'; reasons=['commercial/privacy/region/retention/deletion policy failed']
    elif not set(p['required_mode_classes']).issubset(ev['modes']) or cap['execution_capacity_status']=='INSUFFICIENT': decision='REJECT_CAPABILITY'; reasons=['required modes or execution capacity insufficient']
    elif bm.get('g1_objective_floor_pass') is not True or integer(bm.get('g1_objective_run_count'),'g1')<=0 or diff.get('exact_input_bytes') is not True or diff.get('comparison_state')=='DIFFERENTIAL_FAIL' or diff.get('material_inferiority_detected') is True or diff.get('material_inferiority_vote_pass') is not True: decision='REJECT_QUALITY'; reasons=['objective/current-iPhone differential quality gate failed']
    elif diff.get('overall_usability_delta_project_minus_reference') is not None and (num(diff.get('overall_usability_delta_project_minus_reference'),'delta')<p['minimum_overall_usability_delta'] or diff.get('overall_usability_threshold_pass') is not True): decision='REJECT_QUALITY'; reasons=['blind-listening usability delta below policy']
    elif not e8['cancel']: decision='REJECT_CANCELLATION'; reasons=['cancellation truthfulness invariant failed']
    elif cap['cost_headroom_status']=='INSUFFICIENT': decision='REJECT_COST'; reasons=['cost headroom insufficient']
    elif cap['throughput_headroom_status']=='INSUFFICIENT' or e8['state']=='LIVE_AUTHORITY_REJECTED' or not e8['checks'] or e8['degraded']>p['maximum_non_cancel_degraded_fraction'] or metrics['final_failure_fraction']>p['maximum_final_failure_fraction'] or metrics['retry_fraction']>p['maximum_retry_fraction']: decision='REJECT_RELIABILITY'; reasons=['live reliability/recovery thresholds failed']
    elif metrics['mean_execution_total_ms']>p['maximum_mean_execution_total_ms']: decision='REJECT_LATENCY'; reasons=['mean execution latency exceeds policy']
    elif metrics['cost_currency']!=p['cost_currency'] or metrics['mean_cost_per_successful_run']>p['maximum_mean_cost_per_successful_run']: decision='REJECT_COST'; reasons=['actual live cost exceeds policy or currency incomparable']
    if decision is None and (ev['state'] in {'WAITING_REVIEW','WAITING_HUMAN_REVIEW'} or diff.get('comparison_state')=='WAITING_REVIEW'): return pending(r,GENERIC,['HUMAN_REVIEW'],src,locks,execution,metrics)
    if decision is None and diff.get('overall_usability_delta_project_minus_reference') is None: return pending(r,GENERIC,['USABILITY_SCORE'],src,locks,execution,metrics)
    if decision is None and p['require_capacity_attestation'] and (e8['state']=='PENDING_EXTERNAL_EVIDENCE' or any(v=='UNKNOWN' for v in cap.values())): return pending(r,GENERIC,['RUNTIME_CAPACITY'],src,locks,execution,metrics)
    if decision is None and ev['state']!='READY_FOR_HQ_E09_ROUTE_EVALUATION': return pending(r,GENERIC,['GENERIC_ROUTE_EVALUATION_READY'],src,locks,execution,metrics)
    return {'route_id':r,'evidence_path_kind':GENERIC,'decision':decision or 'ACCEPT_WITH_LIMITS','eligible':decision is None,'reasons':reasons or ['all generic hard route gates satisfied; primary ranking separate'],'execution':execution,'metrics':metrics,'source_sha256':src,'source_locks':locks,'score':None}

def margin(v,m): return (1.0 if v<=0 else 0.0) if m<=0 else max(0,min(1,1-v/m))
def score(r,p):
    m=mp(r.get('metrics'),'metrics'); q=max(0,min(1,(num(m.get('overall_usability_delta_project_minus_reference'),'delta')+4)/8)); w=p['ranking_weights']
    return w['quality']*q+w['latency']*margin(num(m.get('mean_execution_total_ms'),'lat'),p['maximum_mean_execution_total_ms'])+w['reliability']*margin(num(m.get('non_cancel_degraded_fraction'),'degraded'),p['maximum_non_cancel_degraded_fraction'])+w['cost']*margin(num(m.get('mean_cost_per_successful_run'),'cost'),p['maximum_mean_cost_per_successful_run'])

def decide_routes(*,plan,route_inputs,repo_root,private_root):
    n=policy_doc(plan); p=n['policy']; repo,private=private_roots(repo_root,private_root); rows=[]
    if not route_inputs: fail('L1E09_ROUTE_SET_EMPTY')
    for rid in sorted(route_inputs):
        item=mp(route_inputs[rid],rid); kind=st(item.get('evidence_path_kind'),'path').upper(); docs=mp(item.get('docs'),'docs'); hs=mp(item.get('hashes'),'hashes')
        if kind==LEGACY:
            if set(docs)!={'e06'} or set(hs)!={'e06'}: fail('L1E09_LEGACY_SOURCE_SET')
            rows.append(legacy_route(rid,mp(docs['e06'],'e06'),sha(hs['e06'],'e06sha'),p))
        elif kind==GENERIC:
            if set(docs)!={'e07','e08','evaluation'} or set(hs)!={'e07','e08','evaluation'}: fail('L1E09_GENERIC_SOURCE_SET')
            rows.append(generic_route(rid,mp(docs['e07'],'e07'),sha(hs['e07'],'e07sha'),mp(docs['e08'],'e08'),sha(hs['e08'],'e08sha'),mp(docs['evaluation'],'evaluation'),sha(hs['evaluation'],'evsha'),p,repo,private))
        else: fail('L1E09_ROUTE_PATH_KIND')
    ok=[x for x in rows if x['eligible']]; pend=[x for x in rows if x['decision']=='PENDING_EXTERNAL_EVIDENCE']
    for x in ok:x['score']=score(x,p)
    state='NO_ACCEPTABLE_ROUTE'
    if pend:
        state='PENDING_EXTERNAL_EVIDENCE'
        for x in ok:x['decision']='ACCEPT_WITH_LIMITS';x['reasons']=['this route passes, but another declared candidate still lacks required live evidence']
    elif ok:
        rank=sorted(ok,key=lambda x:(-x['score'],x['route_id']))
        if len(rank)==1:rank[0]['decision']='ACCEPT_PRIMARY';rank[0]['reasons']=['only fully evaluated route satisfying all hard gates'];state='PRIMARY_SELECTED'
        else:
            gap=rank[0]['score']-rank[1]['score']
            if gap>=p['minimum_primary_score_margin']:rank[0]['decision']='ACCEPT_PRIMARY';rank[0]['reasons']=[f'highest evidence-derived score with margin {gap:.9f}'];state='PRIMARY_SELECTED'
            else:
                state='MULTIPLE_ACCEPTABLE_ROUTES'
                for x in rank:x['decision']='ACCEPT_WITH_LIMITS';x['reasons']=['hard gates pass but score margin is insufficient for automatic primary selection']
    binding={x['route_id']:{'evidence_path_kind':x['evidence_path_kind'],'source_sha256':x['source_sha256'],'source_locks':x['source_locks']} for x in rows}; outcomes={x['route_id']:x['decision'] for x in rows}; ident=csha({'domain':'l1-e09-generic-route-decision-v1','decision_id':n['decision_id'],'policy':p,'evidence_binding':binding,'route_outcomes':outcomes})
    report={'schema_version':1,'tool_version':TOOL,'evidence_kind':'GENERIC_ROUTE_DECISION','evidence_state':NON,'decision_state':state,'parity_claim':'NONE','decision_id':n['decision_id'],'policy':p,'routes':sorted(rows,key=lambda x:x['route_id']),'decision_identity_sha256':ident,'fallback_order':FALLBACK,'supported_evidence_paths':[LEGACY,GENERIC],'privacy':{k:False for k in ('credential_values_emitted','authority_ids_emitted','provider_account_ids_emitted','private_contract_text_emitted','private_paths_emitted','raw_capacity_values_emitted','raw_billing_records_emitted','raw_reviewer_ids_emitted','raw_audio_emitted')},'parity_reason':'E09 unifies route-selection evidence without establishing product PARITY. Real audio, current-iPhone comparison, physical-device integration and HQ PARITY remain mandatory.'}
    report['e09_route_decision_lock_sha256']=csha({'identity':ident,'routes':report['routes'],'policy':p}); return report

def atomic_dump(path,payload):
    p=Path(path);p.parent.mkdir(parents=True,exist_ok=True);t=p.with_name('.'+p.name+'.tmp')
    try:
        with t.open('w',encoding='utf-8') as f:json.dump(payload,f,indent=2,sort_keys=True,ensure_ascii=False,allow_nan=False);f.write('\n');f.flush();os.fsync(f.fileno())
        os.replace(t,p)
    except OSError as e: raise RouteDecisionError('L1E09_WRITE_FAILED') from e

def main(argv=None):
    import argparse,sys
    ap=argparse.ArgumentParser();ap.add_argument('--repo-root',required=True);ap.add_argument('--private-root',required=True);ap.add_argument('--plan',required=True);ap.add_argument('--route-index',required=True);ap.add_argument('--out',required=True);a=ap.parse_args(argv)
    try:
        repo,private=private_roots(a.repo_root,a.private_root); idx=load(a.route_index)
        if idx.get('schema_version')!=1 or idx.get('private') is not True: fail('L1E09_ROUTE_INDEX_SCHEMA')
        inputs={}
        for rid,raw in mp(idx.get('routes'),'routes').items():
            row=mp(raw,rid); kind=st(row.get('evidence_path_kind'),'path').upper(); ev=mp(row.get('evidence'),'evidence'); expected={'e06'} if kind==LEGACY else {'e07','e08','evaluation'} if kind==GENERIC else set()
            if set(ev)!=expected: fail('L1E09_ROUTE_INDEX_SOURCE_SET',rid)
            docs={};hs={}
            for name,rel in ev.items():
                p=private_path(repo,private,rel,f'{rid}.{name}');docs[name]=load(p);hs[name]=fsha(p)
            inputs[rid]={'evidence_path_kind':kind,'docs':docs,'hashes':hs}
        out=decide_routes(plan=load(a.plan),route_inputs=inputs,repo_root=repo,private_root=private);atomic_dump(a.out,out);print(json.dumps({'status':'PASS','decision_state':out['decision_state'],'lock':out['e09_route_decision_lock_sha256']},sort_keys=True));return 0
    except RouteDecisionError as e: print(json.dumps({'status':'FAIL','code':e.code,'message':e.message},sort_keys=True),file=sys.stderr);return 2
if __name__=='__main__': raise SystemExit(main())
