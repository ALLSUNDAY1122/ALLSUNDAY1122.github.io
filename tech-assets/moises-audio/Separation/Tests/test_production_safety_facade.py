from __future__ import annotations

import ast
import tempfile
import threading
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from production_safety_facade import ProductionSafetyError, ProductionSeparationSafetyFacade
from truthful_cancellation import CancellationTruthError


@dataclass
class Job:
    logical_job_id: str
    provider_asset_id: str | None = "asset-1"
    provider_task_id: str | None = "task-1"
    provider_phase: str = "ready"
    fraction_complete: float = 1.0
    retryable: bool = False
    stable_error_code: str | None = None


@dataclass
class PrivacyRecord:
    local_delete_requested: bool = False
    local_delete_confirmed: bool = False


class FakePrivacyRegistry:
    def __init__(self):
        self.records: dict[str, PrivacyRecord] = {}

    def get(self, logical_job_id: str):
        return self.records.get(logical_job_id)


class FakePrivacyService:
    def __init__(self):
        self.registry = FakePrivacyRegistry()
        self.calls = []

    def request_delete(self, logical_job_id: str, **kwargs):
        self.calls.append((logical_job_id, kwargs))
        record = self.registry.records.setdefault(logical_job_id, PrivacyRecord())
        record.local_delete_requested = True
        record.local_delete_confirmed = True
        return record


class FakeProvider:
    def cancel_task(self, provider_task_id: str):
        return "accepted"


class FakeBackend:
    def __init__(self, job: Job):
        self.job = job
        self.collect_calls = 0
        self.observe_calls = 0
        self.collect_entered = threading.Event()
        self.collect_release = threading.Event()
        self.block_collect = False

    def get(self, logical_job_id: str):
        if logical_job_id != self.job.logical_job_id:
            raise RuntimeError("missing")
        return self.job

    def observe(self, logical_job_id: str):
        self.observe_calls += 1
        return self.job

    def collect_ready_outputs(self, logical_job_id: str):
        self.collect_calls += 1
        if self.block_collect:
            self.collect_entered.set()
            if not self.collect_release.wait(timeout=5):
                raise RuntimeError("collect release timeout")
        return ["raw-output"]


class ProductionSafetyFacadeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.job_id = "a" * 32
        self.job = Job(self.job_id)
        self.backend = FakeBackend(self.job)
        self.privacy = FakePrivacyService()
        self.facade = ProductionSeparationSafetyFacade(
            backend=self.backend,
            provider=FakeProvider(),
            cancellation_registry_path=self.root / "cancel" / "registry.json",
            privacy_service=self.privacy,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_snapshot_and_result_use_safe_cancellation_surface(self):
        snapshot = self.facade.snapshot(self.job_id)
        self.assertEqual(snapshot["phase"], "ready")
        self.assertEqual(self.facade.result(self.job_id), ["raw-output"])
        self.facade.request_cancel(self.job_id)
        with self.assertRaisesRegex(CancellationTruthError, "SEP_CANCELLED_OUTPUT_DISCARDED"):
            self.facade.result(self.job_id)
        self.assertEqual(self.backend.collect_calls, 1)

    def test_privacy_delete_intent_blocks_snapshot_and_result(self):
        self.privacy.registry.records[self.job_id] = PrivacyRecord(local_delete_requested=True)
        with self.assertRaisesRegex(ProductionSafetyError, "SEP_PRIVACY_DELETION_AUTHORITATIVE"):
            self.facade.snapshot(self.job_id)
        with self.assertRaisesRegex(ProductionSafetyError, "SEP_PRIVACY_DELETION_AUTHORITATIVE"):
            self.facade.result(self.job_id)
        self.assertEqual(self.backend.observe_calls, 0)
        self.assertEqual(self.backend.collect_calls, 0)

    def test_overlapping_privacy_delete_is_rechecked_after_collection(self):
        self.backend.block_collect = True
        values = []
        errors = []

        def collect():
            try:
                values.append(self.facade.result(self.job_id))
            except BaseException as exc:
                errors.append(exc)

        thread = threading.Thread(target=collect)
        thread.start()
        self.assertTrue(self.backend.collect_entered.wait(timeout=5))
        self.privacy.registry.records[self.job_id] = PrivacyRecord(local_delete_requested=True)
        self.backend.collect_release.set()
        thread.join(timeout=5)

        self.assertFalse(thread.is_alive())
        self.assertEqual(values, [])
        self.assertEqual(len(errors), 1)
        self.assertIsInstance(errors[0], ProductionSafetyError)
        self.assertEqual(errors[0].code, "SEP_PRIVACY_DELETION_AUTHORITATIVE")

    def test_delete_resolves_provider_ids_only_inside_server_facade(self):
        result = self.facade.request_delete(self.job_id, reason="account_delete")
        self.assertTrue(result.local_delete_confirmed)
        self.assertEqual(len(self.privacy.calls), 1)
        logical_job_id, kwargs = self.privacy.calls[0]
        self.assertEqual(logical_job_id, self.job_id)
        self.assertEqual(kwargs["provider_asset_id"], "asset-1")
        self.assertEqual(kwargs["provider_task_id"], "task-1")
        self.assertEqual(kwargs["reason"], "account_delete")
        self.assertTrue(kwargs["delete_provider"])

    def test_source_binding_never_calls_raw_backend_result_from_public_result_method(self):
        path = SERVER_DIR / "production_safety_facade.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        service = next(
            node for node in tree.body
            if isinstance(node, ast.ClassDef) and node.name == "ProductionSeparationSafetyFacade"
        )
        result_method = next(
            node for node in service.body
            if isinstance(node, ast.FunctionDef) and node.name == "result"
        )
        rendered = ast.unparse(result_method)
        self.assertIn("self._cancellation.collect_ready_outputs", rendered)
        self.assertNotIn("self._backend.collect_ready_outputs", rendered)
        self.assertGreaterEqual(rendered.count("self._assert_privacy_not_deleting"), 2)


if __name__ == "__main__":
    unittest.main()
