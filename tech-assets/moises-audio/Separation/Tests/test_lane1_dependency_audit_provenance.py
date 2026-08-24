import subprocess
import tempfile
import unittest
from pathlib import Path

from lane1_dependency_audit import _git_head_check, _source_snapshot


class Lane1DependencyAuditProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.audio = self.repo / "tech-assets" / "moises-audio"
        (self.audio / "Separation").mkdir(parents=True)
        (self.audio / "Processing").mkdir(parents=True)
        (self.audio / "Separation" / "x.py").write_text("x=1\n", encoding="utf-8")
        (self.audio / "Processing" / "x.json").write_text("{}\n", encoding="utf-8")
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "a26@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "A26 Test"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-qm", "fixture"], check=True)
        self.head = subprocess.run(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def tearDown(self):
        self.tmp.cleanup()

    def test_exact_git_head_passes(self):
        result = _git_head_check(self.audio, self.head)
        self.assertEqual(result["state"], "PASS")
        self.assertEqual(result["actual_git_head"], self.head)

    def test_different_git_head_fails(self):
        result = _git_head_check(self.audio, "0" * 40)
        self.assertEqual(result["state"], "FAIL_GIT_HEAD_MISMATCH")

    def test_missing_expected_git_head_fails(self):
        self.assertEqual(_git_head_check(self.audio, None)["state"], "FAIL_EXPECTED_HEAD_REQUIRED")

    def test_invalid_expected_git_head_fails(self):
        self.assertEqual(_git_head_check(self.audio, "not-a-sha")["state"], "FAIL_EXPECTED_HEAD_INVALID")

    def test_owned_source_snapshot_is_emitted(self):
        result = _source_snapshot(self.audio, [])
        self.assertEqual(result["state"], "PASS")
        snapshot = result["snapshot"]
        self.assertEqual(snapshot["scope"], ["Separation/**", "Processing/**"])
        self.assertEqual(snapshot["parity_claim"], "NONE")
        self.assertEqual(snapshot["file_count"], 2)


if __name__ == "__main__":
    unittest.main()
