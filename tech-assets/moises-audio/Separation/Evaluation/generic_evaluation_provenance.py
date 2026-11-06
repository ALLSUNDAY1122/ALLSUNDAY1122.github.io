"""L1-E10 Generic Evaluation Provenance Producer.

Deterministically derives the three E09 private measurement records and the
GENERIC_ROUTE_LIVE_EVALUATION from physically SHA-bound live source artifacts.
Engineering provenance only; never product PARITY.
"""
from __future__ import annotations
import argparse, hashlib, json, math, os, re, sys
from pathlib import Path
from typing import Any, Mapping, Sequence

V=1
TOOL="L1-E10-v1"
NON="NON_PARITY_EVIDENCE_ONLY"
HEX=re.compile(r"^[0-9a-f]{64}$")
SAFE=re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
ROUTE_AUTHORITY={
    "LICENSED_LOCAL_INFERENCE_SDK":"LOCAL_RUNTIME",
    "ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER":"HOSTED_PROVIDER_ACCOUNT",
    "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE":"PROJECT_OWNED_RUNTIME",
}
OP_FIELDS=(
    "commercial_use_allowed","input_confidential","output_commercial_use_allowed",
    "output_export_allowed","training_on_user_content_allowed","service_region","data_region",
    "uploaded_asset_retention_seconds","deletion_control_available","commercial_basis_sha256",
)

class ProducerError(ValueError):
    def __init__(self,code,message="generic evaluation provenance production failed"):
        super().__init__(f"{code}: {message}"); self.code=code; self.message=message
def fail(code,msg="generic evaluation provenance production failed"): raise ProducerError(code,msg)
def mp(v,f):
    if not isinstance(v,Mapping): fail("L1E10_SCHEMA_TYPE",f)
    return v
def ls(v,f):
    if not isinstance(v,list): fail("L1E10_SCHEMA_TYPE",f)
    return v
def st(v,f):
    if not isinstance(v,str) or not v.strip(): fail("L1E10_SCHEMA_REQUIRED",f)
    return v.strip()
def bl(v,f):
    if not isinstance(v,bool): fail("L1E10_SCHEMA_TYPE",f)
    return v
def integer(v,f,lo=0):
    if isinstance(v,bool) or not isinstance(v,int) or v<lo: fail("L1E10_SCHEMA_INTEGER",f)
    return v
def num(v,f,lo=None,hi=None):
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(float(v)): fail("L1E10_SCHEMA_NUMBER",f)
    x=float(v)
    if lo is not None and x<lo: fail("L1E10_SCHEMA_RANGE",f)
    if hi is not None and x>hi: fail("L1E10_SCHEMA_RANGE",f)
    return x
def sha(v,f):
    x=st(v,f).lower().removeprefix("sha256:")
    if not HEX.fullmatch(x): fail("L1E10_SHA_INVALID",f)
    return x
def csha(v):
    return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def fsha(p:Path):
    h=hashlib.sha256()
    try:
        with p.open("rb") as f:
            for b in iter(lambda:f.read(1048576),b""): h.update(b)
    except OSError as e: raise ProducerError("L1E10_FILE_UNREADABLE",str(p)) from e
    return h.hexdigest()
def load(p:Path):
    try:return mp(json.loads(p.read_text(encoding="utf-8")),str(p))
    except ProducerError: raise
    except Exception as e: raise ProducerError("L1E10_JSON_INVALID",str(p)) from e
def roots(repo_root,private_root):
    repo=Path(repo_root).resolve(); private=Path(private_root).resolve()
    try: private.relative_to(repo)
    except ValueError: return repo,private
    fail("L1E10_PRIVATE_ROOT_INSIDE_REPOSITORY")
def private_file(repo,private,raw,expected,field):
    _,root=roots(repo,private); rel=Path(st(raw,field))
    if rel.is_absolute() or ".." in rel.parts: fail("L1E10_PRIVATE_PATH_UNSAFE",field)
    cur=root
    for part in rel.parts:
        cur/=part
        if cur.is_symlink(): fail("L1E10_PRIVATE_PATH_SYMLINK",field)
    p=(root/rel).resolve()
    try:p.relative_to(root)
    except ValueError as e: raise ProducerError("L1E10_PRIVATE_PATH_ESCAPE",field) from e
    if not p.is_file(): fail("L1E10_PRIVATE_FILE_MISSING",field)
    actual=fsha(p)
    if actual!=sha(expected,field+".sha256"): fail("L1E10_PRIVATE_FILE_SHA_MISMATCH",field)
    return p,actual
def rel_to_private(path:Path,private:Path):
    try:return path.resolve().relative_to(private.resolve()).as_posix()
    except ValueError as e: raise ProducerError("L1E10_OUTPUT_OUTSIDE_PRIVATE_ROOT",str(path)) from e

def validate_plan(d):
    if d.get("schema_version")!=1 or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE":
        fail("L1E10_PLAN_SCHEMA")
    p=mp(d.get("policy"),"policy")
    threshold=num(p.get("minimum_overall_usability_delta"),"minimum_overall_usability_delta",-4,4)
    return {"decision_id":st(d.get("decision_id"),"decision_id"),"minimum_overall_usability_delta":threshold,"plan_sha256":csha(d)}

def validate_e07(d,physical):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE":
        fail("L1E10_E07_SCHEMA")
    rid=st(d.get("route_id"),"e07.route_id"); kind=st(d.get("route_kind"),"e07.route_kind").upper()
    if kind not in ROUTE_AUTHORITY: fail("L1E10_ROUTE_KIND")
    runtime=mp(d.get("runtime"),"e07.runtime"); auth=mp(d.get("capacity_authority"),"e07.capacity_authority")
    if st(auth.get("kind"),"e07.authority.kind").upper()!=ROUTE_AUTHORITY[kind]: fail("L1E10_E07_AUTHORITY_MISMATCH")
    lock=sha(d.get("e07_substitution_lock_sha256"),"e07.lock")
    return {"route_id":rid,"route_kind":kind,"runtime":{
        "runtime_id":st(runtime.get("runtime_id"),"runtime_id"),"model_name":st(runtime.get("model_name"),"model_name"),
        "model_version":st(runtime.get("model_version"),"model_version"),"quality_profile":st(runtime.get("quality_profile"),"quality_profile"),
        "artifact_sha256":sha(runtime.get("artifact_sha256"),"runtime.artifact_sha256")},
        "authority_kind":ROUTE_AUTHORITY[kind],"authority_sha256":sha(auth.get("provenance_sha256"),"authority.sha256"),
        "lock":lock,"physical_sha256":sha(physical,"e07 physical")}

def validate_e08(d,e7,physical):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="RUNTIME_AUTHORITY_LIVE_GATE" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE":
        fail("L1E10_E08_SCHEMA")
    if st(d.get("route_id"),"e08.route_id")!=e7["route_id"] or st(d.get("route_kind"),"e08.route_kind").upper()!=e7["route_kind"] or sha(d.get("runtime_artifact_sha256"),"e08.runtime")!=e7["runtime"]["artifact_sha256"]:
        fail("L1E10_E08_ROUTE_RUNTIME_MISMATCH")
    a=mp(d.get("authority"),"e08.authority"); src=mp(d.get("source_evidence"),"e08.source_evidence")
    if st(a.get("kind"),"e08.authority.kind").upper()!=e7["authority_kind"] or sha(a.get("provenance_sha256"),"e08.authority.sha")!=e7["authority_sha256"]:
        fail("L1E10_E08_AUTHORITY_MISMATCH")
    if sha(src.get("e07_evidence_sha256"),"e08.e07.sha")!=e7["physical_sha256"] or sha(src.get("e07_substitution_lock_sha256"),"e08.e07.lock")!=e7["lock"]:
        fail("L1E10_E08_E07_BINDING")
    return {"physical_sha256":sha(physical,"e08 physical"),"lock":sha(d.get("e08_live_authority_lock_sha256"),"e08.lock"),"state":st(d.get("gate_state"),"e08.gate_state")}

def validate_source_header(d,kind,e7):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!=kind or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE":
        fail("L1E10_SOURCE_SCHEMA",kind)
    if st(d.get("route_id"),"source.route_id")!=e7["route_id"] or st(d.get("route_kind"),"source.route_kind").upper()!=e7["route_kind"] or sha(d.get("runtime_artifact_sha256"),"source.runtime")!=e7["runtime"]["artifact_sha256"]:
        fail("L1E10_SOURCE_ROUTE_RUNTIME_MISMATCH",kind)

def produce_operational(d,e7,repo,private,source_sha):
    validate_source_header(d,"GENERIC_ROUTE_OPERATIONAL_SOURCE",e7)
    measurement=mp(d.get("measurement"),"operational.measurement")
    if set(measurement)!=set(OP_FIELDS): fail("L1E10_OPERATIONAL_FIELD_SET")
    for k in ("commercial_use_allowed","input_confidential","output_commercial_use_allowed","output_export_allowed","training_on_user_content_allowed","deletion_control_available"): bl(measurement.get(k),k)
    st(measurement.get("service_region"),"service_region"); st(measurement.get("data_region"),"data_region")
    num(measurement.get("uploaded_asset_retention_seconds"),"retention",0); sha(measurement.get("commercial_basis_sha256"),"commercial_basis_sha256")
    refs={}
    for raw in ls(d.get("evidence"),"operational.evidence"):
        row=mp(raw,"evidence"); eid=st(row.get("evidence_id"),"evidence_id")
        if not SAFE.fullmatch(eid) or eid in refs: fail("L1E10_OPERATIONAL_EVIDENCE_ID")
        _,actual=private_file(repo,private,row.get("path"),row.get("sha256"),"operational.evidence."+eid); refs[eid]=actual
    fmap=mp(d.get("field_evidence"),"operational.field_evidence")
    if set(fmap)!=set(OP_FIELDS): fail("L1E10_OPERATIONAL_FIELD_EVIDENCE_SET")
    for field, ids in fmap.items():
        vals=ls(ids,field)
        if not vals or any(st(x,field) not in refs for x in vals): fail("L1E10_OPERATIONAL_FIELD_UNPROVEN",field)
    lock=csha({"domain":"l1-e10-operational-source-v1","source_sha256":source_sha,"measurement":measurement,"evidence_sha256":sorted(refs.values()),"field_evidence":{k:sorted(v) for k,v in fmap.items()}})
    return dict(measurement),lock

def produce_benchmark(d,e7,repo,private,source_sha):
    validate_source_header(d,"GENERIC_ROUTE_BENCHMARK_SOURCE",e7)
    runs=ls(d.get("runs"),"benchmark.runs")
    if not runs: fail("L1E10_BENCHMARK_RUNS_EMPTY")
    seen=set(); norm=[]
    for raw in runs:
        r=mp(raw,"run"); rid=st(r.get("run_id"),"run_id")
        if not SAFE.fullmatch(rid) or rid in seen: fail("L1E10_BENCHMARK_RUN_ID")
        seen.add(rid)
        mode=st(r.get("mode_class"),"mode_class"); success=bl(r.get("success"),"success"); retry=integer(r.get("retry_count"),"retry_count")
        total=num(r.get("execution_total_ms"),"execution_total_ms",0); cost=num(r.get("cost_total"),"cost_total",0)
        cur=st(r.get("cost_currency"),"cost_currency").upper()
        if len(cur)!=3 or not cur.isalpha(): fail("L1E10_BENCHMARK_CURRENCY")
        g1_eval=bl(r.get("g1_objective_evaluable"),"g1_objective_evaluable"); g1_pass=bl(r.get("g1_objective_pass"),"g1_objective_pass")
        if g1_pass and not g1_eval: fail("L1E10_G1_PASS_WITHOUT_EVALUATION")
        _,esh=private_file(repo,private,r.get("source_evidence_path"),r.get("source_evidence_sha256"),"benchmark.run."+rid)
        norm.append({"run_id":rid,"mode_class":mode,"success":success,"retry_count":retry,"execution_total_ms":total,"cost_total":cost,"cost_currency":cur,"g1_objective_evaluable":g1_eval,"g1_objective_pass":g1_pass,"source_evidence_sha256":esh})
    success=[r for r in norm if r["success"]]
    if not success: fail("L1E10_BENCHMARK_NO_SUCCESSFUL_RUN")
    currencies={r["cost_currency"] for r in success}
    if len(currencies)!=1: fail("L1E10_BENCHMARK_MIXED_CURRENCY")
    g1=[r for r in success if r["g1_objective_evaluable"]]
    measurement={
        "mode_classes":sorted({r["mode_class"] for r in success}),
        "g1_objective_run_count":len(g1),
        "g1_objective_floor_pass":bool(g1) and all(r["g1_objective_pass"] for r in g1),
        "final_failure_fraction":sum(not r["success"] for r in norm)/len(norm),
        "retry_fraction":sum(r["retry_count"]>0 for r in norm)/len(norm),
        "mean_execution_total_ms":sum(r["execution_total_ms"] for r in success)/len(success),
        "mean_cost_per_successful_run":sum(r["cost_total"] for r in success)/len(success),
        "cost_currency":next(iter(currencies)),
        "successful_run_count":len(success),
    }
    lock=csha({"domain":"l1-e10-benchmark-source-v1","source_sha256":source_sha,"runs":norm})
    return measurement,lock

def produce_differential(d,e7,repo,private,source_sha,threshold):
    validate_source_header(d,"GENERIC_ROUTE_DIFFERENTIAL_SOURCE",e7)
    project_sha=sha(d.get("project_input_sha256"),"project_input_sha256"); reference_sha=sha(d.get("reference_input_sha256"),"reference_input_sha256")
    reviews=ls(d.get("reviews"),"differential.reviews"); seen=set(); norm=[]
    for raw in reviews:
        r=mp(raw,"review"); rid=st(r.get("review_id"),"review_id")
        if not SAFE.fullmatch(rid) or rid in seen: fail("L1E10_REVIEW_ID")
        seen.add(rid)
        case=st(r.get("case_id"),"case_id"); ps=num(r.get("project_usability_score"),"project_score",1,5); rs=num(r.get("reference_usability_score"),"reference_score",1,5)
        worse=bl(r.get("materially_worse"),"materially_worse")
        _,esh=private_file(repo,private,r.get("source_evidence_path"),r.get("source_evidence_sha256"),"differential.review."+rid)
        norm.append({"review_id_hash":hashlib.sha256(("l1e10-review:"+rid).encode()).hexdigest(),"case_id":case,"project_score":ps,"reference_score":rs,"materially_worse":worse,"source_evidence_sha256":esh})
    exact=project_sha==reference_sha
    if not norm:
        delta=None; inferior=False; threshold_pass=False; vote_pass=False; state="WAITING_REVIEW"
    else:
        delta=sum(r["project_score"]-r["reference_score"] for r in norm)/len(norm)
        inferior=any(r["materially_worse"] for r in norm)
        threshold_pass=delta>=threshold
        vote_pass=not inferior
        state="READY_FOR_HQ_E09_ROUTE_EVALUATION" if exact and threshold_pass and vote_pass else "DIFFERENTIAL_FAIL"
    measurement={"exact_input_bytes":exact,"overall_usability_delta_project_minus_reference":delta,"material_inferiority_detected":inferior,"overall_usability_threshold_pass":threshold_pass,"material_inferiority_vote_pass":vote_pass,"comparison_state":state}
    lock=csha({"domain":"l1-e10-differential-source-v1","source_sha256":source_sha,"project_input_sha256":project_sha,"reference_input_sha256":reference_sha,"reviews":norm,"threshold":threshold})
    return measurement,lock

def measurement_record(kind,e7,measurement,source_sha,source_lock,decision_plan_sha):
    body={"schema_version":1,"evidence_kind":kind,"evidence_state":NON,"parity_claim":"NONE","route_id":e7["route_id"],"route_kind":e7["route_kind"],"runtime_artifact_sha256":e7["runtime"]["artifact_sha256"],"measurement":measurement,
          "producer_provenance":{"tool_version":TOOL,"source_sha256":source_sha,"source_lock_sha256":source_lock,"decision_plan_sha256":decision_plan_sha}}
    body["measurement_lock_sha256"]=csha({"domain":"l1-e10-measurement-record-v1","body":body})
    return body

def deterministic_bytes(payload):
    return (json.dumps(payload,sort_keys=True,indent=2,ensure_ascii=False,allow_nan=False)+"\n").encode()
def write_atomic(path,payload):
    p=Path(path); p.parent.mkdir(parents=True,exist_ok=True); t=p.with_name("."+p.name+".tmp")
    try:
        with t.open("wb") as f:
            f.write(deterministic_bytes(payload)); f.flush(); os.fsync(f.fileno())
        os.replace(t,p)
    except OSError as e:
        try:t.unlink(missing_ok=True)
        except OSError:pass
        raise ProducerError("L1E10_WRITE_FAILED",str(p)) from e
    return fsha(p)

def produce(*,decision_plan,e07,e07_sha,e08,e08_sha,source_index,repo_root,private_root,out_dir):
    repo,private=roots(repo_root,private_root); plan=validate_plan(decision_plan)
    e7=validate_e07(e07,e07_sha); e8=validate_e08(e08,e7,e08_sha)
    idx=mp(source_index,"source_index")
    if idx.get("schema_version")!=1 or idx.get("private") is not True or idx.get("evidence_state")!=NON or idx.get("parity_claim")!="NONE": fail("L1E10_SOURCE_INDEX_SCHEMA")
    if st(idx.get("route_id"),"index.route_id")!=e7["route_id"] or st(idx.get("route_kind"),"index.route_kind").upper()!=e7["route_kind"] or sha(idx.get("runtime_artifact_sha256"),"index.runtime")!=e7["runtime"]["artifact_sha256"]: fail("L1E10_SOURCE_INDEX_ROUTE_MISMATCH")
    sources=mp(idx.get("sources"),"sources")
    if set(sources)!={"operational","benchmark","differential"}: fail("L1E10_SOURCE_SET")
    loaded={}; source_hashes={}
    expected_kind={"operational":"GENERIC_ROUTE_OPERATIONAL_SOURCE","benchmark":"GENERIC_ROUTE_BENCHMARK_SOURCE","differential":"GENERIC_ROUTE_DIFFERENTIAL_SOURCE"}
    for key in ("operational","benchmark","differential"):
        ent=mp(sources[key],key); p,actual=private_file(repo,private,ent.get("path"),ent.get("sha256"),"source."+key); loaded[key]=load(p); source_hashes[key]=actual
        if loaded[key].get("evidence_kind")!=expected_kind[key]: fail("L1E10_SOURCE_KIND_MISMATCH",key)
    op,oplock=produce_operational(loaded["operational"],e7,repo,private,source_hashes["operational"])
    bm,bmlock=produce_benchmark(loaded["benchmark"],e7,repo,private,source_hashes["benchmark"])
    diff,difflock=produce_differential(loaded["differential"],e7,repo,private,source_hashes["differential"],plan["minimum_overall_usability_delta"])
    records={
        "operational":measurement_record("GENERIC_ROUTE_OPERATIONAL_MEASUREMENT",e7,op,source_hashes["operational"],oplock,plan["plan_sha256"]),
        "benchmark":measurement_record("GENERIC_ROUTE_BENCHMARK_MEASUREMENT",e7,bm,source_hashes["benchmark"],bmlock,plan["plan_sha256"]),
        "differential":measurement_record("GENERIC_ROUTE_DIFFERENTIAL_MEASUREMENT",e7,diff,source_hashes["differential"],difflock,plan["plan_sha256"]),
    }
    out=Path(out_dir).resolve()
    try: out.relative_to(private)
    except ValueError: fail("L1E10_OUTPUT_OUTSIDE_PRIVATE_ROOT")
    out.mkdir(parents=True,exist_ok=True)
    paths={}; hashes={}
    for key in ("operational","benchmark","differential"):
        p=out/f"{e7['route_id']}.{key}.measurement.json"; hashes[key]=write_atomic(p,records[key]); paths[key]=rel_to_private(p,private)
    eval_state="WAITING_REVIEW" if diff["comparison_state"]=="WAITING_REVIEW" else "READY_FOR_HQ_E09_ROUTE_EVALUATION"
    evaluation={"schema_version":1,"evidence_kind":"GENERIC_ROUTE_LIVE_EVALUATION","evidence_state":NON,"parity_claim":"NONE","evaluation_state":eval_state,"route_id":e7["route_id"],"route_kind":e7["route_kind"],"runtime":e7["runtime"],"source_evidence":{"e07_evidence_sha256":e7["physical_sha256"],"e07_substitution_lock_sha256":e7["lock"],"e08_evidence_sha256":e8["physical_sha256"],"e08_live_authority_lock_sha256":e8["lock"]},"operational":op,"benchmark":bm,"differential":diff,"provenance":{k:{"path":paths[k],"sha256":hashes[k]} for k in paths},"privacy":{"credential_values_emitted":False,"authority_ids_emitted":False,"private_paths_emitted":False,"raw_billing_records_emitted":False,"raw_reviewer_ids_emitted":False,"raw_audio_emitted":False}}
    eval_path=out/f"{e7['route_id']}.generic-route-live-evaluation.json"; eval_sha=write_atomic(eval_path,evaluation)
    receipt={"schema_version":1,"tool_version":TOOL,"evidence_kind":"GENERIC_EVALUATION_PROVENANCE_RECEIPT","evidence_state":NON,"parity_claim":"NONE","route_id":e7["route_id"],"route_kind":e7["route_kind"],"runtime_artifact_sha256":e7["runtime"]["artifact_sha256"],"decision_plan_sha256":plan["plan_sha256"],"source_sha256":{"e07":e7["physical_sha256"],"e08":e8["physical_sha256"],**source_hashes},"source_locks":{"e07_substitution_lock_sha256":e7["lock"],"e08_live_authority_lock_sha256":e8["lock"],"operational_source_lock_sha256":oplock,"benchmark_source_lock_sha256":bmlock,"differential_source_lock_sha256":difflock},"output_sha256":{**hashes,"evaluation":eval_sha},"privacy":{"private_paths_emitted":False,"raw_reviewer_ids_emitted":False,"raw_audio_emitted":False,"raw_contract_text_emitted":False,"raw_billing_records_emitted":False},"parity_reason":"E10 produces deterministic provenance-bound E09 inputs only; live source authenticity, current-iPhone comparison, physical-device evidence and HQ PARITY remain separate."}
    receipt["e10_provenance_lock_sha256"]=csha({"domain":"l1-e10-provenance-receipt-v1","receipt":receipt})
    return {"records":records,"evaluation":evaluation,"receipt":receipt,"paths":{"evaluation":str(eval_path),**{k:str(out/f"{e7['route_id']}.{k}.measurement.json") for k in records}}}

def verify_existing(produced):
    for key,p in produced["paths"].items():
        payload=produced["evaluation"] if key=="evaluation" else produced["records"][key]
        if not Path(p).is_file() or Path(p).read_bytes()!=deterministic_bytes(payload): fail("L1E10_REPLAY_MISMATCH",key)
    return True

def main(argv:Sequence[str]|None=None):
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True); ap.add_argument("--private-root",required=True); ap.add_argument("--decision-plan",required=True)
    ap.add_argument("--e07",required=True); ap.add_argument("--e08",required=True); ap.add_argument("--source-index",required=True); ap.add_argument("--out-dir",required=True); ap.add_argument("--receipt-out",required=True)
    a=ap.parse_args(argv)
    try:
        e07p=Path(a.e07); e08p=Path(a.e08)
        result=produce(decision_plan=load(Path(a.decision_plan)),e07=load(e07p),e07_sha=fsha(e07p),e08=load(e08p),e08_sha=fsha(e08p),source_index=load(Path(a.source_index)),repo_root=a.repo_root,private_root=a.private_root,out_dir=a.out_dir)
        verify_existing(result); write_atomic(Path(a.receipt_out),result["receipt"])
        print(json.dumps({"status":"PASS","route_id":result["receipt"]["route_id"],"lock":result["receipt"]["e10_provenance_lock_sha256"]},sort_keys=True)); return 0
    except ProducerError as e:
        print(json.dumps({"status":"FAIL","code":e.code,"message":e.message},sort_keys=True),file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())
