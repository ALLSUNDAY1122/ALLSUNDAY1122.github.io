import hashlib
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


class ProviderDeleteReconciliationOrderingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.job = "c" * 32
        self.asset_id = "asset-ordering-secret"
        self.task_id = "task-ordering-secret"
        self.service = PrivacyRetentionService(
            artifact_root=self.root / "artifacts",
            registry_path=self.registry_path,
            provider=NoDeleteProvider(),
            now_epoch=lambda: 1_700_100_000,
        )
        self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=1_700_100_000,
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
            record.delete_requested_at_epoch = 1_700_100_001
            record.provider_asset_delete_state = "unknown_after_inflight"
            record.provider_task_delete_state = "unknown_after_inflight"
            return record

        self.service.registry.mutate(self.job, operation)

    def _observation(self, state, epoch, *, object_kind="asset", object_hash=None, authority="authority-a"):
        object_id = self.asset_id if object_kind == "asset" else self.task_id
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind=object_kind,
            object_id_hash=object_hash or _sha(object_id),
            observed_state=state,
            source_kind="provider_api",
            authority_ref_sha256=_sha(authority),
            observed_at_epoch=epoch,
        )

    def test_late_stale_observation_cannot_roll_registry_back(self):
        newer = self.reconciler.apply(self._observation("present", 1_700_100_200))
        stale = self.reconciler.apply(self._observation("unknown", 1_700_100_100, authority="authority-old"))
        self.assertEqual(newer["ordering_decision"], "APPLIED")
        self.assertEqual(stale["ordering_decision"], "STALE_IGNORED")
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "reconciled_present")
        self.assertEqual(self.reconciler.snapshot(self.job)["superseded_stale_count"], 1)

    def test_equal_epoch_equivalent_observation_is_accepted_without_state_change(self):
        first = self.reconciler.apply(self._observation("present", 1_700_100_200, authority="authority-a"))
        second = self.reconciler.apply(self._observation("present", 1_700_100_200, authority="authority-b"))
        self.assertEqual(first["ordering_decision"], "APPLIED")
        self.assertEqual(second["ordering_decision"], "EQUIVALENT_EPOCH_APPLIED")
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "reconciled_present")

    def test_equal_epoch_conflicting_observation_fails_closed_and_stays_pending(self):
        self.reconciler.apply(self._observation("present", 1_700_100_200, authority="authority-a"))
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT"):
            self.reconciler.apply(self._observation("unknown", 1_700_100_200, authority="authority-b"))
        snapshot = self.reconciler.snapshot(self.job)
        self.assertTrue(snapshot["reconciliation_required"])
        self.assertEqual(snapshot["pending_observation_count"], 1)

    def test_same_receipt_remains_idempotent(self):
        observation = self._observation("present", 1_700_100_200)
        first = self.reconciler.apply(observation)
        second = self.reconciler.apply(observation)
        self.assertEqual(first["observation_receipt_sha256"], second["observation_receipt_sha256"])
        self.assertEqual(second["ordering_decision"], "ALREADY_APPLIED")
        self.assertEqual(self.reconciler.snapshot(self.job)["observation_count"], 1)

    def test_newer_nonterminal_observation_cannot_downgrade_terminal_erasure(self):
        self.reconciler.apply(self._observation("confirmed", 1_700_100_200))
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE"):
            self.reconciler.apply(self._observation("present", 1_700_100_300, authority="authority-new"))
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "confirmed")
        self.assertTrue(self.reconciler.snapshot(self.job)["reconciliation_required"])

    def test_newer_wrong_hash_observation_fails_and_remains_pending(self):
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH"):
            self.reconciler.apply(
                self._observation("confirmed", 1_700_100_300, object_hash=_sha("wrong-object"))
            )
        snapshot = self.reconciler.snapshot(self.job)
        self.assertEqual(snapshot["pending_observation_count"], 1)
        self.assertTrue(snapshot["reconciliation_required"])

    def test_restart_resume_supersedes_older_pending_after_newer_applied(self):
        old = self._observation("unknown", 1_700_100_100, authority="authority-old")
        self.reconciler.ledger.append(old)
        self.reconciler.apply(self._observation("present", 1_700_100_200, authority="authority-new"))

        restarted = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
        )
        result = restarted.resume_pending(self.job)
        self.assertEqual(result["state"], "PASS")
        self.assertEqual(result["superseded_stale_count"], 1)
        self.assertEqual(result["remaining_pending_count"], 0)
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "reconciled_present")

    def test_concurrent_out_of_order_observations_finish_at_max_epoch_state(self):
        observations = [
            self._observation(
                "present" if offset % 2 else "unknown",
                1_700_100_200 + offset,
                authority=f"authority-{offset}",
            )
            for offset in range(20)
        ]
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(self.reconciler.apply, reversed(observations)))
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_present",
        )
        rows = self.reconciler.snapshot(self.job)["observations"]
        applied_epochs = [
            row["observed_at_epoch"]
            for row in rows
            if row["application_state"] == "applied"
        ]
        self.assertEqual(max(applied_epochs), 1_700_100_219)
        self.assertFalse(self.reconciler.snapshot(self.job)["reconciliation_required"])


if __name__ == "__main__":
    unittest.main()
