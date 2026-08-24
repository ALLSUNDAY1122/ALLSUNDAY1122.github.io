from __future__ import annotations
import copy, hashlib, json, shutil, sys, tempfile, unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/"Evaluation"))
import generic_evaluation_provenance as gep

def jb(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,sort_keys=True,indent=2)+"\n",encoding="utf-8"); return hashlib.sha256(path.read_bytes()).hexdigest()
def bb(path,data):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data); return hashlib.sha256(data).hexdigest()

class E10Tests(unittest.TestCase):
    def setUp(self):
        self.td=Path(tempfile.mkdtemp()); self.repo=self.td/"repo"; self.private=self.td/"private"; self.repo.mkdir(); self.private.mkdir()
        self.ev={}
        for n in ("commercial","privacy","region","retention","deletion","run1","run2","run3","review1","review2"):
            self.ev[n]=bb(self.private/"evidence"/f"{n}.bin",f"{n}-evidence".encode())
        self.e07={"schema_version":1,"tool_version":"L1-E07-v1","evidence_kind":"PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE","evidence_state":gep.NON,"conformance_state":"CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE","parity_claim":"NONE","substitution_id":"sub1","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","replaced_route_id":"old","runtime":{"runtime_id":"rt1","model_name":"m","model_version":"1","quality_profile":"std","artifact_sha256":"a"*64},"capacity_authority":{"kind":"LOCAL_RUNTIME","provenance_sha256":"b"*64},"e07_substitution_lock_sha256":"e"*64}
        self.e07p=self.private/"e07.json"; self.e07sha=jb(self.e07p,self.e07)
        self.e08={"schema_version":1,"evidence_kind":"RUNTIME_AUTHORITY_LIVE_GATE","evidence_state":gep.NON,"parity_claim":"NONE","gate_state":"READY_FOR_HQ_E08_LIVE_REVIEW","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","authority":{"kind":"LOCAL_RUNTIME","provenance_sha256":"b"*64},"runtime_artifact_sha256":"a"*64,"source_evidence":{"e07_evidence_sha256":self.e07sha,"e07_substitution_lock_sha256":"e"*64},"e08_live_authority_lock_sha256":"f"*64}
        self.e08p=self.private/"e08.json"; self.e08sha=jb(self.e08p,self.e08)
        self.plan={"schema_version":1,"evidence_state":gep.NON,"parity_claim":"NONE","decision_id":"d1","policy":{"minimum_overall_usability_delta":-0.25}}
        self.opm={"commercial_use_allowed":True,"input_confidential":True,"output_commercial_use_allowed":True,"output_export_allowed":True,"training_on_user_content_allowed":False,"service_region":"LOCAL","data_region":"LOCAL","uploaded_asset_retention_seconds":0,"deletion_control_available":True,"commercial_basis_sha256":"c"*64}
        mapping={"commercial_use_allowed":"commercial","input_confidential":"privacy","output_commercial_use_allowed":"commercial","output_export_allowed":"commercial","training_on_user_content_allowed":"privacy","service_region":"region","data_region":"region","uploaded_asset_retention_seconds":"retention","deletion_control_available":"deletion","commercial_basis_sha256":"commercial"}
        self.op={"schema_version":1,"evidence_kind":"GENERIC_ROUTE_OPERATIONAL_SOURCE","evidence_state":gep.NON,"parity_claim":"NONE","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","runtime_artifact_sha256":"a"*64,"measurement":self.opm,"evidence":[{"evidence_id":v,"path":f"evidence/{v}.bin","sha256":self.ev[v]} for v in sorted(set(mapping.values()))],"field_evidence":{k:[v] for k,v in mapping.items()}}
        self.bm={"schema_version":1,"evidence_kind":"GENERIC_ROUTE_BENCHMARK_SOURCE","evidence_state":gep.NON,"parity_claim":"NONE","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","runtime_artifact_sha256":"a"*64,"runs":[
          {"run_id":"r1","mode_class":"CORE_4_STEM","success":True,"retry_count":0,"execution_total_ms":1000,"cost_total":0.1,"cost_currency":"USD","g1_objective_evaluable":True,"g1_objective_pass":True,"source_evidence_path":"evidence/run1.bin","source_evidence_sha256":self.ev["run1"]},
          {"run_id":"r2","mode_class":"CORE_4_STEM","success":True,"retry_count":1,"execution_total_ms":1100,"cost_total":0.12,"cost_currency":"USD","g1_objective_evaluable":True,"g1_objective_pass":True,"source_evidence_path":"evidence/run2.bin","source_evidence_sha256":self.ev["run2"]},
          {"run_id":"r3","mode_class":"CUSTOM","success":False,"retry_count":1,"execution_total_ms":900,"cost_total":0.05,"cost_currency":"USD","g1_objective_evaluable":False,"g1_objective_pass":False,"source_evidence_path":"evidence/run3.bin","source_evidence_sha256":self.ev["run3"]}]}
        self.diff={"schema_version":1,"evidence_kind":"GENERIC_ROUTE_DIFFERENTIAL_SOURCE","evidence_state":gep.NON,"parity_claim":"NONE","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","runtime_artifact_sha256":"a"*64,"project_input_sha256":"1"*64,"reference_input_sha256":"1"*64,"reviews":[
          {"review_id":"rev1","case_id":"c1","project_usability_score":4,"reference_usability_score":4,"materially_worse":False,"source_evidence_path":"evidence/review1.bin","source_evidence_sha256":self.ev["review1"]},
          {"review_id":"rev2","case_id":"c2","project_usability_score":4.5,"reference_usability_score":4,"materially_worse":False,"source_evidence_path":"evidence/review2.bin","source_evidence_sha256":self.ev["review2"]}]}
    def tearDown(self): shutil.rmtree(self.td,ignore_errors=True)
    def make_index(self,op=None,bm=None,diff=None):
        op=self.op if op is None else op; bm=self.bm if bm is None else bm; diff=self.diff if diff is None else diff
        osh=jb(self.private/"op.json",op); bsh=jb(self.private/"bm.json",bm); dsh=jb(self.private/"diff.json",diff)
        return {"schema_version":1,"private":True,"evidence_state":gep.NON,"parity_claim":"NONE","route_id":"route.local","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","runtime_artifact_sha256":"a"*64,"sources":{"operational":{"path":"op.json","sha256":osh},"benchmark":{"path":"bm.json","sha256":bsh},"differential":{"path":"diff.json","sha256":dsh}}}
    def runp(self,idx=None,out=None):
        return gep.produce(decision_plan=self.plan,e07=self.e07,e07_sha=self.e07sha,e08=self.e08,e08_sha=self.e08sha,source_index=idx or self.make_index(),repo_root=self.repo,private_root=self.private,out_dir=out or self.private/"out")
    def assertCode(self,code,fn):
        with self.assertRaises(gep.ProducerError) as cm: fn()
        self.assertEqual(cm.exception.code,code)
    def test_happy_deterministic_and_derived(self):
        r=self.runp(); self.assertTrue(gep.verify_existing(r)); b=r["evaluation"]["benchmark"]; d=r["evaluation"]["differential"]
        self.assertEqual(b["successful_run_count"],2); self.assertEqual(b["g1_objective_run_count"],2); self.assertAlmostEqual(b["mean_execution_total_ms"],1050); self.assertAlmostEqual(b["mean_cost_per_successful_run"],.11)
        self.assertAlmostEqual(b["final_failure_fraction"],1/3); self.assertAlmostEqual(b["retry_fraction"],2/3); self.assertTrue(d["exact_input_bytes"]); self.assertAlmostEqual(d["overall_usability_delta_project_minus_reference"],.25)
        self.assertEqual(d["comparison_state"],"READY_FOR_HQ_E09_ROUTE_EVALUATION")
        before={k:Path(p).read_bytes() for k,p in r["paths"].items()}; r2=self.runp(); after={k:Path(p).read_bytes() for k,p in r2["paths"].items()}; self.assertEqual(before,after)
        self.assertNotIn(str(self.private).lower(),json.dumps(r["receipt"]).lower()); self.assertNotIn("evidence/",json.dumps(r["receipt"]).lower())
    def test_operational_evidence_mutation(self):
        idx=self.make_index(); (self.private/"evidence/commercial.bin").write_bytes(b"mutated")
        self.assertCode("L1E10_PRIVATE_FILE_SHA_MISMATCH",lambda:self.runp(idx))
    def test_operational_unproven_field(self):
        op=copy.deepcopy(self.op); op["field_evidence"]["service_region"]=[]
        self.assertCode("L1E10_OPERATIONAL_FIELD_UNPROVEN",lambda:self.runp(self.make_index(op=op)))
    def test_benchmark_duplicate_run(self):
        bm=copy.deepcopy(self.bm); bm["runs"][1]["run_id"]="r1"
        self.assertCode("L1E10_BENCHMARK_RUN_ID",lambda:self.runp(self.make_index(bm=bm)))
    def test_benchmark_mixed_currency(self):
        bm=copy.deepcopy(self.bm); bm["runs"][1]["cost_currency"]="JPY"
        self.assertCode("L1E10_BENCHMARK_MIXED_CURRENCY",lambda:self.runp(self.make_index(bm=bm)))
    def test_g1_pass_requires_evaluation(self):
        bm=copy.deepcopy(self.bm); bm["runs"][0]["g1_objective_evaluable"]=False
        self.assertCode("L1E10_G1_PASS_WITHOUT_EVALUATION",lambda:self.runp(self.make_index(bm=bm)))
    def test_no_successful_run_fails_closed(self):
        bm=copy.deepcopy(self.bm)
        for r in bm["runs"]: r["success"]=False; r["g1_objective_pass"]=False
        self.assertCode("L1E10_BENCHMARK_NO_SUCCESSFUL_RUN",lambda:self.runp(self.make_index(bm=bm)))
    def test_exact_input_mismatch_is_derived(self):
        diff=copy.deepcopy(self.diff); diff["reference_input_sha256"]="2"*64
        r=self.runp(self.make_index(diff=diff)); self.assertFalse(r["evaluation"]["differential"]["exact_input_bytes"]); self.assertEqual(r["evaluation"]["differential"]["comparison_state"],"DIFFERENTIAL_FAIL")
    def test_waiting_review_is_derived(self):
        diff=copy.deepcopy(self.diff); diff["reviews"]=[]
        r=self.runp(self.make_index(diff=diff)); self.assertEqual(r["evaluation"]["evaluation_state"],"WAITING_REVIEW"); self.assertIsNone(r["evaluation"]["differential"]["overall_usability_delta_project_minus_reference"])
    def test_material_inferiority_is_fail(self):
        diff=copy.deepcopy(self.diff); diff["reviews"][0]["materially_worse"]=True
        r=self.runp(self.make_index(diff=diff)); self.assertTrue(r["evaluation"]["differential"]["material_inferiority_detected"]); self.assertFalse(r["evaluation"]["differential"]["material_inferiority_vote_pass"]); self.assertEqual(r["evaluation"]["differential"]["comparison_state"],"DIFFERENTIAL_FAIL")
    def test_review_id_duplicate(self):
        diff=copy.deepcopy(self.diff); diff["reviews"][1]["review_id"]="rev1"
        self.assertCode("L1E10_REVIEW_ID",lambda:self.runp(self.make_index(diff=diff)))
    def test_source_route_mismatch(self):
        bm=copy.deepcopy(self.bm); bm["route_id"]="other"
        self.assertCode("L1E10_SOURCE_ROUTE_RUNTIME_MISMATCH",lambda:self.runp(self.make_index(bm=bm)))
    def test_e08_binding_mismatch(self):
        e8=copy.deepcopy(self.e08); e8["source_evidence"]["e07_evidence_sha256"]="0"*64
        self.assertCode("L1E10_E08_E07_BINDING",lambda:gep.produce(decision_plan=self.plan,e07=self.e07,e07_sha=self.e07sha,e08=e8,e08_sha=self.e08sha,source_index=self.make_index(),repo_root=self.repo,private_root=self.private,out_dir=self.private/"out"))
    def test_source_index_sha_mismatch(self):
        idx=self.make_index(); idx["sources"]["benchmark"]["sha256"]="0"*64
        self.assertCode("L1E10_PRIVATE_FILE_SHA_MISMATCH",lambda:self.runp(idx))
    def test_private_root_must_be_outside_repo(self):
        inside=self.repo/"private"; inside.mkdir()
        self.assertCode("L1E10_PRIVATE_ROOT_INSIDE_REPOSITORY",lambda:gep.roots(self.repo,inside))
    def test_output_must_stay_private(self):
        self.assertCode("L1E10_OUTPUT_OUTSIDE_PRIVATE_ROOT",lambda:self.runp(self.make_index(),self.repo/"out"))
    def test_replay_detects_output_mutation(self):
        r=self.runp(); Path(r["paths"]["benchmark"]).write_text("{}")
        self.assertCode("L1E10_REPLAY_MISMATCH",lambda:gep.verify_existing(r))
    def test_source_path_traversal_rejected(self):
        idx=self.make_index(); idx["sources"]["benchmark"]["path"]="../bm.json"
        self.assertCode("L1E10_PRIVATE_PATH_UNSAFE",lambda:self.runp(idx))

if __name__=="__main__": unittest.main()
