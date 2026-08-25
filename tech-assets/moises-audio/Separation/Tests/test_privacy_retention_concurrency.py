import threading
import time
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from mutation_topology import assess_store_topology
from privacy_retention import AtomicPrivacyRegistry, PrivacyRetentionService, audioshake_documented_policy


class SlowProvider:
    def __init__(self):
        self.lock = threading.Lock()
        self.asset_calls = 0
        self.task_calls = 0

    def delete_asset(self, object_id):
        with self.lock:
            self.asset_calls += 1
        time.sleep(0.03)
        return "confirmed"

    def delete_task(self, object_id):
        with self.lock:
            self.task_calls += 1
        time.sleep(0.03)
        return "confirmed"


class PrivacyRetentionConcurrencyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.artifacts = self.root / "artifacts"
        self.registry = self.root / "privacy" / "registry.json"
        self.provider = SlowProvider()
        self.now = 1_700_000_000

    def tearDown(self):
        self.tmp.cleanup()

    def service(self):
        return PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=self.provider,
            now_epoch=lambda: self.now,
        )

    def register_job(self, job, asset=None, task=None):
        return self.service().register(
            logical_job_id=job,
            provider_asset_id=asset,
            provider_task_id=task,
            policy=audioshake_documented_policy(),
            created_at_epoch=self.now,
        )

    def test_concurrent_distinct_registrations_preserve_every_record(self):
        jobs = [f"{i:032x}" for i in range(1, 17)]
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda job: self.register_job(job), jobs))
        records = AtomicPrivacyRegistry(self.registry).load()
        self.assertEqual(set(records), set(jobs))

    def test_concurrent_diagnostic_writers_preserve_all_updates(self):
        job = "a" * 32
        self.register_job(job)

        def write(i):
            self.service().record_diagnostic(job, {"state": "SEPARATING", "attempt": i})

        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(write, range(24)))
        record = AtomicPrivacyRegistry(self.registry).get(job)
        self.assertIsNotNone(record)
        self.assertEqual(len(record.diagnostics), 24)
        self.assertEqual(sorted(item["attempt"] for item in record.diagnostics), list(range(24)))

    def test_concurrent_delete_reserves_provider_side_effect_once(self):
        job = "b" * 32
        asset = "asset-b"
        task = "task-b"
        self.register_job(job, asset=asset, task=task)
        directory = self.artifacts / job
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "stem.wav").write_bytes(b"audio")

        def delete(_):
            return self.service().request_delete(job, provider_asset_id=asset, provider_task_id=task)

        with ThreadPoolExecutor(max_workers=10) as pool:
            list(pool.map(delete, range(10)))
        snapshot = self.service().snapshot(job)
        self.assertEqual(self.provider.asset_calls, 1)
        self.assertEqual(self.provider.task_calls, 1)
        self.assertTrue(snapshot["overallPrivacyDeletionComplete"])
        self.assertFalse(directory.exists())

    def test_concurrent_registration_and_diagnostic_do_not_overwrite_each_other(self):
        primary = "c" * 32
        secondary = "d" * 32
        self.register_job(primary)
        start = threading.Barrier(2)

        def diagnostic():
            start.wait()
            self.service().record_diagnostic(primary, {"state": "SEPARATING", "attempt": 1})

        def registration():
            start.wait()
            self.register_job(secondary)

        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda fn: fn(), (diagnostic, registration)))
        records = AtomicPrivacyRegistry(self.registry).load()
        self.assertIn(primary, records)
        self.assertIn(secondary, records)
        self.assertEqual(records[primary].diagnostics[0]["attempt"], 1)

    def test_a09_topology_now_passes_single_host_only(self):
        one = assess_store_topology("a09_privacy_registry", "single_host")
        many = assess_store_topology("a09_privacy_registry", "multi_host")
        self.assertEqual(one.state, "PASS")
        self.assertEqual(many.state, "FAIL_CLOSED")
        self.assertEqual(many.stable_error_code, "L1A27_SHARED_AUTHORITY_REQUIRED")


if __name__ == "__main__":
    unittest.main()
