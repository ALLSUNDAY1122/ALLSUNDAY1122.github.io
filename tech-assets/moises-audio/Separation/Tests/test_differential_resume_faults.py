from __future__ import annotations
import json, sys, tempfile
from pathlib import Path
HERE=Path(__file__).resolve().parent; EVAL=HERE.parent/'Evaluation'; sys.path.insert(0,str(EVAL))
from differential_resume import DifferentialResumeLedger, ResumeError, build_reviewer_assignments

PASS=0
def ok(x,n):
 global PASS
 if not x: raise AssertionError(n)
 PASS+=1

def expect(code,fn,n):
 global PASS
 try: fn()
 except ResumeError as e:
  if e.code!=code: raise AssertionError(f'{n}: {e.code}')
  PASS+=1; return
 raise AssertionError(n)

def mk(root,n=24):
 cases=[]
 for i in range(n):
  f=root/f'f/{i}.json'; f.parent.mkdir(parents=True,exist_ok=True); f.write_text(json.dumps({'id':i}))
  cases.append({'case_id':f'C{i:02d}','genre':f'g{i%4}','duration_bucket':['short','medium','long'][i%3],
   'target_roles':['vocals','drums','bass','other'],'fixture_path':f,'project_run_path':root/f'p/{i}.json','reference_run_path':root/f'r/{i}.json'})
 return {'batch_id':'B24','purpose':'REGRESSION','max_attempts':3,'timeout_seconds':99.0,'command':['driver','{idempotency_key}'],
 'credential_env_names':['Z','A'],'legal_gate':{'commercial_approval_basis_id':'C','privacy_retention_approval_id':'P','reference_comparison_rights_id':'R','provider_idempotency_contract_id':'I'},
 'policy':{'policy_id':'P','a':1,'b':2},'cases':cases}

def main():
 global PASS
 with tempfile.TemporaryDirectory() as td:
  root=Path(td); cfg=mk(root); out=root/'out'; tool=root/'tool.py'; tool.write_text('v1')
  golden='a'*64
  l=DifferentialResumeLedger(root,out,cfg,golden_corpus_lock_sha256=golden,toolchain_paths=[tool])
  ok(len(l.data['cases'])==24,'24-cases')
  ok(l.data['golden_corpus_lock_sha256']==golden,'golden-bound')
  ok(l.semantic['credential_env_names']==['A','Z'],'env-order-normalized')
  ok(l.semantic['toolchain'][0]['name']=='tool.py','toolchain-name')
  ok(len(l.semantic['toolchain'][0]['sha256'])==64,'toolchain-hash')
  ids=[v['case_identity_sha256'] for v in l.data['cases'].values()]; ok(len(set(ids))==24,'case-ids-unique')
  assignments=build_reviewer_assignments(cfg,l.batch_identity_sha256,['R3','R1','R2'],min_reviewers=2)
  ok(len(assignments)==24*4*2*2,'24-case-assignment-scale')
  ok(len({a['assignment_id'] for a in assignments})==len(assignments),'assignment-scale-unique')
  assignments2=build_reviewer_assignments(cfg,l.batch_identity_sha256,['R1','R2','R3'],min_reviewers=2)
  ok(assignments==assignments2,'assignment-scale-deterministic')

  tool.write_text('v2')
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg,golden_corpus_lock_sha256=golden,toolchain_paths=[tool]),'toolchain-drift')
  tool.write_text('v1')
  cfg_cmd=mk(root); cfg_cmd['command']=['driver2','{idempotency_key}']
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg_cmd,golden_corpus_lock_sha256=golden,toolchain_paths=[tool]),'command-drift')
  cfg_legal=mk(root); cfg_legal['legal_gate']=dict(cfg_legal['legal_gate']); cfg_legal['legal_gate']['reference_comparison_rights_id']='R2'
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg_legal,golden_corpus_lock_sha256=golden,toolchain_paths=[tool]),'legal-drift')
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg,golden_corpus_lock_sha256='b'*64,toolchain_paths=[tool]),'golden-drift')
  cfg_timeout=mk(root); cfg_timeout['timeout_seconds']=100.0
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg_timeout,golden_corpus_lock_sha256=golden,toolchain_paths=[tool]),'execution-drift')

  cfg['cases'][0]['fixture_path'].write_text('{"changed":true}')
  expect('L1A20_BATCH_IDENTITY_MISMATCH',lambda:DifferentialResumeLedger(root,out,cfg,golden_corpus_lock_sha256=golden,toolchain_paths=[tool]),'fixture-byte-drift')

 with tempfile.TemporaryDirectory() as td:
  root=Path(td); cfg=mk(root,2); out=root/'out'; l=DifferentialResumeLedger(root,out,cfg)
  d=json.loads(l.path.read_text()); d['schema_version']=99; l.path.write_text(json.dumps(d))
  expect('L1A20_LEDGER_SCHEMA_UNSUPPORTED',lambda:DifferentialResumeLedger(root,out,cfg),'ledger-version')
  l.path.write_text('{bad')
  expect('L1A20_LEDGER_CORRUPT',lambda:DifferentialResumeLedger(root,out,cfg),'ledger-corrupt')

 with tempfile.TemporaryDirectory() as td:
  root=Path(td); cfg=mk(root,1); out=root/'out'; l=DifferentialResumeLedger(root,out,cfg)
  h='1'*64
  l.set_review_hashes(roster_sha256=h,assignments_sha256='2'*64,replacements_sha256='3'*64,scores_sha256='4'*64,active_assignment_sha256='5'*64,missing_assignment_ids=['x'])
  expect('L1A20_REVIEW_ASSIGNMENT_MUTATED',lambda:l.set_review_hashes(roster_sha256='6'*64,assignments_sha256='2'*64,replacements_sha256='3'*64,scores_sha256='4'*64,active_assignment_sha256='5'*64,missing_assignment_ids=['x']),'roster-freeze')
  expect('L1A20_REVIEW_ASSIGNMENT_MUTATED',lambda:l.set_review_hashes(roster_sha256=h,assignments_sha256='7'*64,replacements_sha256='3'*64,scores_sha256='4'*64,active_assignment_sha256='5'*64,missing_assignment_ids=['x']),'assignment-freeze')
  l.set_review_hashes(roster_sha256=h,assignments_sha256='2'*64,replacements_sha256='8'*64,scores_sha256='9'*64,active_assignment_sha256='a'*64,missing_assignment_ids=[])
  ok(l.data['review']['replacements_sha256']=='8'*64,'replacement-evolves-precomplete')
  ok(l.data['review']['scores_sha256']=='9'*64,'scores-evolve-precomplete')
  acceptance=root/'out/acceptance.json'; acceptance.write_text('{}')
  audit=l.finalize(acceptance); ok(audit['evidence_chain_sha256'] is not None,'finalize-chain')
  expect('L1A20_COMPLETE_REVIEW_MUTATED',lambda:l.set_review_hashes(roster_sha256=h,assignments_sha256='2'*64,replacements_sha256='b'*64,scores_sha256='9'*64,active_assignment_sha256='a'*64,missing_assignment_ids=[]),'review-immutable-after-complete')

 print(f'L1_A20_RESUME_FAULTS_PASS assertions={PASS}')
if __name__=='__main__': main()
