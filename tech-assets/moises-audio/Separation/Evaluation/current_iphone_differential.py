"""L1-E04 current-iPhone blind differential listening gate (NON-PARITY)."""
from __future__ import annotations
import argparse, hashlib, hmac, json, math, os, re, secrets, sys
from datetime import datetime
from pathlib import Path
from typing import Any, Mapping

V=1; TOOL="L1-E04-v1"; NON="NON_PARITY_EVIDENCE_ONLY"; EVIDENCE_STATE=NON; EXT=3
LISTENING_DIMENSIONS=("target_preservation","bleed","musical_noise","transient_integrity","timbre_formant_integrity","stereo_phase_integrity","low_frequency_integrity","reverb_ambience","overall_practice_usability")
DIMS=LISTENING_DIMENSIONS
ID=re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$"); SHA=re.compile(r"^[0-9a-f]{64}$")
class E04Error(ValueError):
 def __init__(self,code,msg,exit_code=2): super().__init__(f"{code}: {msg}"); self.code=code; self.message=msg; self.exit_code=exit_code
DifferentialError=E04Error
def fail(c,m="E04 validation failed",external=False): return E04Error(c,m,EXT if external else 2)
def mp(x,f):
 if not isinstance(x,Mapping): raise fail("L1E04_SCHEMA_TYPE",f+" must be object")
 return x
def st(x,f):
 if not isinstance(x,str) or not x.strip(): raise fail("L1E04_SCHEMA_REQUIRED",f+" required")
 return x.strip()
def bl(x,f):
 if not isinstance(x,bool): raise fail("L1E04_SCHEMA_TYPE",f+" must be boolean")
 return x
def num(x,f,lo=None,hi=None):
 if isinstance(x,bool) or not isinstance(x,(int,float)) or not math.isfinite(float(x)): raise fail("L1E04_SCHEMA_NUMBER",f+" invalid")
 x=float(x)
 if lo is not None and x<lo or hi is not None and x>hi: raise fail("L1E04_SCHEMA_RANGE",f+" out of range")
 return x
def integer(x,f,lo=0):
 if isinstance(x,bool) or not isinstance(x,int) or x<lo: raise fail("L1E04_SCHEMA_INTEGER",f+" invalid")
 return x
def sh(x,f):
 x=st(x,f).lower().removeprefix("sha256:")
 if not SHA.fullmatch(x): raise fail("L1E04_SHA256_INVALID",f+" invalid")
 return x
def sj(x): return hashlib.sha256(json.dumps(x,sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def sf(p):
 h=hashlib.sha256()
 try:
  with p.open("rb") as f:
   for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
 except OSError as e: raise fail("L1E04_FILE_UNREADABLE","cannot hash file") from e
 return h.hexdigest()
def inside(c,p):
 try:c.resolve().relative_to(p.resolve());return True
 except ValueError:return False
def file(root,raw,f):
 r=Path(st(raw,f));
 if r.is_absolute() or ".." in r.parts: raise fail("L1E04_PATH_UNSAFE",f+" unsafe")
 b=root.resolve(); p=(b/r).resolve()
 try:p.relative_to(b)
 except ValueError as e: raise fail("L1E04_PATH_OUTSIDE_ROOT",f+" escapes root") from e
 cur=b
 for q in r.parts:
  cur/=q
  if cur.is_symlink(): raise fail("L1E04_SYMLINK_FORBIDDEN",f+" symlink")
 if not p.is_file(): raise fail("L1E04_FILE_MISSING",f+" missing",True)
 return p
def load(p,f):
 try:return mp(json.loads(Path(p).read_text(encoding="utf-8")),f)
 except E04Error:raise
 except Exception as e:raise fail("L1E04_JSON_INVALID","cannot read "+f) from e
def dump(p,v):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);t=p.with_name("."+p.name+".tmp")
 with t.open("w",encoding="utf-8") as f: json.dump(v,f,indent=2,sort_keys=True,ensure_ascii=False,allow_nan=False);f.write("\n");f.flush();os.fsync(f.fileno())
 os.replace(t,p)
def iso(x,f):
 s=st(x,f)
 try:
  d=datetime.fromisoformat(s.replace("Z","+00:00")); assert d.tzinfo is not None
 except Exception as e: raise fail("L1E04_TIME_INVALID",f+" invalid") from e
 return s

def e02doc(e):
 if e.get("schema_version")!=1 or e.get("evidence_kind")!="RIGHTS_CLEARED_REAL_AUDIO_INTAKE": raise fail("L1E04_E02_SCHEMA","E02 invalid")
 if e.get("evidence_state")!=NON or e.get("parity_state")!=NON: raise fail("L1E04_E02_STATE","E02 must remain NON-PARITY")
 if e.get("intake_state")!="READY_FOR_HQ_LIVE_AUDIO_GATE": raise fail("L1E04_E02_NOT_READY","E02 not ready",True)
 fs={}
 for z in e.get("fixtures",[]):
  z=mp(z,"e02.fixture");fid=st(z.get("fixture_id"),"fixture_id")
  if fid in fs: raise fail("L1E04_E02_DUPLICATE","duplicate fixture")
  fs[fid]={"group":st(z.get("group"),"group"),"mix":sh(z.get("mixture_sha256"),"mixture_sha256")}
 return {"lock":sh(e.get("e02_rights_intake_lock_sha256"),"e02_lock"),"a19":sh(e.get("a19_corpus_lock_sha256"),"a19_lock"),"fixtures":fs}
def e03doc(e,e02):
 if e.get("schema_version")!=1 or e.get("evidence_kind")!="LIVE_SEPARATION_BENCHMARK": raise fail("L1E04_E03_SCHEMA","E03 invalid")
 if e.get("evidence_state")!=NON or e.get("parity_claim")!="NONE": raise fail("L1E04_E03_STATE","E03 must remain NON-PARITY")
 if e.get("benchmark_state")!="READY_FOR_HQ_E03_LIVE_REVIEW": raise fail("L1E04_E03_NOT_READY","E03 not ready",True)
 if sh(mp(e.get("source_evidence"),"source_evidence").get("e02_rights_intake_lock_sha256"),"e03.e02_lock")!=e02["lock"]: raise fail("L1E04_E03_E02_LOCK_MISMATCH","E03/E02 mismatch")
 runs={}
 for z in e.get("runs",[]):
  z=mp(z,"e03.run"); lid=st(z.get("logical_run_id"),"logical_run_id")
  if lid in runs: raise fail("L1E04_E03_RUN_DUPLICATE","duplicate E03 run")
  fid=st(z.get("fixture_id"),"fixture_id"); grp=st(z.get("fixture_group"),"fixture_group"); er=e02["fixtures"].get(fid)
  if not er or er["group"]!=grp: raise fail("L1E04_E03_FIXTURE_GROUP_MISMATCH","E03 fixture/group differs from E02")
  arts={st(a.get("role"),"role").lower():sh(a.get("sha256"),"artifact sha") for a in z.get("artifacts",[]) if isinstance(a,Mapping)}
  ok=z.get("success") is True
  if ok and not arts: raise fail("L1E04_E03_ARTIFACTS_EMPTY","successful E03 run has no artifacts")
  runs[lid]={"ok":ok,"fixture":fid,"group":grp,"mode":st(z.get("mode_id"),"mode_id"),"runsha":sh(z.get("run_manifest_sha256"),"run sha") if ok else None,"arts":arts}
 return {"lock":sh(e.get("e03_live_benchmark_lock_sha256"),"e03_lock"),"runs":runs}
def rosterdoc(r):
 if r.get("schema_version")!=1: raise fail("L1E04_ROSTER_SCHEMA","roster invalid")
 active=[];known=set()
 for z in r.get("reviewers",[]):
  z=mp(z,"reviewer");rid=st(z.get("reviewer_id"),"reviewer_id")
  if not ID.fullmatch(rid) or rid in known: raise fail("L1E04_REVIEWER_ID","bad reviewer id")
  known.add(rid); a=bl(z.get("active"),"active")
  if a and (not bl(z.get("independent_from_separator_development"),"independent") or not bl(z.get("conflict_free"),"conflict_free")): raise fail("L1E04_REVIEWER_INDEPENDENCE_REQUIRED","reviewer not independent")
  if a:active.append(rid)
 if not active: raise fail("L1E04_REVIEWER_ROSTER_EMPTY","no active reviewer",True)
 return sorted(active)
def projectdoc(idx,root,e03):
 out={}
 for z in idx.get("runs",[]):
  z=mp(z,"project run");lid=st(z.get("logical_run_id"),"logical_run_id");r=e03["runs"].get(lid)
  if not r or not r["ok"]:raise fail("L1E04_PROJECT_RUN_NOT_E03_SUCCESS","project run not E03 success")
  if sh(z.get("run_manifest_sha256"),"run sha")!=r["runsha"]:raise fail("L1E04_PROJECT_RUN_SHA_MISMATCH","project run changed")
  arts={}
  for a in z.get("artifacts",[]):
   a=mp(a,"artifact");role=st(a.get("role"),"role").lower();p=file(root,a.get("path"),"project artifact");s=sh(a.get("sha256"),"artifact sha")
   if sf(p)!=s or r["arts"].get(role)!=s:raise fail("L1E04_PROJECT_ARTIFACT_E03_MISMATCH","project artifact changed")
   arts[role]={"path":p,"sha":s}
  if set(arts)!=set(r["arts"]):raise fail("L1E04_PROJECT_ROLE_SET_MISMATCH","project roles changed")
  out[lid]={"fixture":r["fixture"],"group":r["group"],"arts":arts}
 return out
def refdoc(idx,root,repo,e02):
 out={}
 for z in idx.get("captures",[]):
  z=mp(z,"reference capture");cid=st(z.get("capture_id"),"capture_id")
  if cid in out:raise fail("L1E04_REFERENCE_CAPTURE_DUPLICATE","duplicate capture")
  if st(z.get("reference_system"),"reference_system")!="MOISES_CURRENT_IPHONE":raise fail("L1E04_REFERENCE_SYSTEM","wrong reference system")
  fid=st(z.get("fixture_id"),"fixture_id"); fr=e02["fixtures"].get(fid)
  if not fr or fr["group"]!="G2":raise fail("L1E04_REFERENCE_G2_REQUIRED","E04 reference must be G2")
  if sh(z.get("input_mixture_sha256"),"input sha")!=fr["mix"]:raise fail("L1E04_REFERENCE_INPUT_MISMATCH","reference input differs")
  for f in ("app_version","app_build","ios_version","device_model","account_tier","reference_mode_label"):st(z.get(f),f)
  iso(z.get("captured_at"),"captured_at");p=file(root,z.get("capture_provenance_path"),"capture provenance");ps=sh(z.get("capture_provenance_sha256"),"provenance sha")
  if sf(p)!=ps:raise fail("L1E04_CAPTURE_PROVENANCE_SHA_MISMATCH","capture provenance changed")
  if repo and inside(p,repo):raise fail("L1E04_REFERENCE_ASSET_IN_REPOSITORY","reference provenance in repo")
  arts={}
  for a in z.get("artifacts",[]):
   a=mp(a,"reference artifact");role=st(a.get("role"),"role").lower();p=file(root,a.get("path"),"reference artifact");s=sh(a.get("sha256"),"reference sha")
   if sf(p)!=s:raise fail("L1E04_REFERENCE_ARTIFACT_SHA_MISMATCH","reference artifact changed")
   if repo and inside(p,repo):raise fail("L1E04_REFERENCE_ASSET_IN_REPOSITORY","reference audio in repo")
   arts[role]={"path":p,"sha":s}
  if not arts:raise fail("L1E04_REFERENCE_ARTIFACTS_EMPTY","reference artifacts missing")
  out[cid]={"fixture":fid,"arts":arts,"provenance_sha":ps,"device_identity_sha":sj({k:z[k] for k in ("app_version","app_build","ios_version","device_model","account_tier","reference_mode_label")})}
 return out

def plandoc(p,e02,proj,ref,active):
 if p.get("schema_version")!=1 or p.get("evidence_state")!=NON:raise fail("L1E04_PLAN_SCHEMA","plan invalid")
 cid=st(p.get("comparison_id"),"comparison_id");pol=mp(p.get("policy"),"policy");n=integer(pol.get("minimum_reviewers_per_case_role"),"min reviewers",2)
 if len(active)<n:raise fail("L1E04_REVIEWER_COUNT_INSUFFICIENT","not enough reviewers",True)
 vote=num(pol.get("material_inferiority_vote_fraction"),"vote",0,1);use=num(pol.get("min_mean_overall_usability_delta"),"usability",-4,4);cases=[];seen=set()
 for z in p.get("cases",[]):
  z=mp(z,"case");case=st(z.get("case_id"),"case_id");fid=st(z.get("fixture_id"),"fixture_id");lid=st(z.get("project_logical_run_id"),"project run");cap=st(z.get("reference_capture_id"),"reference capture")
  if case in seen:raise fail("L1E04_CASE_ID","duplicate case")
  seen.add(case)
  if not e02["fixtures"].get(fid) or e02["fixtures"][fid]["group"]!="G2":raise fail("L1E04_CASE_G2_REQUIRED","case must be G2")
  pr,rr=proj.get(lid),ref.get(cap)
  if not pr or not rr:raise fail("L1E04_CASE_ARTIFACT_SOURCE_MISSING","case source missing",True)
  if pr["fixture"]!=fid or rr["fixture"]!=fid:raise fail("L1E04_CASE_FIXTURE_MISMATCH","fixture mismatch")
  roles=sorted(pr["arts"])
  if roles!=sorted(rr["arts"]):raise fail("L1E04_CASE_ROLE_SET_MISMATCH","role mismatch")
  cases.append({"case_id":case,"fixture_id":fid,"project_logical_run_id":lid,"reference_capture_id":cap,"roles":roles})
 if not cases:raise fail("L1E04_CASES_EMPTY","no cases",True)
 return {"comparison_id":cid,"min_reviewers":n,"vote":vote,"use":use,"cases":cases}
def aid(ca,ro,rv):return hashlib.sha256(("l1e04-a-v1\0"+ca+"\0"+ro+"\0"+rv).encode()).hexdigest()
def rref(r):return hashlib.sha256(("l1e04-r-v1\0"+r).encode()).hexdigest()
def session(path,identity):
 if path.is_file():
  s=load(path,"session")
  if s.get("identity_sha256")!=identity:raise fail("L1E04_SESSION_IDENTITY_MISMATCH","source identity changed")
  return dict(s)
 s={"schema_version":1,"identity_sha256":identity,"blinding_seed":secrets.token_hex(32)};dump(path,s);return s
def assignments(n,proj,ref,active,s):
 pub=[];priv=[];seed=bytes.fromhex(s["blinding_seed"])
 for c in n["cases"]:
  for role in c["roles"]:
   for rv in active:
    i=aid(c["case_id"],role,rv);swap=hmac.new(seed,i.encode(),hashlib.sha256).digest()[0]&1; m={"A":"REFERENCE","B":"PROJECT"} if swap else {"A":"PROJECT","B":"REFERENCE"};loc={"PROJECT":proj[c["project_logical_run_id"]]["arts"][role],"REFERENCE":ref[c["reference_capture_id"]]["arts"][role]}
    pub.append({"assignment_id":i,"case_id":c["case_id"],"stem":role,"reviewer_ref_hash":rref(rv),"blind_ids":["A","B"],"dimensions":list(DIMS)})
    priv.append({"assignment_id":i,"reviewer_id":rv,"case_id":c["case_id"],"stem":role,"A":{"system":m["A"],"path":str(loc[m["A"]]["path"]),"sha256":loc[m["A"]]["sha"]},"B":{"system":m["B"],"path":str(loc[m["B"]]["path"]),"sha256":loc[m["B"]]["sha"]}})
 return {"schema_version":1,"evidence_state":NON,"comparison_id":n["comparison_id"],"blinding_seed_sha256":hashlib.sha256(seed).hexdigest(),"assignments":pub},{"schema_version":1,"private":True,"assignments":priv}
def score_rows(scores,pub,priv):
 pi={x["assignment_id"]:x for x in pub["assignments"]};ri={x["assignment_id"]:x for x in priv["assignments"]};seen=set();rows=[]
 for z in scores.get("reviews",[]):
  z=mp(z,"review");i=st(z.get("assignment_id"),"assignment_id")
  if i in seen:raise fail("L1E04_REVIEW_DUPLICATE","duplicate review")
  seen.add(i)
  if i not in pi:raise fail("L1E04_ASSIGNMENT_UNKNOWN","unknown assignment")
  if not bl(z.get("blind_intact_at_submission"),"blind intact"):raise fail("L1E04_BLINDNESS_COMPROMISED","blindness compromised")
  iso(z.get("timestamp"),"timestamp"); by={}
  for b in ("A","B"):
   q=mp(z.get(b),b);by[b]={d:integer(q.get(d),d,0) for d in DIMS}
   if any(v>4 for v in by[b].values()):raise fail("L1E04_REVIEW_SCORE","score must be 0..4")
  w=st(z.get("materially_worse"),"materially_worse").upper()
  if w not in {"A","B","NONE"}:raise fail("L1E04_MATERIAL_VOTE","bad materially_worse")
  r=ri[i];mapping={"A":r["A"]["system"],"B":r["B"]["system"]};rows.append({"assignment_id":i,"case_id":r["case_id"],"stem":r["stem"],"reviewer_ref_hash":pi[i]["reviewer_ref_hash"],"scores":{mapping[b]:by[b] for b in ("A","B")} ,"materially_worse_system":"NONE" if w=="NONE" else mapping[w]})
 return rows,sorted(set(pi)-seen)
def avg(xs):return sum(xs)/len(xs) if xs else None
def summary(n,rows,missing):
 g={};ds={d:[] for d in DIMS};bad=[];roles=[]
 for r in rows:g.setdefault((r["case_id"],r["stem"]),[]).append(r)
 for c in n["cases"]:
  for role in c["roles"]:
   rr=g.get((c["case_id"],role),[])
   if len(rr)<n["min_reviewers"]:continue
   dd={}
   for d in DIMS:
    x=avg([float(q["scores"]["PROJECT"][d])-float(q["scores"]["REFERENCE"][d]) for q in rr]);dd[d]=x;ds[d].append(x)
   frac=sum(q["materially_worse_system"]=="PROJECT" for q in rr)/len(rr);f=frac>=n["vote"]
   if f:bad.append(c["case_id"]+":"+role)
   roles.append({"case_id":c["case_id"],"stem":role,"review_count":len(rr),"project_materially_worse_vote_fraction":frac,"dimension_deltas":dd,"material_inferiority":f})
 md={d:avg(v) for d,v in ds.items()};u=md["overall_practice_usability"];uok=u is not None and u>=n["use"]
 state="WAITING_REVIEW" if missing else "READY_FOR_HQ_E04_LIVE_REVIEW" if not bad and uok else "DIFFERENTIAL_FAIL"
 return {"review_state":state,"missing_assignment_count":len(missing),"mean_dimension_delta_project_minus_reference":md,"material_inferiority_case_roles":sorted(bad),"overall_usability_threshold_pass":uok,"material_inferiority_vote_pass":not bad,"role_results":roles}
def run_e04(*,root,plan,e02_evidence,e03_evidence,project_index,reference_index,reviewer_roster,scores,output_dir,repo_root=None,source_hashes=None):
 root=Path(root).resolve();out=Path(output_dir).resolve();repo=Path(repo_root).resolve() if repo_root else None
 if not root.is_dir():raise fail("L1E04_ROOT_INVALID","private root missing",True)
 if repo and inside(root,repo):raise fail("L1E04_PRIVATE_ROOT_IN_REPOSITORY","private root must be outside repository")
 e2=e02doc(e02_evidence);e3=e03doc(e03_evidence,e2);active=rosterdoc(reviewer_roster);proj=projectdoc(project_index,root,e3);ref=refdoc(reference_index,root,repo,e2);n=plandoc(plan,e2,proj,ref,active)
 hashes={"plan_sha256":sj(plan),"e02_evidence_sha256":sj(e02_evidence),"e03_evidence_sha256":sj(e03_evidence),"project_index_sha256":sj(project_index),"reference_index_sha256":sj(reference_index),"reviewer_roster_sha256":sj(reviewer_roster)}
 if source_hashes:
  for k,v in source_hashes.items():
   if k!="scores_sha256":hashes[k]=sh(v,k)
 ident=sj({"domain":"l1e04-session-v1","comparison_id":n["comparison_id"],"e02_lock":e2["lock"],"e03_lock":e3["lock"],"hashes":hashes,"policy":{"min_reviewers":n["min_reviewers"],"vote":n["vote"],"use":n["use"]},"cases":n["cases"]})
 out.mkdir(parents=True,exist_ok=True);s=session(out/"e04-session.private.json",ident);pub,priv=assignments(n,proj,ref,active,s);dump(out/"e04-review-assignments.json",pub);dump(out/"e04-reveal-map.private.json",priv);rows,missing=score_rows(scores,pub,priv);sm=summary(n,rows,missing);scorehash=sh(source_hashes["scores_sha256"],"scores_sha256") if source_hashes and source_hashes.get("scores_sha256") else sj(scores)
 clean=[{k:r[k] for k in ("assignment_id","case_id","stem","reviewer_ref_hash","scores","materially_worse_system")} for r in rows];lock=sj({"identity":ident,"e02":e2["lock"],"e03":e3["lock"],"assignments":sj(pub),"scores":scorehash,"summary":sm})
 report={"schema_version":1,"tool_version":TOOL,"evidence_kind":"CURRENT_IPHONE_DIFFERENTIAL_LISTENING","evidence_state":NON,"comparison_state":sm["review_state"],"parity_claim":"NONE","comparison_id":n["comparison_id"],"source_evidence":{**hashes,"scores_sha256":scorehash,"e02_rights_intake_lock_sha256":e2["lock"],"e03_live_benchmark_lock_sha256":e3["lock"]},"policy":{"minimum_reviewers_per_case_role":n["min_reviewers"],"material_inferiority_vote_fraction":n["vote"],"min_mean_overall_usability_delta":n["use"],"engineering_policy_not_reference_fact":True,"exact_input_bytes_required":True},"summary":sm,"reviews":clean,"privacy":{"reference_assets_copied_to_repository":False,"reference_locator_paths_emitted":False,"project_locator_paths_emitted":False,"raw_reviewer_ids_emitted":False,"blinding_seed_emitted":False,"raw_audio_emitted":False},"e04_differential_lock_sha256":lock,"parity_reason":"E04 blind listening is necessary but not sufficient for PARITY; HQ must confirm live provenance, recovery/device gates and integrated product evidence."}
 dump(out/"e04-current-iphone-differential.json",report);return report
def main(argv=None):
 p=argparse.ArgumentParser()
 for x in ("root","plan","e02","e03","project-index","reference-index","reviewer-roster","scores","output-dir"):p.add_argument("--"+x,required=True)
 p.add_argument("--repo-root");a=p.parse_args(argv)
 paths={k:Path(getattr(a,k.replace("-","_"))) for k in ("plan","e02","e03","project-index","reference-index","reviewer-roster","scores")}
 try:r=run_e04(root=a.root,plan=load(paths["plan"],"plan"),e02_evidence=load(paths["e02"],"e02"),e03_evidence=load(paths["e03"],"e03"),project_index=load(paths["project-index"],"project index"),reference_index=load(paths["reference-index"],"reference index"),reviewer_roster=load(paths["reviewer-roster"],"reviewer roster"),scores=load(paths["scores"],"scores"),output_dir=a.output_dir,repo_root=a.repo_root,source_hashes={k.replace("-","_")+"_sha256":sf(v) for k,v in paths.items()})
 except E04Error as e:print(json.dumps({"status":"FAIL","code":e.code,"message":e.message},sort_keys=True),file=sys.stderr);return e.exit_code
 print(json.dumps({"status":r["comparison_state"],"lock":r["e04_differential_lock_sha256"]},sort_keys=True));return 0 if r["comparison_state"]=="READY_FOR_HQ_E04_LIVE_REVIEW" else EXT if r["comparison_state"]=="WAITING_REVIEW" else 2
if __name__=="__main__":raise SystemExit(main())
