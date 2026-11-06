import tempfile
import unittest
from pathlib import Path

from lane1_source_snapshot import SourceSnapshotError, build_source_snapshot, verify_expected_snapshot


class Lane1SourceSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "Separation").mkdir()
        (self.root / "Processing").mkdir()
        (self.root / "Separation" / "a.py").write_text("x=1\n", encoding="utf-8")
        (self.root / "Processing" / "b.json").write_text("{}\n", encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_deterministic_and_mutation_sensitive(self):
        first = build_source_snapshot(self.root)
        second = build_source_snapshot(self.root)
        self.assertEqual(first["source_snapshot_sha256"], second["source_snapshot_sha256"])
        (self.root / "Separation" / "a.py").write_text("x=2\n", encoding="utf-8")
        self.assertNotEqual(first["source_snapshot_sha256"], build_source_snapshot(self.root)["source_snapshot_sha256"])

    def test_non_owned_scope_and_runtime_cache_are_excluded(self):
        (self.root / "Other").mkdir()
        other = self.root / "Other" / "x.txt"
        other.write_text("one", encoding="utf-8")
        first = build_source_snapshot(self.root)
        other.write_text("two", encoding="utf-8")
        self.assertEqual(first["source_snapshot_sha256"], build_source_snapshot(self.root)["source_snapshot_sha256"])
        cache = self.root / "Separation" / "__pycache__"
        cache.mkdir()
        (cache / "x.pyc").write_bytes(b"runtime")
        self.assertEqual(first["source_snapshot_sha256"], build_source_snapshot(self.root)["source_snapshot_sha256"])

    def test_explicit_output_exclude_prevents_self_reference(self):
        report = self.root / "Processing" / "audit-report.json"
        report.write_text("one", encoding="utf-8")
        first = build_source_snapshot(self.root, excludes=[report])
        report.write_text("two", encoding="utf-8")
        second = build_source_snapshot(self.root, excludes=[report])
        self.assertEqual(first["source_snapshot_sha256"], second["source_snapshot_sha256"])

    def test_exclude_outside_lane_root_rejected(self):
        with self.assertRaises(SourceSnapshotError) as cm:
            build_source_snapshot(self.root, excludes=[Path("/tmp/outside-a26")])
        self.assertEqual(cm.exception.code, "L1A26_SOURCE_EXCLUDE_OUTSIDE_ROOT")

    def test_symlink_in_owned_scope_rejected(self):
        target = self.root / "Separation" / "a.py"
        link = self.root / "Processing" / "link.py"
        try:
            link.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink unavailable")
        with self.assertRaises(SourceSnapshotError) as cm:
            build_source_snapshot(self.root)
        self.assertEqual(cm.exception.code, "L1A26_SOURCE_SYMLINK_FORBIDDEN")

    def test_expected_snapshot_match_and_mismatch(self):
        snapshot = build_source_snapshot(self.root)
        self.assertEqual(verify_expected_snapshot(snapshot, snapshot["source_snapshot_sha256"])["state"], "PASS")
        self.assertEqual(verify_expected_snapshot(snapshot, "0" * 64)["state"], "FAIL")
        self.assertEqual(verify_expected_snapshot(snapshot, None)["state"], "NOT_REQUESTED")

    def test_missing_owned_scope_rejected(self):
        (self.root / "Processing" / "b.json").unlink()
        (self.root / "Processing").rmdir()
        with self.assertRaises(SourceSnapshotError) as cm:
            build_source_snapshot(self.root)
        self.assertEqual(cm.exception.code, "L1A26_OWNED_SCOPE_MISSING")


if __name__ == "__main__":
    unittest.main()
