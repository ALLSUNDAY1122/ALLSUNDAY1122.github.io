"""Lane 1 provider fault normalization and recovery policy.

NON-PARITY production hardening. This module never retries provider task creation itself.
It separates whether a failed operation is retryable from whether a provider create request
may be automatically re-issued. Ambiguous create outcomes always go through A07 reconciliation.
"""
from __future__ import annotations

import errno
import json
import re
import socket
import ssl
from dataclasses import asdict, dataclass
from typing import Any

_SAFE_CODE = re.compile(r"^[A-Z0-9_.:-]{1,200}$")


@dataclass(frozen=True)
class FaultDisposition:
    category: str
    stable_error_code: str
    operation_retryable: bool
    automatic_provider_create_retry_allowed: bool
    action: str
    user_message_key: str
    preserve_existing_result: bool = True


@dataclass(frozen=True)
class CrashDisposition:
    phase: str
    stable_error_code: str
    operation_retryable: bool
    automatic_provider_create_retry_allowed: bool
    action: str


class ProviderFaultError(RuntimeError):
    def __init__(self, disposition: FaultDisposition, *, original_code: str | None = None):
        self.code = disposition.stable_error_code
        self.retryable = disposition.operation_retryable
        self.category = disposition.category
        self.action = disposition.action
        self.automatic_provider_create_retry_allowed = (
            disposition.automatic_provider_create_retry_allowed
        )
        self.original_code = (
            original_code
            if isinstance(original_code, str) and _SAFE_CODE.fullmatch(original_code)
            else None
        )
        super().__init__(self.code)


_HTTP = {
    400: ("provider_request_invalid", "SEP_PROVIDER_BAD_REQUEST", False, "fix_request"),
    401: ("credential_invalid", "SEP_PROVIDER_AUTH_INVALID", False, "fix_credentials"),
    402: ("billing_rejected", "SEP_PROVIDER_BILLING_REJECTED", False, "resolve_billing"),
    403: (
        "credential_or_entitlement_forbidden",
        "SEP_PROVIDER_FORBIDDEN",
        False,
        "fix_credentials_or_entitlement",
    ),
    404: (
        "provider_job_missing",
        "SEP_PROVIDER_JOB_NOT_FOUND",
        False,
        "reconcile_not_recreate",
    ),
    409: (
        "provider_conflict",
        "SEP_PROVIDER_CONFLICT",
        False,
        "reconcile_conflict_not_recreate",
    ),
    413: (
        "source_too_large",
        "SEP_PROVIDER_SOURCE_TOO_LARGE",
        False,
        "reduce_or_transcode_source",
    ),
    429: (
        "rate_limited",
        "SEP_PROVIDER_RATE_LIMITED",
        True,
        "backoff_then_retry_safe_operation",
    ),
}

_PREFIX = (
    ("AUDIOSHAKE_API_KEY_MISSING", ("credential_invalid", "SEP_PROVIDER_AUTH_MISSING", False, "fix_credentials")),
    ("AUDIOSHAKE_API_KEY_INVALID", ("credential_invalid", "SEP_PROVIDER_AUTH_INVALID", False, "fix_credentials")),
    ("AUDIOSHAKE_DNS_FAILED", ("dns_failure", "SEP_PROVIDER_DNS_FAILED", True, "backoff_then_retry_safe_operation")),
    ("AUDIOSHAKE_TLS_FAILED", ("tls_failure", "SEP_PROVIDER_TLS_FAILED", False, "fix_tls_or_endpoint")),
    ("AUDIOSHAKE_UPLOAD_TIMEOUT", ("upload_timeout", "SEP_PROVIDER_UPLOAD_TIMEOUT", True, "retry_upload_without_task_create")),
    ("AUDIOSHAKE_CREATE_TIMEOUT", ("create_ambiguous", "SEP_PROVIDER_CREATE_AMBIGUOUS", True, "reconcile_create_not_repost")),
    ("AUDIOSHAKE_POLL_TIMEOUT", ("poll_timeout", "SEP_PROVIDER_POLL_TIMEOUT", True, "retry_poll")),
    ("AUDIOSHAKE_DOWNLOAD_TIMEOUT", ("download_timeout", "SEP_PROVIDER_DOWNLOAD_TIMEOUT", True, "retry_download")),
    ("AUDIOSHAKE_NETWORK_FAILED", ("network_failure", "SEP_PROVIDER_NETWORK_FAILED", True, "backoff_then_retry_safe_operation")),
    ("AUDIOSHAKE_RESPONSE_INVALID_JSON", ("malformed_provider_response", "SEP_PROVIDER_RESPONSE_INVALID_JSON", True, "retry_safe_read_operation")),
    ("AUDIOSHAKE_RESPONSE_INVALID_SHAPE", ("malformed_provider_response", "SEP_PROVIDER_RESPONSE_INVALID_SHAPE", True, "retry_safe_read_operation")),
    ("AUDIOSHAKE_TASK_STATE_INVALID", ("malformed_provider_response", "SEP_PROVIDER_TASK_STATE_INVALID", True, "retry_poll")),
    ("AUDIOSHAKE_TARGET_STATE_INVALID", ("malformed_provider_response", "SEP_PROVIDER_TARGET_STATE_INVALID", True, "retry_poll")),
    ("AUDIOSHAKE_COMPLETED_WITHOUT_OUTPUT", ("missing_target_output", "SEP_PROVIDER_TARGET_OUTPUT_MISSING", False, "discard_provider_result")),
    ("AUDIOSHAKE_WAV_OUTPUT_MISSING", ("missing_target_output", "SEP_PROVIDER_WAV_OUTPUT_MISSING", False, "discard_provider_result")),
    ("AUDIOSHAKE_TARGET_ERROR_", ("vendor_task_error", "SEP_PROVIDER_TASK_FAILED", False, "surface_failure_allow_explicit_new_job")),
    ("SEP_PROVIDER_RATE_LIMITED", ("rate_limited", "SEP_PROVIDER_RATE_LIMITED", True, "backoff_then_retry_safe_operation")),
    ("SEP_PROVIDER_QUOTA_EXHAUSTED", ("quota_exhausted", "SEP_PROVIDER_QUOTA_EXHAUSTED", False, "wait_or_upgrade_quota")),
    ("SEP_PROVIDER_CREDIT_EXHAUSTED", ("credit_exhausted", "SEP_PROVIDER_CREDIT_EXHAUSTED", False, "add_credit_or_change_provider")),
    ("SEP_PROVIDER_BILLING_REJECTED", ("billing_rejected", "SEP_PROVIDER_BILLING_REJECTED", False, "resolve_billing")),
    ("SEP_PROVIDER_DUPLICATE_TASKS_DETECTED", ("duplicate_provider_tasks", "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED", False, "billing_incident_manual_reconcile")),
    ("SEP_COST_DUPLICATE_PROVIDER_TASKS", ("duplicate_provider_tasks", "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED", False, "billing_incident_manual_reconcile")),
    ("SEP_OUTPUT_URL_EXPIRING", ("expired_output_url", "SEP_PROVIDER_OUTPUT_URL_EXPIRED", True, "refresh_output_url_or_use_verified_local_copy")),
    ("SEP_OUTPUT_URL_EXPIRED", ("expired_output_url", "SEP_PROVIDER_OUTPUT_URL_EXPIRED", True, "refresh_output_url_or_use_verified_local_copy")),
    ("SEP_OUTPUT_COUNT_MISMATCH", ("missing_or_duplicate_target", "SEP_PROVIDER_OUTPUT_SET_INVALID", False, "discard_provider_result")),
    ("SEP_OUTPUT_ROLE_SET_MISMATCH", ("missing_or_duplicate_target", "SEP_PROVIDER_OUTPUT_SET_INVALID", False, "discard_provider_result")),
    ("SEP_COMMIT_EXPECTED_SET_INVALID", ("duplicate_or_invalid_target", "SEP_PROVIDER_OUTPUT_SET_INVALID", False, "discard_provider_result")),
    ("SEP_OUTPUT_WAV_", ("corrupt_audio", "SEP_PROVIDER_OUTPUT_CORRUPT", True, "redownload_output_then_fail_closed")),
    ("SEP_OUTPUT_RIFF_", ("corrupt_audio", "SEP_PROVIDER_OUTPUT_CORRUPT", True, "redownload_output_then_fail_closed")),
    ("SEP_OUTPUT_EXTENSION_CONTAINER_MISMATCH", ("corrupt_audio", "SEP_PROVIDER_OUTPUT_CORRUPT", True, "redownload_output_then_fail_closed")),
    ("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", ("disk_full", "SEP_LOCAL_STORAGE_INSUFFICIENT", True, "free_space_then_resume")),
    ("SEP_STORAGE_EXHAUSTED", ("disk_full", "SEP_LOCAL_STORAGE_EXHAUSTED", True, "free_space_then_resume")),
    ("SEP_PRIVACY_LOCAL_DELETE_FAILED", ("local_delete_failure", "SEP_LOCAL_DELETE_FAILED", True, "retry_local_delete")),
    ("SEP_PRIVACY_LOCAL_DELETE_UNCONFIRMED", ("local_delete_failure", "SEP_LOCAL_DELETE_UNCONFIRMED", True, "retry_local_delete")),
)

_CRASH_PHASES = {
    "intent_persisted": ("SEP_CRASH_AFTER_INTENT", True, True, "resume_same_logical_start"),
    "uploading": ("SEP_CRASH_DURING_UPLOAD", True, True, "resume_or_retry_upload_before_task_create"),
    "provider_create_in_flight": ("SEP_CRASH_DURING_PROVIDER_CREATE", True, False, "reconcile_create_not_repost"),
    "provider_task_bound": ("SEP_CRASH_AFTER_PROVIDER_BIND", True, False, "recover_registry_then_poll"),
    "polling": ("SEP_CRASH_DURING_POLL", True, False, "recover_registry_then_poll"),
    "downloading": ("SEP_CRASH_DURING_DOWNLOAD", True, False, "recover_then_redownload_missing_output"),
    "staging_verified": ("SEP_CRASH_AFTER_STAGING_VERIFIED", True, False, "commit_verified_local_set"),
    "promotion_in_flight": ("SEP_CRASH_DURING_PROMOTION", True, False, "run_atomic_commit_recovery"),
    "ledger_commit_in_flight": ("SEP_CRASH_DURING_LEDGER_COMMIT", True, False, "verify_final_then_finish_ledger_commit"),
    "committed": ("SEP_CRASH_AFTER_COMMIT", True, False, "verify_committed_result_then_resume"),
}


def _safe_code(error: Any) -> str:
    code = error if isinstance(error, str) else getattr(error, "code", None)
    return code if isinstance(code, str) and _SAFE_CODE.fullmatch(code) else ""


def _http_status(error: Any) -> int | None:
    value = getattr(error, "status", None)
    if isinstance(value, int):
        return value
    match = re.search(r"(?:HTTP_|HTTP:)(\d{3})(?:$|[^0-9])", _safe_code(error))
    return int(match.group(1)) if match else None


def _create_allowed(operation: str, attempted: bool, candidate: bool) -> bool:
    return bool(candidate and operation != "create" and not attempted)


def classify_fault(
    error: Any,
    *,
    operation: str,
    provider_create_attempted: bool = False,
) -> FaultDisposition:
    if operation not in {"auth", "upload", "create", "poll", "download", "validate", "commit", "delete", "recover"}:
        raise ValueError("SEP_FAULT_OPERATION_INVALID")

    code = _safe_code(error)
    status = _http_status(error)
    if status is not None:
        if status >= 500:
            category, stable, retryable, action = (
                "provider_5xx",
                "SEP_PROVIDER_5XX",
                True,
                "backoff_then_retry_safe_operation",
            )
        elif status in _HTTP:
            category, stable, retryable, action = _HTTP[status]
        else:
            category, stable, retryable, action = (
                "provider_http_error",
                "SEP_PROVIDER_HTTP_ERROR",
                False,
                "inspect_provider_response",
            )
        if operation == "create" and retryable:
            action = "reconcile_create_not_repost"
        return FaultDisposition(
            category,
            stable,
            retryable,
            _create_allowed(operation, provider_create_attempted, operation in {"auth", "upload"}),
            action,
            stable.lower(),
        )

    for prefix, values in _PREFIX:
        if code == prefix or (prefix.endswith("_") and code.startswith(prefix)):
            category, stable, retryable, action = values
            if operation == "create" and retryable:
                action = "reconcile_create_not_repost"
            create_candidate = operation in {"auth", "upload"} and category not in {
                "credential_invalid",
                "quota_exhausted",
                "credit_exhausted",
                "billing_rejected",
            }
            return FaultDisposition(
                category,
                stable,
                retryable,
                _create_allowed(operation, provider_create_attempted, create_candidate),
                action,
                stable.lower(),
            )

    if isinstance(error, (socket.timeout, TimeoutError)):
        stable = f"SEP_PROVIDER_{operation.upper()}_TIMEOUT"
        return FaultDisposition(
            f"{operation}_timeout",
            stable,
            True,
            _create_allowed(operation, provider_create_attempted, operation == "upload"),
            "reconcile_create_not_repost" if operation == "create" else "retry_safe_operation",
            stable.lower(),
        )
    if isinstance(error, socket.gaierror):
        return FaultDisposition(
            "dns_failure",
            "SEP_PROVIDER_DNS_FAILED",
            True,
            _create_allowed(operation, provider_create_attempted, operation in {"auth", "upload"}),
            "reconcile_create_not_repost" if operation == "create" else "backoff_then_retry_safe_operation",
            "sep_provider_dns_failed",
        )
    if isinstance(error, (ssl.SSLError, ssl.CertificateError)):
        return FaultDisposition(
            "tls_failure",
            "SEP_PROVIDER_TLS_FAILED",
            False,
            False,
            "fix_tls_or_endpoint",
            "sep_provider_tls_failed",
        )
    if isinstance(error, json.JSONDecodeError):
        return FaultDisposition(
            "malformed_provider_response",
            "SEP_PROVIDER_RESPONSE_INVALID_JSON",
            True,
            False,
            "reconcile_create_not_repost" if operation == "create" else "retry_safe_read_operation",
            "sep_provider_response_invalid_json",
        )
    if isinstance(error, OSError) and getattr(error, "errno", None) in {
        errno.ENOSPC,
        getattr(errno, "EDQUOT", 122),
    }:
        return FaultDisposition(
            "disk_full",
            "SEP_LOCAL_STORAGE_EXHAUSTED",
            True,
            False,
            "free_space_then_resume",
            "sep_local_storage_exhausted",
        )

    retryable = bool(getattr(error, "retryable", False))
    stable = code or "SEP_PROVIDER_FAULT_UNKNOWN"
    return FaultDisposition(
        "unclassified_provider_fault",
        stable,
        retryable,
        False,
        "reconcile_create_not_repost"
        if operation == "create"
        else ("retry_safe_operation" if retryable else "fail_closed_inspect"),
        stable.lower(),
    )


def classify_process_crash(phase: str) -> CrashDisposition:
    try:
        stable, retryable, create_allowed, action = _CRASH_PHASES[phase]
    except KeyError as exc:
        raise ValueError("SEP_CRASH_PHASE_INVALID") from exc
    return CrashDisposition(phase, stable, retryable, create_allowed, action)


class FaultNormalizedProviderAdapter:
    """Translate raw provider/transport failures into Lane 1 stable semantics without retrying."""

    def __init__(self, provider: Any):
        self.provider = provider

    def _call(
        self,
        operation: str,
        fn: Any,
        *args: Any,
        provider_create_attempted: bool = False,
        **kwargs: Any,
    ) -> Any:
        try:
            return fn(*args, **kwargs)
        except ProviderFaultError:
            raise
        except Exception as exc:
            disposition = classify_fault(
                exc,
                operation=operation,
                provider_create_attempted=provider_create_attempted,
            )
            raise ProviderFaultError(disposition, original_code=_safe_code(exc)) from exc

    def upload_asset(self, source_path: Any) -> Any:
        return self._call("upload", self.provider.upload_asset, source_path)

    def create_separation_task(
        self,
        asset_id: str,
        models: Any,
        *,
        metadata: dict[str, Any] | None = None,
    ) -> Any:
        return self._call(
            "create",
            self.provider.create_separation_task,
            asset_id,
            models,
            metadata=metadata,
            provider_create_attempted=True,
        )

    def get_task_state(self, task_id: str) -> Any:
        return self._call(
            "poll",
            self.provider.get_task_state,
            task_id,
            provider_create_attempted=True,
        )

    def find_tasks_by_metadata(self, metadata: dict[str, Any], **kwargs: Any) -> Any:
        return self._call(
            "recover",
            getattr(self.provider, "find_tasks_by_metadata"),
            metadata,
            provider_create_attempted=True,
            **kwargs,
        )

    def cancel_task(self, task_id: str) -> Any:
        return self._call(
            "recover",
            getattr(self.provider, "cancel_task"),
            task_id,
            provider_create_attempted=True,
        )

    def delete_asset(self, asset_id: str) -> Any:
        return self._call(
            "delete",
            getattr(self.provider, "delete_asset"),
            asset_id,
            provider_create_attempted=True,
        )

    def delete_task(self, task_id: str) -> Any:
        return self._call(
            "delete",
            getattr(self.provider, "delete_task"),
            task_id,
            provider_create_attempted=True,
        )


def machine_fault_matrix() -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for status in (401, 403, 404, 409, 413, 429, 500, 503):
        disposition = classify_fault(
            f"AUDIOSHAKE_HTTP_{status}",
            operation="create",
            provider_create_attempted=True,
        )
        rows.append({"id": f"http-{status}", **asdict(disposition)})
    explicit = (
        ("credential-missing", "AUDIOSHAKE_API_KEY_MISSING", "auth", False),
        ("dns", "AUDIOSHAKE_DNS_FAILED", "poll", True),
        ("tls", "AUDIOSHAKE_TLS_FAILED", "poll", True),
        ("upload-timeout", "AUDIOSHAKE_UPLOAD_TIMEOUT", "upload", False),
        ("poll-timeout", "AUDIOSHAKE_POLL_TIMEOUT", "poll", True),
        ("malformed-json", "AUDIOSHAKE_RESPONSE_INVALID_JSON", "poll", True),
        ("vendor-task-error", "AUDIOSHAKE_TARGET_ERROR_UNKNOWN", "poll", True),
        ("missing-target", "SEP_OUTPUT_COUNT_MISMATCH", "validate", True),
        ("duplicate-target", "SEP_COMMIT_EXPECTED_SET_INVALID", "validate", True),
        ("expired-output-url", "SEP_OUTPUT_URL_EXPIRING", "download", True),
        ("corrupt-wav", "SEP_OUTPUT_WAV_INVALID", "validate", True),
        ("disk-full", "SEP_STORAGE_EXHAUSTED", "commit", True),
        ("local-deletion-failure", "SEP_PRIVACY_LOCAL_DELETE_FAILED", "delete", True),
    )
    for row_id, error, operation, attempted in explicit:
        rows.append(
            {
                "id": row_id,
                **asdict(
                    classify_fault(
                        error,
                        operation=operation,
                        provider_create_attempted=attempted,
                    )
                ),
            }
        )
    return {
        "schema_version": 1,
        "result": "NON_PARITY_EVIDENCE_ONLY",
        "faults": rows,
        "process_crashes": [asdict(classify_process_crash(phase)) for phase in _CRASH_PHASES],
    }
