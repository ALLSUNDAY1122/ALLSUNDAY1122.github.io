from pathlib import Path
import subprocess
import unittest


class AppleValidationHarnessContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.scanner_root = Path(__file__).resolve().parents[2]
        cls.script = cls.scanner_root / "AppleValidation" / "run-apple-sdk-compile.sh"
        cls.probe = cls.scanner_root / "AppleValidation" / "AppleAdapterContractProbe.swift"
        cls.script_text = cls.script.read_text(encoding="utf-8")
        cls.probe_text = cls.probe.read_text(encoding="utf-8")

    def test_shell_is_syntactically_valid(self) -> None:
        subprocess.run(["bash", "-n", str(self.script)], check=True)

    def test_all_apple_adapter_sources_are_compiled(self) -> None:
        required = [
            "FrameExtraction/AVFoundationStableFrameExtractor.swift",
            "ImageCorrection/ApplePageCorrectionEngine.swift",
            "PageAudit/VisionPageAuditRecognizer.swift",
            "PageAudit/PagePerceptualHasher.swift",
        ]
        for relative_path in required:
            self.assertIn(relative_path, self.script_text)

    def test_compile_target_is_iphoneos_and_cross_module(self) -> None:
        self.assertIn("xcrun --sdk iphoneos --show-sdk-path", self.script_text)
        self.assertIn("compile_module FrameExtraction", self.script_text)
        self.assertIn("compile_module ImageCorrection", self.script_text)
        self.assertIn("compile_module PageAudit", self.script_text)
        self.assertIn("AppleAdapterContractProbe.swift", self.script_text)
        self.assertIn("-typecheck", self.script_text)

    def test_probe_touches_modules_and_apple_frameworks(self) -> None:
        for token in [
            "import FrameExtraction",
            "import ImageCorrection",
            "import PageAudit",
            "AVFoundationStableFrameExtractor",
            "PageCorrectionEngine",
            "VisionPageAuditRecognizer",
            "VNRecognizeTextRequest",
        ]:
            self.assertIn(token, self.probe_text)

    def test_report_cannot_claim_formal_golden_result(self) -> None:
        self.assertIn('"formal_golden_decision": None', self.script_text)
        self.assertIn('STATUS="PASS"', self.script_text)
        self.assertNotIn('GOLDEN_PASS', self.script_text)


if __name__ == "__main__":
    unittest.main()
