import hashlib
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from privacy_retention import PrivacyRetentionError, PrivacyRetentionService, audioshake_documented_policy
from provider_delete_reconciliation import ProviderDeletionObservation, ProviderDeletionReconciler


class NoDeleteProvider:
    pass


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class ProviderDeleteReconciliationTests(unittest.TestCase):
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

    def tearDown(self):
        self.tmp.cleanup()

    def reserve_ambiguous_delete(self):
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

    def observation(self, object_kind, observed_state, *, source_kind="provider_api", object_hash=None, epoch=1_700_000_100):
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind=object_kind,
            object_id_hash=object_hash or _sha(self.asset_id if object_kind == "asset" else self.task_id),
            observed_state=observed_state,
            source_kind=source_kind,
            authority_ref_sha256=_sha("private-authority-record"),
            observed_at_epoch=epoch,
        )

    def test_ambiguous_delete_can_be_resolved_without_replaying_provider_delete(self):
        self.reserve_ambiguous_delete()
        self.reconciler.apply(self.observation("asset", "confirmed"))
        self.reconciler.apply(self.observation("task", "not_found", epoch=1_700_000_101))
        snapshot = self.service.snapshot(self.job)
        self.assertTrue(snapshot["providerErasureComplete"])
        self.assertTrue(snapshot["overallPrivacyDeletionComplete"])

    def test_reconciliation_requires_prior_durable_delete_reservation(self):
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_DELETE_NOT_RESERVED"):
            self.reconciler.apply(self.observation("asset", "confirmed"))

    def test_observation_is_bound_to_registered_provider_object_hash(self):
        self.reserve_ambiguous_delete()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH"):
            self.reconciler.apply(self.observation("asset", "confirmed", object_hash=_sha("wrong-object")))

    def test_present_observation_never_claims_erasure(self):
        self.reserve_ambiguous_delete()
        result = self.reconciler.apply(self.observation("asset", "present"))
        self.assertEqual(result["applied_state"], "reconciled_present")
        self.assertFalse(self.service.snapshot(self.job)["providerErasureComplete"])

    def test_terminal_erasure_state_cannot_be_downgraded(self):
        self.reserve_ambiguous_delete()
        self.reconciler.apply(self.observation("asset", "confirmed"))
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE"):
            self.reconciler.apply(self.observation("asset", "present", epoch=1_700_000_102))
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "confirmed")

    def test_same_observation_is_idempotent_and_ledger_marks_applied(self):
        self.reserve_ambiguous_delete()
        observation = self.observation("asset", "confirmed")
        first = self.reconciler.apply(observation)
        second = self.reconciler.apply(observation)
        self.assertEqual(first["observation_receipt_sha256"], second["observation_receipt_sha256"])
        evidence = self.reconciler.snapshot(self.job)
        self.assertEqual(evidence["observation_count"], 1)
        self.assertEqual(evidence["observations"][0]["application_state"], "applied")
        self.assertEqual(evidence["parity_claim"], "NONE")

    def test_failed_application_remains_observed_not_applied_for_recovery(self):
        self.reserve_ambiguous_delete()
        observation = self.observation("asset", "confirmed", object_hash=_sha("wrong-object"))
        with self.assertRaises(PrivacyRetentionError):
            self.reconciler.apply(observation)
        evidence = self.reconciler.snapshot(self.job)
        self.assertEqual(evidence["observation_count"], 1)
        self.assertEqual(evidence["observations"][0]["application_state"], "observed_not_applied")

    def test_documented_expiry_cannot_claim_provider_confirmation_or_task_expiry(self):
        self.reserve_ambiguous_delete()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_SOURCE_INSUFFICIENT"):
            self.reconciler.apply(self.observation("asset", "confirmed", source_kind="documented_expiry"))
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_EXPIRY_SCOPE_INVALID"):
            self.reconciler.apply(self.observation("task", "expired", source_kind="documented_expiry"))

    def test_ledger_contains_hashes_not_raw_provider_ids(self):
        self.reserve_ambiguous_delete()
        self.reconciler.apply(self.observation("asset", "confirmed"))
        text = self.ledger_path.read_text(encoding="utf-8")
        self.assertNotIn(self.asset_id, text)
        self.assertNotIn(self.task_id, text)
        self.assertNotIn("http://", text)
        self.assertNotIn("https://", text)
        self.assertIn(_sha(self.asset_id), text)

    def test_concurrent_duplicate_observation_has_one_durable_receipt(self):
        self.reserve_ambiguous_delete()
        observation = self.observation("asset", "confirmed")
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.reconciler.apply(observation), range(16)))
        self.assertEqual(len({row["observation_receipt_sha256"] for row in results}), 1)
        self.assertEqual(self.reconciler.snapshot(self.job)["observation_count"], 1)

    def test_corrupt_reconciliation_ledger_fails_closed(self):
        self.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        self.ledger_path.write_text("{bad json", encoding="utf-8")
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_LEDGER_CORRUPT"):
            self.reconciler.snapshot(self.job)


if __name__ == "__main__":
    unittest.main()
