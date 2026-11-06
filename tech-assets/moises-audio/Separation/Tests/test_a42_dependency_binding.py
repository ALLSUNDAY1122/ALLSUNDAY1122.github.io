from __future__ import annotations

import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


class A42DependencyBindingTests(unittest.TestCase):
    def test_a42_source_and_regressions_are_present(self):
        for name in (
            "test_differential_execute_resume.py",
            "test_differential_execute_resume_isolation.py",
            "test_differential_module_isolation_policy.py",
        ):
            self.assertTrue((HERE / name).is_file(), name)

    def test_execute_resume_remains_exact_restore_bound(self):
        text = (HERE / "test_differential_execute_resume.py").read_text(encoding="utf-8")
        for token in (
            "isolated_execute_import",
            "previous_modules",
            "previous_path",
            "sys.path[:] = previous_path",
            "_restore_module",
            "sys.modules[_PROBE_MODULE] = module",
        ):
            self.assertIn(token, text)

    def test_isolation_regression_exercises_absent_and_preexisting_states(self):
        text = (HERE / "test_differential_execute_resume_isolation.py").read_text(encoding="utf-8")
        for token in (
            "test_import_restores_preexisting_common_resume_probe_and_path",
            "test_import_does_not_create_bare_name_modules_when_initially_absent",
            "sentinel_common",
            "sentinel_resume",
            "sentinel_probe",
        ):
            self.assertIn(token, text)

    def test_cross_test_policy_forbids_top_level_bare_module_writes(self):
        text = (HERE / "test_differential_module_isolation_policy.py").read_text(encoding="utf-8")
        for token in (
            "_top_level_differential_module_writes",
            "test_differential*.py",
            "key.startswith(\"differential_\")",
            "test_differential_gate_a20_import.py",
        ):
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
