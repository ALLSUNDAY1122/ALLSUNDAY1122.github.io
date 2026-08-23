from __future__ import annotations
import importlib.util, sys, types
from pathlib import Path
HERE=Path(__file__).resolve().parent; EVAL=HERE.parent/'Evaluation'; sys.path.insert(0,str(EVAL))

common=types.ModuleType('differential_common')
common.EVIDENCE_STATE='NON_PARITY_EVIDENCE_ONLY'; common.SCHEMA_VERSION=1; common.EXIT_CANDIDATE_FAIL=4; common.EXIT_EXTERNAL_INPUT_REQUIRED=3
class GateError(ValueError):
 def __init__(self,code,message='',exit_code=2): super().__init__(message); self.code=code; self.message=message; self.exit_code=exit_code
common.GateError=GateError
for name in ['dump_json','load_json','req_map','validate_fixture_for_batch','validate_plan','validate_run','validate_system_identity']:
 setattr(common,name,lambda *a,**k: None)
sys.modules['differential_common']=common
execute=types.ModuleType('differential_execute')
for n in ['build_comparison_inputs','evaluate_all_runs','execute_project_cases']: setattr(execute,n,lambda *a,**k: None)
sys.modules['differential_execute']=execute
review=types.ModuleType('differential_review')
for n in ['build_blind_review','calculate_acceptance','parse_reviews']: setattr(review,n,lambda *a,**k: None)
sys.modules['differential_review']=review
spec=importlib.util.spec_from_file_location('gate_a20',EVAL/'differential_gate.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
count=0

def ok(x):
 global count
 assert x; count+=1
ok(m._normalize_golden_lock({'golden_corpus_lock_sha256':'a'*64},'PARITY_CANDIDATE')=='a'*64)
ok(m._normalize_golden_lock({},'REGRESSION') is None)
try: m._normalize_golden_lock({},'PARITY_CANDIDATE')
except GateError as e: ok(e.code=='L1A20_GOLDEN_LOCK_REQUIRED' and e.exit_code==3)
else: raise AssertionError
try: m._normalize_golden_lock({'golden_corpus_lock_sha256':'bad'},'REGRESSION')
except GateError as e: ok(e.code=='L1A20_GOLDEN_LOCK_INVALID')
else: raise AssertionError
ok(m.build_parser().prog is not None)

class R:
 def __init__(self): self.batch_identity_sha256='b'*64; self.state=None; self.hashes=None
 def bind_global_artifact(self,*a,**k): pass
 def set_state(self,s): self.state=s
 def set_review_hashes(self,**kw): self.hashes=kw
r=R()
m.build_blind_review=lambda *a,**k:(Path('/tmp/w.json'),Path('/tmp/r.json'),Path('/tmp/s.json'))
m.load_reviewer_roster=lambda *a,**k:['R1']
m.build_reviewer_assignments=lambda *a,**k:[{'assignment_id':'A1','case_id':'C','stem':'vocals','system_blind_id':'A','reviewer_id':'R1','replaces_assignment_id':None}]
m.load_replacements=lambda *a,**k:[]
m.apply_replacements=lambda base,repl,batch:(base,[])
m.reviewer_assignment_document=lambda *a,**k:{}
m.dump_json=lambda *a,**k:None
def no_reviews(*a,**k): raise GateError('L1M04_BLIND_REVIEW_REQUIRED','none',exit_code=3)
m.parse_reviews=no_reviews
m.filter_reviews_for_active_assignments=lambda reviews,base,active,hist:([],['A1'],{'missing_assignment_count':1})
m.sha256_json=lambda v:'c'*64
try:
 m._review_stage({'batch_id':'B','min_reviewers':1},Path('/tmp'),Path('/tmp'),r)
except m.ResumeError as e:
 ok(e.code=='L1A20_REVIEW_ASSIGNMENTS_INCOMPLETE' and e.exit_code==3)
 ok(r.state=='WAITING_REVIEW')
 ok(r.hashes['missing_assignment_ids']==['A1'])
else: raise AssertionError

print(f'L1_A20_GATE_IMPORT_PASS assertions={count}')
