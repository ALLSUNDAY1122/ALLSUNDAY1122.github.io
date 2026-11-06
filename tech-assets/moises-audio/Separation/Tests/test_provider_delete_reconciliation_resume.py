import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from privacy_retention import PrivacyRetentionError, PrivacyRetentionService, audioshake_documented_policy
from provider_delete_reconciliation import ProviderDeletionObservation, ProviderDeletionReconciler


class NoDeleteProvider:
    pass


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class ProviderDeleteReconciliationResumeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.artifact_root = self.root / "artifacts"
        self.job = "a" * 32
        self.asset_id = "asset-secret-123"
        self.task_id = "task-secret-456"
        self.service = PrivacyRetentionService(
            artifact_root=self.artifact_root,
            registry_path=self.registry_path,
            provider=NoDeleteProvider(),
            now_epoch=lambda: 1_700_000_000,
        )
        self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=1_700_000_000,
        )
        self.reconciler = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
        )
        self._reserve_ambiguous_delete()

    def tearDown(self):
        self.tmp.cleanup()

    def _reserve_ambiguous_delete(self):
        def operation(record):
            self.assertIsNotNone(record)
            record.local_delete_requested = True
            record.local_delete_confirmed = True
            record.provider_delete_requested = True
            record.delete_requested_at_epoch = 1_700_000_001
            record.provider_asset_delete_state = "unknown_after_inflight"
            record.provider_task_delete_state = "unknown_after_inflight"
            return record

        self.service.registry.mutate(self.job, operation)

    def observation(self, object_kind, observed_state="confirmed", *, object_hash=None, epoch=1_700_000_100):
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind=object_kind,
            object_id_hash=object_hash or _sha(self.asset_id if object_kind == "asset" else self.task_id),
            observed_state=observed_state,
            source_kind="provider_api",
            authority_ref_sha256=_sha("private-authority-record"),
            observed_at_epoch=epoch,
        )

    def test_restart_resumes_durable_observation_without_provider_replay(self):
        self.reconciler.ledger.append(self.observation("asset"))
        restarted = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
        )
        result = restarted.resume_pending(self.job)
        self.assertEqual(result["state"], "PASS")
        self.assertEqual(result["applied_count"], 1)
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "confirmed")
        self.assertFalse(restarted.snapshot(self.job)["reconciliation_required"])

    def test_resume_multiple_pending_observations(self):
        self.reconciler.ledger.append(self.observation("asset", epoch=1_700_000_100))
        self.reconciler.ledger.append(self.observation("task", "not_found", epoch=1_700_000_101))
        result = self.reconciler.resume_pending(self.job)
        self.assertEqual(result["applied_count"], 2)
        self.assertEqual(result["remaining_pending_count"], 0)
        self.assertTrue(self.service.snapshot(self.job)["providerErasureComplete"])

    def test_failed_resume_remains_pending_with_stable_error(self):
        self.reconciler.ledger.append(
            self.observation("asset", object_hash=_sha("wrong-object"))
        )
        result = self.reconciler.resume_pending(self.job)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(result["failure_count"], 1)
        self.assertEqual(result["remaining_pending_count"], 1)
        self.assertEqual(
            result["failures"][0]["stable_error_code"],
            "SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH",
        )

    def test_snapshot_exposes_pending_reconciliation(self):
        self.reconciler.ledger.append(self.observation("asset"))
        self.reconciler.ledger.append(self.observation("task", epoch=1_700_000_101))
        snapshot = self.reconciler.snapshot(self.job)
        self.assertEqual(snapshot["pending_observation_count"], 2)
        self.assertTrue(snapshot["reconciliation_required"])

    def test_semantically_invalid_application_state_fails_closed(self):
        observation = self.observation("asset")
        receipt = self.reconciler.ledger.append(observation)
        payload = json.loads(self.ledger_path.read_text(encoding="utf-8"))
        payload["events"][receipt]["application_state"] = "pretend_applied"
        self.ledger_path.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_LEDGER_EVENT_INVALID",
        ):
            self.reconciler.snapshot(self.job)

    def test_tampered_event_receipt_fails_closed(self):
        observation = self.observation("asset")
        receipt = self.reconciler.ledger.append(observation)
        payload = json.loads(self.ledger_path.read_text(encoding="utf-8"))
        payload["events"][receipt]["observed_at_epoch"] += 1
        self.ledger_path.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_LEDGER_RECEIPT_MISMATCH",
        ):
            self.reconciler.snapshot(self.job)

    def test_already_applied_observation_is_not_resumed(self):
        self.reconciler.apply(self.observation("asset"))
        result = self.reconciler.resume_pending(self.job)
        self.assertEqual(result["attempted_count"], 0)
        self.assertEqual(result["applied_count"], 0)
        self.assertEqual(result["state"], "PASS")

    def test_terminal_downgrade_remains_pending_for_operator_review(self):
        self.reconciler.apply(self.observation("asset", "confirmed", epoch=1_700_000_100))
        self.reconciler.ledger.append(
            self.observation("asset", "present", epoch=1_700_000_101)
        )
        result = self.reconciler.resume_pending(self.job)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(
            result["failures"][0]["stable_error_code"],
            "SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE",
        )
        self.assertEqual(result["remaining_pending_count"], 1)


if __name__ == "__main__":
    unittest.main()
