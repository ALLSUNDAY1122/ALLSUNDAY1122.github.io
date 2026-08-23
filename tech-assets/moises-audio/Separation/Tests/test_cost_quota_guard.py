import json
import tempfile
import unittest
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from cost_quota_guard import CostGuardError, CostQuotaGuard, PricingPolicy, classify_provider_limit

JOB1 = "a" * 32
JOB2 = "b" * 32
JOB3 = "c" * 32
FP1 = "1" * 64
FP2 = "2" * 64


class ProviderError(RuntimeError):
    def __init__(self, code, status=None):
        self.code = code
        self.status = status
        super().__init__(code)


class CostQuotaGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ledger = Path(self.tmp.name) / "cost" / "ledger.json"
        self.policy = PricingPolicy(
            currency="USD",
            per_target_minute_cost="0.10",
            per_job_ceiling="3.00",
            daily_budget="5.00",
            monthly_budget="12.00",
            billing_increment_seconds=60,
            minimum_billable_seconds=60,
            budget_timezone="Asia/Tokyo",
        )
        self.guard = CostQuotaGuard(policy=self.policy, ledger_path=self.ledger)
        self.now = datetime(2026, 8, 23, 12, 0, tzinfo=timezone.utc)

    def tearDown(self):
        self.tmp.cleanup()

    def reserve(self, job=JOB1, fp=FP1, duration=121, targets=4, now=None):
        return self.guard.reserve(
            logical_job_id=job,
            request_fingerprint=fp,
            duration_seconds=duration,
            target_count=targets,
            now=now or self.now,
        )

    def test_estimate_duration_times_targets_with_rounding(self):
        record = self.reserve()
        self.assertEqual(record.estimated_cost, "1.200000")

    def test_per_job_ceiling_blocks_before_write(self):
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_PER_JOB_CEILING_EXCEEDED"):
            self.reserve(duration=1000, targets=4)
        self.assertFalse(self.ledger.exists())

    def test_daily_budget_counts_active_reservations(self):
        self.reserve(JOB1, FP1, duration=600, targets=2)
        self.reserve(JOB2, FP2, duration=600, targets=2)
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_DAILY_BUDGET_EXCEEDED"):
            self.reserve(JOB3, "3" * 64, duration=600, targets=2)

    def test_monthly_budget_accumulates_across_days(self):
        policy = PricingPolicy("USD", "0.10", "3", "3", "4", budget_timezone="UTC")
        guard = CostQuotaGuard(policy=policy, ledger_path=self.ledger)
        guard.reserve(logical_job_id=JOB1, request_fingerprint=FP1, duration_seconds=600, target_count=2,
                      now=datetime(2026, 8, 1, tzinfo=timezone.utc))
        guard.reserve(logical_job_id=JOB2, request_fingerprint=FP2, duration_seconds=600, target_count=2,
                      now=datetime(2026, 8, 2, tzinfo=timezone.utc))
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_MONTHLY_BUDGET_EXCEEDED"):
            guard.reserve(logical_job_id=JOB3, request_fingerprint="3" * 64, duration_seconds=60, target_count=1,
                          now=datetime(2026, 8, 3, tzinfo=timezone.utc))

    def test_same_logical_job_is_idempotent_and_not_double_reserved(self):
        first = self.reserve()
        second = self.reserve()
        self.assertEqual(first.estimated_cost, second.estimated_cost)
        raw = json.loads(self.ledger.read_text())
        self.assertEqual(len(raw["records"]), 1)

    def test_same_job_different_fingerprint_fails_closed(self):
        self.reserve()
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_IDEMPOTENCY_CONFLICT"):
            self.reserve(fp=FP2)

    def test_provider_create_authorization_is_exactly_once(self):
        self.reserve()
        first = self.guard.authorize_provider_create(JOB1)
        self.assertEqual(first.provider_create_state, "in_flight")
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_DUPLICATE_PROVIDER_CREATE_BLOCKED"):
            self.guard.authorize_provider_create(JOB1)

    def test_ambiguous_create_holds_budget_and_blocks_release(self):
        self.reserve()
        self.guard.authorize_provider_create(JOB1)
        record = self.guard.mark_create_ambiguous(JOB1, ProviderError("AUDIOSHAKE_HTTP_429", 429))
        self.assertEqual(record.provider_create_state, "ambiguous")
        self.assertEqual(record.stable_limit_code, "SEP_PROVIDER_RATE_LIMITED")
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_RELEASE_AFTER_CREATE_FORBIDDEN"):
            self.guard.release_before_provider_create(JOB1, reason_code="unsafe_release")

    def test_confirmed_task_stores_hash_not_raw_provider_id(self):
        self.reserve()
        self.guard.authorize_provider_create(JOB1)
        self.guard.confirm_provider_task(JOB1, "provider-secret-task-id")
        text = self.ledger.read_text()
        self.assertNotIn("provider-secret-task-id", text)
        self.assertIn("provider_task_id_hash", text)

    def test_confirm_recovery_from_ambiguous_is_allowed(self):
        self.reserve()
        self.guard.authorize_provider_create(JOB1)
        self.guard.mark_create_ambiguous(JOB1, "NETWORK_TIMEOUT")
        record = self.guard.confirm_provider_task(JOB1, "task-recovered")
        self.assertEqual(record.provider_create_state, "confirmed")

    def test_conflicting_provider_task_is_billing_incident(self):
        self.reserve()
        self.guard.authorize_provider_create(JOB1)
        self.guard.confirm_provider_task(JOB1, "task-1")
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_PROVIDER_TASK_CONFLICT"):
            self.guard.confirm_provider_task(JOB1, "task-2")
        self.assertEqual(self.guard.get(JOB1).provider_create_state, "billing_incident")

    def test_precreate_release_frees_daily_budget(self):
        self.reserve(JOB1, FP1, duration=600, targets=2)
        self.guard.release_before_provider_create(JOB1, reason_code="upload_failed")
        self.reserve(JOB2, FP2, duration=900, targets=2)
        self.assertEqual(self.guard.get(JOB1).accounting_state, "released")

    def test_precreate_release_can_be_safely_reactivated_same_job(self):
        self.reserve()
        self.guard.release_before_provider_create(JOB1, reason_code="upload_failed")
        again = self.reserve()
        self.assertEqual(again.accounting_state, "reserved")
        self.assertEqual(again.provider_create_state, "not_attempted")
        self.assertEqual(again.reconciliation_note, "reactivated_after_precreate_release")

    def test_actual_cost_reconciliation_replaces_reservation(self):
        self.reserve()
        record = self.guard.reconcile_actual(JOB1, actual_cost="0.85")
        self.assertEqual(record.accounting_state, "actual_reconciled")
        self.assertEqual(record.actual_cost, "0.850000")
        self.assertEqual(record.reserved_cost, "0.000000")

    def test_actual_cost_persists_after_relaunch(self):
        self.reserve()
        self.guard.reconcile_actual(JOB1, actual_cost=Decimal("0.91"))
        restarted = CostQuotaGuard(policy=self.policy, ledger_path=self.ledger)
        self.assertEqual(restarted.get(JOB1).actual_cost, "0.910000")

    def test_actual_over_ceiling_is_recorded_as_incident(self):
        self.reserve()
        record = self.guard.reconcile_actual(JOB1, actual_cost="4.50")
        self.assertEqual(record.stable_limit_code, "SEP_COST_ACTUAL_JOB_CEILING_OVERRUN")

    def test_actual_after_release_is_rejected(self):
        self.reserve()
        self.guard.release_before_provider_create(JOB1, reason_code="safe")
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_ACTUAL_AFTER_RELEASE_INVALID"):
            self.guard.reconcile_actual(JOB1, actual_cost="0.10")

    def test_actual_cost_daily_budget_overrun_is_recorded(self):
        policy=PricingPolicy("USD","0.05","2.00","0.30","5.00",budget_timezone="UTC")
        guard=CostQuotaGuard(policy=policy,ledger_path=self.ledger)
        first=guard.reserve(logical_job_id="1"*32,request_fingerprint="1"*64,duration_seconds=60,target_count=1,now=self.now)
        guard.reconcile_actual(first.logical_job_id,actual_cost="0.15")
        second=guard.reserve(logical_job_id="2"*32,request_fingerprint="2"*64,duration_seconds=60,target_count=1,now=self.now)
        reconciled=guard.reconcile_actual(second.logical_job_id,actual_cost="0.20")
        self.assertEqual(reconciled.stable_limit_code,"SEP_COST_ACTUAL_DAILY_BUDGET_OVERRUN")

    def test_actual_cost_monthly_budget_overrun_is_recorded(self):
        policy=PricingPolicy("USD","0.10","3.00","2.00","2.00",budget_timezone="UTC")
        guard=CostQuotaGuard(policy=policy,ledger_path=self.ledger)
        first=guard.reserve(logical_job_id="3"*32,request_fingerprint="3"*64,duration_seconds=60,target_count=1,now=datetime(2026,8,1,tzinfo=timezone.utc))
        guard.reconcile_actual(first.logical_job_id,actual_cost="1.10")
        second=guard.reserve(logical_job_id="4"*32,request_fingerprint="4"*64,duration_seconds=60,target_count=1,now=datetime(2026,8,2,tzinfo=timezone.utc))
        reconciled=guard.reconcile_actual(second.logical_job_id,actual_cost="1.10")
        self.assertEqual(reconciled.stable_limit_code,"SEP_COST_ACTUAL_MONTHLY_BUDGET_OVERRUN")

    def test_ledger_corruption_fails_closed(self):
        self.ledger.parent.mkdir(parents=True, exist_ok=True)
        self.ledger.write_text("{bad json", encoding="utf-8")
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_LEDGER_CORRUPT"):
            self.reserve()

    def test_rate_limit_semantics_never_allow_automatic_create_retry(self):
        semantics = classify_provider_limit(ProviderError("AUDIOSHAKE_HTTP_429", 429))
        self.assertEqual(semantics.kind, "rate_limited")
        self.assertTrue(semantics.retryable_non_create_operation)
        self.assertFalse(semantics.automatic_provider_create_retry_allowed)

    def test_credit_exhausted_semantics_are_nonretryable(self):
        semantics = classify_provider_limit("AUDIOSHAKE_CREDIT_EXHAUSTED")
        self.assertEqual(semantics.stable_error_code, "SEP_PROVIDER_CREDIT_EXHAUSTED")
        self.assertFalse(semantics.retryable_non_create_operation)

    def test_quota_exhausted_semantics_are_nonretryable(self):
        semantics = classify_provider_limit("PROVIDER_QUOTA_EXCEEDED")
        self.assertEqual(semantics.stable_error_code, "SEP_PROVIDER_QUOTA_EXHAUSTED")
        self.assertFalse(semantics.retryable_non_create_operation)

    def test_402_is_billing_rejected(self):
        semantics = classify_provider_limit(ProviderError("HTTP_402", 402))
        self.assertEqual(semantics.stable_error_code, "SEP_PROVIDER_BILLING_REJECTED")

    def test_privacy_safe_evidence_contains_no_raw_logical_job_id(self):
        self.reserve()
        evidence = self.guard.privacy_safe_evidence(JOB1)
        self.assertNotIn(JOB1, json.dumps(evidence))
        self.assertEqual(evidence["parity_state"], "NON_PARITY_EVIDENCE_ONLY")

    def test_jst_budget_day_uses_policy_timezone(self):
        instant = datetime(2026, 8, 23, 16, 30, tzinfo=timezone.utc)
        record = self.reserve(now=instant)
        self.assertEqual(record.budget_day, "2026-08-24")

    def test_naive_datetime_is_rejected(self):
        with self.assertRaisesRegex(CostGuardError, "SEP_COST_NOW_NAIVE"):
            self.reserve(now=datetime(2026, 8, 23, 12, 0))

    def test_invalid_duration_and_target_count_fail_closed(self):
        with self.assertRaises(CostGuardError):
            self.reserve(duration=0)
        with self.assertRaises(CostGuardError):
            self.reserve(targets=0)


if __name__ == "__main__":
    unittest.main()
