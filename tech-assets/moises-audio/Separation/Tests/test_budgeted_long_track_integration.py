import hashlib
import tempfile
import unittest
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from budgeted_production_orchestrator import BudgetedProductionSeparationOrchestrator
from cost_quota_guard import CostQuotaGuard, PricingPolicy
from long_track_io import MIB, LongTrackIOGuard, LongTrackPolicy
from production_orchestrator import OrchestratorError


class FakeProvider:
    def __init__(self):
        self.upload_calls = 0
        self.create_calls = 0

    def upload_asset(self, path):
        self.upload_calls += 1
        return "asset-1"

    def create_separation_task(self, asset_id, models, metadata=None):
        self.create_calls += 1
        return "task-1"

    def get_task_state(self, task_id):
        return None


class BudgetedLongTrackIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source_root = self.root / "source"
        self.source_root.mkdir()
        self.source = self.source_root / "song.wav"
        self.source.write_bytes(b"audio")
        self.provider = FakeProvider()
        pricing = PricingPolicy("USD", "0.10", "2.00", "5.00", "20.00")
        self.cost_guard = CostQuotaGuard(policy=pricing, ledger_path=self.root / "cost.json")

    def tearDown(self):
        self.tmp.cleanup()

    def make_orchestrator(self, free_bytes):
        long_guard = LongTrackIOGuard(
            LongTrackPolicy(
                max_source_bytes=32 * MIB,
                output_estimate_ratio_per_target=1.0,
                max_output_ratio_per_target=2.0,
                minimum_estimated_stem_bytes=1,
                minimum_max_stem_bytes=1,
                safety_reserve_bytes=100,
            ),
            free_bytes_provider=lambda _: free_bytes,
        )
        return BudgetedProductionSeparationOrchestrator(
            provider=self.provider,
            cost_guard=self.cost_guard,
            source_root=self.source_root,
            artifact_root=self.root / "artifacts",
            registry_path=self.root / "jobs.json",
            duration_resolver=lambda _: 120.0,
            long_track_guard=long_guard,
        )

    def test_storage_preflight_failure_releases_cost_reservation_before_provider_create(self):
        orch = self.make_orchestrator(free_bytes=1)
        with self.assertRaisesRegex(OrchestratorError, "SEP_STORAGE_PREFLIGHT_INSUFFICIENT"):
            orch.start(
                source_path=self.source,
                project_id="p1",
                asset_id="a1",
                models=["vocals", "drums"],
                idempotency_key="idem-storage",
            )
        logical_job_id = hashlib.sha256(b"lane1:idem-storage").hexdigest()[:32]
        cost = self.cost_guard.get(logical_job_id)
        self.assertEqual(cost.provider_create_state, "not_attempted")
        self.assertEqual(cost.accounting_state, "released")
        self.assertEqual(self.provider.upload_calls, 0)
        self.assertEqual(self.provider.create_calls, 0)

    def test_success_exposes_long_track_preflight_telemetry_without_changing_cost_semantics(self):
        orch = self.make_orchestrator(free_bytes=1024 * MIB)
        record = orch.start(
            source_path=self.source,
            project_id="p1",
            asset_id="a1",
            models=["vocals"],
            idempotency_key="idem-success",
        )
        cost = self.cost_guard.get(record.logical_job_id)
        telemetry = orch.long_track_status(record.logical_job_id)
        self.assertEqual(cost.provider_create_state, "confirmed")
        self.assertEqual(self.provider.create_calls, 1)
        self.assertEqual(telemetry.storage_preflight_state, "passed_before_provider")
        self.assertEqual(telemetry.target_count, 1)
        self.assertEqual(telemetry.upload_bytes, self.source.stat().st_size)


if __name__ == "__main__":
    unittest.main()
