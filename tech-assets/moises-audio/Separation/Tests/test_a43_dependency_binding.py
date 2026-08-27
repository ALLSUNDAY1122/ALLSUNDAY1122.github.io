from __future__ import annotations

import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "Server"
TESTS = ROOT / "Tests"


class A43DependencyBindingTests(unittest.TestCase):
    def test_runtime_and_regressions_are_present(self):
        required = (
            SERVER / "resumable_transfer_cache.py",
            SERVER / "bounded_resumable_long_track_production_orchestrator.py",
            TESTS / "test_resumable_transfer_cache.py",
            TESTS / "test_a43_privacy_cache_deletion.py",
            TESTS / "test_a43_deleted_job_runtime.py",
            TESTS / "test_a43_budgeted_deleted_job.py",
        )
        for path in required:
            self.assertTrue(path.is_file(), path.name)

    def test_budgeted_entrypoint_uses_a43_wrapper_and_delete_first_order(self):
        path = SERVER / "budgeted_production_orchestrator.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn("BoundedCrashResumableLongTrackProductionSeparationOrchestrator", text)
        self.assertIn("resume_cache_policy", text)
        self.assertIn("reclaim_resume_caches", text)
        self.assertIn("purge_resume_cache", text)
        self.assertIn("tombstone_and_purge_resume_cache", text)
        tree = ast.parse(text)
        service = next(
            node for node in tree.body
            if isinstance(node, ast.ClassDef) and node.name == "BudgetedProductionSeparationOrchestrator"
        )
        start = next(
            node for node in service.body
            if isinstance(node, ast.FunctionDef) and node.name == "start"
        )
        rendered = ast.unparse(start)
        self.assertLess(rendered.index("resume_cache.is_deleted"), rendered.index("_contained_file"))
        self.assertLess(rendered.index("resume_cache.is_deleted"), rendered.index("_sha256_file"))
        self.assertLess(rendered.index("resume_cache.is_deleted"), rendered.index("cost_guard.reserve"))

    def test_privacy_delete_tombstones_before_local_confirmation(self):
        path = SERVER / "privacy_retention.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn("tombstone_and_purge", text)
        self.assertIn('suffix=".staging"', text)
        self.assertIn("resume_cache_manager.is_deleted", text)
        tree = ast.parse(text)
        service = next(
            node for node in tree.body
            if isinstance(node, ast.ClassDef) and node.name == "PrivacyRetentionService"
        )
        method = next(
            node for node in service.body
            if isinstance(node, ast.FunctionDef) and node.name == "_delete_local_artifacts"
        )
        rendered = ast.unparse(method)
        self.assertLess(rendered.index("tombstone_and_purge"), rendered.index("shutil.rmtree"))

    def test_a43_wrapper_checks_delete_tombstone_on_start_and_collect(self):
        text = (
            SERVER / "bounded_resumable_long_track_production_orchestrator.py"
        ).read_text(encoding="utf-8")
        self.assertGreaterEqual(text.count("SEP_OUTPUT_RESUME_CACHE_JOB_DELETED"), 3)
        self.assertIn("def start(", text)
        self.assertIn("def collect_ready_outputs(", text)
        self.assertIn("self.resume_cache.lease(logical_job_id)", text)


if __name__ == "__main__":
    unittest.main()
