from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class BootstrapContractTests(unittest.TestCase):
    def test_session_boundaries_exist(self):
        contract = (ROOT / "Integration/INTERFACE_CONTRACT.md").read_text(encoding="utf-8")
        self.assertIn("Core gameplay surface", contract)
        self.assertIn("World/progression surface", contract)
        self.assertIn("Normalized input", contract)

    def test_mock_isolated_from_owned_a_b_paths(self):
        mock_paths = list((ROOT / "Integration/Mock").glob("*.gd"))
        self.assertGreaterEqual(len(mock_paths), 2)
        self.assertFalse((ROOT / "Player").exists())
        self.assertFalse((ROOT / "World").exists())

    def test_release_identity_is_independent(self):
        export = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn("jp.allsunday1122.loopforge", export)
        self.assertNotIn("peppertango", export.lower())

if __name__ == "__main__":
    unittest.main()
