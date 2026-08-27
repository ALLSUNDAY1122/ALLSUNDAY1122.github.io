import hashlib
import tempfile
import unittest
from pathlib import Path

from privacy_retention import PrivacyRetentionError, PrivacyRetentionService, audioshake_documented_policy
from provider_delete_conflict_resolution import (
    ConflictResolvingProviderDeletionReconciler,
    EqualEpochConflictDecision,
)
from provider_delete_reconciliation import ProviderDeletionObservation


class NoDeleteProvider:
    pass


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class ProviderDeleteConflictResolutionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry_path = self.root / "privacy" / "registry.json"
        self.ledger_path = self.root / "privacy" / "provider-delete-reconciliation.json"
        self.decision_path = self.root / "privacy" / "provider-delete-conflict-decisions.json"
        self.job = "d" * 32
        self.asset_id = "asset-conflict-secret"
        self.task_id = "task-conflict-secret"
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
        self.reconciler = self._make_reconciler()
        self._reserve_ambiguous_delete()

    def tearDown(self):
        self.tmp.cleanup()

    def _make_reconciler(self):
        return ConflictResolvingProviderDeletionReconciler(
            registry_path=self.registry_path,
            ledger_path=self.ledger_path,
            conflict_decision_path=self.decision_path,
            now_epoch=lambda: 1_700_101_000,
        )

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

    def _observation(self, state, epoch=1_700_100_200, *, object_kind="asset", authority="authority-a"):
        object_id = self.asset_id if object_kind == "asset" else self.task_id
        return ProviderDeletionObservation(
            logical_job_id=self.job,
            object_kind=object_kind,
            object_id_hash=_sha(object_id),
            observed_state=state,
            source_kind="provider_api",
            authority_ref_sha256=_sha(authority),
            observed_at_epoch=epoch,
        )

    def _decision(self, chosen_receipt, *, object_kind="asset", epoch=1_700_100_200, decided=1_700_100_300):
        return EqualEpochConflictDecision(
            logical_job_id=self.job,
            object_kind=object_kind,
            observed_at_epoch=epoch,
            chosen_observation_receipt_sha256=chosen_receipt,
            decision_authority_ref_sha256=_sha("operator-ticket-private"),
            rationale_ref_sha256=_sha("review-rationale-private"),
            decided_at_epoch=decided,
        )

    def _establish_asset_conflict(self, first="present", second="unknown"):
        first_observation = self._observation(first, authority="authority-a")
        second_observation = self._observation(second, authority="authority-b")
        self.reconciler.apply(first_observation)
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT"):
            self.reconciler.apply(second_observation)
        return first_observation, second_observation

    def test_no_decision_preserves_fail_closed_pending_behavior(self):
        self._establish_asset_conflict()
        snapshot = self.reconciler.snapshot(self.job)
        self.assertTrue(snapshot["reconciliation_required"])
        self.assertEqual(snapshot["pending_observation_count"], 1)
        self.assertEqual(snapshot["equal_epoch_conflict_resolution_count"], 0)

    def test_decision_can_choose_pending_conflicting_observation(self):
        _, pending = self._establish_asset_conflict()
        result = self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(pending.receipt_sha256)
        )
        self.assertEqual(result["resume_state"], "PASS")
        self.assertEqual(result["remaining_pending_count"], 0)
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_unknown",
        )

    def test_decision_can_keep_already_applied_observation_and_retire_loser(self):
        applied, _ = self._establish_asset_conflict()
        result = self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(applied.receipt_sha256)
        )
        self.assertEqual(result["remaining_pending_count"], 0)
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_present",
        )
        self.assertFalse(self.reconciler.snapshot(self.job)["reconciliation_required"])

    def test_decision_is_immutable_after_first_durable_record(self):
        applied, pending = self._establish_asset_conflict()
        self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(applied.receipt_sha256)
        )
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_IMMUTABLE",
        ):
            self.reconciler.conflict_decisions.record(self._decision(pending.receipt_sha256))

    def test_unknown_chosen_receipt_is_rejected(self):
        self._establish_asset_conflict()
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_CHOSEN_RECEIPT_NOT_FOUND",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(self._decision("0" * 64))

    def test_equivalent_equal_epoch_rows_are_not_adjudicatable_conflict(self):
        first = self._observation("present", authority="authority-a")
        second = self._observation("present", authority="authority-b")
        self.reconciler.apply(first)
        self.reconciler.apply(second)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_NOT_ESTABLISHED",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(
                self._decision(first.receipt_sha256)
            )

    def test_future_decision_epoch_is_rejected(self):
        applied, _ = self._establish_asset_conflict()
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_FROM_FUTURE",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(
                self._decision(applied.receipt_sha256, decided=1_700_102_000)
            )

    def test_decision_cannot_predate_conflicting_observation(self):
        applied, _ = self._establish_asset_conflict()
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_PRECEDES_OBSERVATION",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(
                self._decision(applied.receipt_sha256, decided=1_700_100_199)
            )

    def test_restart_resumes_pending_using_durable_decision_sidecar(self):
        _, pending = self._establish_asset_conflict()
        decision = self._decision(pending.receipt_sha256)
        self.reconciler.conflict_decisions.record(decision)

        restarted = self._make_reconciler()
        result = restarted.resume_pending(self.job)
        self.assertEqual(result["state"], "PASS")
        self.assertEqual(result["remaining_pending_count"], 0)
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_unknown",
        )

    def test_late_same_epoch_loser_is_ignored_after_resolution(self):
        applied, _ = self._establish_asset_conflict()
        self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(applied.receipt_sha256)
        )
        late_loser = self._observation("unknown", authority="authority-c")
        result = self.reconciler.apply(late_loser)
        self.assertEqual(result["ordering_decision"], "CONFLICT_RESOLUTION_IGNORED")
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "reconciled_present",
        )

    def test_late_same_epoch_equivalent_observation_is_accepted(self):
        applied, _ = self._establish_asset_conflict()
        self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(applied.receipt_sha256)
        )
        equivalent = self._observation("present", authority="authority-c")
        result = self.reconciler.apply(equivalent)
        self.assertEqual(result["ordering_decision"], "RESOLUTION_EQUIVALENT_APPLIED")
        self.assertEqual(
            result["conflict_decision_receipt_sha256"],
            self._decision(applied.receipt_sha256).decision_receipt_sha256,
        )

    def test_terminal_erasure_cannot_be_downgraded_by_operator_decision(self):
        terminal = self._observation("confirmed", authority="authority-a")
        nonterminal = self._observation("present", authority="authority-b")
        self.reconciler.apply(terminal)
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT"):
            self.reconciler.apply(nonterminal)
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_TERMINAL_DOWNGRADE",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(
                self._decision(nonterminal.receipt_sha256)
            )
        self.assertEqual(
            self.service.snapshot(self.job)["providerAssetDeleteState"],
            "confirmed",
        )

    def test_newer_applied_watermark_makes_older_conflict_decision_stale(self):
        applied, _ = self._establish_asset_conflict()
        self.reconciler.apply(
            self._observation("unknown", epoch=1_700_100_300, authority="authority-new")
        )
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_DECISION_STALE",
        ):
            self.reconciler.record_equal_epoch_conflict_resolution(
                self._decision(applied.receipt_sha256)
            )

    def test_corrupt_decision_sidecar_fails_closed(self):
        self.decision_path.parent.mkdir(parents=True, exist_ok=True)
        self.decision_path.write_text("{not-json", encoding="utf-8")
        with self.assertRaisesRegex(
            PrivacyRetentionError,
            "SEP_PRIVACY_RECONCILE_CONFLICT_STORE_CORRUPT",
        ):
            self.reconciler.conflict_decisions.decisions_for(self.job)

    def test_public_decision_sidecar_contains_hash_refs_not_private_text(self):
        applied, _ = self._establish_asset_conflict()
        self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(applied.receipt_sha256)
        )
        text = self.decision_path.read_text(encoding="utf-8")
        self.assertNotIn("operator-ticket-private", text)
        self.assertNotIn("review-rationale-private", text)
        self.assertIn(_sha("operator-ticket-private"), text)
        self.assertIn(_sha("review-rationale-private"), text)

    def test_asset_and_task_conflicts_are_scoped_independently(self):
        asset_applied, _ = self._establish_asset_conflict()
        task_first = self._observation("present", object_kind="task", authority="task-a")
        task_second = self._observation("unknown", object_kind="task", authority="task-b")
        self.reconciler.apply(task_first)
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_RECONCILE_EQUAL_EPOCH_CONFLICT"):
            self.reconciler.apply(task_second)

        self.reconciler.record_equal_epoch_conflict_resolution(
            self._decision(asset_applied.receipt_sha256)
        )
        snapshot = self.reconciler.snapshot(self.job)
        self.assertEqual(snapshot["equal_epoch_conflict_resolution_count"], 1)
        self.assertTrue(snapshot["reconciliation_required"])
        self.assertEqual(snapshot["pending_observation_count"], 1)


if __name__ == "__main__":
    unittest.main()
