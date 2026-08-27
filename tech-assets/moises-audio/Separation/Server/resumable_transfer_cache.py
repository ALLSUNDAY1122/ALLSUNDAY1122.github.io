"""Bounded lifecycle management for crash-resumable long-track transfer caches.

A43 prevents A41's validator-bound partial stem bytes from becoming unbounded or indefinitely
retained user content. Cache eviction may sacrifice resume progress, never committed output.
This is server-side engineering hardening, not current-iPhone or Moises PARITY evidence.
"""
from __future__ import annotations

import errno
import os
import re
import shutil
import threading
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator

from production_orchestrator import OrchestratorError

TOOL_VERSION = "L1-A43-v1"
_SAFE_JOB = re.compile(r"^[0-9a-f]{32}$")
_CACHE_SUFFIX = ".download-cache"
_LOCK_DIR_NAME = ".resume-cache-locks"
_ACCESS_MARKER = ".last-access"

try:
    import fcntl as _fcntl
except ImportError:  # pragma: no cover - production server qualification is POSIX.
    _fcntl = None

_PROCESS_LOCKS: dict[str, threading.RLock] = {}
_PROCESS_LOCKS_GUARD = threading.Lock()


def _process_lock(path: Path) -> threading.RLock:
    key = str(path.resolve())
    with _PROCESS_LOCKS_GUARD:
        return _PROCESS_LOCKS.setdefault(key, threading.RLock())


@dataclass(frozen=True)
class ResumeCachePolicy:
    policy_version: int = 1
    max_age_seconds: int = 24 * 60 * 60
    max_total_bytes: int = 4 * 1024 * 1024 * 1024
    max_entries: int = 32

    def validate(self) -> None:
        if self.policy_version != 1:
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_POLICY_VERSION_INVALID")
        if (
            not isinstance(self.max_age_seconds, int)
            or self.max_age_seconds <= 0
            or not isinstance(self.max_total_bytes, int)
            or self.max_total_bytes <= 0
            or not isinstance(self.max_entries, int)
            or self.max_entries <= 0
        ):
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_POLICY_INVALID")


@dataclass(frozen=True)
class ResumeCacheReclaimReport:
    scanned_entries: int
    removed_entries: int
    removed_bytes: int
    skipped_active_entries: int
    retained_entries: int
    retained_bytes: int
    over_budget: bool


@dataclass(frozen=True)
class _Candidate:
    logical_job_id: str
    path: Path
    last_access: float
    byte_count: int


class ResumableTransferCacheManager:
    """TTL/quota reclamation with an external per-job lease.

    The lease lives outside the deletable cache directory. This avoids the classic race where a
    collector deletes a directory containing the lock inode while another process is waiting on
    that old inode and later writes into a newly-created directory without owning its real lock.
    """

    def __init__(
        self,
        artifact_root: str | Path,
        policy: ResumeCachePolicy | None = None,
        *,
        now: Callable[[], float] = time.time,
    ):
        self.artifact_root = Path(artifact_root)
        self.policy = policy or ResumeCachePolicy()
        self.policy.validate()
        self.now = now
        self.artifact_root.mkdir(parents=True, exist_ok=True)
        self.lock_root = self.artifact_root / _LOCK_DIR_NAME
        if self.lock_root.exists() and (self.lock_root.is_symlink() or not self.lock_root.is_dir()):
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_LOCK_ROOT_UNSAFE")
        self.lock_root.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def _validate_job(logical_job_id: str) -> str:
        if not isinstance(logical_job_id, str) or _SAFE_JOB.fullmatch(logical_job_id) is None:
            raise OrchestratorError("SEP_LOGICAL_JOB_ID_INVALID")
        return logical_job_id

    def cache_root(self, logical_job_id: str) -> Path:
        job = self._validate_job(logical_job_id)
        return self.artifact_root / f"{job}{_CACHE_SUFFIX}"

    def _lock_path(self, logical_job_id: str) -> Path:
        job = self._validate_job(logical_job_id)
        return self.lock_root / f"{job}.lock"

    @contextmanager
    def lease(self, logical_job_id: str, *, blocking: bool = True) -> Iterator[bool]:
        """Acquire the job's external lease; nonblocking mode yields False if currently active."""
        lock_path = self._lock_path(logical_job_id)
        process_lock = _process_lock(lock_path)
        acquired = process_lock.acquire(blocking=blocking)
        if not acquired:
            yield False
            return
        handle = None
        file_locked = False
        try:
            handle = lock_path.open("a+b")
            if _fcntl is not None:
                flags = _fcntl.LOCK_EX | (0 if blocking else _fcntl.LOCK_NB)
                try:
                    _fcntl.flock(handle.fileno(), flags)
                    file_locked = True
                except OSError as exc:
                    if not blocking and exc.errno in {errno.EACCES, errno.EAGAIN}:
                        handle.close()
                        handle = None
                        yield False
                        return
                    raise OrchestratorError(
                        "SEP_OUTPUT_RESUME_CACHE_LOCK_FAILED", retryable=True
                    ) from exc
            yield True
        finally:
            if handle is not None:
                if file_locked and _fcntl is not None:
                    try:
                        _fcntl.flock(handle.fileno(), _fcntl.LOCK_UN)
                    except OSError:
                        pass
                handle.close()
            process_lock.release()

    def ensure_cache_root(self, logical_job_id: str) -> Path:
        root = self.cache_root(logical_job_id)
        if root.exists() and (root.is_symlink() or not root.is_dir()):
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
        root.mkdir(parents=True, exist_ok=True)
        self.touch(logical_job_id)
        return root

    def touch(self, logical_job_id: str) -> None:
        root = self.cache_root(logical_job_id)
        if not root.is_dir() or root.is_symlink():
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
        marker = root / _ACCESS_MARKER
        try:
            marker.touch(exist_ok=True)
        except OSError as exc:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_TOUCH_FAILED", retryable=True
            ) from exc

    def _last_access(self, root: Path) -> float:
        marker = root / _ACCESS_MARKER
        try:
            if marker.exists():
                if marker.is_symlink() or not marker.is_file():
                    raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
                return marker.stat().st_mtime
            return root.stat().st_mtime
        except OSError as exc:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_STAT_FAILED", retryable=True
            ) from exc

    def _tree_size(self, root: Path) -> int:
        total = 0
        try:
            for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
                base = Path(directory)
                kept = []
                for name in dirnames:
                    child = base / name
                    if child.is_symlink():
                        raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
                    kept.append(name)
                dirnames[:] = kept
                for name in filenames:
                    child = base / name
                    if child.is_symlink() or not child.is_file():
                        raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
                    total += child.stat().st_size
        except OrchestratorError:
            raise
        except OSError as exc:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_STAT_FAILED", retryable=True
            ) from exc
        return total

    def _remove_root(self, root: Path) -> None:
        if not root.exists() and not root.is_symlink():
            return
        try:
            if root.is_symlink():
                root.unlink()
                return
            if not root.is_dir():
                raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
            shutil.rmtree(root)
        except OrchestratorError:
            raise
        except OSError as exc:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_RECLAIM_FAILED", retryable=True
            ) from exc

    def purge(self, logical_job_id: str) -> None:
        """Explicit privacy/deletion hook for one logical job's resumable bytes."""
        with self.lease(logical_job_id) as acquired:
            if not acquired:  # blocking lease always acquires; defensive only.
                raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_LOCK_FAILED", retryable=True)
            self._remove_root(self.cache_root(logical_job_id))

    @staticmethod
    def _job_from_cache_name(name: str) -> str | None:
        if not name.endswith(_CACHE_SUFFIX):
            return None
        job = name[: -len(_CACHE_SUFFIX)]
        return job if _SAFE_JOB.fullmatch(job) else None

    def reclaim(self) -> ResumeCacheReclaimReport:
        """Remove stale/over-budget inactive caches. Active leases are never reclaimed."""
        if _fcntl is None:
            # Cross-process deletion without an OS lease is unsafe. Normal A41 download remains
            # available, but A43 reclamation fails closed until a qualified locking backend exists.
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_RECLAIM_LOCK_UNAVAILABLE", retryable=True
            )

        now = float(self.now())
        scanned = removed_entries = removed_bytes = skipped_active = 0
        retained: list[_Candidate] = []

        try:
            entries = list(self.artifact_root.iterdir())
        except OSError as exc:
            raise OrchestratorError(
                "SEP_OUTPUT_RESUME_CACHE_SCAN_FAILED", retryable=True
            ) from exc

        for path in entries:
            job = self._job_from_cache_name(path.name)
            if job is None:
                continue
            scanned += 1
            with self.lease(job, blocking=False) as acquired:
                if not acquired:
                    skipped_active += 1
                    continue
                if path.is_symlink():
                    self._remove_root(path)
                    removed_entries += 1
                    continue
                if not path.exists():
                    continue
                if not path.is_dir():
                    raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
                try:
                    size = self._tree_size(path)
                    last_access = self._last_access(path)
                except OrchestratorError as exc:
                    if exc.code == "SEP_OUTPUT_RESUME_CACHE_UNSAFE":
                        # The root itself is contained and leased. Removing it is safer than
                        # traversing an untrusted link or special file inside it.
                        self._remove_root(path)
                        removed_entries += 1
                        continue
                    raise
                if last_access > now + 300:
                    self._remove_root(path)
                    removed_entries += 1
                    removed_bytes += size
                    continue
                if now - last_access > self.policy.max_age_seconds:
                    self._remove_root(path)
                    removed_entries += 1
                    removed_bytes += size
                    continue
                retained.append(_Candidate(job, path, last_access, size))

        retained.sort(key=lambda item: (item.last_access, item.logical_job_id))
        retained_bytes = sum(item.byte_count for item in retained)
        quota_candidates = list(retained)
        protected: set[str] = set()

        for candidate in quota_candidates:
            if len(retained) <= self.policy.max_entries and retained_bytes <= self.policy.max_total_bytes:
                break
            with self.lease(candidate.logical_job_id, blocking=False) as acquired:
                if not acquired:
                    skipped_active += 1
                    protected.add(candidate.logical_job_id)
                    continue
                path = candidate.path
                if not path.exists():
                    retained = [x for x in retained if x.logical_job_id != candidate.logical_job_id]
                    retained_bytes -= candidate.byte_count
                    continue
                if path.is_symlink() or not path.is_dir():
                    self._remove_root(path)
                    removed_entries += 1
                    retained = [x for x in retained if x.logical_job_id != candidate.logical_job_id]
                    retained_bytes -= candidate.byte_count
                    continue
                fresh_access = self._last_access(path)
                fresh_size = self._tree_size(path)
                if fresh_access != candidate.last_access or fresh_size != candidate.byte_count:
                    # It became active between scan and eviction selection. Preserve it for this
                    # sweep and report over_budget if the remaining old candidates cannot suffice.
                    protected.add(candidate.logical_job_id)
                    retained_bytes += fresh_size - candidate.byte_count
                    retained = [
                        _Candidate(x.logical_job_id, x.path, fresh_access, fresh_size)
                        if x.logical_job_id == candidate.logical_job_id
                        else x
                        for x in retained
                    ]
                    continue
                self._remove_root(path)
                removed_entries += 1
                removed_bytes += fresh_size
                retained = [x for x in retained if x.logical_job_id != candidate.logical_job_id]
                retained_bytes -= fresh_size

        over_budget = (
            len(retained) > self.policy.max_entries
            or retained_bytes > self.policy.max_total_bytes
        )
        return ResumeCacheReclaimReport(
            scanned_entries=scanned,
            removed_entries=removed_entries,
            removed_bytes=removed_bytes,
            skipped_active_entries=skipped_active,
            retained_entries=len(retained),
            retained_bytes=max(0, retained_bytes),
            over_budget=over_budget,
        )
