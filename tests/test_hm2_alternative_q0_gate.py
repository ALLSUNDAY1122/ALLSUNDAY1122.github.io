#!/usr/bin/env python3
"""Negative and positive fixture tests for fail-closed HM2 alternative Q0 gate."""
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("hm2_q0", ROOT / "scripts/hm2_alternative_q0_gate.py")
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.base = self.root / "ios/health-manager-2"
        (self.base / "audit").mkdir(parents=True)
        (self.root / "apps/sanitary-manager-2").mkdir(parents=True)
        (self.root / "health-manager-2").mkdir(parents=True)
        for p in (
            self.root / "apps/sanitary-manager-2/gm4.js",
            self.root / "health-manager-2/support.html",
            self.base / "APP_STORE_METADATA_JA.md",
        ):
            p.write_text("非公式、専門家による監修なし", encoding="utf-8")
        self.bank = [
            {"id": f"sm2-test-{i:03}", "choices": [f"{i}-{j}" for j in range(5)], "correct_index": 0}
            for i in range(300)
        ]
        bank_path = self.base / "release-questions.json"
        bank_path.write_text(json.dumps(self.bank, ensure_ascii=False), encoding="utf-8")
        self.sha = hashlib.sha256(bank_path.read_bytes()).hexdigest()
        rows = "\n".join(f"| `sm2-test-{i:03}` | x |" for i in range(178))
        (self.base / "audit/FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md").write_text(
            "## 178件個別照合の着手明細\n" + rows + "\n## 今回の判断\n", encoding="utf-8"
        )
        self.review_file = self.base / "audit/HM2_INDEPENDENT_DOUBLE_CHECK_178.json"
        self.rights_file = self.base / "audit/HM2_RIGHTS_CLEARANCE_300.json"
        self.reviews = {"question_bank_sha256": self.sha, "reviews": []}
        for q in self.bank[:178]:
            passes = []
            for reviewer in ("first-independent-pass", "second-independent-pass"):
                passes.append({
                    "reviewer_id": reviewer, "reviewed_at": "2026-11-22",
                    "method": "independent primary-source verification",
                    "primary_source_url": "https://laws.e-gov.go.jp/law/347M50002000032",
                    "source_section": "test", "applicable_on": "2026-11-22",
                    "reasoning": "test fixture only",
                    "question_bank_sha256": self.sha,
                    "choices": [
                        {"text": choice, "correct": j == 0,
                         "reason": "fixture", "source_section": "test"}
                        for j, choice in enumerate(q["choices"])
                    ],
                })
            self.reviews["reviews"].append({
                "id": q["id"], "passes": passes,
                "final_disposition": "approved_after_reconciliation",
            })
        self.rights = {
            "question_bank_sha256": self.sha,
            "decisions": [{
                "id": q["id"], "cleared": True, "source_url": "https://example.org",
                "rights_holder": "fixture", "license_or_exception": "fixture",
                "originality_comparison": "fixture", "decision_rationale": "fixture",
                "reviewer_id": "fixture", "reviewed_at": "2026-11-22",
            } for q in self.bank],
        }
        self.persist()

    def tearDown(self):
        self.temp.cleanup()

    def persist(self):
        self.review_file.write_text(json.dumps(self.reviews), encoding="utf-8")
        self.rights_file.write_text(json.dumps(self.rights), encoding="utf-8")

    def check(self):
        return MOD.validate(self.root, self.review_file, self.rights_file)

    def test_complete_fixture_structure(self):
        self.assertTrue(self.check()["pass"])

    def test_missing_rights_file_fails(self):
        self.rights_file.unlink()
        self.assertFalse(self.check()["pass"])

    def test_duplicate_reviewer_fails(self):
        p = self.reviews["reviews"][0]["passes"]
        p[1]["reviewer_id"] = p[0]["reviewer_id"]
        self.persist()
        self.assertIn("sm2-test-000:INDEPENDENCE_UNPROVEN", self.check()["failures"])

    def test_wrong_choice_text_fails(self):
        self.reviews["reviews"][0]["passes"][0]["choices"][1]["text"] = "tampered"
        self.persist()
        self.assertIn("sm2-test-000:PASS1_CHOICE2_INCOMPLETE", self.check()["failures"])

    def test_stale_bank_hash_fails(self):
        self.reviews["question_bank_sha256"] = "obsolete"
        self.persist()
        self.assertIn("DOUBLE_CHECK_BANK_SHA_MISMATCH", self.check()["failures"])

    def test_nonobject_double_check_payload_fails(self):
        self.review_file.write_text("[]", encoding="utf-8")
        self.assertIn("DOUBLE_CHECK_SCHEMA_INVALID", self.check()["failures"])

    def test_nonobject_rights_payload_fails(self):
        self.rights_file.write_text("[]", encoding="utf-8")
        self.assertIn("RIGHTS_SCHEMA_INVALID", self.check()["failures"])

    def test_nonobject_rights_row_fails(self):
        self.rights["decisions"][0] = "not-a-decision"
        self.persist()
        self.assertIn("RIGHTS_ROW_SCHEMA_INVALID", self.check()["failures"])

    def test_nonobject_double_review_row_fails(self):
        self.reviews["reviews"][0] = "not-a-review"
        self.persist()
        self.assertIn("DOUBLE_CHECK_ROW_SCHEMA_INVALID", self.check()["failures"])

    def test_missing_nonofficial_notice_fails(self):
        (self.root / "apps/sanitary-manager-2/gm4.js").write_text("unrelated", encoding="utf-8")
        self.assertIn("IN_APP_DISCLAIMER_MISSING", self.check()["failures"])


if __name__ == "__main__":
    unittest.main()
