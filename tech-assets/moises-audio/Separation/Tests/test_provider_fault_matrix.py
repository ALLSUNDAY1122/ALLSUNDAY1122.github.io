import errno
import json
import socket
import ssl
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "Server"))

from provider_fault_matrix import (
    FaultNormalizedProviderAdapter,
    ProviderFaultError,
    classify_fault,
    classify_process_crash,
    machine_fault_matrix,
)


class CodedError(RuntimeError):
    def __init__(self, code, *, status=None, retryable=False):
        self.code = code
        self.status = status
        self.retryable = retryable
        super().__init__(code)


class StubProvider:
    def __init__(self):
        self.failure = None
        self.calls = []

    def _result(self, name, value):
        self.calls.append(name)
        if self.failure is not None:
            raise self.failure
        return value

    def upload_asset(self, path):
        return self._result("upload", "asset-1")

    def create_separation_task(self, asset_id, models, *, metadata=None):
        return self._result("create", "task-1")

    def get_task_state(self, task_id):
        return self._result("poll", {"phase": "separating"})

    def find_tasks_by_metadata(self, metadata, **kwargs):
        return self._result("recover", ("task-1",))

    def cancel_task(self, task_id):
        return self._result("cancel", "confirmed")

    def delete_asset(self, asset_id):
        return self._result("delete_asset", "confirmed")

    def delete_task(self, task_id):
        return self._result("delete_task", "confirmed")


class ProviderFaultMatrixTests(unittest.TestCase):
    def disposition(self, error, operation="poll", attempted=True):
        return classify_fault(
            error,
            operation=operation,
            provider_create_attempted=attempted,
        )

    def test_credential_missing_is_nonretryable(self):
        item = self.disposition("AUDIOSHAKE_API_KEY_MISSING", "auth", False)
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_AUTH_MISSING")
        self.assertFalse(item.operation_retryable)

    def test_http_401_is_auth_invalid(self):
        item = self.disposition(CodedError("x", status=401), "auth", False)
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_AUTH_INVALID")
        self.assertFalse(item.operation_retryable)

    def test_http_403_is_forbidden(self):
        item = self.disposition("AUDIOSHAKE_HTTP_403", "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_FORBIDDEN")

    def test_http_404_job_is_not_recreated(self):
        item = self.disposition("AUDIOSHAKE_HTTP_404", "poll")
        self.assertEqual(item.action, "reconcile_not_recreate")
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_http_409_conflict_reconciles(self):
        item = self.disposition("AUDIOSHAKE_HTTP_409", "create")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_CONFLICT")
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_http_413_source_too_large(self):
        item = self.disposition("AUDIOSHAKE_HTTP_413", "upload", False)
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_SOURCE_TOO_LARGE")
        self.assertFalse(item.operation_retryable)

    def test_http_429_poll_is_retryable(self):
        item = self.disposition("AUDIOSHAKE_HTTP_429", "poll")
        self.assertTrue(item.operation_retryable)
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_RATE_LIMITED")

    def test_http_429_create_never_blind_reposts(self):
        item = self.disposition("AUDIOSHAKE_HTTP_429", "create", True)
        self.assertTrue(item.operation_retryable)
        self.assertFalse(item.automatic_provider_create_retry_allowed)
        self.assertEqual(item.action, "reconcile_create_not_repost")

    def test_http_503_poll_is_retryable(self):
        item = self.disposition("AUDIOSHAKE_HTTP_503", "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_5XX")
        self.assertTrue(item.operation_retryable)

    def test_http_503_create_is_ambiguous_no_repost(self):
        item = self.disposition("AUDIOSHAKE_HTTP_503", "create", True)
        self.assertTrue(item.operation_retryable)
        self.assertFalse(item.automatic_provider_create_retry_allowed)
        self.assertEqual(item.action, "reconcile_create_not_repost")

    def test_dns_failure_retryable_safe_operation(self):
        item = self.disposition(socket.gaierror(-2, "name"), "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_DNS_FAILED")
        self.assertTrue(item.operation_retryable)

    def test_tls_failure_is_not_automatic_retry(self):
        item = self.disposition(ssl.SSLError("bad cert"), "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_TLS_FAILED")
        self.assertFalse(item.operation_retryable)

    def test_upload_timeout_before_create_can_retry_upload(self):
        item = self.disposition("AUDIOSHAKE_UPLOAD_TIMEOUT", "upload", False)
        self.assertTrue(item.operation_retryable)
        self.assertTrue(item.automatic_provider_create_retry_allowed)

    def test_socket_upload_timeout_before_create_can_retry_upload(self):
        item = self.disposition(socket.timeout("timeout"), "upload", False)
        self.assertTrue(item.operation_retryable)
        self.assertTrue(item.automatic_provider_create_retry_allowed)

    def test_create_timeout_requires_reconciliation(self):
        item = self.disposition("AUDIOSHAKE_CREATE_TIMEOUT", "create", True)
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_CREATE_AMBIGUOUS")
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_poll_timeout_is_safe_to_retry(self):
        item = self.disposition("AUDIOSHAKE_POLL_TIMEOUT", "poll")
        self.assertEqual(item.action, "retry_poll")
        self.assertTrue(item.operation_retryable)

    def test_malformed_json_poll_is_retryable_read(self):
        item = self.disposition("AUDIOSHAKE_RESPONSE_INVALID_JSON", "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_RESPONSE_INVALID_JSON")
        self.assertTrue(item.operation_retryable)

    def test_json_decode_error_create_is_not_reposted(self):
        exc = json.JSONDecodeError("bad", "{", 0)
        item = self.disposition(exc, "create", True)
        self.assertEqual(item.action, "reconcile_create_not_repost")
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_vendor_task_error_is_nonretryable_current_job(self):
        item = self.disposition("AUDIOSHAKE_TARGET_ERROR_MODEL_FAILED", "poll")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_TASK_FAILED")
        self.assertFalse(item.operation_retryable)

    def test_missing_target_fails_closed(self):
        item = self.disposition("SEP_OUTPUT_COUNT_MISMATCH", "validate")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_OUTPUT_SET_INVALID")
        self.assertFalse(item.operation_retryable)

    def test_duplicate_target_fails_closed(self):
        item = self.disposition("SEP_COMMIT_EXPECTED_SET_INVALID", "validate")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_OUTPUT_SET_INVALID")

    def test_expired_output_url_can_refresh_not_recreate(self):
        item = self.disposition("SEP_OUTPUT_URL_EXPIRING", "download")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_OUTPUT_URL_EXPIRED")
        self.assertTrue(item.operation_retryable)
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_corrupt_wav_can_redownload_but_not_recreate(self):
        item = self.disposition("SEP_OUTPUT_WAV_INVALID", "validate")
        self.assertEqual(item.stable_error_code, "SEP_PROVIDER_OUTPUT_CORRUPT")
        self.assertTrue(item.operation_retryable)
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_disk_full_from_stable_code(self):
        item = self.disposition("SEP_STORAGE_EXHAUSTED", "commit")
        self.assertEqual(item.action, "free_space_then_resume")
        self.assertTrue(item.preserve_existing_result)

    def test_disk_full_from_os_error(self):
        item = self.disposition(OSError(errno.ENOSPC, "full"), "commit")
        self.assertEqual(item.stable_error_code, "SEP_LOCAL_STORAGE_EXHAUSTED")

    def test_local_delete_failure_retryable(self):
        item = self.disposition("SEP_PRIVACY_LOCAL_DELETE_FAILED", "delete")
        self.assertEqual(item.stable_error_code, "SEP_LOCAL_DELETE_FAILED")
        self.assertTrue(item.operation_retryable)

    def test_quota_exhausted_nonretryable(self):
        item = self.disposition("SEP_PROVIDER_QUOTA_EXHAUSTED", "create")
        self.assertFalse(item.operation_retryable)

    def test_credit_exhausted_nonretryable(self):
        item = self.disposition("SEP_PROVIDER_CREDIT_EXHAUSTED", "create")
        self.assertFalse(item.operation_retryable)

    def test_duplicate_provider_tasks_is_billing_incident(self):
        item = self.disposition("SEP_COST_DUPLICATE_PROVIDER_TASKS", "recover")
        self.assertEqual(item.action, "billing_incident_manual_reconcile")
        self.assertFalse(item.operation_retryable)

    def test_unknown_retryable_error_still_never_authorizes_create(self):
        item = self.disposition(CodedError("SEP_UNKNOWN_TRANSIENT", retryable=True), "create", True)
        self.assertTrue(item.operation_retryable)
        self.assertFalse(item.automatic_provider_create_retry_allowed)

    def test_invalid_operation_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "SEP_FAULT_OPERATION_INVALID"):
            classify_fault("X", operation="magic")

    def test_all_crash_phases_are_defined(self):
        phases = (
            "intent_persisted",
            "uploading",
            "provider_create_in_flight",
            "provider_task_bound",
            "polling",
            "downloading",
            "staging_verified",
            "promotion_in_flight",
            "ledger_commit_in_flight",
            "committed",
        )
        dispositions = [classify_process_crash(phase) for phase in phases]
        self.assertEqual(len(dispositions), 10)
        self.assertTrue(all(item.operation_retryable for item in dispositions))

    def test_create_crash_never_reposts(self):
        item = classify_process_crash("provider_create_in_flight")
        self.assertFalse(item.automatic_provider_create_retry_allowed)
        self.assertEqual(item.action, "reconcile_create_not_repost")

    def test_precreate_crash_can_resume_same_logical_start(self):
        item = classify_process_crash("intent_persisted")
        self.assertTrue(item.automatic_provider_create_retry_allowed)

    def test_invalid_crash_phase_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "SEP_CRASH_PHASE_INVALID"):
            classify_process_crash("between_dimensions")

    def test_adapter_passes_successes_through(self):
        provider = StubProvider()
        adapter = FaultNormalizedProviderAdapter(provider)
        self.assertEqual(adapter.upload_asset("x"), "asset-1")
        self.assertEqual(adapter.create_separation_task("asset-1", ["vocals"]), "task-1")
        self.assertEqual(adapter.get_task_state("task-1")["phase"], "separating")

    def test_adapter_normalizes_create_429(self):
        provider = StubProvider()
        provider.failure = CodedError("AUDIOSHAKE_HTTP_429", status=429, retryable=True)
        adapter = FaultNormalizedProviderAdapter(provider)
        with self.assertRaises(ProviderFaultError) as context:
            adapter.create_separation_task("asset-1", ["vocals"])
        error = context.exception
        self.assertEqual(error.code, "SEP_PROVIDER_RATE_LIMITED")
        self.assertTrue(error.retryable)
        self.assertFalse(error.automatic_provider_create_retry_allowed)
        self.assertEqual(error.action, "reconcile_create_not_repost")

    def test_adapter_normalizes_dns_poll(self):
        provider = StubProvider()
        provider.failure = socket.gaierror(-2, "name")
        adapter = FaultNormalizedProviderAdapter(provider)
        with self.assertRaises(ProviderFaultError) as context:
            adapter.get_task_state("task-1")
        self.assertEqual(context.exception.code, "SEP_PROVIDER_DNS_FAILED")

    def test_adapter_does_not_expose_raw_exception_message(self):
        provider = StubProvider()
        provider.failure = RuntimeError("https://signed.example/secret?token=abc")
        adapter = FaultNormalizedProviderAdapter(provider)
        with self.assertRaises(ProviderFaultError) as context:
            adapter.get_task_state("task-1")
        self.assertEqual(str(context.exception), "SEP_PROVIDER_FAULT_UNKNOWN")
        self.assertIsNone(context.exception.original_code)

    def test_machine_matrix_contains_minimum_faults_and_crashes(self):
        matrix = machine_fault_matrix()
        ids = {item["id"] for item in matrix["faults"]}
        self.assertTrue({
            "http-401",
            "http-403",
            "http-404",
            "http-409",
            "http-413",
            "http-429",
            "http-500",
            "dns",
            "tls",
            "upload-timeout",
            "poll-timeout",
            "malformed-json",
            "vendor-task-error",
            "missing-target",
            "duplicate-target",
            "expired-output-url",
            "corrupt-wav",
            "disk-full",
            "local-deletion-failure",
        }.issubset(ids))
        self.assertEqual(len(matrix["process_crashes"]), 10)
        self.assertEqual(matrix["result"], "NON_PARITY_EVIDENCE_ONLY")


if __name__ == "__main__":
    unittest.main()
