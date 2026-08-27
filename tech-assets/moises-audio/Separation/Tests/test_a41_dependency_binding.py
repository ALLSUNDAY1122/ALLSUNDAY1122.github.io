from __future__ import annotations

import unittest
from pathlib import Path


class A41DependencyBindingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.separation = Path(__file__).resolve().parents[1]
        cls.server = cls.separation / "Server"
        cls.tests = cls.separation / "Tests"

    def test_a41_runtime_surface_is_present(self):
        self.assertTrue(
            (self.server / "resumable_long_track_production_orchestrator.py").is_file()
        )

    def test_a41_regression_surface_is_present(self):
        self.assertTrue(
            (self.tests / "test_resumable_long_track_production_orchestrator.py").is_file()
        )

    def test_budgeted_production_entrypoint_is_wired_to_a41(self):
        text = (self.server / "budgeted_production_orchestrator.py").read_text(encoding="utf-8")
        self.assertIn("CrashResumableLongTrackProductionSeparationOrchestrator", text)
        self.assertIn("self.inner = CrashResumableLongTrackProductionSeparationOrchestrator(", text)


if __name__ == "__main__":
    unittest.main()
