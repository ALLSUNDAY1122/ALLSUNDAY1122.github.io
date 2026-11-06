import tempfile
import unittest
from pathlib import Path

from lane1_dependency_audit import _dependency_checks


class Lane1DependencyAuditSafetySurfaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.audio = Path(self.tmp.name)
        self.server = self.audio / "Separation" / "Server"
        self.tests = self.audio / "Separation" / "Tests"
        self.server.mkdir(parents=True)
        self.tests.mkdir(parents=True)

        for name in (
            "ai_stem_generation_contract.py",
            "ai_stem_generation_runtime.py",
            "generated_stem_mix_compatibility.py",
            "ai_stem_generation_delete_resume.py",
            "privacy_retention.py",
            "provider_delete_reconciliation.py",
            "provider_delete_conflict_resolution.py",
        ):
            (self.server / name).write_text("x = 1\n", encoding="utf-8")

        (self.server / "mutation_topology.py").write_text(
            'a37_conflict_decision_store = "a37_conflict_decision_store"\n'
            'RECONCILIATION_STORE_IDS = ("a09_privacy_registry", "a29_provider_delete_reconciliation_ledger", "a37_conflict_decision_store")\n'
            'def reconciliation_topology_snapshot(): pass\n'
            'def assert_reconciliation_topology_safe(): pass\n',
            encoding="utf-8",
        )

        (self.server / "generated_stem_retention.py").write_text(
            "class GeneratedStemRetentionCoordinator:\n"
            "    def begin_delete(self): pass\n"
            "    def execute_local_delete(self): pass\n"
            "    def assert_generation_not_deleted(self): pass\n"
            "    def privacy_safe_evidence(self): pass\n"
            "    def record_runtime_delete(self): pass\n"
            "# self.manifests self.active _collect_referenced_artifacts\n",
            encoding="utf-8",
        )
        (self.server / "ai_stem_generation_retention_gateway.py").write_text(
            "class A24RetentionGateway:\n"
            "    def register_variant(self): pass\n"
            "    def request_delete(self): pass\n"
            "    def snapshot(self): pass\n",
            encoding="utf-8",
        )
        (self.server / "ai_stem_generation_processing_facade.py").write_text(
            "# register_variant request_delete snapshot retention_policy_sha256\n",
            encoding="utf-8",
        )

        for name in (
            "test_privacy_retention.py",
            "test_privacy_retention_concurrency.py",
            "test_provider_delete_reconciliation.py",
            "test_provider_delete_reconciliation_resume.py",
            "test_provider_delete_reconciliation_ordering.py",
            "test_provider_delete_reconciliation_crash_atomicity.py",
            "test_provider_delete_reconciliation_temporal_causality.py",
            "test_provider_delete_reconciliation_documented_expiry.py",
            "test_provider_delete_reconciliation_conflict_resolution.py",
        ):
            (self.tests / name).write_text("pass\n", encoding="utf-8")
        (self.tests / "test_mutation_topology.py").write_text(
            '# a37_conflict_decision_store\n'
            '# reconciliation_topology_snapshot\n'
            '# assert_reconciliation_topology_safe\n'
            'pass\n',
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_complete_safety_surface_inventory_passes(self):
        result = _dependency_checks(self.audio)
        self.assertEqual(result["state"], "PASS")
        self.assertEqual(result["checked"], 28)

    def test_missing_topology_module_fails_closed(self):
        (self.server / "mutation_topology.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn("L1A36_REQUIRED_SAFETY_FILE_MISSING", [row["code"] for row in result["failures"]])

    def test_missing_privacy_module_fails_closed(self):
        (self.server / "privacy_retention.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn({"check": "A28_privacy", "code": "L1A36_REQUIRED_SAFETY_FILE_MISSING"}, result["failures"])

    def test_missing_reconciliation_module_fails_closed(self):
        (self.server / "provider_delete_reconciliation.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn({"check": "A29_reconciliation", "code": "L1A36_REQUIRED_SAFETY_FILE_MISSING"}, result["failures"])

    def test_missing_a37_conflict_adjudication_module_fails_closed(self):
        (self.server / "provider_delete_conflict_resolution.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn(
            {"check": "A37_conflict_adjudication", "code": "L1A36_REQUIRED_SAFETY_FILE_MISSING"},
            result["failures"],
        )

    def test_missing_reconciliation_regression_fails_closed(self):
        (self.tests / "test_provider_delete_reconciliation_crash_atomicity.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn("L1A36_REQUIRED_REGRESSION_MISSING", [row["code"] for row in result["failures"]])

    def test_missing_a37_conflict_adjudication_regression_fails_closed(self):
        (self.tests / "test_provider_delete_reconciliation_conflict_resolution.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn(
            {"check": "A37_conflict_adjudication_regression", "code": "L1A36_REQUIRED_REGRESSION_MISSING"},
            result["failures"],
        )

    def test_paired_a37_module_and_regression_removal_cannot_false_green(self):
        (self.server / "provider_delete_conflict_resolution.py").unlink()
        (self.tests / "test_provider_delete_reconciliation_conflict_resolution.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertEqual(result["state"], "FAIL")
        self.assertIn(
            {"check": "A37_conflict_adjudication", "code": "L1A36_REQUIRED_SAFETY_FILE_MISSING"},
            result["failures"],
        )
        self.assertIn(
            {"check": "A37_conflict_adjudication_regression", "code": "L1A36_REQUIRED_REGRESSION_MISSING"},
            result["failures"],
        )

    def test_missing_topology_regression_fails_closed(self):
        (self.tests / "test_mutation_topology.py").unlink()
        result = _dependency_checks(self.audio)
        self.assertIn(
            {"check": "A27_A35_topology_regression", "code": "L1A36_REQUIRED_REGRESSION_MISSING"},
            result["failures"],
        )

    def test_a38_topology_contract_semantic_removal_fails_closed(self):
        (self.server / "mutation_topology.py").write_text("x = 1\n", encoding="utf-8")
        result = _dependency_checks(self.audio)
        self.assertIn(
            "L1A38_RECONCILIATION_TOPOLOGY_CONTRACT_MISSING",
            [row["code"] for row in result["failures"]],
        )

    def test_a38_composite_membership_shrink_fails_even_if_a37_token_remains_elsewhere(self):
        (self.server / "mutation_topology.py").write_text(
            'a37_conflict_decision_store = "a37_conflict_decision_store"\n'
            'RECONCILIATION_STORE_IDS = ("a09_privacy_registry", "a29_provider_delete_reconciliation_ledger")\n'
            'def reconciliation_topology_snapshot(): pass\n'
            'def assert_reconciliation_topology_safe(): pass\n',
            encoding="utf-8",
        )
        result = _dependency_checks(self.audio)
        self.assertIn(
            "L1A38_RECONCILIATION_TOPOLOGY_MEMBERSHIP_MISMATCH",
            [row["code"] for row in result["failures"]],
        )

    def test_a38_topology_regression_semantic_removal_fails_closed(self):
        (self.tests / "test_mutation_topology.py").write_text("pass\n", encoding="utf-8")
        result = _dependency_checks(self.audio)
        self.assertIn(
            "L1A38_RECONCILIATION_TOPOLOGY_REGRESSION_MISSING",
            [row["code"] for row in result["failures"]],
        )

    def test_paired_a38_semantic_removal_cannot_false_green(self):
        (self.server / "mutation_topology.py").write_text("x = 1\n", encoding="utf-8")
        (self.tests / "test_mutation_topology.py").write_text("pass\n", encoding="utf-8")
        result = _dependency_checks(self.audio)
        self.assertEqual(result["state"], "FAIL")
        codes = [row["code"] for row in result["failures"]]
        self.assertIn("L1A38_RECONCILIATION_TOPOLOGY_CONTRACT_MISSING", codes)
        self.assertIn("L1A38_RECONCILIATION_TOPOLOGY_REGRESSION_MISSING", codes)

    def test_legacy_a24_surface_check_is_preserved(self):
        (self.server / "generated_stem_retention.py").write_text(
            "class GeneratedStemRetentionCoordinator: pass\n",
            encoding="utf-8",
        )
        result = _dependency_checks(self.audio)
        self.assertIn("L1A26_A24_SURFACE_MISMATCH", [row["code"] for row in result["failures"]])

    def test_stale_a24_schema_check_is_preserved(self):
        stale = self.audio / "Separation" / "Evaluation" / "schemas" / "generated-stem-retention-policy.schema.json"
        stale.parent.mkdir(parents=True)
        stale.write_text("{}\n", encoding="utf-8")
        result = _dependency_checks(self.audio)
        self.assertIn("L1A26_STALE_A24_SCHEMA_PRESENT", [row["code"] for row in result["failures"]])


if __name__ == "__main__":
    unittest.main()
