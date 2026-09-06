"""A43 bounded-cache production wrapper for A41 crash-resumable long-track downloads."""
from __future__ import annotations

import hashlib
import time
from typing import Any, Callable

from production_orchestrator import OrchestratorError
from resumable_long_track_production_orchestrator import (
    CrashResumableLongTrackProductionSeparationOrchestrator,
)
from resumable_transfer_cache import (
    ResumeCachePolicy,
    ResumeCacheReclaimReport,
    ResumableTransferCacheManager,
)


class BoundedCrashResumableLongTrackProductionSeparationOrchestrator(
    CrashResumableLongTrackProductionSeparationOrchestrator
):
    """A41 output resumption plus A43 TTL/quota/privacy-safe cache lifecycle."""

    def __init__(
        self,
        *,
        resume_cache_policy: ResumeCachePolicy | None = None,
        resume_cache_now: Callable[[], float] = time.time,
        **kwargs: Any,
    ):
        super().__init__(**kwargs)
        if resume_cache_policy is None:
            # A resumable cache is retry acceleration, not the authoritative artifact store.
            # Bound the default to two maximum accepted source files; deployments may lower this.
            resume_cache_policy = ResumeCachePolicy(
                max_total_bytes=2 * self.long_track_guard.policy.max_source_bytes
            )
        self.resume_cache = ResumableTransferCacheManager(
            self.artifact_root,
            resume_cache_policy,
            now=resume_cache_now,
        )

    def reclaim_resume_caches(self) -> ResumeCacheReclaimReport:
        report = self.resume_cache.reclaim()
        if report.over_budget:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_BUDGET_EXCEEDED",
                retryable=True,
            )
        return report

    def purge_resume_cache(self, logical_job_id: str) -> None:
        """Maintenance purge that permits a later retry to rebuild the cache."""
        self.resume_cache.purge(logical_job_id)

    def tombstone_and_purge_resume_cache(self, logical_job_id: str) -> None:
        """Privacy deletion hook: purge retry bytes and permanently reject same-job resurrection."""
        self.resume_cache.tombstone_and_purge(logical_job_id)

    def start(self, *, idempotency_key: str, **kwargs: Any) -> Any:
        # The parent remains authoritative for idempotency-key validation. For a syntactically
        # usable key, reject recreation of a job whose content was explicitly deleted.
        if (
            isinstance(idempotency_key, str)
            and idempotency_key
            and "\r" not in idempotency_key
            and "\n" not in idempotency_key
        ):
            logical_job_id = hashlib.sha256(
                ("lane1:" + idempotency_key).encode("utf-8")
            ).hexdigest()[:32]
            if self.resume_cache.is_deleted(logical_job_id):
                raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")
        return super().start(idempotency_key=idempotency_key, **kwargs)

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        if self.resume_cache.is_deleted(logical_job_id):
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")
        # Reclaim abandoned bytes before the A15 storage preflight/download path. If a same-job
        # prefix has aged out or lost the quota race, A41 safely restarts that stem from byte zero.
        self.reclaim_resume_caches()
        cache_root = self.resume_cache.cache_root(logical_job_id)
        try:
            with self.resume_cache.lease(logical_job_id) as acquired:
                if not acquired:  # blocking lease always acquires; defensive only.
                    raise OrchestratorError(
                        "SEP_OUTPUT_RESUME_CACHE_LOCK_FAILED", retryable=True
                    )
                # Re-check after the lease: deletion may have won the race after the early preview.
                if self.resume_cache.is_deleted(logical_job_id):
                    raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_JOB_DELETED")
                if cache_root.exists():
                    self.resume_cache.touch(logical_job_id)
                try:
                    result = super().collect_ready_outputs(logical_job_id)
                except Exception:
                    # A41 intentionally retains only validator-bound safe prefixes. Refresh their
                    # access time before the lease is released so TTL is based on actual retry use.
                    if cache_root.exists():
                        self.resume_cache.touch(logical_job_id)
                    raise
                return result
        except Exception:
            # Once the job lease is released, immediately enforce quota. This may intentionally
            # discard a very large partial prefix; correctness is unaffected because retry restarts.
            try:
                self.reclaim_resume_caches()
            except OrchestratorError:
                # Preserve the primary processing/network error. A later preflight/reclaim will
                # surface a persistent cache-management failure before more output bytes are read.
                pass
            raise
