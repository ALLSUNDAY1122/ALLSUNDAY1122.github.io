import json, os, tempfile, unittest
from pathlib import Path
from generated_stem_retention import *

H=lambda c:c*64
def V(project=H("1"),role="guitar",gen=H("2"),variant=0,artifact=H("a")):
    return {"schema_version":1,"project_ref_hash":project,"role":role,"generation_ref_hash":gen,
            "variant_index":variant,"artifact_sha256":artifact,"artifact_bytes":123,"sample_rate":48000,
            "channels":2,"audio_format":1,"bits_per_sample":16,"frame_count":4800,
            "mix_ready_receipt_sha256":H("b")}

class A24(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory(); self.root=Path(self.t.name)/"store"
        for d in ("objects","manifests","active"):(self.root/d).mkdir(parents=True,exist_ok=True)
        self.c=GeneratedStemRetentionCoordinator(self.root,Path(self.t.name)/"ledger.json")
    def tearDown(self): self.t.cleanup()
    def put(self,v,active=True):
        mp=self.root/"manifests"/f"{v['generation_ref_hash']}.v{v['variant_index']}.json"
        mp.write_text(json.dumps(v,sort_keys=True,separators=(",",":")))
        op=self.root/"objects"/f"{v['artifact_sha256']}.wav";op.write_bytes(b"x")
        if active:(self.root/"active"/f"{v['project_ref_hash']}.{v['role']}.json").write_text(json.dumps(v,sort_keys=True,separators=(",",":")))
        return mp,op
    def begin(self,v):
        return self.c.begin_delete(project_ref_hash=v["project_ref_hash"],role=v["role"],
          generation_ref_hash=v["generation_ref_hash"],variant_index=v["variant_index"],
          request_reason="USER_DELETE",delete_intent_evidence_sha256=H("c"))
    def code(self,code,fn):
        with self.assertRaises(GeneratedStemRetentionError) as x:fn()
        self.assertEqual(x.exception.code,code)

    def test_01_intent_before_delete_and_idempotent(self):
        v=V();mp,op=self.put(v);a=self.begin(v);b=self.begin(v)
        self.assertEqual(a,b);self.assertTrue(mp.exists() and op.exists());self.assertEqual(a.local_state,"DELETE_INTENT_DURABLE")
    def test_02_active_delete(self):
        v=V();mp,op=self.put(v);r=self.begin(v);x=self.c.execute_local_delete(r.deletion_id)
        self.assertTrue(x.local_delete_completed);self.assertFalse(mp.exists());self.assertFalse(op.exists())
    def test_03_inactive_delete_preserves_other_active(self):
        old=V(gen=H("2"),variant=0,artifact=H("a"));new=V(gen=H("3"),variant=1,artifact=H("d"))
        self.put(old,False);self.put(new,True);r=self.begin(old);self.c.execute_local_delete(r.deletion_id)
        self.assertEqual(json.loads((self.root/"active"/f"{new['project_ref_hash']}.{new['role']}.json").read_text())["generation_ref_hash"],H("3"))
    def test_04_shared_object_protected_by_manifest(self):
        a=V(gen=H("2"),artifact=H("a"));b=V(gen=H("3"),variant=1,artifact=H("a"))
        _,op=self.put(a,True);self.put(b,False);x=self.c.execute_local_delete(self.begin(a).deletion_id)
        self.assertTrue(op.exists());self.assertTrue(x.object_retained_due_to_reference)
    def test_05_shared_object_protected_by_active_without_manifest(self):
        a=V();b=V(project=H("4"),gen=H("3"),variant=1,artifact=H("a"));_,op=self.put(a,True)
        (self.root/"active"/f"{b['project_ref_hash']}.{b['role']}.json").write_text(json.dumps(b,sort_keys=True,separators=(",",":")))
        x=self.c.execute_local_delete(self.begin(a).deletion_id);self.assertTrue(op.exists());self.assertTrue(x.object_retained_due_to_reference)
    def test_06_corrupt_manifest_blocks_gc(self):
        v=V();self.put(v);r=self.begin(v);(self.root/"manifests"/"broken.v0.json").write_text("bad")
        self.code("GENRET_REFERENCE_MANIFEST_CORRUPT",lambda:self.c.execute_local_delete(r.deletion_id))
    def test_07_corrupt_active_blocks_gc(self):
        v=V();self.put(v);r=self.begin(v);(self.root/"active"/f"{H('4')}.bass.json").write_text("bad")
        self.code("GENRET_REFERENCE_ACTIVE_CORRUPT",lambda:self.c.execute_local_delete(r.deletion_id))
    def test_08_manifest_mutation_after_intent(self):
        v=V();mp,_=self.put(v);r=self.begin(v);mp.write_text(mp.read_text()+" ")
        self.code("GENRET_MANIFEST_MUTATED",lambda:self.c.execute_local_delete(r.deletion_id))
    def test_09_delete_idempotent(self):
        v=V();self.put(v);r=self.begin(v);a=self.c.execute_local_delete(r.deletion_id);b=self.c.execute_local_delete(r.deletion_id);self.assertEqual(a,b)
    def test_10_tombstone_guard(self):
        v=V();self.put(v);self.begin(v);self.code("GENRET_GENERATION_TOMBSTONED",lambda:self.c.assert_generation_not_deleted(v["generation_ref_hash"]))
    def test_11_refund_request_needs_a21_pending(self):
        v=V();self.put(v);r=self.begin(v);self.code("GENRET_A21_REFUND_PENDING_REQUIRED",lambda:self.c.record_refund_requested(r.deletion_id,a21_credit_state="committed",request_evidence_sha256=H("d")))
    def test_12_refund_independent_of_delete(self):
        v=V();self.put(v);r=self.begin(v);x=self.c.record_refund_requested(r.deletion_id,a21_credit_state="refund_pending",request_evidence_sha256=H("d"))
        self.assertEqual(x.refund_state,"PENDING");self.assertEqual(x.local_state,"DELETE_INTENT_DURABLE")
    def test_13_refund_confirm_needs_a21_refunded(self):
        v=V();self.put(v);r=self.begin(v);self.c.record_refund_requested(r.deletion_id,a21_credit_state="refund_pending",request_evidence_sha256=H("d"))
        self.code("GENRET_A21_REFUNDED_REQUIRED",lambda:self.c.record_refund_authority(r.deletion_id,a21_credit_state="refund_pending",outcome="CONFIRMED",authority_evidence_sha256=H("e")))
    def test_14_refund_authority_needs_request(self):
        v=V();self.put(v);r=self.begin(v);self.code("GENRET_REFUND_AUTHORITY_WITHOUT_REQUEST",lambda:self.c.record_refund_authority(r.deletion_id,a21_credit_state="refunded",outcome="CONFIRMED",authority_evidence_sha256=H("e")))
    def test_15_refund_confirmed(self):
        v=V();self.put(v);r=self.begin(v);self.c.record_refund_requested(r.deletion_id,a21_credit_state="refund_pending",request_evidence_sha256=H("d"))
        self.assertEqual(self.c.record_refund_authority(r.deletion_id,a21_credit_state="refunded",outcome="CONFIRMED",authority_evidence_sha256=H("e")).refund_state,"CONFIRMED")
    def test_16_local_delete_does_not_imply_refund(self):
        v=V();self.put(v);r=self.begin(v);self.c.execute_local_delete(r.deletion_id);e=self.c.privacy_safe_evidence(r.deletion_id)
        self.assertTrue(e["local_deletion_complete"]);self.assertFalse(e["refund_confirmed"]);self.assertTrue(e["deletion_does_not_imply_refund"])
    def test_17_runtime_unsupported_not_erasure(self):
        v=V();self.put(v);r=self.begin(v);self.c.execute_local_delete(r.deletion_id);self.c.record_runtime_delete(r.deletion_id,outcome="UNSUPPORTED",authority_evidence_sha256=H("f"))
        self.assertFalse(self.c.privacy_safe_evidence(r.deletion_id)["runtime_erasure_authoritatively_complete"])
    def test_18_runtime_not_applicable_evidence(self):
        v=V();self.put(v);r=self.begin(v);self.c.execute_local_delete(r.deletion_id);self.c.record_runtime_delete(r.deletion_id,outcome="NOT_APPLICABLE",authority_evidence_sha256=H("f"))
        self.assertTrue(self.c.privacy_safe_evidence(r.deletion_id)["overall_erasure_complete"])
    def test_19_orphan_object_sweep(self):
        p=self.root/"objects"/f"{H('a')}.wav";p.write_bytes(b"x");os.utime(p,(1,1));self.assertEqual(self.c.sweep_orphan_objects(minimum_age_seconds=10,now_epoch=100),(H("a"),))
    def test_20_orphan_sweep_keeps_active_only_reference(self):
        v=V();p=self.root/"objects"/f"{H('a')}.wav";p.write_bytes(b"x");os.utime(p,(1,1))
        (self.root/"active"/f"{v['project_ref_hash']}.{v['role']}.json").write_text(json.dumps(v,sort_keys=True,separators=(",",":")))
        self.assertEqual(self.c.sweep_orphan_objects(minimum_age_seconds=10,now_epoch=100),());self.assertTrue(p.exists())
    def test_21_orphan_sweep_grace(self):
        p=self.root/"objects"/f"{H('a')}.wav";p.write_bytes(b"x");os.utime(p,(95,95));self.assertEqual(self.c.sweep_orphan_objects(minimum_age_seconds=10,now_epoch=100),())
    def test_22_stale_temp_only(self):
        p=self.root/"objects"/"x.tmp";p.write_bytes(b"x");os.utime(p,(1,1));q=self.root/"objects"/f"{H('a')}.wav";q.write_bytes(b"x");os.utime(q,(1,1))
        self.assertEqual(self.c.sweep_stale_temp_files(minimum_age_seconds=10,now_epoch=100),("objects/x.tmp",));self.assertTrue(q.exists())
    def test_23_abandoned_cleanup_requires_failed_cancelled_and_inactive(self):
        v=V();self.put(v,False);r=self.c.begin_abandoned_cleanup(generation_ref_hash=H("2"),variant_index=0,a21_lifecycle_state="failed",abandonment_evidence_sha256=H("8"))
        self.assertEqual(r.request_reason,"CANCEL_CLEANUP")
        w=V(project=H("4"),gen=H("5"),artifact=H("6"));self.put(w,True)
        self.code("GENRET_ACTIVE_VARIANT_NOT_ABANDONED",lambda:self.c.begin_abandoned_cleanup(generation_ref_hash=H("5"),variant_index=0,a21_lifecycle_state="cancelled",abandonment_evidence_sha256=H("8")))
    def test_24_privacy_safe_evidence(self):
        v=V();self.put(v);r=self.begin(v);e=self.c.privacy_safe_evidence(r.deletion_id);s=json.dumps(e)
        self.assertNotIn(str(self.root),s);self.assertFalse(e["path_emitted"]);self.assertFalse(e["raw_audio_emitted"]);self.assertEqual(e["parity_claim"],"NONE")

if __name__=="__main__":unittest.main()
