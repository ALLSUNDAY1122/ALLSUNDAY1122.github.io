from __future__ import annotations
import importlib.util, json, sys, tempfile, types
from pathlib import Path

HERE=Path(__file__).resolve().parent
EVAL=HERE.parent/'Evaluation'
sys.path.insert(0,str(EVAL))
from differential_resume import DifferentialResumeLedger, ResumeError

fake=types.ModuleType('differential_common')
fake.EVIDENCE_STATE='NON_PARITY_EVIDENCE_ONLY'; fake.SCHEMA_VERSION=1
class GateError(ValueError):
    def __init__(self,code,msg='x'): super().__init__(msg); self.code=code
fake.GateError=GateError
fake.dump_json=lambda path,value: (path.parent.mkdir(parents=True,exist_ok=True),path.write_text(json.dumps(value,sort_keys=True)))
fake.load_json=lambda path: json.loads(path.read_text())
fake.relpath=lambda root,path: path.resolve().relative_to(root.resolve()).as_posix()
fake.req_map=lambda value,field:value if isinstance(value,dict) else (_ for _ in ()).throw(GateError('TYPE'))
fake.stable_idempotency_key=lambda batch,case:'stable-'+batch+'-'+case
fake.command_for_case=lambda template,root,case,batch:list(template)
def validate_run(evaluator,root,case,path,timeout):
    if not path.is_file(): raise GateError('MISSING')
    obj=json.loads(path.read_text())
    if obj.get('valid') is not True: raise GateError('INVALID')
fake.validate_run=validate_run
fake.validate_system_identity=lambda path,expected: None
import hashlib
fake.sha256_file=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def evaluator_call(*args,**kwargs): return {'status':'PASS'}
fake.evaluator_call=evaluator_call
sys.modules['differential_common']=fake
spec=importlib.util.spec_from_file_location('differential_execute_under_test',EVAL/'differential_execute.py')
de=importlib.util.module_from_spec(spec); spec.loader.exec_module(de)

PASS=0
def ok(x,n):
    global PASS
    if not x: raise AssertionError(n)
    PASS+=1

def cfg(root,project):
    fixture=root/'fixture.json'; fixture.write_text('{}')
    ref=root/'ref.json'
    return {'batch_id':'B','purpose':'REGRESSION','max_attempts':2,'timeout_seconds':5.0,
      'command':['ignored'],'credential_env_names':[],'legal_gate':{},'policy':{'policy_id':'P'},
      'cases':[{'case_id':'C','genre':'rock','duration_bucket':'short','target_roles':['other','vocals'],
       'fixture_path':fixture,'project_run_path':project,'reference_run_path':ref}]}

class Completed:
    returncode=0; stdout=''; stderr=''

def main():
  global PASS
  with tempfile.TemporaryDirectory() as td:
    root=Path(td); out=root/'out'; project=root/'project.json'; c=cfg(root,project)
    ledger=DifferentialResumeLedger(root,out,c)
    calls=[]
    def successful_run(*args,**kwargs):
      calls.append(1); project.write_text(json.dumps({'valid':True})); return Completed()
    de.subprocess.run=successful_run
    doc=de.execute_project_cases(c,Path('eval'),root,out,resume=ledger)
    ok(len(calls)==1,'first-exec')
    ok(doc['cases'][0]['success'] is True,'success')
    ok(doc['cases'][0]['attempts']==1,'attempt-one')
    ok(ledger.data['cases']['C']['project_source']=='EXECUTED','source-executed')
    ok(ledger.data['cases']['C']['attempts'][0]['status']=='PASS','attempt-pass')
    ok('batch_execution' not in ledger.data['global_artifacts'],'execution-not-frozen-mid-resume')

    ledger2=DifferentialResumeLedger(root,out,c)
    de.subprocess.run=lambda *a,**k: (_ for _ in ()).throw(AssertionError('should not run'))
    doc2=de.execute_project_cases(c,Path('eval'),root,out,resume=ledger2)
    ok(doc2['cases'][0]['attempts']==1,'history-retained')
    ok(doc2['cases'][0]['success'] is True,'restart-success')

    project.unlink()
    try:
      de.execute_project_cases(c,Path('eval'),root,out,resume=ledger2)
    except ResumeError as exc:
      ok(exc.code=='L1A20_ARTIFACT_MISSING','missing-bound-fail')
    else: raise AssertionError('missing bound artifact accepted')

  with tempfile.TemporaryDirectory() as td:
    root=Path(td); out=root/'out'; project=root/'project.json'; c=cfg(root,project)
    ledger=DifferentialResumeLedger(root,out,c)
    ledger.begin_attempt('C'); project.write_text(json.dumps({'valid':True}))
    de.subprocess.run=lambda *a,**k: (_ for _ in ()).throw(AssertionError('should not rerun recovered output'))
    doc=de.execute_project_cases(c,Path('eval'),root,out,resume=ledger)
    ok(doc['cases'][0]['success'] is True,'crash-output-recovered')
    ok(ledger.data['cases']['C']['attempts'][0]['status']=='RECOVERED_OUTPUT','crash-attempt-marked')
    ok(ledger.data['cases']['C']['project_source']=='RECOVERED_AFTER_TERMINATION','crash-source')

  with tempfile.TemporaryDirectory() as td:
    root=Path(td); out=root/'out'; project=root/'project.json'; c=cfg(root,project)
    ledger=DifferentialResumeLedger(root,out,c)
    ledger.begin_attempt('C')
    calls=[]
    def fail_run(*a,**k): calls.append(1); return type('X',(),{'returncode':9,'stdout':'','stderr':''})()
    de.subprocess.run=fail_run
    doc=de.execute_project_cases(c,Path('eval'),root,out,resume=ledger)
    ok(len(calls)==1,'only-one-new-attempt')
    ok(doc['cases'][0]['attempts']==2,'attempt-cap-across-restart')
    ok(ledger.data['cases']['C']['attempts'][0]['status']=='INTERRUPTED','first-interrupted')
    ok(ledger.data['cases']['C']['attempts'][1]['status']=='FAIL','second-fail')
    ok(doc['cases'][0]['success'] is False,'failed-after-cap')

  print(f'L1_A20_EXECUTE_RESUME_PASS assertions={PASS}')
if __name__=='__main__': main()
