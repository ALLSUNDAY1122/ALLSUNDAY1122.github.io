from __future__ import annotations

import os
import tempfile
import threading
import unittest
from pathlib import Path

from production_orchestrator import OrchestratorError
from resumable_transfer_cache import ResumeCachePolicy, ResumableTransferCacheManager


class ResumeCacheLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.now = {"value": 100_000.0}

    def tearDown(self):
        self.tmp.cleanup()

    def manager(self, *, age=100, byte_cap=100, entries=10):
        return ResumableTransferCacheManager(
            self.root,
            ResumeCachePolicy(
                max_age_seconds=age,
                max_total_bytes=byte_cap,
                max_entries=entries,
            ),
            now=lambda: self.now["value"],
        )

    def seed(self, manager, job, data=b"abc", *, age=0):
        with manager.lease(job) as acquired:
            self.assertTrue(acquired)
            root = manager.ensure_cache_root(job)
            (root / "stem.wav").write_bytes(data)
            marker = root / ".last-access"
            timestamp = self.now["value"] - age
            os.utime(marker, (timestamp, timestamp))
            return root

    def test_ttl_removes_stale_inactive_cache(self):
        manager = self.manager(age=10)
        root = self.seed(manager, "a" * 32, age=11)
        report = manager.reclaim()
        self.assertFalse(root.exists())
        self.assertEqual(report.removed_entries, 1)
        self.assertFalse(report.over_budget)

    def test_byte_quota_evicts_oldest_cache_first(self):
        manager = self.manager(byte_cap=8)
        old = self.seed(manager, "a" * 32, b"12345", age=20)
        recent = self.seed(manager, "b" * 32, b"67890", age=10)
        report = manager.reclaim()
        self.assertFalse(old.exists())
        self.assertTrue(recent.exists())
        self.assertFalse(report.over_budget)

    def test_entry_quota_evicts_oldest_cache_first(self):
        manager = self.manager(entries=1)
        old = self.seed(manager, "a" * 32, age=20)
        recent = self.seed(manager, "b" * 32, age=10)
        manager.reclaim()
        self.assertFalse(old.exists())
        self.assertTrue(recent.exists())

    def test_active_lease_is_never_reclaimed(self):
        manager = self.manager(age=1)
        job = "c" * 32
        root = self.seed(manager, job, age=10)
        entered = threading.Event()
        release = threading.Event()

        def hold():
            with manager.lease(job) as acquired:
                if not acquired:
                    raise AssertionError("blocking lease did not acquire")
                entered.set()
                release.wait(2)

        thread = threading.Thread(target=hold)
        thread.start()
        self.assertTrue(entered.wait(1))
        try:
            report = manager.reclaim()
            self.assertTrue(root.exists())
            self.assertEqual(report.skipped_active_entries, 1)
        finally:
            release.set()
            thread.join(timeout=2)
        manager.reclaim()
        self.assertFalse(root.exists())

    def test_maintenance_purge_removes_only_selected_cache_without_tombstone(self):
        manager = self.manager()
        first = "d" * 32
        second = "e" * 32
        first_root = self.seed(manager, first)
        second_root = self.seed(manager, second)
        manager.purge(first)
        self.assertFalse(first_root.exists())
        self.assertTrue(second_root.exists())
        self.assertFalse(manager.is_deleted(first))

    def test_tombstone_and_purge_is_durable_and_blocks_recreation(self):
        manager = self.manager()
        job = "f" * 32
        root = self.seed(manager, job)
        manager.tombstone_and_purge(job)
        self.assertFalse(root.exists())
        self.assertTrue(manager.is_deleted(job))
        restarted = self.manager()
        self.assertTrue(restarted.is_deleted(job))
        with self.assertRaises(OrchestratorError) as caught:
            restarted.ensure_cache_root(job)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")

    def test_future_access_marker_is_removed_fail_closed(self):
        manager = self.manager()
        job = "1" * 32
        root = self.seed(manager, job)
        marker = root / ".last-access"
        timestamp = self.now["value"] + 301
        os.utime(marker, (timestamp, timestamp))
        manager.reclaim()
        self.assertFalse(root.exists())

    @unittest.skipIf(not hasattr(os, "symlink"), "symlink unavailable")
    def test_symlink_cache_root_is_unlinked_without_following_target(self):
        manager = self.manager()
        target = self.root / "target"
        target.mkdir()
        (target / "keep").write_text("keep", encoding="utf-8")
        link = manager.cache_root("2" * 32)
        link.symlink_to(target, target_is_directory=True)
        report = manager.reclaim()
        self.assertFalse(link.exists())
        self.assertEqual((target / "keep").read_text(encoding="utf-8"), "keep")
        self.assertEqual(report.removed_entries, 1)

    def test_unrelated_artifact_directory_is_never_scanned_as_cache(self):
        manager = self.manager(age=1)
        unrelated = self.root / ("3" * 32)
        unrelated.mkdir()
        (unrelated / "vocals.wav").write_bytes(b"keep")
        manager.reclaim()
        self.assertTrue(unrelated.exists())

    def test_invalid_policy_fails_closed(self):
        with self.assertRaises(OrchestratorError) as caught:
            ResumeCachePolicy(max_total_bytes=0).validate()
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_POLICY_INVALID")

    def test_delete_tombstone_path_cannot_be_symlink(self):
        manager = self.manager()
        job = "4" * 32
        target = self.root / "target-file"
        target.write_text("x", encoding="utf-8")
        tombstone = manager.lock_root / f"{job}.deleted"
        try:
            tombstone.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink unavailable")
        with self.assertRaises(OrchestratorError) as caught:
            manager.is_deleted(job)
        self.assertEqual(
            caught.exception.code,
            "SEP_OUTPUT_RESUME_CACHE_DELETE_TOMBSTONE_UNSAFE",
        )
        self.assertEqual(target.read_text(encoding="utf-8"), "x")


if __name__ == "__main__":
    unittest.main()
