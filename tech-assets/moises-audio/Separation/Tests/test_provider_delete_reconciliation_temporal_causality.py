import hashlib
import tempfile
import unittest
from pathlib import Path

from privacy_retention import PrivacyRetentionError, PrivacyRetentionService, audioshake_documented_policy
from provider_delete_reconciliation import ProviderDeletionObservation, ProviderDeletionReconciler


class NoDeleteProvider:
    pass


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class ProviderDeleteReconciliationTemporalCausalityTests(unittest.TestCase):
    DELETE_EPOCH = 1_700_300_050
    NOW_EPOCH = 1_700_300_100

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.job = "e" * 32
        self.asset_id = "asset-temporal-secret"
        self.task_id = "task-temporal-secret"
        self.service = PrivacyRetentionService(
            artifact_root=self.root / "artifacts",
            registry_path=self.registry_path,
            provider=NoDeleteProvider(),
            now_epoch=lambda: self.NOW_EPOCH,
        )
        self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=1_700_300_000,
        )
        self._reserve_ambiguous_delete()
        self.reconciler = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
            now_epoch=lambda: self.NOW_EPOCH,
            max_future_skew_seconds=300,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def _reserve_ambiguous_delete(self):
        def operation(record):
            self.assertIsNotNone(record)
            record.local_delete_requested = True
            record.local_delete_confirmed = True
            record.provider_delete_requested = True
            record.delete_requested_at_epoch = self.DELETE_EPOCH
            record.provider_asset_delete_state = "unknown_after_inflight"
            record.provider_task_delete_state = "unknown_after_inflight"
            return record

        self.service.registry.mutate(self.job, operation)

    def _observation(self, state: str, epoch: int, *, authority: str = "authority-a") -> ProviderDeletionObservation:
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind="asset",
            object_id_hash=_sha(self.asset_id),
            observed_state=state,
            source_kind="provider_api",
            authority_ref_sha256=_sha(authority),
            observed_at_epoch=epoch,
        )

    def test_observation_before_delete_request_is_rejected_before_watermark(self):
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_OBSERVATION_PRECEDES_DELETE",
        ):
            self.reconciler.apply(self._observation("confirmed", self.DELETE_EPOCH - 1))
        row = self.reconciler.snapshot(self.job)["observations"][0]
        self.assertEqual(row["application_state"], "observed_not_applied")
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "unknown_after_inflight")

    def test_observation_at_delete_epoch_is_causally_accepted(self):
        result = self.reconciler.apply(self._observation("present", self.DELETE_EPOCH))
        self.assertEqual(result["ordering_decision"], "APPLIED")
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "reconciled_present")

    def test_observation_beyond_future_skew_is_rejected_before_watermark(self):
        future = self.NOW_EPOCH + 301
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_OBSERVATION_FROM_FUTURE",
        ):
            self.reconciler.apply(self._observation("confirmed", future))
        row = self.reconciler.snapshot(self.job)["observations"][0]
        self.assertEqual(row["application_state"], "observed_not_applied")
        self.assertEqual(self.reconciler.snapshot(self.job)["inflight_observation_count"], 0)

    def test_future_skew_boundary_is_accepted(self):
        result = self.reconciler.apply(self._observation("present", self.NOW_EPOCH + 300))
        self.assertEqual(result["ordering_decision"], "APPLIED")

    def test_future_invalid_high_epoch_does_not_block_later_valid_observation(self):
        invalid = self._observation("unknown", self.NOW_EPOCH + 10_000, authority="bad-clock")
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_OBSERVATION_FROM_FUTURE",
        ):
            self.reconciler.apply(invalid)
        valid = self.reconciler.apply(self._observation("present", self.NOW_EPOCH, authority="good-clock"))
        self.assertEqual(valid["ordering_decision"], "APPLIED")
        self.assertEqual(self.service.snapshot(self.job)["providerAssetDeleteState"], "reconciled_present")
        rows = self.reconciler.snapshot(self.job)["observations"]
        bad_row = next(row for row in rows if row["authority_ref_sha256"] == _sha("bad-clock"))
        self.assertEqual(bad_row["application_state"], "observed_not_applied")

    def test_missing_delete_epoch_fails_closed(self):
        def corrupt_temporal_anchor(record):
            self.assertIsNotNone(record)
            record.delete_requested_at_epoch = None
            return record

        self.service.registry.mutate(self.job, corrupt_temporal_anchor)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_DELETE_EPOCH_INVALID",
        ):
            self.reconciler.apply(self._observation("confirmed", self.NOW_EPOCH))

    def test_invalid_runtime_clock_fails_closed(self):
        bad_clock = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
            now_epoch=lambda: True,
        )
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CLOCK_INVALID",
        ):
            bad_clock.apply(self._observation("present", self.NOW_EPOCH))

    def test_resume_keeps_temporally_invalid_observation_pending_with_stable_error(self):
        self.reconciler.ledger.append(self._observation("confirmed", self.DELETE_EPOCH - 1))
        result = self.reconciler.resume_pending(self.job)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(result["failure_count"], 1)
        self.assertEqual(result["remaining_pending_count"], 1)
        self.assertEqual(
            result["failures"][0]["stable_error_code"],
            "SEP_PRIVACY_RECONCILE_OBSERVATION_PRECEDES_DELETE",
        )

    def test_invalid_future_skew_configuration_is_rejected(self):
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_FUTURE_SKEW_INVALID",
        ):
            ProviderDeletionReconciler(
                registry_path=self.registry_path,
                ledger_path=self.ledger_path,
                max_future_skew_seconds=-1,
            )


if __name__ == "__main__":
    unittest.main()
