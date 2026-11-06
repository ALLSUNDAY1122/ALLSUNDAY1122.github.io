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


class ProviderDeleteDocumentedExpiryAuthorityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.job = "e" * 32
        self.asset_id = "asset-expiry-secret"
        self.task_id = "task-expiry-secret"
        self.created = 1_700_300_000
        self.delete_epoch = self.created + 10
        self.asset_expiry = self.created + (72 * 60 * 60)
        self.clock = {"now": self.asset_expiry}
        self.service = PrivacyRetentionService(
            artifact_root=self.root / "artifacts",
            registry_path=self.registry_path,
            provider=NoDeleteProvider(),
            now_epoch=lambda: self.clock["now"],
        )
        self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=self.created,
        )
        self.reconciler = ProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
            now_epoch=lambda: self.clock["now"],
            max_future_skew_seconds=300,
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
            record.delete_requested_at_epoch = self.delete_epoch
            record.provider_asset_delete_state = "unknown_after_inflight"
            record.provider_task_delete_state = "unknown_after_inflight"
            return record

        self.service.registry.mutate(self.job, operation)

    def _observation(
        self,
        *,
        state="expired",
        source="documented_expiry",
        epoch=None,
        kind="asset",
        authority="authority-expiry",
    ):
        object_id = self.asset_id if kind == "asset" else self.task_id
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind=kind,
            object_id_hash=_sha(object_id),
            observed_state=state,
            source_kind=source,
            authority_ref_sha256=_sha(authority),
            observed_at_epoch=self.asset_expiry if epoch is None else epoch,
        )

    def test_documented_expiry_before_registered_ttl_is_rejected(self):
        premature = self.asset_expiry - 1
        self.clock["now"] = premature
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_NOT_REACHED",
        ):
            self.reconciler.apply(self._observation(epoch=premature))
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "unknown_after_inflight",
        )

    def test_documented_expiry_at_registered_ttl_is_accepted(self):
        result = self.reconciler.apply(self._observation())
        self.assertEqual(result["applied_state"], "expired")
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "expired",
        )

    def test_local_clock_must_also_have_reached_expiry(self):
        self.clock["now"] = self.asset_expiry - 1
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_LOCAL_CLOCK_BEFORE_EXPIRY",
        ):
            self.reconciler.apply(self._observation(epoch=self.asset_expiry))

    def test_missing_registered_expiry_fails_closed(self):
        def operation(record):
            self.assertIsNotNone(record)
            record.vendor_asset_expires_at_epoch = None
            return record

        self.service.registry.mutate(self.job, operation)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_EPOCH_INVALID",
        ):
            self.reconciler.apply(self._observation())

    def test_boolean_registered_expiry_fails_closed(self):
        def operation(record):
            self.assertIsNotNone(record)
            record.vendor_asset_expires_at_epoch = True
            return record

        self.service.registry.mutate(self.job, operation)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_EPOCH_INVALID",
        ):
            self.reconciler.apply(self._observation())

    def test_documented_expiry_cannot_claim_present_or_unknown(self):
        for state in ("present", "unknown"):
            with self.subTest(state=state):
                with self.assertRaisesRegex(
                    PrivacyRetentionError,
                    "SEP_PRIVACY_RECONCILE_DOCUMENTED_EXPIRY_STATE_INVALID",
                ):
                    self.reconciler.apply(self._observation(state=state, authority=f"authority-{state}"))

    def test_existing_confirmation_error_contract_is_preserved(self):
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_SOURCE_INSUFFICIENT",
        ):
            self.reconciler.apply(self._observation(state="confirmed"))

    def test_task_expiry_remains_out_of_scope_for_documented_asset_ttl(self):
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_EXPIRY_SCOPE_INVALID",
        ):
            self.reconciler.apply(self._observation(kind="task"))

    def test_rejected_premature_expiry_does_not_poison_later_provider_observation(self):
        premature = self.asset_expiry - 100
        self.clock["now"] = premature
        with self.assertRaises(PrivacyRetentionError):
            self.reconciler.apply(self._observation(epoch=premature))

        self.clock["now"] = self.asset_expiry
        provider_result = self.reconciler.apply(
            self._observation(
                state="confirmed",
                source="provider_api",
                epoch=self.asset_expiry,
                authority="authority-provider",
            )
        )
        self.assertEqual(provider_result["applied_state"], "confirmed")
        snapshot = self.reconciler.snapshot(self.job)
        states = [row["application_state"] for row in snapshot["observations"]]
        self.assertEqual(states.count("applied"), 1)
        self.assertEqual(states.count("observed_not_applied"), 1)
        self.assertTrue(snapshot["reconciliation_required"])


if __name__ == "__main__":
    unittest.main()
