import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from budgeted_production_orchestrator import BudgetedProductionSeparationOrchestrator
from cost_quota_guard import CostQuotaGuard, PricingPolicy
from long_track_io import MIB, LongTrackIOGuard, LongTrackPolicy
from production_orchestrator import OrchestratorError


class Provider:
    def upload_asset(self, path):
        raise AssertionError("provider upload must not be reached")

    def create_separation_task(self, asset_id, models, metadata=None):
        raise AssertionError("provider create must not be reached")

    def get_task_state(self, task_id):
        return None


class BudgetedSourceBoundaryTests(unittest.TestCase):
    def test_oversize_source_rejects_before_sha_duration_or_cost_reservation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_root = root / "source"
            source_root.mkdir()
            source = source_root / "oversize.wav"
            with source.open("wb") as handle:
                handle.truncate(MIB + 1)
            cost_guard = CostQuotaGuard(
                policy=PricingPolicy("USD", "0.10", "2.00", "5.00", "20.00"),
                ledger_path=root / "cost.json",
            )
            duration_calls = []
            guard = LongTrackIOGuard(
                LongTrackPolicy(max_source_bytes=MIB, safety_reserve_bytes=0),
                free_bytes_provider=lambda _: 1024 * MIB,
            )
            orchestrator = BudgetedProductionSeparationOrchestrator(
                provider=Provider(),
                cost_guard=cost_guard,
                source_root=source_root,
                artifact_root=root / "artifacts",
                registry_path=root / "jobs.json",
                duration_resolver=lambda _: duration_calls.append(True) or 1.0,
                long_track_guard=guard,
            )
            with patch(
                "budgeted_production_orchestrator._sha256_file",
                side_effect=AssertionError("hash must not be reached"),
            ) as hasher:
                with self.assertRaisesRegex(OrchestratorError, "SEP_SOURCE_TOO_LARGE"):
                    orchestrator.start(
                        source_path=source,
                        project_id="p1",
                        asset_id="a1",
                        models=["vocals"],
                        idempotency_key="oversize",
                    )
            self.assertEqual(hasher.call_count, 0)
            self.assertEqual(duration_calls, [])
            self.assertFalse((root / "cost.json").exists())


if __name__ == "__main__":
    unittest.main()
