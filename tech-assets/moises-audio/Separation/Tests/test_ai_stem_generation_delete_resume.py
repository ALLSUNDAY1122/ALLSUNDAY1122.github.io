import json, sys, unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
sys.path.insert(0,str(HERE.parent/"Server"))

from ai_stem_generation_delete_resume import DeleteResumableGenerationFacade, GenerationFacadeError
from test_ai_stem_generation_processing_facade import GenerationFacadeTests, H

class DeleteResumeTests(unittest.TestCase):
    def setUp(self):
        self.base=GenerationFacadeTests();self.base.setUp()
        self.base.ready_runtime()
        self.base.facade.finalize_mix(logical_generation_id=self.base.gid,alignment_evidence_sha256=H("9"))
        self.wrapper=DeleteResumableGenerationFacade(facade=self.base.facade,journal_path=self.base.root/"delete-intent.json")
    def tearDown(self): self.base.tearDown()
    def assertCode(self,code,fn):
        with self.assertRaises(GenerationFacadeError) as cm: fn()
        self.assertEqual(cm.exception.code,code)
    def test_crash_after_delete_intent_resumes_same_operation(self):
        original=self.base.retention.request_delete
        calls={"n":0}
        def flaky(**kwargs):
            calls["n"]+=1
            if calls["n"]==1: raise RuntimeError("crash")
            return original(**kwargs)
        self.base.retention.request_delete=flaky
        with self.assertRaises(RuntimeError):
            self.wrapper.request_delete(logical_generation_id=self.base.gid,reason="USER_DELETE")
        self.assertEqual(self.base.facade.snapshot(self.base.gid)["directive"],"RECONCILE_DELETE")
        out=self.wrapper.advance_delete(logical_generation_id=self.base.gid)
        self.assertEqual(out["phase"],"DELETED_ASSOCIATION")
        self.assertEqual(calls["n"],2)
    def test_reason_change_rejected(self):
        original=self.base.retention.request_delete
        self.base.retention.request_delete=lambda **kwargs: (_ for _ in ()).throw(RuntimeError("crash"))
        with self.assertRaises(RuntimeError):
            self.wrapper.request_delete(logical_generation_id=self.base.gid,reason="USER_DELETE")
        self.base.retention.request_delete=original
        self.assertCode("GEN_FACADE_DELETE_REASON_CONFLICT",lambda:self.wrapper.request_delete(logical_generation_id=self.base.gid,reason="PROJECT_DELETE"))
    def test_public_result_hashes_reason_but_does_not_emit_it(self):
        out=self.wrapper.request_delete(logical_generation_id=self.base.gid,reason="USER_DELETE")
        self.assertFalse(out["delete_reason_emitted"])
        self.assertEqual(len(out["delete_reason_hash"]),64)
        self.assertNotIn("USER_DELETE",json.dumps(out))
    def test_corrupt_delete_journal_fails_closed(self):
        self.wrapper.journal.path.write_text("{bad")
        self.assertCode("GEN_FACADE_DELETE_JOURNAL_CORRUPT",lambda:self.wrapper.advance_delete(logical_generation_id=self.base.gid))
if __name__=="__main__":unittest.main()
