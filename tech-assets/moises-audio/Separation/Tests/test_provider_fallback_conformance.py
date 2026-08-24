from __future__ import annotations
import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent / "Evaluation"
sys.path.insert(0, str(EVAL))
import provider_fallback_conformance as e07

def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

class E07Tests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(); base = Path(self.td.name)
        self.repo = base / "repo"; self.private = base / "private"; self.repo.mkdir(); self.private.mkdir()
        self.adapter = self.repo / "Separation" / "fallback_adapter.py"; self.adapter.parent.mkdir()
        self.adapter.write_text("class FallbackAdapter:\n def upload_asset(self, source_path): pass\n def create_separation_task(self, asset_id, models, metadata=None): pass\n def get_task_state(self, task_id): pass\n def find_tasks_by_metadata(self, metadata): pass\n def cancel_task(self, task_id): pass\n")
        self.inv = []; evdir = self.repo / "Processing" / "Evidence"; evdir.mkdir(parents=True)
        for iid in e07.REQUIRED_INVARIANTS:
            p = evdir / (iid + ".json"); p.write_text(json.dumps({"id": iid, "pass": True}))
            self.inv.append({"invariant_id": iid, "status": "PASS", "waived": False, "evidence_path": p.relative_to(self.repo).as_posix(), "evidence_sha256": sha(p)})
        for name in ("commercial.txt","authority.txt","runtime.bin","local-disposition.txt","hosted-disposition.txt","training.txt"):
            (self.private/name).write_text(name+"-evidence")
        self.plan = {"schema_version":1,"evidence_state":e07.EVIDENCE_STATE,"parity_claim":"NONE","substitution_id":"sub-1","replaced_route_id":"hosted-primary","selected_fallback_kind":"LICENSED_LOCAL_INFERENCE_SDK","fallback_order":list(e07.FALLBACK_ORDER)}
        self.manifest = {"schema_version":1,"evidence_state":e07.EVIDENCE_STATE,"parity_claim":"NONE","route_id":"local-fallback","route_kind":"LICENSED_LOCAL_INFERENCE_SDK","replaced_route_id":"hosted-primary","adapter":{"source_path":self.adapter.relative_to(self.repo).as_posix(),"source_sha256":sha(self.adapter),"class_name":"FallbackAdapter"},"shared_app_contract_changed":False,"provider_neutral_publication_contract_preserved":True,"prior_fallback_dispositions":[],"invariants":copy.deepcopy(self.inv),"capacity_authority":{"kind":"LOCAL_RUNTIME","provenance_path":"authority.txt","provenance_sha256":sha(self.private/"authority.txt")},"commercial_basis":{"document_path":"commercial.txt","document_sha256":sha(self.private/"commercial.txt"),"consumer_app_commercial_use_allowed":True,"output_export_allowed":True,"provider_training_on_user_content_allowed":False},"runtime":{"runtime_id":"local-sdk-v1","model_name":"model","model_version":"1","quality_profile":"standard","artifact_path":"runtime.bin","artifact_sha256":sha(self.private/"runtime.bin")},"training_rights":None}
    def tearDown(self): self.td.cleanup()
    def runit(self, plan=None, manifest=None): return e07.evaluate_substitution(plan=plan or self.plan,manifest=manifest or self.manifest,repo_root=self.repo,private_root=self.private)
    def expect(self, code, mutate):
        m=copy.deepcopy(self.manifest);p=copy.deepcopy(self.plan);mutate(p,m)
        with self.assertRaises(e07.SubstitutionError) as cm:self.runit(p,m)
        self.assertEqual(cm.exception.code,code)
    def test_01_local_honest_authority(self):
        r=self.runit();self.assertEqual(r["conformance_state"],"CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE");self.assertEqual(r["capacity_authority"]["kind"],"LOCAL_RUNTIME");self.assertFalse(r["compatibility"]["legacy_e05_e06_hosted_account_schema_compatible"])
    def test_02_hosted_fallback(self):
        p=copy.deepcopy(self.plan);m=copy.deepcopy(self.manifest);p["selected_fallback_kind"]=e07.FALLBACK_ORDER[1];m["route_kind"]=p["selected_fallback_kind"];m["route_id"]="hosted-2";m["capacity_authority"]["kind"]="HOSTED_PROVIDER_ACCOUNT";m["prior_fallback_dispositions"]=[{"fallback_kind":e07.FALLBACK_ORDER[0],"disposition":"UNAVAILABLE","evidence_path":"local-disposition.txt","evidence_sha256":sha(self.private/"local-disposition.txt")}]
        r=self.runit(p,m);self.assertEqual(r["conformance_state"],"READY_FOR_HQ_E07_SUBSTITUTION_REVIEW");self.assertTrue(r["compatibility"]["legacy_e05_e06_hosted_account_schema_compatible"])
    def test_03_project_owned(self):
        p=copy.deepcopy(self.plan);m=copy.deepcopy(self.manifest);p["selected_fallback_kind"]=e07.FALLBACK_ORDER[2];m["route_kind"]=p["selected_fallback_kind"];m["route_id"]="owned";m["capacity_authority"]["kind"]="PROJECT_OWNED_RUNTIME";m["prior_fallback_dispositions"]=[{"fallback_kind":e07.FALLBACK_ORDER[0],"disposition":"REJECTED","evidence_path":"local-disposition.txt","evidence_sha256":sha(self.private/"local-disposition.txt")},{"fallback_kind":e07.FALLBACK_ORDER[1],"disposition":"UNAVAILABLE","evidence_path":"hosted-disposition.txt","evidence_sha256":sha(self.private/"hosted-disposition.txt")}];m["training_rights"]={"rights_cleared_for_training":True,"evidence_path":"training.txt","evidence_sha256":sha(self.private/"training.txt")}
        r=self.runit(p,m);self.assertEqual(r["capacity_authority"]["kind"],"PROJECT_OWNED_RUNTIME");self.assertIsNotNone(r["training_rights_evidence_sha256"])
    def test_04_fake_provider_account_for_local_rejected(self): self.expect("L1E07_FAKE_PROVIDER_ACCOUNT_FORBIDDEN",lambda p,m:m["capacity_authority"].update(provider_account_id="fake"))
    def test_05_authority_kind_mismatch(self): self.expect("L1E07_CAPACITY_AUTHORITY_KIND_MISMATCH",lambda p,m:m["capacity_authority"].update(kind="HOSTED_PROVIDER_ACCOUNT"))
    def test_06_adapter_sha_mismatch(self): self.expect("L1E07_REPO_FILE_SHA_MISMATCH",lambda p,m:m["adapter"].update(source_sha256="0"*64))
    def test_07_adapter_class_missing(self): self.expect("L1E07_ADAPTER_CLASS_MISSING",lambda p,m:m["adapter"].update(class_name="Nope"))
    def test_08_adapter_method_missing(self):
        self.adapter.write_text("class FallbackAdapter:\n def upload_asset(self,x): pass\n");m=copy.deepcopy(self.manifest);m["adapter"]["source_sha256"]=sha(self.adapter)
        with self.assertRaises(e07.SubstitutionError) as cm:self.runit(manifest=m)
        self.assertEqual(cm.exception.code,"L1E07_ADAPTER_METHOD_MISSING")
    def test_09_unsafe_repo_path(self): self.expect("L1E07_REPO_PATH_UNSAFE",lambda p,m:m["adapter"].update(source_path="../x"))
    def test_10_private_root_inside_repo(self):
        with self.assertRaises(e07.SubstitutionError) as cm:e07.evaluate_substitution(plan=self.plan,manifest=self.manifest,repo_root=self.repo,private_root=self.repo/"x")
        self.assertEqual(cm.exception.code,"L1E07_PRIVATE_ROOT_INSIDE_REPOSITORY")
    def test_11_invariant_missing(self): self.expect("L1E07_INVARIANT_SET_INCOMPLETE",lambda p,m:m["invariants"].pop())
    def test_12_invariant_duplicate(self): self.expect("L1E07_INVARIANT_DUPLICATE",lambda p,m:m["invariants"].append(copy.deepcopy(m["invariants"][0])))
    def test_13_invariant_fail(self): self.expect("L1E07_INVARIANT_NOT_PASS",lambda p,m:m["invariants"][0].update(status="FAIL"))
    def test_14_invariant_waiver(self): self.expect("L1E07_INVARIANT_WAIVER_FORBIDDEN",lambda p,m:m["invariants"][0].update(waived=True))
    def test_15_invariant_evidence_mutated(self): self.expect("L1E07_REPO_FILE_SHA_MISMATCH",lambda p,m:m["invariants"][0].update(evidence_sha256="1"*64))
    def test_16_shared_app_change(self): self.expect("L1E07_SHARED_APP_CHANGE_FORBIDDEN",lambda p,m:m.update(shared_app_contract_changed=True))
    def test_17_contract_not_preserved(self): self.expect("L1E07_PROVIDER_NEUTRAL_CONTRACT_NOT_PRESERVED",lambda p,m:m.update(provider_neutral_publication_contract_preserved=False))
    def test_18_reuse_rejected_route_id(self): self.expect("L1E07_ROUTE_ID_REUSE_FORBIDDEN",lambda p,m:m.update(route_id="hosted-primary"))
    def test_19_skip_local_without_disposition(self):
        def mut(p,m):p.update(selected_fallback_kind=e07.FALLBACK_ORDER[1]);m.update(route_kind=e07.FALLBACK_ORDER[1]);m["capacity_authority"].update(kind="HOSTED_PROVIDER_ACCOUNT")
        self.expect("L1E07_FALLBACK_ORDER_SKIP_UNPROVEN",mut)
    def test_20_prior_disposition_bad_state(self):
        def mut(p,m):p.update(selected_fallback_kind=e07.FALLBACK_ORDER[1]);m.update(route_kind=e07.FALLBACK_ORDER[1]);m["capacity_authority"].update(kind="HOSTED_PROVIDER_ACCOUNT");m["prior_fallback_dispositions"]=[{"fallback_kind":e07.FALLBACK_ORDER[0],"disposition":"SKIPPED","evidence_path":"local-disposition.txt","evidence_sha256":sha(self.private/"local-disposition.txt")}]
        self.expect("L1E07_PRIOR_DISPOSITION_STATE_INVALID",mut)
    def test_21_commercial_missing(self): self.expect("L1E07_COMMERCIAL_USE_NOT_APPROVED",lambda p,m:m["commercial_basis"].update(consumer_app_commercial_use_allowed=False))
    def test_22_export_missing(self): self.expect("L1E07_OUTPUT_EXPORT_NOT_APPROVED",lambda p,m:m["commercial_basis"].update(output_export_allowed=False))
    def test_23_training_forbidden(self): self.expect("L1E07_PROVIDER_TRAINING_NOT_ALLOWED",lambda p,m:m["commercial_basis"].update(provider_training_on_user_content_allowed=True))
    def test_24_project_owned_training_rights_required(self):
        def mut(p,m):
            p.update(selected_fallback_kind=e07.FALLBACK_ORDER[2]);m.update(route_kind=e07.FALLBACK_ORDER[2],route_id="owned");m["capacity_authority"].update(kind="PROJECT_OWNED_RUNTIME");m["prior_fallback_dispositions"]=[{"fallback_kind":e07.FALLBACK_ORDER[0],"disposition":"REJECTED","evidence_path":"local-disposition.txt","evidence_sha256":sha(self.private/"local-disposition.txt")},{"fallback_kind":e07.FALLBACK_ORDER[1],"disposition":"REJECTED","evidence_path":"hosted-disposition.txt","evidence_sha256":sha(self.private/"hosted-disposition.txt")}];m["training_rights"]={"rights_cleared_for_training":False,"evidence_path":"training.txt","evidence_sha256":sha(self.private/"training.txt")}
        self.expect("L1E07_TRAINING_RIGHTS_NOT_CLEARED",mut)
    def test_25_private_artifact_sha_mismatch(self): self.expect("L1E07_PRIVATE_FILE_SHA_MISMATCH",lambda p,m:m["runtime"].update(artifact_sha256="2"*64))
    def test_26_parity_claim_forbidden(self): self.expect("L1E07_PARITY_CLAIM_FORBIDDEN",lambda p,m:p.update(parity_claim="PARITY"))
    def test_27_output_privacy(self):
        r=self.runit();text=json.dumps(r);self.assertNotIn(str(self.private),text);self.assertNotIn("commercial.txt",text);self.assertNotIn("authority.txt",text);self.assertTrue(all(v is False for v in r["privacy"].values()))
    def test_28_order_identity_deterministic(self):
        r1=self.runit();m=copy.deepcopy(self.manifest);m["invariants"]=list(reversed(m["invariants"]));r2=self.runit(manifest=m);self.assertEqual(r1["substitution_identity_sha256"],r2["substitution_identity_sha256"])
    def test_29_authority_mutation_changes_lock(self):
        r1=self.runit();(self.private/"authority.txt").write_text("changed");m=copy.deepcopy(self.manifest);m["capacity_authority"]["provenance_sha256"]=sha(self.private/"authority.txt");r2=self.runit(manifest=m);self.assertNotEqual(r1["e07_substitution_lock_sha256"],r2["e07_substitution_lock_sha256"])
    def test_30_unexpected_training_rights_local(self): self.expect("L1E07_TRAINING_RIGHTS_UNEXPECTED",lambda p,m:m.update(training_rights={"x":1}))

if __name__=="__main__": unittest.main()
