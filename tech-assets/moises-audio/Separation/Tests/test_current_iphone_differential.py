import copy, importlib.util, json, tempfile
from pathlib import Path
MODULE=Path(__file__).resolve().parents[1]/'Evaluation'/'current_iphone_differential.py'
spec=importlib.util.spec_from_file_location('e04',MODULE); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

def h(data:bytes):
 import hashlib; return hashlib.sha256(data).hexdigest()
def base(tmp):
 root=Path(tmp)/'private'; root.mkdir(); repo=Path(tmp)/'repo'; repo.mkdir(); out=root/'out'
 files={}
 for name,data in [('p-voc.wav',b'pvoc'),('p-inst.wav',b'pinst'),('r-voc.wav',b'rvoc'),('r-inst.wav',b'rinst'),('prov.bin',b'video-proof')]:
  p=root/name;p.write_bytes(data);files[name]=(p,h(data))
 mixsha=h(b'exact-source')
 e02={'schema_version':1,'evidence_kind':'RIGHTS_CLEARED_REAL_AUDIO_INTAKE','evidence_state':m.EVIDENCE_STATE,'intake_state':'READY_FOR_HQ_LIVE_AUDIO_GATE','parity_state':m.EVIDENCE_STATE,'a19_corpus_lock_sha256':'1'*64,'e02_rights_intake_lock_sha256':'2'*64,'fixtures':[{'fixture_id':'G2-1','group':'G2','manifest_sha256':'3'*64,'mixture_sha256':mixsha}]}
 e03={'schema_version':1,'evidence_kind':'LIVE_SEPARATION_BENCHMARK','evidence_state':m.EVIDENCE_STATE,'benchmark_state':'READY_FOR_HQ_E03_LIVE_REVIEW','parity_claim':'NONE','source_evidence':{'e02_rights_intake_lock_sha256':'2'*64},'e03_live_benchmark_lock_sha256':'4'*64,'runs':[{'logical_run_id':'case:r001','fixture_id':'G2-1','fixture_group':'G2','mode_id':'two','success':True,'run_manifest_sha256':'5'*64,'artifacts':[{'role':'vocals','sha256':files['p-voc.wav'][1]},{'role':'instrumental','sha256':files['p-inst.wav'][1]}]}]}
 pidx={'schema_version':1,'runs':[{'logical_run_id':'case:r001','run_manifest_sha256':'5'*64,'artifacts':[{'role':'vocals','path':'p-voc.wav','sha256':files['p-voc.wav'][1]},{'role':'instrumental','path':'p-inst.wav','sha256':files['p-inst.wav'][1]}]}]}
 ridx={'schema_version':1,'captures':[{'capture_id':'cap1','reference_system':'MOISES_CURRENT_IPHONE','fixture_id':'G2-1','input_mixture_sha256':mixsha,'app_version':'x','app_build':'1','ios_version':'20','device_model':'iPhone','account_tier':'Pro','reference_mode_label':'2-stem','captured_at':'2026-08-24T00:00:00Z','capture_provenance_path':'prov.bin','capture_provenance_sha256':files['prov.bin'][1],'artifacts':[{'role':'vocals','path':'r-voc.wav','sha256':files['r-voc.wav'][1]},{'role':'instrumental','path':'r-inst.wav','sha256':files['r-inst.wav'][1]}]}]}
 roster={'schema_version':1,'reviewers':[{'reviewer_id':'rev1','independent_from_separator_development':True,'conflict_free':True,'active':True,'replaces_reviewer_id':None,'replacement_reason':None},{'reviewer_id':'rev2','independent_from_separator_development':True,'conflict_free':True,'active':True,'replaces_reviewer_id':None,'replacement_reason':None}]}
 plan={'schema_version':1,'evidence_state':m.EVIDENCE_STATE,'comparison_id':'E04-TEST','policy':{'minimum_reviewers_per_case_role':2,'material_inferiority_vote_fraction':0.5,'min_mean_overall_usability_delta':-0.5},'cases':[{'case_id':'cmp1','fixture_id':'G2-1','project_logical_run_id':'case:r001','reference_capture_id':'cap1'}]}
 return root,repo,out,e02,e03,pidx,ridx,roster,plan

def scores_from(out, project_worse=False, compromise=False):
 pub=json.loads((out/'e04-review-assignments.json').read_text()); reviews=[]
 for a in pub['assignments']:
  rv={'assignment_id':a['assignment_id'],'blind_intact_at_submission':not compromise,'timestamp':'2026-08-24T00:00:00Z'}
  rv['A']={d:3 for d in m.LISTENING_DIMENSIONS};rv['B']={d:3 for d in m.LISTENING_DIMENSIONS};rv['materially_worse']='NONE';reviews.append(rv)
 if project_worse:
  priv=json.loads((out/'e04-reveal-map.private.json').read_text()); idx={x['assignment_id']:x for x in priv['assignments']}
  for rv in reviews:
   x=idx[rv['assignment_id']]
   blind='A' if x['A']['system']=='PROJECT' else 'B'; rv[blind]['overall_practice_usability']=0; other='B' if blind=='A' else 'A';rv[other]['overall_practice_usability']=4;rv['materially_worse']=blind
 return {'schema_version':1,'reviews':reviews}

with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td)
 r=m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 assert r['comparison_state']=='WAITING_REVIEW'
 seed1=json.loads((out/'e04-session.private.json').read_text())['blinding_seed']
 r=m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=scores_from(out),output_dir=out,repo_root=repo)
 assert r['comparison_state']=='READY_FOR_HQ_E04_LIVE_REVIEW'
 seed2=json.loads((out/'e04-session.private.json').read_text())['blinding_seed'];assert seed1==seed2
 text=json.dumps(r);assert 'r-voc.wav' not in text and 'rev1' not in text and seed1 not in text

with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td);m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 r=m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=scores_from(out,True),output_dir=out,repo_root=repo);assert r['comparison_state']=='DIFFERENTIAL_FAIL'

cases=[]
def expect(code, mutate):
 with tempfile.TemporaryDirectory() as td:
  root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td); args=[root,repo,out,e02,e03,pidx,ridx,roster,plan]; mutate(args)
  try:m.run_e04(root=args[0],plan=args[8],e02_evidence=args[3],e03_evidence=args[4],project_index=args[5],reference_index=args[6],reviewer_roster=args[7],scores={'schema_version':1,'reviews':[]},output_dir=args[2],repo_root=args[1])
  except m.DifferentialError as ex: assert ex.code==code,(ex.code,code);cases.append(code);return
  raise AssertionError('expected '+code)
expect('L1E04_E03_NOT_READY',lambda a:a[4].__setitem__('benchmark_state','LIVE_BENCHMARK_FAILED'))
expect('L1E04_E03_E02_LOCK_MISMATCH',lambda a:a[4]['source_evidence'].__setitem__('e02_rights_intake_lock_sha256','9'*64))
expect('L1E04_E03_FIXTURE_GROUP_MISMATCH',lambda a:a[3]['fixtures'][0].__setitem__('group','G1'))
expect('L1E04_PROJECT_RUN_SHA_MISMATCH',lambda a:a[5]['runs'][0].__setitem__('run_manifest_sha256','9'*64))
expect('L1E04_PROJECT_ARTIFACT_E03_MISMATCH',lambda a:a[5]['runs'][0]['artifacts'][0].__setitem__('sha256','9'*64))
expect('L1E04_REFERENCE_INPUT_MISMATCH',lambda a:a[6]['captures'][0].__setitem__('input_mixture_sha256','9'*64))
expect('L1E04_CAPTURE_PROVENANCE_SHA_MISMATCH',lambda a:a[6]['captures'][0].__setitem__('capture_provenance_sha256','9'*64))
expect('L1E04_REVIEWER_INDEPENDENCE_REQUIRED',lambda a:a[7]['reviewers'][0].__setitem__('independent_from_separator_development',False))
expect('L1E04_REVIEWER_COUNT_INSUFFICIENT',lambda a:a[8]['policy'].__setitem__('minimum_reviewers_per_case_role',3))
with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td); (repo/'rv.wav').write_bytes(b'rvoc');ridx['captures'][0]['artifacts'][0]['path']='../repo/rv.wav'
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_PATH_UNSAFE'
 else:raise AssertionError
with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td);m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=scores_from(out,False,True),output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_BLINDNESS_COMPROMISED'
 else:raise AssertionError
 s=scores_from(out);s['reviews'].append(copy.deepcopy(s['reviews'][0]))
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=s,output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_REVIEW_DUPLICATE'
 else:raise AssertionError
with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td);m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo); plan['policy']['min_mean_overall_usability_delta']=-1.0
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_SESSION_IDENTITY_MISMATCH'
 else:raise AssertionError
print('E04_TESTS_PASS', 2+len(cases)+4)
expect('L1E04_E03_ARTIFACTS_EMPTY',lambda a:a[4]['runs'][0].__setitem__('artifacts',[]))
expect('L1E04_REFERENCE_SYSTEM',lambda a:a[6]['captures'][0].__setitem__('reference_system','OTHER'))
with tempfile.TemporaryDirectory() as td:
 root,repo,out,e02,e03,pidx,ridx,roster,plan=base(td);m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores={'schema_version':1,'reviews':[]},output_dir=out,repo_root=repo)
 s=scores_from(out);s['reviews'][0]['A']['bleed']=5
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=s,output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_REVIEW_SCORE'
 else:raise AssertionError
 s=scores_from(out);s['reviews'][0]['assignment_id']='f'*64
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=s,output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_ASSIGNMENT_UNKNOWN'
 else:raise AssertionError
 s=scores_from(out);s['reviews'][0]['materially_worse']='BOTH'
 try:m.run_e04(root=root,plan=plan,e02_evidence=e02,e03_evidence=e03,project_index=pidx,reference_index=ridx,reviewer_roster=roster,scores=s,output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_MATERIAL_VOTE'
 else:raise AssertionError
with tempfile.TemporaryDirectory() as td:
 repo=Path(td)/'repo';repo.mkdir();root=repo/'private';root.mkdir();out=root/'out'
 try:m.run_e04(root=root,plan={},e02_evidence={},e03_evidence={},project_index={},reference_index={},reviewer_roster={},scores={},output_dir=out,repo_root=repo)
 except m.DifferentialError as ex: assert ex.code=='L1E04_PRIVATE_ROOT_IN_REPOSITORY'
 else:raise AssertionError
print('E04_ADDITIONAL_PASS',6)
