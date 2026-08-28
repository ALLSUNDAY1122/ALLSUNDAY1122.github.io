import shutil
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest import mock

from privacy_retention import PrivacyRetentionService, audioshake_documented_policy


class PrivacyRetentionDeleteSerializationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.artifacts = self.root / "artifacts"
        self.registry = self.root / "privacy" / "registry.json"
        self.now = 1_700_000_000

    def tearDown(self):
        self.tmp.cleanup()

    def service(self):
        return PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=object(),
            now_epoch=lambda: self.now,
        )

    def test_concurrent_local_artifact_delete_uses_per_job_lease(self):
        job = "f" * 32
        self.service().register(
            logical_job_id=job,
            provider_asset_id=None,
            provider_task_id=None,
            policy=audioshake_documented_policy(),
            created_at_epoch=self.now,
        )
        directory = self.artifacts / job
        staging = self.artifacts / f"{job}.staging"
        for root in (directory, staging):
            root.mkdir(parents=True, exist_ok=True)
            for index in range(16):
                (root / f"stem-{index}.wav").write_bytes(b"audio")

        barrier = threading.Barrier(10)
        guard = threading.Lock()
        active = 0
        max_active = 0
        original_rmtree = shutil.rmtree
        measured = {directory.resolve(), staging.resolve()}

        def tracked_rmtree(path, *args, **kwargs):
            nonlocal active, max_active
            if Path(path).resolve() not in measured:
                return original_rmtree(path, *args, **kwargs)
            with guard:
                active += 1
                max_active = max(max_active, active)
            try:
                time.sleep(0.01)
                return original_rmtree(path, *args, **kwargs)
            finally:
                with guard:
                    active -= 1

        class PrivacyShutilProxy:
            rmtree = staticmethod(tracked_rmtree)

        def delete(_):
            barrier.wait()
            return self.service().request_delete(job, delete_provider=False)

        with mock.patch("privacy_retention.shutil", PrivacyShutilProxy):
            with ThreadPoolExecutor(max_workers=10) as pool:
                list(pool.map(delete, range(10)))

        self.assertEqual(max_active, 1)
        self.assertFalse(directory.exists())
        self.assertFalse(staging.exists())
        self.assertTrue(self.service().snapshot(job)["localDeleteConfirmed"])


if __name__ == "__main__":
    unittest.main()
