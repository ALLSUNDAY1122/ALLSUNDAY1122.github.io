#!/usr/bin/env python3
"""Synthetic positive/negative tests; passing these is not a source-content or legal audit."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

PATH = Path(__file__).with_name("audit_product_bank.py")
spec = importlib.util.spec_from_file_location("fp2_gate", PATH)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.catalog = root / "catalog.json"
        self.bank = root / "bank.json"
        self.doc = "https://www.jafp.or.jp/exam/mohan/files/g2_202501_q.pdf"
        self.catalog.write_text(json.dumps({"rights_policy_url":"https://www.jafp.or.jp/exam/mohan/files/exam_riyou.pdf","rounds":[{"round":"202501","law_baseline_date":"2024-10-01","exam_types":{"gakka":{"count":2,"question_url":self.doc},"jitsugi":{"count":1,"question_url":"https://www.jafp.or.jp/exam/mohan/files/j2_202501_q.pdf"}}}]}), encoding="utf-8")
        self.qs = [self.question("gakka", 1), self.question("gakka", 2), self.question("jitsugi", 1)]
    def question(self, typ, num):
        url = self.doc if typ == "gakka" else "https://www.jafp.or.jp/exam/mohan/files/j2_202501_q.pdf"
        return {"id":f"p-{typ}-{num}", "sourceQuestionId":f"JAFP-FP2-202501-{'ACA' if typ=='gakka' else 'PRAC'}-{num:02d}",
            "examRound":"202501","examType":typ,"originalQuestionNumber":num,
            "sourceDocumentUrl":url,"lawBaselineDate":"2024-10-01","originType":"official_past_exam",
            "auditStatus":"approved","transcriptionReviewStatus":"verified","answerReviewStatus":"verified",
            "explanationReviewStatus":"verified","rightsReviewStatus":"approved","thirdPartyRightsStatus":"not_applicable",
            "attributionText":f"日本FP協会 2級 {'学科' if typ=='gakka' else '実技'} 2025年1月",
            "modifiedFromOriginal":True,"modificationDisclosure":"日本FP協会の問題を加工して作成",
            "rightsNoticeDisplayed":True,"sourceRefs":[url],
            "question":f"検査用の別々の設問 {typ} {num}","topic":"試験","point":"根拠","detail":"独立検証済みの説明",
            "contentVersion":"test","answerType":"singleChoice","choices":["正しい","誤り"],"answerIndex":0}
    def check(self):
        self.bank.write_text(json.dumps({"questions":self.qs},ensure_ascii=False),encoding="utf-8")
        return gate.audit(self.bank, self.catalog)
    def test_synthetic_valid_complete_bank(self):
        self.assertTrue(self.check()["release_ready"])
    def test_missing_and_padding_not_pass(self):
        self.qs.pop()
        r=self.check()
        self.assertFalse(r["release_ready"])
        self.assertTrue(any("MISSING_OFFICIAL_SOURCE_IDS" in x for x in r["errors"]))
    def test_unverified_rights_fail(self):
        self.qs[0]["rightsReviewStatus"]="pending"
        self.assertFalse(self.check()["release_ready"])
    def test_unknown_source_fail(self):
        self.qs[0]["sourceQuestionId"]="INVENTED"
        self.assertFalse(self.check()["release_ready"])
    def test_repeated_origin_fail(self):
        self.qs[1]["sourceQuestionId"]=self.qs[0]["sourceQuestionId"]
        r=self.check()
        self.assertTrue(any("DUPLICATE_SOURCE_QUESTION_ID" in x for x in r["errors"]))
    def test_missing_attribution_fail(self):
        self.qs[0]["attributionText"]=""
        self.assertFalse(self.check()["release_ready"])
    def test_missing_modification_disclosure_fail(self):
        self.qs[0]["modificationDisclosure"]=""
        self.assertFalse(self.check()["release_ready"])
    def test_near_duplicate_fail(self):
        self.qs[1]["question"]=self.qs[0]["question"]
        self.assertFalse(self.check()["release_ready"])
    def test_unaudited_flag_fail(self):
        self.qs[0]["answerReviewStatus"]="pending"
        self.assertFalse(self.check()["release_ready"])
    def test_source_url_mismatch_fail(self):
        self.qs[0]["sourceDocumentUrl"]=self.qs[2]["sourceDocumentUrl"]
        self.assertFalse(self.check()["release_ready"])

if __name__ == "__main__":
    unittest.main()
