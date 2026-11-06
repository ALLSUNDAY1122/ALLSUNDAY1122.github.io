import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "Server"
TESTS = ROOT / "Tests"


class A45DependencyBindingTests(unittest.TestCase):
    def test_audioshake_source_parses_and_binds_task_identity(self):
        text = (SERVER / "audioshake_api.py").read_text(encoding="utf-8")
        ast.parse(text)
        self.assertIn("AUDIOSHAKE_TASK_ID_MISMATCH", text)
        self.assertIn("state.task_id != task_id", text)

    def test_audioshake_parser_rejects_duplicate_and_ambiguous_outputs(self):
        text = (SERVER / "audioshake_api.py").read_text(encoding="utf-8")
        self.assertIn("AUDIOSHAKE_TARGET_MODEL_DUPLICATE", text)
        self.assertIn("AUDIOSHAKE_WAV_OUTPUT_AMBIGUOUS", text)
        self.assertIn("not parsed_output.hostname", text)

    def test_canonical_boundary_parses_and_rechecks_identity(self):
        text = (SERVER / "canonical_advanced_provider.py").read_text(encoding="utf-8")
        ast.parse(text)
        self.assertIn("SEP_ADV_TASK_ID_MISMATCH", text)
        self.assertIn("raw_task_id != task_id", text)
        self.assertIn("SEP_ADV_OUTPUT_MODEL_DUPLICATE", text)
        self.assertIn("_catalog_model_to_role", text)

    def test_existing_task_observation_has_no_live_discovery_dependency(self):
        text = (SERVER / "canonical_advanced_provider.py").read_text(encoding="utf-8")
        tree = ast.parse(text)
        method = None
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "get_task_state":
                method = node
                break
        self.assertIsNotNone(method)
        calls_refresh = any(
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "_refresh_maps"
            for node in ast.walk(method)
        )
        self.assertFalse(calls_refresh)
        self.assertIn("self._catalog_model_to_role.get(provider_model)", text)

    def test_formal_a45_regression_is_present_and_parses(self):
        path = TESTS / "test_a45_provider_task_identity.py"
        self.assertTrue(path.is_file())
        ast.parse(path.read_text(encoding="utf-8"))

    def test_a44_preflight_contract_remains_bound(self):
        text = (SERVER / "canonical_advanced_provider.py").read_text(encoding="utf-8")
        self.assertIn("AUDIOSHAKE_TASK_MAX_TARGETS", text)
        self.assertIn("build_contract_bound_audioshake_capabilities", text)
        self.assertIn("def preflight_separation", text)
        self.assertIn("self._refresh_maps()", text)


if __name__ == "__main__":
    unittest.main()
