import subprocess
import tempfile
import unittest
from pathlib import Path

from lane1_source_snapshot import SourceSnapshotError, build_source_snapshot


class Lane1SourceSnapshotGitBindingTests(unittest.TestCase):
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

    def tearDown(self):
        self.tmp.cleanup()

    def assert_snapshot_error(self, code):
        with self.assertRaises(SourceSnapshotError) as cm:
            build_source_snapshot(self.audio)
        self.assertEqual(cm.exception.code, code)

    def test_clean_head_owned_tree_passes(self):
        snapshot = build_source_snapshot(self.audio)
        self.assertEqual(snapshot["file_count"], 2)

    def test_modified_tracked_file_fails(self):
        (self.audio / "Separation" / "x.py").write_text("x=2\n", encoding="utf-8")
        self.assert_snapshot_error("L1A26_OWNED_WORKTREE_DIRTY")

    def test_deleted_tracked_file_fails(self):
        (self.audio / "Processing" / "x.json").unlink()
        self.assert_snapshot_error("L1A26_OWNED_WORKTREE_DIRTY")

    def test_untracked_durable_file_fails(self):
        (self.audio / "Separation" / "extra.md").write_text("extra\n", encoding="utf-8")
        self.assert_snapshot_error("L1A26_OWNED_TREE_MISMATCH")

    def test_gitignored_durable_file_still_fails(self):
        info_exclude = self.repo / ".git" / "info" / "exclude"
        info_exclude.write_text(
            "tech-assets/moises-audio/Separation/ignored.md\n",
            encoding="utf-8",
        )
        (self.audio / "Separation" / "ignored.md").write_text("ignored\n", encoding="utf-8")
        self.assert_snapshot_error("L1A26_OWNED_TREE_MISMATCH")

    def test_explicit_untracked_audit_output_can_be_excluded(self):
        report = self.audio / "Processing" / "audit-report.json"
        report.write_text("{}\n", encoding="utf-8")
        snapshot = build_source_snapshot(self.audio, excludes=[report])
        self.assertEqual(snapshot["file_count"], 2)

    def test_tracked_file_cannot_be_hidden_by_explicit_exclude(self):
        tracked = self.audio / "Processing" / "x.json"
        with self.assertRaises(SourceSnapshotError) as cm:
            build_source_snapshot(self.audio, excludes=[tracked])
        self.assertEqual(cm.exception.code, "L1A26_OWNED_TREE_MISMATCH")


if __name__ == "__main__":
    unittest.main()
