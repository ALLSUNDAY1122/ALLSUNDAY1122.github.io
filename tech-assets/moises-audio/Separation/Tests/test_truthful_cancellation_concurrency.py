from __future__ import annotations

import json
import tempfile
import threading
import time
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from truthful_cancellation import CancellationTruthError, TruthfulCancellationService


@dataclass
class Job:
    logical_job_id: str
    provider_task_id: str | None
    provider_phase: str = "separating"
    fraction_complete: float = 0.5
    retryable: bool = True
    stable_error_code: str | None = None


class MultiJobBackend:
    def __init__(self, jobs: list[Job]):
        self.jobs = {job.logical_job_id: job for job in jobs}
        self.collect_calls = 0

    def get(self, logical_job_id: str) -> Job:
        return self.jobs[logical_job_id]

    def observe(self, logical_job_id: str) -> Job:
        return self.jobs[logical_job_id]

    def collect_ready_outputs(self, logical_job_id: str):
        self.collect_calls += 1
        return [logical_job_id]


class BlockingProvider:
    def __init__(self):
        self.entered = threading.Event()
        self.release = threading.Event()
        self.cancel_calls = 0

    def cancel_task(self, provider_task_id: str):
        self.cancel_calls += 1
        self.entered.set()
        if not self.release.wait(timeout=5):
            raise RuntimeError("cancel release timeout")
        return "accepted"


class AcceptedProvider:
    def cancel_task(self, provider_task_id: str):
        return "accepted"


class TruthfulCancellationConcurrencyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry = self.root / "cancel" / "registry.json"
        self.job_a = Job("a" * 32, "task-a")
        self.job_b = Job("b" * 32, "task-b")
        self.backend = MultiJobBackend([self.job_a, self.job_b])

    def tearDown(self):
        self.tmp.cleanup()

    def test_concurrent_different_job_cancels_preserve_both_registry_records(self):
        provider = AcceptedProvider()
        service_a = TruthfulCancellationService(
            backend=self.backend,
            provider=provider,
            registry_path=self.registry,
        )
        service_b = TruthfulCancellationService(
            backend=self.backend,
            provider=provider,
            registry_path=self.registry,
        )
        barrier = threading.Barrier(3)
        errors: list[BaseException] = []

        def run(service, logical_job_id):
            try:
                barrier.wait(timeout=5)
                service.request_cancel(logical_job_id)
            except BaseException as exc:  # pragma: no cover - asserted below
                errors.append(exc)

        ta = threading.Thread(target=run, args=(service_a, self.job_a.logical_job_id))
        tb = threading.Thread(target=run, args=(service_b, self.job_b.logical_job_id))
        ta.start()
        tb.start()
        barrier.wait(timeout=5)
        ta.join(timeout=5)
        tb.join(timeout=5)

        self.assertFalse(ta.is_alive())
        self.assertFalse(tb.is_alive())
        self.assertEqual(errors, [])
        raw = json.loads(self.registry.read_text(encoding="utf-8"))
        self.assertEqual(set(raw["records"]), {self.job_a.logical_job_id, self.job_b.logical_job_id})
        self.assertTrue(raw["records"][self.job_a.logical_job_id]["cancel_requested"])
        self.assertTrue(raw["records"][self.job_b.logical_job_id]["cancel_requested"])

    def test_cancel_intent_linearizes_before_concurrent_result_across_instances(self):
        provider = BlockingProvider()
        cancel_service = TruthfulCancellationService(
            backend=self.backend,
            provider=provider,
            registry_path=self.registry,
        )
        result_service = TruthfulCancellationService(
            backend=self.backend,
            provider=provider,
            registry_path=self.registry,
        )
        cancel_errors: list[BaseException] = []
        result_errors: list[BaseException] = []
        result_values: list[object] = []

        def cancel():
            try:
                cancel_service.request_cancel(self.job_a.logical_job_id)
            except BaseException as exc:  # pragma: no cover - asserted below
                cancel_errors.append(exc)

        def collect():
            try:
                result_values.append(result_service.collect_ready_outputs(self.job_a.logical_job_id))
            except BaseException as exc:
                result_errors.append(exc)

        cancel_thread = threading.Thread(target=cancel)
        cancel_thread.start()
        self.assertTrue(provider.entered.wait(timeout=5))

        # The logical intent is already durable while the provider call is blocked. A second service
        # instance must not pass the result gate during this window.
        persisted = json.loads(self.registry.read_text(encoding="utf-8"))
        self.assertTrue(persisted["records"][self.job_a.logical_job_id]["cancel_requested"])
        result_thread = threading.Thread(target=collect)
        result_thread.start()
        time.sleep(0.05)
        self.assertTrue(result_thread.is_alive())
        self.assertEqual(self.backend.collect_calls, 0)

        provider.release.set()
        cancel_thread.join(timeout=5)
        result_thread.join(timeout=5)

        self.assertEqual(cancel_errors, [])
        self.assertEqual(result_values, [])
        self.assertEqual(self.backend.collect_calls, 0)
        self.assertEqual(len(result_errors), 1)
        self.assertIsInstance(result_errors[0], CancellationTruthError)
        self.assertEqual(result_errors[0].code, "SEP_CANCELLED_OUTPUT_DISCARDED")


if __name__ == "__main__":
    unittest.main()
