"""Cost-guarded production separation entrypoint.

This adapter composes A10 cost safety with the A15 long-track production wrapper without changing
the frozen Shared/App contracts. Provider create remains guarded against duplicate billing, while
source/output storage pressure and transfer backpressure are enforced by the inner long-track layer.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Callable, Iterable

from cost_quota_guard import CostGuardError, CostQuotaGuard, classify_provider_limit
from long_track_io import LongTrackIOError, LongTrackIOGuard
from long_track_production_orchestrator import LongTrackProductionSeparationOrchestrator
from production_orchestrator import (
    OrchestratorError,
    _contained_file,
    _normalize_models,
    _request_fingerprint,
    _sha256_file,
)


class BudgetedProviderProxy:
    def __init__(self, provider: Any, cost_guard: CostQuotaGuard):
        self._provider = provider
        self._cost_guard = cost_guard

    def upload_asset(self, source_path: str | Path) -> str:
        return self._provider.upload_asset(source_path)

    def create_separation_task(
        self, asset_id: str, models: Iterable[str], *, metadata: dict[str, Any] | None = None
    ) -> str:
        if not isinstance(metadata, dict):
            raise CostGuardError("SEP_COST_PROVIDER_METADATA_REQUIRED")
        logical_job_id = metadata.get("logical_job_id")
        request_fingerprint = metadata.get("request_fingerprint")
        record = self._cost_guard.get(logical_job_id)
        if record.request_fingerprint != request_fingerprint:
            raise CostGuardError("SEP_COST_PROVIDER_METADATA_CONFLICT")
        self._cost_guard.authorize_provider_create(logical_job_id)
        try:
            task_id = self._provider.create_separation_task(asset_id, models, metadata=metadata)
        except Exception as exc:
            self._cost_guard.mark_create_ambiguous(logical_job_id, exc)
            raise
        self._cost_guard.confirm_provider_task(logical_job_id, task_id)
        return task_id

    def get_task_state(self, task_id: str) -> Any:
        return self._provider.get_task_state(task_id)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._provider, name)


class BudgetedProductionSeparationOrchestrator:
    def __init__(
        self,
        *,
        provider: Any,
        cost_guard: CostQuotaGuard,
        source_root: str | Path,
        artifact_root: str | Path,
        registry_path: str | Path,
        duration_resolver: Callable[[Path], float],
        downloader: Any | None = None,
        long_track_guard: LongTrackIOGuard | None = None,
        long_track_telemetry_path: str | Path | None = None,
    ):
        if not callable(duration_resolver):
            raise CostGuardError("SEP_COST_DURATION_RESOLVER_REQUIRED")
        self.cost_guard = cost_guard
        self.duration_resolver = duration_resolver
        self.source_root = Path(source_root).resolve()
        self.inner = LongTrackProductionSeparationOrchestrator(
            provider=BudgetedProviderProxy(provider, cost_guard),
            source_root=source_root,
            artifact_root=artifact_root,
            registry_path=registry_path,
            downloader=downloader,
            long_track_guard=long_track_guard,
            long_track_telemetry_path=long_track_telemetry_path,
        )

    def start(
        self,
        *,
        source_path: str | Path,
        project_id: str,
        asset_id: str,
        models: Iterable[str],
        idempotency_key: str,
    ) -> Any:
        selected_models = _normalize_models(models)
        source = _contained_file(source_path, self.source_root)
        # Reject the deployment/provider source-size boundary before hashing a multi-gigabyte file,
        # duration analysis or cost reservation. The inner layer repeats this check defensively.
        try:
            self.inner.long_track_guard.validate_source_size(source.stat().st_size)
        except LongTrackIOError as exc:
            raise OrchestratorError(exc.code, retryable=exc.retryable) from exc
        source_sha, _ = _sha256_file(source)
        fingerprint = _request_fingerprint(project_id, asset_id, source_sha, selected_models)
        if not isinstance(idempotency_key, str) or not idempotency_key or "\r" in idempotency_key or "\n" in idempotency_key:
            raise OrchestratorError("SEP_IDEMPOTENCY_KEY_INVALID")
        logical_job_id = hashlib.sha256(("lane1:" + idempotency_key).encode("utf-8")).hexdigest()[:32]
        try:
            duration_seconds = self.duration_resolver(source)
        except CostGuardError:
            raise
        except Exception as exc:
            raise CostGuardError("SEP_COST_DURATION_RESOLUTION_FAILED") from exc
        self.cost_guard.reserve(
            logical_job_id=logical_job_id,
            request_fingerprint=fingerprint,
            duration_seconds=duration_seconds,
            target_count=len(selected_models),
        )
        try:
            return self.inner.start(
                source_path=source,
                project_id=project_id,
                asset_id=asset_id,
                models=selected_models,
                idempotency_key=idempotency_key,
            )
        except Exception:
            # Upload/local validation/storage-preflight failures happen before the provider proxy
            # authorizes create. Only that provably pre-create state may release the reservation.
            record = self.cost_guard.get(logical_job_id)
            if record.provider_create_state == "not_attempted" and record.accounting_state == "reserved":
                self.cost_guard.release_before_provider_create(logical_job_id, reason_code="pre_create_failure")
            raise

    def reconcile_ambiguous_start(self, logical_job_id: str) -> Any:
        try:
            record = self.inner.reconcile_ambiguous_start(logical_job_id)
        except OrchestratorError as exc:
            if exc.code == "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED":
                self.cost_guard.mark_duplicate_billing_incident(logical_job_id)
            raise
        if record.provider_task_id:
            self.cost_guard.confirm_provider_task(logical_job_id, record.provider_task_id)
        return record

    def reconcile_actual_cost(self, logical_job_id: str, actual_cost: str) -> Any:
        return self.cost_guard.reconcile_actual(logical_job_id, actual_cost=actual_cost)

    def observe(self, logical_job_id: str) -> Any:
        try:
            return self.inner.observe(logical_job_id)
        except Exception as exc:
            semantics = classify_provider_limit(exc)
            if semantics is not None:
                self.cost_guard.record_limit_signal(logical_job_id, exc)
            raise

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        return self.inner.collect_ready_outputs(logical_job_id)

    def long_track_status(self, logical_job_id: str) -> Any:
        return self.inner.long_track_status(logical_job_id)

    def get(self, logical_job_id: str) -> Any:
        return self.inner.get(logical_job_id)
