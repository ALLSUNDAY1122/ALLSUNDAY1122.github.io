from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from budgeted_production_orchestrator import BudgetedProductionSeparationOrchestrator
from production_orchestrator import OrchestratorError


class UnusedProvider:
    pass


class CostGuardMustNotRun:
    def __getattr__(self, name):
        raise AssertionError(f"cost guard accessed after delete tombstone: {name}")


class A43BudgetedDeletedJobTests(unittest.TestCase):
    def test_deleted_job_rejects_before_source_hash_duration_cost_or_provider(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            sources = root / "sources"
            sources.mkdir()
            duration_calls = []
            runtime = BudgetedProductionSeparationOrchestrator(
                provider=UnusedProvider(),
                cost_guard=CostGuardMustNotRun(),
                source_root=sources,
                artifact_root=root / "artifacts",
                registry_path=root / "registry.json",
                duration_resolver=lambda path: duration_calls.append(path) or 1.0,
            )
            key = "deleted-stable-operation"
            job = hashlib.sha256(("lane1:" + key).encode("utf-8")).hexdigest()[:32]
            runtime.tombstone_and_purge_resume_cache(job)
            with self.assertRaises(OrchestratorError) as caught:
                runtime.start(
                    source_path=sources / "does-not-exist.wav",
                    project_id="project",
                    asset_id="asset",
                    models=["vocals"],
                    idempotency_key=key,
                )
            self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")
            self.assertEqual(duration_calls, [])


if __name__ == "__main__":
    unittest.main()
