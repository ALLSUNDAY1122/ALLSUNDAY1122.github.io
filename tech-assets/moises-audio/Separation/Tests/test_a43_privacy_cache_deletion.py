from __future__ import annotations

import tempfile
import threading
import time
import unittest
from pathlib import Path

from privacy_retention import PrivacyRetentionService, RetentionPolicy, audioshake_documented_policy
from production_orchestrator import OrchestratorError
from resumable_transfer_cache import ResumeCachePolicy, ResumableTransferCacheManager


class NoDeleteProvider:
    pass


class A43PrivacyCacheDeletionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.artifacts = self.root / "artifacts"
        self.registry = self.root / "privacy" / "registry.json"
        self.now = {"value": 1_700_000_000}
        self.cache = ResumableTransferCacheManager(
            self.artifacts,
            ResumeCachePolicy(max_age_seconds=3600, max_total_bytes=1024, max_entries=8),
            now=lambda: float(self.now["value"]),
        )
        self.service = PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=NoDeleteProvider(),
            now_epoch=lambda: self.now["value"],
            resume_cache_manager=self.cache,
        )
        self.job = "a" * 32

    def tearDown(self):
        self.tmp.cleanup()

    def register(self, policy=None):
        return self.service.register(
            logical_job_id=self.job,
            provider_asset_id=None,
            provider_task_id=None,
            policy=policy or audioshake_documented_policy(),
            created_at_epoch=self.now["value"],
        )

    def seed_all_local_surfaces(self):
        committed = self.artifacts / self.job
        staging = self.artifacts / f"{self.job}.staging"
        committed.mkdir(parents=True, exist_ok=True)
        staging.mkdir(parents=True, exist_ok=True)
        (committed / "vocals.wav").write_bytes(b"committed")
        (staging / "bass.wav").write_bytes(b"staging")
        with self.cache.lease(self.job) as acquired:
            self.assertTrue(acquired)
            cache_root = self.cache.ensure_cache_root(self.job)
            (cache_root / "drums.wav").write_bytes(b"partial")
        return committed, staging, cache_root

    def test_user_delete_confirms_only_after_committed_staging_and_cache_are_absent(self):
        committed, staging, cache_root = self.seed_all_local_surfaces()
        self.register()
        record = self.service.request_delete(self.job, delete_provider=False)
        self.assertTrue(record.local_delete_confirmed)
        self.assertFalse(committed.exists())
        self.assertFalse(staging.exists())
        self.assertFalse(cache_root.exists())
        self.assertTrue(self.cache.is_deleted(self.job))

    def test_delete_tombstone_blocks_retry_cache_resurrection_after_confirmation(self):
        self.seed_all_local_surfaces()
        self.register()
        self.service.request_delete(self.job, delete_provider=False)
        restarted_cache = ResumableTransferCacheManager(self.artifacts)
        self.assertTrue(restarted_cache.is_deleted(self.job))
        with self.assertRaises(OrchestratorError) as caught:
            restarted_cache.ensure_cache_root(self.job)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")

    def test_expiry_sweep_removes_staging_and_resume_cache_too(self):
        committed, staging, cache_root = self.seed_all_local_surfaces()
        self.register(policy=RetentionPolicy(None, None, "explicit_expiry", 60))
        self.now["value"] += 61
        self.assertEqual(self.service.sweep_expired(), (self.job,))
        self.assertFalse(committed.exists())
        self.assertFalse(staging.exists())
        self.assertFalse(cache_root.exists())
        self.assertTrue(self.cache.is_deleted(self.job))

    def test_delete_waits_for_active_output_cache_lease_then_cleans(self):
        committed, staging, cache_root = self.seed_all_local_surfaces()
        self.register()
        entered = threading.Event()
        release = threading.Event()
        deletion_done = threading.Event()
        errors = []

        def active_output():
            with self.cache.lease(self.job) as acquired:
                if not acquired:
                    raise AssertionError("active lease not acquired")
                entered.set()
                release.wait(2)

        def delete():
            try:
                self.service.request_delete(self.job, delete_provider=False)
            except Exception as exc:  # captured for assertion on the calling thread
                errors.append(exc)
            finally:
                deletion_done.set()

        output_thread = threading.Thread(target=active_output)
        output_thread.start()
        self.assertTrue(entered.wait(1))
        delete_thread = threading.Thread(target=delete)
        delete_thread.start()
        time.sleep(0.05)
        self.assertFalse(deletion_done.is_set())
        release.set()
        output_thread.join(timeout=2)
        delete_thread.join(timeout=2)
        self.assertEqual(errors, [])
        self.assertTrue(deletion_done.is_set())
        self.assertFalse(committed.exists())
        self.assertFalse(staging.exists())
        self.assertFalse(cache_root.exists())
        self.assertTrue(self.cache.is_deleted(self.job))

    def test_delete_never_removes_sibling_job_surfaces(self):
        self.seed_all_local_surfaces()
        sibling = "b" * 32
        sibling_dir = self.artifacts / sibling
        sibling_staging = self.artifacts / f"{sibling}.staging"
        sibling_dir.mkdir(parents=True)
        sibling_staging.mkdir(parents=True)
        (sibling_dir / "keep.wav").write_bytes(b"keep")
        (sibling_staging / "keep.wav").write_bytes(b"keep")
        with self.cache.lease(sibling) as acquired:
            self.assertTrue(acquired)
            sibling_cache = self.cache.ensure_cache_root(sibling)
            (sibling_cache / "keep.wav").write_bytes(b"keep")
        self.register()
        self.service.request_delete(self.job, delete_provider=False)
        self.assertTrue(sibling_dir.exists())
        self.assertTrue(sibling_staging.exists())
        self.assertTrue(sibling_cache.exists())
        self.assertFalse(self.cache.is_deleted(sibling))


if __name__ == "__main__":
    unittest.main()
