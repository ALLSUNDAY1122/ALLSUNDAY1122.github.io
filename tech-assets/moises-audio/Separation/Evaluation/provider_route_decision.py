"""L1-E06 provider route decision loop. Engineering evidence only; never PARITY."""
from __future__ import annotations
import argparse, hashlib, json, math, os, re, sys
from pathlib import Path
from typing import Any, Mapping, Sequence

V=1; TOOL="L1-E06-v1"; NON="NON_PARITY_EVIDENCE_ONLY"; EVIDENCE_STATE=NON; HEX=re.compile(r"^[0-9a-f]{64}$")
CANCEL={"CANCEL_UPLOAD","CANCEL_SEPARATING","CANCEL_FINALIZING"}
E05_KINDS={"NETWORK_INTERRUPTION","CANCEL_UPLOAD","CANCEL_SEPARATING","CANCEL_FINALIZING","AMBIGUOUS_CREATE_RETRY","RELAUNCH","OUTPUT_EXPIRY","RATE_LIMIT","LONG_TRACK","STORAGE_PRESSURE"}
CAP={"ADEQUATE","INSUFFICIENT","UNKNOWN"}

class DecisionError(ValueError):
    def __init__(self,code,msg="provider route decision validation failed"):
        super().__init__(f"{code}: {msg}"); self.code=code; self.message=msg
def fail(code,msg="provider route decision validation failed"): raise DecisionError(code,msg)
def mp(v,f):
    if not isinstance(v,Mapping): fail("L1E06_SCHEMA_TYPE",f"{f} must be object")
    return v
def ls(v,f):
    if not isinstance(v,list): fail("L1E06_SCHEMA_TYPE",f"{f} must be array")
    return v
def st(v,f):
    if not isinstance(v,str) or not v.strip(): fail("L1E06_SCHEMA_REQUIRED",f)
    return v.strip()
def bl(v,f):
    if not isinstance(v,bool): fail("L1E06_SCHEMA_TYPE",f)
    return v
def num(v,f,lo=None):
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(float(v)): fail("L1E06_SCHEMA_NUMBER",f)
    x=float(v)
    if lo is not None and x<lo: fail("L1E06_SCHEMA_RANGE",f)
    return x
def sh(v,f):
    x=st(v,f).lower().removeprefix("sha256:")
    if not HEX.fullmatch(x): fail("L1E06_SHA_INVALID",f)
    return x
def csha(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False).encode()).hexdigest()
def fsha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda:f.read(1048576),b""): h.update(b)
    return h.hexdigest()

def plan_doc(p):
    if p.get("schema_version")!=1 or p.get("evidence_state")!=NON: fail("L1E06_PLAN_INVALID")
    q=mp(p.get("policy"),"policy")
    modes=sorted({st(x,"required_mode_classes[]") for x in ls(q.get("required_mode_classes"),"required_mode_classes")})
    sr=sorted({st(x,"allowed_service_regions[]") for x in ls(q.get("allowed_service_regions"),"allowed_service_regions")})
    dr=sorted({st(x,"allowed_data_regions[]") for x in ls(q.get("allowed_data_regions"),"allowed_data_regions")})
    if not modes or not sr or not dr: fail("L1E06_PLAN_EMPTY_SET")
    w=mp(q.get("ranking_weights"),"ranking_weights"); weights={k:num(w.get(k),k,0) for k in ("quality","latency","reliability","cost")}
    total=sum(weights.values())
    if total<=0: fail("L1E06_RANKING_WEIGHTS_EMPTY")
    weights={k:v/total for k,v in weights.items()}
    ff=num(q.get("maximum_final_failure_fraction"),"maximum_final_failure_fraction",0)
    rf=num(q.get("maximum_retry_fraction"),"maximum_retry_fraction",0)
    dg=num(q.get("maximum_non_cancel_degraded_fraction"),"maximum_non_cancel_degraded_fraction",0)
    if max(ff,rf,dg)>1: fail("L1E06_SCHEMA_RANGE","fraction > 1")
    ud=num(q.get("minimum_overall_usability_delta"),"minimum_overall_usability_delta")
    if not -4<=ud<=4: fail("L1E06_SCHEMA_RANGE","usability delta")
    return {"decision_id":st(p.get("decision_id"),"decision_id"),"policy":{
      "required_mode_classes":modes,"allowed_service_regions":sr,"allowed_data_regions":dr,
      "maximum_mean_provider_total_ms":num(q.get("maximum_mean_provider_total_ms"),"maximum_mean_provider_total_ms",1),
      "maximum_final_failure_fraction":ff,"maximum_retry_fraction":rf,
      "cost_currency":st(q.get("cost_currency"),"cost_currency").upper(),
      "maximum_mean_cost_per_successful_run":num(q.get("maximum_mean_cost_per_successful_run"),"maximum_mean_cost_per_successful_run",0),
      "maximum_non_cancel_degraded_fraction":dg,
      "maximum_uploaded_asset_retention_seconds":num(q.get("maximum_uploaded_asset_retention_seconds"),"maximum_uploaded_asset_retention_seconds",0),
      "require_delete_api":bl(q.get("require_delete_api"),"require_delete_api"),
      "require_capacity_attestation":bl(q.get("require_capacity_attestation"),"require_capacity_attestation"),
      "minimum_overall_usability_delta":ud,
      "minimum_primary_score_margin":num(q.get("minimum_primary_score_margin"),"minimum_primary_score_margin",0),
      "ranking_weights":weights,
      "engineering_policy_not_reference_fact":bl(q.get("engineering_policy_not_reference_fact"),"engineering_policy_not_reference_fact")}}

def e01_doc(d):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="COMMERCIAL_ROUTE_APPROVAL" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE": fail("L1E06_E01_INVALID")
    p=mp(d.get("provider"),"e01.provider"); models=[]; keys=set()
    for x in ls(p.get("models"),"e01.models"):
        x=mp(x,"model"); row={"model_name":st(x.get("model_name"),"model_name"),"model_version":st(x.get("model_version"),"model_version"),"quality_profile":st(x.get("quality_profile"),"quality_profile"),"canonical_roles":sorted({st(r,"role").lower() for r in ls(x.get("canonical_roles"),"canonical_roles")})}
        models.append(row); keys.add((row["model_name"],row["model_version"],row["quality_profile"]))
    if not models: fail("L1E06_E01_MODELS_EMPTY")
    op=mp(d.get("operational_policy"),"e01.operational_policy"); flags=mp(op.get("commercial_route_flags"),"flags"); cred=mp(d.get("credential_preflight"),"credential_preflight")
    return {"ready":d.get("result")=="READY_FOR_LIVE_PROVIDER_GATE" and cred.get("all_present") is True,
      "provider_id":st(p.get("provider_id"),"provider_id"),"provider_kind":st(p.get("provider_kind"),"provider_kind"),
      "account_tier":st(p.get("account_tier"),"account_tier"),"service_region":st(p.get("service_region"),"service_region"),
      "data_region":st(op.get("data_region"),"data_region"),"capability_snapshot_sha256":sh(p.get("capability_snapshot_sha256"),"capability sha"),
      "models":sorted(models,key=lambda x:(x["model_name"],x["model_version"],x["quality_profile"])),"model_keys":keys,
      "approval_identity":sh(d.get("approval_manifest_identity_sha256"),"approval identity"),
      "retention":num(op.get("uploaded_asset_retention_seconds"),"retention",0),"delete_api":bl(op.get("delete_api_available"),"delete api"),
      "training":bl(op.get("provider_training_on_user_content_allowed"),"training"),
      "commercial":all(bl(flags.get(k),k) for k in ("consumer_app_commercial_use_allowed","input_confidential","output_commercial_use_allowed","output_export_to_end_user_allowed"))}

def e03_doc(d,e1,e1sha):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="LIVE_SEPARATION_BENCHMARK" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE": fail("L1E06_E03_INVALID")
    state=st(d.get("benchmark_state"),"benchmark_state")
    if state not in {"READY_FOR_HQ_E03_LIVE_REVIEW","LIVE_BENCHMARK_FAILED"}: fail("L1E06_E03_STATE_INVALID")
    src=mp(d.get("source_evidence"),"e03.source")
    if sh(src.get("e01_evidence_sha256"),"e03 e01 sha")!=e1sha: fail("L1E06_E03_E01_FILE_SHA_MISMATCH")
    if sh(src.get("e01_approval_identity_sha256"),"e03 approval")!=e1["approval_identity"]: fail("L1E06_E03_E01_IDENTITY_MISMATCH")
    sm=mp(d.get("summary"),"e03.summary"); checks=mp(d.get("acceptance_checks"),"e03.checks"); classes=set()
    for m in mp(sm.get("modes"),"e03.modes").values():
        m=mp(m,"mode")
        if m.get("required") is True: classes.add(st(m.get("mode_class"),"mode_class"))
    lat=[]; cost=[]; curr=set(); used=set()
    for r in ls(d.get("runs"),"e03.runs"):
        r=mp(r,"run")
        if r.get("success") is not True: continue
        lat.append(num(mp(r.get("timing_ms"),"timing").get("total"),"total",0)); c=mp(r.get("cost"),"cost")
        cost.append(num(c.get("total"),"cost.total",0)); curr.add(st(c.get("currency"),"currency").upper()); pr=mp(r.get("provider"),"provider")
        if st(pr.get("provider_id"),"provider_id")!=e1["provider_id"]: fail("L1E06_E03_PROVIDER_MISMATCH")
        used.add((st(pr.get("model_name"),"model"),st(pr.get("model_version"),"version"),st(pr.get("quality_profile"),"profile")))
    if used-e1["model_keys"]: fail("L1E06_E03_UNAPPROVED_MODEL")
    if len(curr)>1: fail("L1E06_E03_MIXED_CURRENCY")
    return {"ready":state=="READY_FOR_HQ_E03_LIVE_REVIEW","lock":sh(d.get("e03_live_benchmark_lock_sha256"),"e03 lock"),
      "classes":classes,"checks":all(v is True for v in checks.values()),"obj":checks.get("g1_objective_floor") is True,
      "g1":int(num(sm.get("g1_objective_run_count"),"g1",0)),"fail":num(sm.get("final_failure_fraction"),"fail",0),
      "retry":num(sm.get("retry_fraction"),"retry",0),"lat":sum(lat)/len(lat) if lat else math.inf,
      "cost":sum(cost)/len(cost) if cost else math.inf,"currency":next(iter(curr)) if curr else None,"success":len(lat),
      "used_models":[{"model_name":a,"model_version":b,"quality_profile":c} for a,b,c in sorted(used)]}

def e04_doc(d,e3,e3sha):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="CURRENT_IPHONE_DIFFERENTIAL_LISTENING" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE": fail("L1E06_E04_INVALID")
    state=st(d.get("comparison_state"),"comparison_state")
    if state not in {"WAITING_REVIEW","READY_FOR_HQ_E04_LIVE_REVIEW","DIFFERENTIAL_FAIL"}: fail("L1E06_E04_STATE_INVALID")
    src=mp(d.get("source_evidence"),"e04.source")
    if sh(src.get("e03_evidence_sha256"),"e04 e03 sha")!=e3sha: fail("L1E06_E04_E03_FILE_SHA_MISMATCH")
    if sh(src.get("e03_live_benchmark_lock_sha256"),"e04 e03 lock")!=e3["lock"]: fail("L1E06_E04_E03_LOCK_MISMATCH")
    sm=mp(d.get("summary"),"e04.summary"); delta=mp(sm.get("mean_dimension_delta_project_minus_reference"),"delta").get("overall_practice_usability")
    return {"state":state,"lock":sh(d.get("e04_differential_lock_sha256"),"e04 lock"),"delta":None if delta is None else num(delta,"delta"),
      "inferior":bool(ls(sm.get("material_inferiority_case_roles"),"inferior")),"threshold":sm.get("overall_usability_threshold_pass") is True,"vote":sm.get("material_inferiority_vote_pass") is True}

def e05_doc(d,e1,e3,e1sha,e3sha):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="LIVE_PROCESSING_RECOVERY" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE": fail("L1E06_E05_INVALID")
    state=st(d.get("recovery_state"),"recovery_state")
    if state not in {"READY_FOR_HQ_E05_LIVE_REVIEW","LIVE_RECOVERY_FAILED"}: fail("L1E06_E05_STATE_INVALID")
    src=mp(d.get("source_evidence"),"e05.source")
    if sh(src.get("e01_evidence_sha256"),"e05 e01 sha")!=e1sha: fail("L1E06_E05_E01_FILE_SHA_MISMATCH")
    if sh(src.get("e03_evidence_sha256"),"e05 e03 sha")!=e3sha: fail("L1E06_E05_E03_FILE_SHA_MISMATCH")
    if sh(src.get("e01_approval_identity_sha256"),"e05 approval")!=e1["approval_identity"]: fail("L1E06_E05_E01_IDENTITY_MISMATCH")
    if sh(src.get("e03_live_benchmark_lock_sha256"),"e05 e03 lock")!=e3["lock"]: fail("L1E06_E05_E03_LOCK_MISMATCH")
    rows=[mp(x,"scenario") for x in ls(d.get("scenarios"),"e05.scenarios")]; kinds=[st(x.get("scenario_kind"),"kind") for x in rows]
    if len(kinds)!=10 or set(kinds)!=E05_KINDS: fail("L1E06_E05_SCENARIO_SET_INVALID")
    cancel=True; non=[]; rate=False; rate_sha=None; long=False; storage=False
    for r,k in zip(rows,kinds):
        ps=st(r.get("project_state_after"),"project_state")
        if k in CANCEL:
            n=r.get("provider_cancel_request_count")
            if isinstance(n,bool) or not isinstance(n,int): fail("L1E06_E05_CANCEL_COUNT_INVALID")
            cancel &= r.get("logical_cancelled") is True and r.get("outputs_published_after_cancel") is False and n<=1 and ps=="cancelled" and (r.get("claimed_upstream_cancelled") is not True or r.get("upstream_cancel_state")=="confirmed")
        else: non.append(ps)
        if k=="RATE_LIMIT": rate=r.get("rate_limit_observed") is True; rate_sha=sh(r.get("provider_account_provenance_sha256"),"rate provenance")
        if k=="LONG_TRACK": long=r.get("bounded_streaming_observed") is True
        if k=="STORAGE_PRESSURE": storage=r.get("storage_preflight_observed") is True
    checks=mp(d.get("checks"),"e05.checks"); degraded=sum(x in {"recoverable","failed_closed"} for x in non)/len(non)
    return {"ready":state=="READY_FOR_HQ_E05_LIVE_REVIEW","lock":sh(d.get("e05_live_recovery_lock_sha256"),"e05 lock"),
      "checks":all(v is True for v in checks.values()),"cancel":cancel and checks.get("cancel_claims_truthful") is True,
      "degraded":degraded,"rate":rate,"rate_sha":rate_sha,"long":long,"storage":storage}

def cap_doc(d,e1,e5):
    if d.get("schema_version")!=1 or d.get("evidence_kind")!="PROVIDER_CAPACITY_SNAPSHOT" or d.get("evidence_state")!=NON or d.get("parity_claim")!="NONE": fail("L1E06_CAPACITY_INVALID")
    if st(d.get("provider_id"),"capacity provider")!=e1["provider_id"]: fail("L1E06_CAPACITY_PROVIDER_MISMATCH")
    if sh(d.get("e01_approval_identity_sha256"),"capacity approval")!=e1["approval_identity"]: fail("L1E06_CAPACITY_E01_IDENTITY_MISMATCH")
    c=mp(d.get("capacity"),"capacity"); out={}
    for k in ("quota_status","credit_status","rate_limit_capacity_status"):
        x=st(c.get(k),k).upper()
        if x not in CAP: fail("L1E06_CAPACITY_STATUS_INVALID",k)
        out[k]=x
    prov=sh(c.get("provider_account_provenance_sha256"),"capacity provenance")
    if prov!=e5["rate_sha"]: fail("L1E06_CAPACITY_E05_PROVENANCE_MISMATCH")
    for k in ("provider_account_id_emitted","raw_quota_values_emitted","raw_credit_values_emitted","raw_billing_records_emitted"):
        if mp(d.get("privacy"),"capacity privacy").get(k) is not False: fail("L1E06_CAPACITY_PRIVACY_FAIL",k)
    out.update(provenance=prov,unknown=any(v=="UNKNOWN" for v in out.values()))
    return out

def pending(r,missing,hs,provider=None,metrics=None,locks=None):
    return {"route_id":r,"decision":"PENDING_EXTERNAL_EVIDENCE","eligible":False,"reasons":["missing or incomplete live evidence: "+",".join(sorted(missing))],
      "metrics":metrics,"provider":provider,"source_sha256":dict(hs),"source_locks":locks,"score":None}

def route(r,docs,hs,p):
    if docs.get("e01") is None: return pending(r,["E01"],hs)
    if not hs.get("e01"): fail("L1E06_SOURCE_SHA_REQUIRED","e01")
    e1=e01_doc(mp(docs["e01"],"e01")); provider={"provider_id":e1["provider_id"],"provider_kind":e1["provider_kind"],"account_tier":e1["account_tier"],"service_region":e1["service_region"],"data_region":e1["data_region"],"capability_snapshot_sha256":e1["capability_snapshot_sha256"],"approved_models":e1["models"]}; l1={"e01_approval_identity_sha256":e1["approval_identity"]}
    if not e1["commercial"] or e1["training"] or e1["service_region"] not in p["allowed_service_regions"] or e1["data_region"] not in p["allowed_data_regions"] or e1["retention"]>p["maximum_uploaded_asset_retention_seconds"] or (p["require_delete_api"] and not e1["delete_api"]):
        return {"route_id":r,"decision":"REJECT_PRIVACY","eligible":False,"reasons":["commercial/privacy/service-region/data-region/retention/delete policy failed"],"metrics":{"uploaded_asset_retention_seconds":e1["retention"],"delete_api_available":e1["delete_api"]},"provider":provider,"source_sha256":dict(hs),"source_locks":l1,"score":None}
    if not e1["ready"]: return pending(r,["E01_READY"],hs,provider,None,l1)
    miss=[x.upper() for x in ("e03","e04","e05") if docs.get(x) is None]
    if miss: return pending(r,miss,hs,provider,None,l1)
    for x in ("e03","e04","e05"):
        if not hs.get(x): fail("L1E06_SOURCE_SHA_REQUIRED",x)
    e3=e03_doc(mp(docs["e03"],"e03"),e1,str(hs["e01"])); e4=e04_doc(mp(docs["e04"],"e04"),e3,str(hs["e03"])); e5=e05_doc(mp(docs["e05"],"e05"),e1,e3,str(hs["e01"]),str(hs["e03"]))
    cp=None
    if docs.get("capacity") is not None:
        if not hs.get("capacity"): fail("L1E06_SOURCE_SHA_REQUIRED","capacity")
        cp=cap_doc(mp(docs["capacity"],"capacity"),e1,e5)
    locks={**l1,"e03_live_benchmark_lock_sha256":e3["lock"],"e04_differential_lock_sha256":e4["lock"],"e05_live_recovery_lock_sha256":e5["lock"]}
    if cp: locks["capacity_provider_account_provenance_sha256"]=cp["provenance"]
    met={"mode_classes":sorted(e3["classes"]),"used_models":e3["used_models"],"g1_objective_run_count":e3["g1"],"g1_objective_floor_pass":e3["obj"],"final_failure_fraction":e3["fail"],"retry_fraction":e3["retry"],"mean_provider_total_ms":e3["lat"],"mean_cost_per_successful_run":e3["cost"],"cost_currency":e3["currency"],"successful_run_count":e3["success"],"overall_usability_delta_project_minus_reference":e4["delta"],"material_inferiority_detected":e4["inferior"],"non_cancel_degraded_fraction":e5["degraded"],"rate_limit_fault_observed":e5["rate"],"long_track_streaming_observed":e5["long"],"storage_preflight_observed":e5["storage"],"capacity":{k:(cp[k] if cp else "UNKNOWN") for k in ("quota_status","credit_status","rate_limit_capacity_status")}}
    decision=None; reason=[]
    if not set(p["required_mode_classes"]).issubset(e3["classes"]): decision="REJECT_CAPABILITY"; reason=["required separation mode class missing"]
    elif cp and (cp["quota_status"]=="INSUFFICIENT" or cp["credit_status"]=="INSUFFICIENT"): decision="REJECT_CAPABILITY"; reason=["provider quota/credit capacity insufficient"]
    elif e4["state"]=="DIFFERENTIAL_FAIL" or e4["inferior"] or not e4["vote"] or not e3["obj"] or e3["g1"]<=0: decision="REJECT_QUALITY"; reason=["objective or current-iPhone differential quality gate failed"]
    elif e4["delta"] is not None and (e4["delta"]<p["minimum_overall_usability_delta"] or not e4["threshold"]): decision="REJECT_QUALITY"; reason=["blind-listening usability delta below policy"]
    elif not e5["cancel"]: decision="REJECT_CANCELLATION"; reason=["cancellation truthfulness/publication invariant failed"]
    elif cp and cp["rate_limit_capacity_status"]=="INSUFFICIENT": decision="REJECT_RELIABILITY"; reason=["provider rate-limit capacity insufficient"]
    elif not e3["ready"] or not e3["checks"] or e3["fail"]>p["maximum_final_failure_fraction"] or e3["retry"]>p["maximum_retry_fraction"] or not e5["ready"] or not e5["checks"] or e5["degraded"]>p["maximum_non_cancel_degraded_fraction"]: decision="REJECT_RELIABILITY"; reason=["live reliability/recovery thresholds failed; safe fail-closed is degraded, not success"]
    elif e3["lat"]>p["maximum_mean_provider_total_ms"]: decision="REJECT_LATENCY"; reason=["mean provider latency exceeds policy"]
    elif e3["currency"]!=p["cost_currency"] or e3["cost"]>p["maximum_mean_cost_per_successful_run"]: decision="REJECT_COST"; reason=["actual live cost exceeds policy or currency incomparable"]
    if decision is None and e4["state"]=="WAITING_REVIEW": return pending(r,["E04_HUMAN_REVIEW"],hs,provider,met,locks)
    if decision is None and e4["delta"] is None: return pending(r,["E04_USABILITY_SCORE"],hs,provider,met,locks)
    if decision is None and p["require_capacity_attestation"] and (cp is None or cp["unknown"]): return pending(r,["E06_CAPACITY_ATTESTATION"],hs,provider,met,locks)
    return {"route_id":r,"decision":decision or "ACCEPT_WITH_LIMITS","eligible":decision is None,"reasons":reason or ["all hard route gates satisfied; primary ranking separate"],"metrics":met,"provider":provider,"source_sha256":dict(hs),"source_locks":locks,"score":None}

def margin(v,m):
    if m<=0:return 1.0 if v<=0 else 0.0
    return max(0,min(1,1-v/m))
def score(r,p):
    m=r["metrics"]; q=max(0,min(1,(float(m["overall_usability_delta_project_minus_reference"])+4)/8))
    return p["ranking_weights"]["quality"]*q+p["ranking_weights"]["latency"]*margin(m["mean_provider_total_ms"],p["maximum_mean_provider_total_ms"])+p["ranking_weights"]["reliability"]*margin(m["non_cancel_degraded_fraction"],p["maximum_non_cancel_degraded_fraction"])+p["ranking_weights"]["cost"]*margin(m["mean_cost_per_successful_run"],p["maximum_mean_cost_per_successful_run"])

def decide_routes(*,plan,route_docs,source_hashes):
    n=plan_doc(plan)
    if not n["policy"]["engineering_policy_not_reference_fact"]: fail("L1E06_POLICY_REFERENCE_FACT_PROHIBITED")
    ids=sorted(route_docs)
    if not ids or set(ids)!=set(source_hashes): fail("L1E06_ROUTE_SOURCE_SET_MISMATCH")
    rows=[route(i,mp(route_docs[i],i),mp(source_hashes[i],i),n["policy"]) for i in ids]; ok=[x for x in rows if x["eligible"]]; pend=[x for x in rows if x["decision"]=="PENDING_EXTERNAL_EVIDENCE"]
    for x in ok:x["score"]=score(x,n["policy"])
    state="NO_ACCEPTABLE_ROUTE"
    if pend:
        state="PENDING_EXTERNAL_EVIDENCE"
        for x in ok:x["decision"]="ACCEPT_WITH_LIMITS";x["reasons"]=["this route passes, but another declared candidate still lacks required live evidence"]
    elif ok:
        rank=sorted(ok,key=lambda x:(-x["score"],x["route_id"]))
        if len(rank)==1:rank[0]["decision"]="ACCEPT_PRIMARY";rank[0]["reasons"]=["only fully evaluated route satisfying all hard gates"];state="PRIMARY_SELECTED"
        else:
            gap=rank[0]["score"]-rank[1]["score"]
            if gap>=n["policy"]["minimum_primary_score_margin"]:rank[0]["decision"]="ACCEPT_PRIMARY";rank[0]["reasons"]=[f"highest evidence-derived score with margin {gap:.9f}"];state="PRIMARY_SELECTED"
            else:
                state="MULTIPLE_ACCEPTABLE_ROUTES"
                for x in rank:x["decision"]="ACCEPT_WITH_LIMITS";x["reasons"]=["hard gates pass but score margin is insufficient for automatic primary selection"]
    outcomes={x["route_id"]:x["decision"] for x in rows}; binding={i:{k:source_hashes[i].get(k) for k in ("e01","e03","e04","e05","capacity")} for i in ids}
    ident=csha({"domain":"l1-e06-provider-route-decision-v1","decision_id":n["decision_id"],"policy":n["policy"],"evidence_binding":binding,"route_outcomes":outcomes})
    report={"schema_version":1,"tool_version":TOOL,"evidence_kind":"PROVIDER_ROUTE_DECISION","evidence_state":NON,"decision_state":state,"parity_claim":"NONE","decision_id":n["decision_id"],"policy":n["policy"],"routes":sorted(rows,key=lambda x:x["route_id"]),"decision_identity_sha256":ident,
      "fallback_order":["LICENSED_LOCAL_INFERENCE_SDK","ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER","PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE"],
      "privacy":{k:False for k in ("credential_values_emitted","provider_task_ids_emitted","provider_account_ids_emitted","private_contract_text_emitted","raw_billing_records_emitted","raw_audio_emitted","private_paths_emitted","raw_quota_values_emitted","raw_credit_values_emitted")},
      "parity_reason":"E06 provider routing evidence is necessary but never sufficient for product PARITY; HQ Late Integration remains authoritative."}
    report["decision_lock_sha256"]=csha({"identity":ident,"routes":rows,"policy":n["policy"]})
    return report

def load(p):
    try:return mp(json.loads(p.read_text(encoding="utf-8")),str(p))
    except DecisionError:raise
    except Exception as e:raise DecisionError("L1E06_JSON_INVALID",str(p)) from e
def dump(p,v):
    p.parent.mkdir(parents=True,exist_ok=True);t=p.with_name("."+p.name+".tmp")
    with t.open("w",encoding="utf-8") as f:json.dump(v,f,indent=2,sort_keys=True,ensure_ascii=False,allow_nan=False);f.write("\n");f.flush();os.fsync(f.fileno())
    os.replace(t,p)
def main(argv:Sequence[str]|None=None):
    ap=argparse.ArgumentParser();ap.add_argument("--plan",required=True);ap.add_argument("--route-index",required=True);ap.add_argument("--private-root",required=True);ap.add_argument("--out",required=True);a=ap.parse_args(argv)
    try:
        root=Path(a.private_root).resolve(); idx=load(Path(a.route_index)); docs={}; hashes={}
        for rid,raw in mp(idx.get("routes"),"routes").items():
            ev=mp(mp(raw,rid).get("evidence"),"evidence");docs[rid]={};hashes[rid]={}
            for gate in ("e01","e03","e04","e05","capacity"):
                v=ev.get(gate)
                if v is None:docs[rid][gate]=None;hashes[rid][gate]=None;continue
                rel=Path(st(v,f"{rid}.{gate}"))
                if rel.is_absolute() or ".." in rel.parts:fail("L1E06_EVIDENCE_PATH_UNSAFE",f"{rid}:{gate}")
                p=(root/rel).resolve()
                try:p.relative_to(root)
                except ValueError as e:raise DecisionError("L1E06_EVIDENCE_PATH_ESCAPE",f"{rid}:{gate}") from e
                if not p.is_file():fail("L1E06_EVIDENCE_FILE_MISSING",f"{rid}:{gate}")
                docs[rid][gate]=load(p);hashes[rid][gate]=fsha(p)
        r=decide_routes(plan=load(Path(a.plan)),route_docs=docs,source_hashes=hashes);dump(Path(a.out),r)
        print(json.dumps({"status":"PASS","decision_state":r["decision_state"],"decision_lock":r["decision_lock_sha256"]},sort_keys=True));return 0
    except DecisionError as e:
        print(json.dumps({"status":"FAIL","code":e.code,"message":e.message},sort_keys=True),file=sys.stderr);return 2
if __name__=="__main__":raise SystemExit(main())
