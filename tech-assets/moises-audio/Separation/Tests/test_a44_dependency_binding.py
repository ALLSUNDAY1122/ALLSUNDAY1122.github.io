from __future__ import annotations

import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "Server"
TESTS = ROOT / "Tests"
PROCESSING = ROOT.parent / "Processing"


class A44DependencyBindingTests(unittest.TestCase):
    def test_runtime_and_regression_surfaces_exist(self):
        required = (
            SERVER / "audioshake_task_contract.py",
            SERVER / "canonical_advanced_provider.py",
            SERVER / "budgeted_production_orchestrator.py",
            TESTS / "test_a44_audioshake_task_target_contract.py",
        )
        for path in required:
            self.assertTrue(path.is_file(), path.name)

    def test_task_contract_cannot_widen_beyond_twenty(self):
        text = (SERVER / "audioshake_task_contract.py").read_text(encoding="utf-8")
        self.assertIn("AUDIOSHAKE_TASK_MAX_TARGETS = 20", text)
        self.assertIn("min(AUDIOSHAKE_TASK_MAX_TARGETS, configured_max_targets)", text)
        self.assertIn("SEP_ADV_TARGET_LIMIT_EXCEEDED", text)

    def test_canonical_adapter_is_bound_to_contract_preflight(self):
        text = (SERVER / "canonical_advanced_provider.py").read_text(encoding="utf-8")
        self.assertIn("build_contract_bound_audioshake_capabilities", text)
        self.assertIn("def preflight_separation", text)
        self.assertIn("max_targets=AUDIOSHAKE_TASK_MAX_TARGETS", text)
        self.assertIn("canonical_roles = self.preflight_separation(models)", text)

    def test_budgeted_start_runs_preflight_before_source_io(self):
        text = (SERVER / "budgeted_production_orchestrator.py").read_text(encoding="utf-8")
        tree = ast.parse(text)
        target_class = next(
            node for node in tree.body
            if isinstance(node, ast.ClassDef) and node.name == "BudgetedProductionSeparationOrchestrator"
        )
        start = next(
            node for node in target_class.body
            if isinstance(node, ast.FunctionDef) and node.name == "start"
        )
        rendered = ast.unparse(start)
        self.assertLess(rendered.index("preflight(selected_models)"), rendered.index("_contained_file"))
        self.assertLess(rendered.index("preflight(selected_models)"), rendered.index("_sha256_file"))
        self.assertLess(rendered.index("preflight(selected_models)"), rendered.index("self.cost_guard.reserve"))


if __name__ == "__main__":
    unittest.main()
