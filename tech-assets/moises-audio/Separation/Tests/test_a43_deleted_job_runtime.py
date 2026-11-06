from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from bounded_resumable_long_track_production_orchestrator import (
    BoundedCrashResumableLongTrackProductionSeparationOrchestrator,
)
from production_orchestrator import OrchestratorError


class UnusedProvider:
    pass


class A43DeletedJobRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.sources = self.root / "sources"
        self.artifacts = self.root / "artifacts"
        self.sources.mkdir()
        self.key = "stable-user-operation"
        self.job = hashlib.sha256(("lane1:" + self.key).encode("utf-8")).hexdigest()[:32]

    def tearDown(self):
        self.tmp.cleanup()

    def make_runtime(self):
        return BoundedCrashResumableLongTrackProductionSeparationOrchestrator(
            provider=UnusedProvider(),
            source_root=self.sources,
            artifact_root=self.artifacts,
            registry_path=self.root / "registry.json",
        )

    def test_tombstoned_job_is_rejected_before_start_can_touch_source_or_provider(self):
        runtime = self.make_runtime()
        runtime.tombstone_and_purge_resume_cache(self.job)
        with self.assertRaises(OrchestratorError) as caught:
            runtime.start(
                source_path=self.sources / "missing.wav",
                project_id="project",
                asset_id="asset",
                models=["vocals"],
                idempotency_key=self.key,
            )
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")

    def test_tombstoned_job_is_rejected_before_output_collection(self):
        runtime = self.make_runtime()
        runtime.tombstone_and_purge_resume_cache(self.job)
        with self.assertRaises(OrchestratorError) as caught:
            runtime.collect_ready_outputs(self.job)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")

    def test_delete_tombstone_survives_runtime_restart(self):
        first = self.make_runtime()
        first.tombstone_and_purge_resume_cache(self.job)
        second = self.make_runtime()
        self.assertTrue(second.resume_cache.is_deleted(self.job))
        with self.assertRaises(OrchestratorError) as caught:
            second.collect_ready_outputs(self.job)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")


if __name__ == "__main__":
    unittest.main()
