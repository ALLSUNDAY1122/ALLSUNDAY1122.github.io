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


class ProviderDeleteReconciliationCrashAtomicityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.job = "d" * 32
        self.asset_id = "asset-crash-secret"
        self.task_id = "task-crash-secret"
        self.service = PrivacyRetentionService(
            artifact_root=self.root / "artifacts",
            registry_path=self.registry_path,
            provider=NoDeleteProvider(),
            now_epoch=lambda: 1_700_200_000,
        )
        self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=1_700_200_000,
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
            record.delete_requested_at_epoch = 1_700_200_001
            record.provider_asset_delete_state = "unknown_after_inflight"
            record.provider_task_delete_state = "unknown_after_inflight"
            return record

        self.service.registry.mutate(self.job, operation)

    def _observation(self, state, epoch, *, object_hash=None, authority="authority-a"):
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind="asset",
            object_id_hash=object_hash or _sha(self.asset_id),
            observed_state=state,
            source_kind="provider_api",
            authority_ref_sha256=_sha(authority),
            observed_at_epoch=epoch,
        )

    def test_crash_after_registry_write_before_applied_commit_blocks_older(self):
        newer = self._observation("present", 1_700_200_200)
        receipt = self.reconciler.ledger.append(newer)
        self.reconciler.ledger.mark_applying(receipt)

        def simulate_registry_write(record):
            self.assertIsNotNone(record)
            record.provider_asset_delete_state = "reconciled_present"
            return record

        self.service.registry.mutate(self.job, simulate_registry_write)
        stale = self.reconciler.apply(
            self._observation("unknown", 1_700_200_100, authority="authority-old")
        )
        self.assertEqual(stale["ordering_decision"], "STALE_IGNORED")
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_present",
        )

        restarted = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
        )
        resumed = restarted.resume_pending(self.job)
        self.assertEqual(resumed["state"], "PASS")
        self.assertEqual(restarted.snapshot(self.job)["inflight_observation_count"], 0)

    def test_crash_before_registry_write_still_blocks_older_then_resumes(self):
        newer = self._observation("present", 1_700_200_200)
        receipt = self.reconciler.ledger.append(newer)
        self.reconciler.ledger.mark_applying(receipt)

        stale = self.reconciler.apply(
            self._observation("unknown", 1_700_200_100, authority="authority-old")
        )
        self.assertEqual(stale["ordering_decision"], "STALE_IGNORED")
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "unknown_after_inflight",
        )
        resumed = self.reconciler.resume_pending(self.job)
        self.assertEqual(resumed["state"], "PASS")
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_present",
        )

    def test_wrong_hash_never_becomes_ordering_watermark(self):
        bad = self._observation(
            "confirmed",
            1_700_299_999,
            object_hash=_sha("wrong-object"),
        )
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_OBJECT_HASH_MISMATCH",
        ):
            self.reconciler.apply(bad)
        row = self.reconciler.snapshot(self.job)["observations"][0]
        self.assertEqual(row["application_state"], "observed_not_applied")
        self.assertEqual(self.reconciler.snapshot(self.job)["inflight_observation_count"], 0)

    def test_applied_receipt_cannot_transition_back_to_applying(self):
        result = self.reconciler.apply(self._observation("present", 1_700_200_200))
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_APPLICATION_TRANSITION_INVALID",
        ):
            self.reconciler.ledger.mark_applying(result["observation_receipt_sha256"])

    def test_equal_epoch_equivalent_inflight_receipt_converges(self):
        first = self._observation("present", 1_700_200_200, authority="authority-a")
        first_receipt = self.reconciler.ledger.append(first)
        self.reconciler.ledger.mark_applying(first_receipt)

        second = self.reconciler.apply(
            self._observation("present", 1_700_200_200, authority="authority-b")
        )
        self.assertEqual(second["ordering_decision"], "APPLIED")
        resumed = self.reconciler.resume_pending(self.job)
        self.assertEqual(resumed["state"], "PASS")
        self.assertEqual(self.reconciler.snapshot(self.job)["pending_observation_count"], 0)

    def test_equal_epoch_conflict_against_inflight_fails_closed(self):
        first = self._observation("present", 1_700_200_200)
        receipt = self.reconciler.ledger.append(first)
        self.reconciler.ledger.mark_applying(receipt)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT",
        ):
            self.reconciler.apply(
                self._observation("unknown", 1_700_200_200, authority="authority-b")
            )
        snapshot = self.reconciler.snapshot(self.job)
        self.assertEqual(snapshot["inflight_observation_count"], 1)
        self.assertEqual(snapshot["pending_observation_count"], 2)

    def test_snapshot_exposes_inflight_as_reconciliation_required(self):
        observation = self._observation("present", 1_700_200_200)
        receipt = self.reconciler.ledger.append(observation)
        self.reconciler.ledger.mark_applying(receipt)
        snapshot = self.reconciler.snapshot(self.job)
        self.assertEqual(snapshot["pending_observation_count"], 1)
        self.assertEqual(snapshot["inflight_observation_count"], 1)
        self.assertTrue(snapshot["reconciliation_required"])

    def test_concurrent_out_of_order_delivery_still_finishes_at_max_epoch(self):
        observations = [
            self._observation(
                "present" if offset % 2 else "unknown",
                1_700_200_200 + offset,
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
        self.assertFalse(self.reconciler.snapshot(self.job)["reconciliation_required"])


if __name__ == "__main__":
    unittest.main()
