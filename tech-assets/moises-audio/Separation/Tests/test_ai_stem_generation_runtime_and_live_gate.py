import hashlib, tempfile, unittest, wave
from pathlib import Path
from types import SimpleNamespace

from ai_stem_generation_runtime import AIStemGenerationRuntimeAdapter, RuntimeDescriptor, descriptor_template_digest, GenerationRuntimeError, EVIDENCE_STATE
from ai_stem_generation_live_gate import evaluate_live_gate, surface_template_digest, GenerationLiveGateError, REQUIRED_RECOVERY
H=lambda c:c*64; G=lambda c:c*32

class Rec:
    def __init__(self,i,e):
        self.logical_generation_id=i.logical_generation_id; self.request_fingerprint=i.request_fingerprint; self.source_sha256=i.source_sha256; self.target_role=i.target_role; self.generation_mode=i.generation_mode; self.prompt_sha256=i.prompt_sha256; self.reference_audio_sha256=i.reference_audio_sha256; self.credit_state='reserved'; self.execution_state='not_attempted'; self.execution_ref_hash=None; self.progress_percent=0; self.logical_cancelled=False; self.lifecycle_state='reserved'; self.upstream_cancel_state='not_requested'; self.output_sha256=None; self.output_bytes=None
class Contract:
    def __init__(self): self.rs={}
    def reserve(self,*,intent,entitlement): self.rs.setdefault(intent.logical_generation_id,Rec(intent,entitlement)); return self.rs[intent.logical_generation_id]
    def authorize_start(self,g): self.rs[g].execution_state='in_flight'; self.rs[g].lifecycle_state='starting'; return self.rs[g]
    def mark_start_ambiguous(self,g,**kw): self.rs[g].execution_state='ambiguous'; self.rs[g].lifecycle_state='unknown'; return self.rs[g]
    def bind_execution(self,g,*,execution_id): self.rs[g].execution_ref_hash=hashlib.sha256(('l1-a21-execution-v1:'+execution_id).encode()).hexdigest(); self.rs[g].execution_state='bound'; self.rs[g].lifecycle_state='generating'; return self.rs[g]
    def confirm_no_execution(self,g,**kw): self.rs[g].execution_state='confirmed_absent'; return self.rs[g]
    def release_credit_if_no_execution(self,g,**kw): self.rs[g].credit_state='released'; return self.rs[g]
    def commit_credit_usage(self,g,**kw): self.rs[g].credit_state='committed'; return self.rs[g]
    def update_progress(self,g,*,progress_percent):
        if progress_percent<self.rs[g].progress_percent: raise RuntimeError('regress')
        self.rs[g].progress_percent=progress_percent; return self.rs[g]
    def request_cancel(self,g,*,upstream_cancel_supported): self.rs[g].logical_cancelled=True; self.rs[g].lifecycle_state='cancelled'; self.rs[g].upstream_cancel_state='requested' if upstream_cancel_supported and self.rs[g].execution_state=='bound' else 'not_requested'; return self.rs[g]
    def confirm_upstream_cancelled(self,g,**kw): self.rs[g].upstream_cancel_state='confirmed'; return self.rs[g]
    def publish_output(self,g,*,role,artifact_sha256,artifact_bytes,project_controlled,integrity_verified): self.rs[g].output_sha256=artifact_sha256; self.rs[g].output_bytes=artifact_bytes; self.rs[g].lifecycle_state='ready'; self.rs[g].progress_percent=100; return self.rs[g]
    def mark_failed(self,g,**kw): self.rs[g].lifecycle_state='failed'; return self.rs[g]
    def get(self,g): return self.rs[g]
    def privacy_safe_evidence(self,g): return {'schema_version':1,'generation_ref_hash':H('e'),'request_fingerprint':self.rs[g].request_fingerprint,'privacy':{'raw_prompt_emitted':False,'raw_execution_id_emitted':False}}
class Transport:
    def __init__(self,responses): self.responses=list(responses); self.calls=[]
    def request(self,op,payload):
        self.calls.append((op,payload)); x=self.responses.pop(0)
        if isinstance(x,Exception): raise x
        return x

def desc():
    x={'schema_version':1,'evidence_state':EVIDENCE_STATE,'protocol_version':'L1-A22-GENERATION-RUNTIME-v1','runtime_id':'rt','authority_kind':'LOCAL_RUNTIME','runtime_identity_sha256':H('a'),'driver_artifact_sha256':H('b'),'capability_snapshot_sha256':H('c'),'supports_cancel':True,'supports_reconcile':True,'credential_env_names':[]}; x['descriptor_sha256']=descriptor_template_digest(x); return RuntimeDescriptor.from_mapping(x)
def intent(source): return SimpleNamespace(logical_generation_id=G('a'),request_fingerprint=H('f'),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source_duration_seconds=1.0,target_role='drums',generation_mode='AUTO_MATCH',preset_id=None,prompt_sha256=None,reference_audio_sha256=None,variant_index=0)
def ent(): return SimpleNamespace(capability_snapshot_sha256=H('c'))
def response(op,**kw): return {'schema_version':1,'protocol_version':'L1-A22-GENERATION-RUNTIME-v1','operation':op,'runtime_id':'rt','runtime_identity_sha256':H('a'),'request_fingerprint':H('f'),'authority_evidence_sha256':H('d'),'credit_event':'NOT_COMMITTED',**kw}
def wav(p):
    with wave.open(str(p),'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000); w.writeframes(b'\0\0'*80)

class RuntimeRegression(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory(); root=Path(self.t.name); self.src=root/'s.bin'; self.src.write_bytes(b'source'); self.out=root/'runtime'; self.out.mkdir(); self.proj=root/'project'; self.c=Contract()
    def tearDown(self): self.t.cleanup()
    def adapter(self,resps): return AIStemGenerationRuntimeAdapter(contract=self.c,descriptor=desc(),transport=Transport(resps),binding_store_path=Path(self.t.name)/'bind.json',project_output_root=self.proj,runtime_output_root=self.out)
    def test_started_binds(self):
        a=self.adapter([response('start',outcome='STARTED',execution_id='x',credit_event='COMMITTED')]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src); self.assertEqual(self.c.get(G('a')).execution_state,'bound')
    def test_timeout_ambiguous(self):
        a=self.adapter([GenerationRuntimeError('GENRT_TRANSPORT_TIMEOUT',retryable=True)])
        with self.assertRaises(GenerationRuntimeError): a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src)
        self.assertEqual(self.c.get(G('a')).execution_state,'ambiguous')
    def test_reconcile_zero_releases(self):
        a=self.adapter([response('start',outcome='AMBIGUOUS'),response('reconcile',execution_ids=[])]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src); a.reconcile(logical_generation_id=G('a')); self.assertEqual(self.c.get(G('a')).credit_state,'released')
    def test_reconcile_duplicate_fails(self):
        a=self.adapter([response('start',outcome='AMBIGUOUS'),response('reconcile',execution_ids=['a','b'])]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src)
        with self.assertRaises(GenerationRuntimeError): a.reconcile(logical_generation_id=G('a'))
    def test_ready_promotes_wav(self):
        p=self.out/'x.wav'; wav(p); sh=hashlib.sha256(p.read_bytes()).hexdigest(); a=self.adapter([response('start',outcome='STARTED',execution_id='x',credit_event='COMMITTED'),response('observe',state='READY',progress_percent=100,credit_event='COMMITTED',output={'role':'drums','path':str(p),'sha256':sh,'bytes':p.stat().st_size})]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src); a.observe(logical_generation_id=G('a')); self.assertEqual(self.c.get(G('a')).lifecycle_state,'ready')
    def test_output_sha_mismatch_fails(self):
        p=self.out/'x.wav'; wav(p); a=self.adapter([response('start',outcome='STARTED',execution_id='x',credit_event='COMMITTED'),response('observe',state='READY',progress_percent=100,credit_event='COMMITTED',output={'role':'drums','path':str(p),'sha256':H('1'),'bytes':p.stat().st_size})]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src)
        with self.assertRaises(GenerationRuntimeError): a.observe(logical_generation_id=G('a'))
    def test_cancel_discards_ready(self):
        p=self.out/'x.wav'; wav(p); sh=hashlib.sha256(p.read_bytes()).hexdigest(); a=self.adapter([response('start',outcome='STARTED',execution_id='x',credit_event='COMMITTED'),response('cancel',cancel_state='REQUEST_ACCEPTED'),response('observe',state='READY',progress_percent=100,credit_event='COMMITTED',output={'role':'drums','path':str(p),'sha256':sh,'bytes':p.stat().st_size})]); a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src); a.cancel(logical_generation_id=G('a')); a.observe(logical_generation_id=G('a')); self.assertIsNone(self.c.get(G('a')).output_sha256)
    def test_source_mutation_fails(self):
        i=intent(self.src); self.src.write_bytes(b'changed'); a=self.adapter([])
        with self.assertRaises(GenerationRuntimeError): a.start(intent=i,entitlement=ent(),source_path=self.src)
    def test_receipt_privacy(self):
        a=self.adapter([response('start',outcome='AMBIGUOUS')]); r=a.start(intent=intent(self.src),entitlement=ent(),source_path=self.src); self.assertFalse(r['privacy']['raw_execution_id_emitted'])

def cap(conf='CURRENT_IPHONE_CAPTURED'): return {'schema_version':1,'evidence_state':EVIDENCE_STATE,'reference_confidence':conf,'allowed_tiers':['FREE','PREMIUM','PRO'],'allowed_roles':['drums','bass'],'supported_modes':['AUTO_MATCH'],'snapshot_sha256':H('c'),'source_evidence_sha256':H('a')}
def surf():
    x={'schema_version':1,'evidence_kind':'AI_STEM_GENERATION_CURRENT_IPHONE_SURFACE','evidence_state':EVIDENCE_STATE,'platform':'CURRENT_IPHONE_MOISES','capability_snapshot_sha256':H('c'),'role_mode_pairs':[{'role':'drums','mode':'AUTO_MATCH'},{'role':'bass','mode':'AUTO_MATCH'}],'observed_tiers':['FREE','PREMIUM','PRO'],'source_evidence_sha256':H('9')}; x['surface_sha256']=surface_template_digest(x); return x
def rd(): return {'schema_version':1,'evidence_state':EVIDENCE_STATE,'runtime_id':'rt','authority_kind':'LOCAL_RUNTIME','runtime_identity_sha256':H('a'),'capability_snapshot_sha256':H('c'),'descriptor_sha256':H('d')}
def eo(t): return {'schema_version':1,'evidence_state':EVIDENCE_STATE,'plan_tier':t,'capability_snapshot_sha256':H('c'),'generation_enabled':True,'source_evidence_sha256':H({'FREE':'1','PREMIUM':'2','PRO':'3'}[t])}
def lr(i,role,terminal='READY',retry=0,lat=100): return {'schema_version':1,'evidence_kind':'AI_STEM_GENERATION_LIVE_RUN','evidence_state':EVIDENCE_STATE,'parity_claim':'NONE','source_class':'RIGHTS_CLEARED_REAL','runtime_descriptor_sha256':H('d'),'capability_snapshot_sha256':H('c'),'run_id':f'r{i}','target_role':role,'generation_mode':'AUTO_MATCH','terminal_state':terminal,'output_sha256':H('4') if terminal=='READY' else None,'project_controlled_output':terminal=='READY','integrity_verified':terminal=='READY','retry_count':retry,'duplicate_execution_detected':False,'credit_accounting_consistent':True,'cancel_truthful':True,'raw_prompt_emitted':False,'raw_account_id_emitted':False,'raw_execution_id_emitted':False,'latency_ms':lat,'source_sha256':H('5'),'settings_sha256':H('6'),'execution_provenance_sha256':H('7'),'runtime_receipt_sha256':H('8')}
def df(i,role,delta=0,material=False): return {'schema_version':1,'evidence_kind':'AI_STEM_GENERATION_DIFFERENTIAL','project_run_id':f'r{i}','source_sha256':H('5'),'settings_sha256':H('6'),'target_role':role,'generation_mode':'AUTO_MATCH','reference_platform':'CURRENT_IPHONE_MOISES','blind_review':True,'usability_delta_project_minus_reference':delta,'material_inferiority_detected':material,'reference_capture_sha256':H('a'),'review_evidence_sha256':H('b')}
def rc(k): return {'schema_version':1,'evidence_kind':'AI_STEM_GENERATION_RECOVERY_SCENARIO','runtime_descriptor_sha256':H('d'),'scenario_kind':k,'passed':True,'duplicate_execution_detected':False,'project_corruption_detected':False,'credit_accounting_consistent':True,'cancel_truthful':True,'fault_provenance_sha256':H('c'),'authority_evidence_sha256':H('d')}
def pl(): return {'schema_version':1,'evidence_state':EVIDENCE_STATE,'parity_claim':'NONE','plan_id':'p025','policy':{'minimum_successful_runs_per_role_mode':1,'maximum_failure_fraction':0.25,'maximum_retry_fraction':0.5,'maximum_mean_latency_ms':1000,'minimum_mean_usability_delta_project_minus_reference':-0.5,'maximum_material_inferiority_fraction':0.25,'required_tiers':['FREE','PREMIUM','PRO'],'engineering_policy_not_reference_fact':True}}
class GateRegression(unittest.TestCase):
    def good(self,**kw): return evaluate_live_gate(plan=kw.get('plan',pl()),capability=kw.get('capability',cap()),current_iphone_surface=kw.get('surface',surf()),runtime_descriptor=rd(),entitlement_observations=kw.get('entitlements',[eo(x) for x in ['FREE','PREMIUM','PRO']]),runs=kw.get('runs',[lr(1,'drums'),lr(2,'bass')]),differentials=kw.get('diffs',[df(1,'drums'),df(2,'bass')]),recovery_scenarios=kw.get('recovery',[rc(x) for x in REQUIRED_RECOVERY]))
    def test_ready(self): self.assertEqual(self.good()['gate_state'],'READY_FOR_HQ_P025_LIVE_REVIEW')
    def test_cross_platform_waits(self): self.assertEqual(self.good(capability=cap('OFFICIAL_CROSS_PLATFORM_ONLY'))['gate_state'],'WAITING_CURRENT_IPHONE_REFERENCE')
    def test_missing_tier_fails(self):
        with self.assertRaises(GenerationLiveGateError): self.good(entitlements=[eo('FREE'),eo('PREMIUM')])
    def test_synthetic_fails(self):
        x=lr(1,'drums'); x['source_class']='SYNTHETIC'
        with self.assertRaises(GenerationLiveGateError): self.good(runs=[x,lr(2,'bass')])
    def test_duplicate_exec_fails(self):
        x=lr(1,'drums'); x['duplicate_execution_detected']=True
        with self.assertRaises(GenerationLiveGateError): self.good(runs=[x,lr(2,'bass')])
    def test_nonblind_fails(self):
        x=df(1,'drums'); x['blind_review']=False
        with self.assertRaises(GenerationLiveGateError): self.good(diffs=[x,df(2,'bass')])
    def test_missing_pair_waits(self): self.assertEqual(self.good(runs=[lr(1,'drums')],diffs=[df(1,'drums')])['gate_state'],'WAITING_EXTERNAL_EVIDENCE')
    def test_latency_rejects(self): self.assertEqual(self.good(runs=[lr(1,'drums',lat=5000),lr(2,'bass',lat=5000)])['gate_state'],'LIVE_EVALUATION_REJECTED')
    def test_quality_rejects(self): self.assertEqual(self.good(diffs=[df(1,'drums',delta=-2),df(2,'bass',delta=-2)])['gate_state'],'LIVE_EVALUATION_REJECTED')
    def test_material_rejects(self): self.assertEqual(self.good(diffs=[df(1,'drums',material=True),df(2,'bass',material=True)])['gate_state'],'LIVE_EVALUATION_REJECTED')
    def test_recovery_missing_fails(self):
        with self.assertRaises(GenerationLiveGateError): self.good(recovery=[rc(x) for x in list(REQUIRED_RECOVERY)[:3]])
    def test_nonready_output_fails(self):
        x=lr(1,'drums',terminal='FAILED'); x['output_sha256']=H('1')
        with self.assertRaises(GenerationLiveGateError): self.good(runs=[x,lr(2,'bass')],diffs=[df(2,'bass')])
    def test_lock_deterministic(self): self.assertEqual(self.good()['a22_live_gate_lock_sha256'],self.good()['a22_live_gate_lock_sha256'])
    def test_privacy(self): self.assertTrue(all(v is False for v in self.good()['privacy'].values()))

if __name__=='__main__': unittest.main()
