"""Long-track IO/storage primitives for Lane 1.

The policy values are conservative deployment guards, not provider truth or PARITY evidence.
They are configurable because input compression ratio and provider output encoding vary.
"""
from __future__ import annotations

import errno
import math
import os
import shutil
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

MIB = 1024 * 1024
GIB = 1024 * MIB


class LongTrackIOError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


@dataclass(frozen=True)
class LongTrackPolicy:
    policy_version: int = 1
    max_source_bytes: int = 2 * GIB
    chunk_bytes: int = 1 * MIB
    output_estimate_ratio_per_target: float = 8.0
    max_output_ratio_per_target: float = 16.0
    minimum_estimated_stem_bytes: int = 16 * MIB
    minimum_max_stem_bytes: int = 64 * MIB
    safety_reserve_bytes: int = 256 * MIB
    max_parallel_transfers: int = 1

    def validate(self) -> None:
        if self.policy_version != 1:
            raise LongTrackIOError("SEP_LONG_TRACK_POLICY_VERSION_INVALID")
        if self.max_source_bytes <= 0 or self.chunk_bytes <= 0:
            raise LongTrackIOError("SEP_LONG_TRACK_POLICY_SIZE_INVALID")
        if self.chunk_bytes > 8 * MIB:
            raise LongTrackIOError("SEP_LONG_TRACK_CHUNK_TOO_LARGE")
        if (
            not math.isfinite(self.output_estimate_ratio_per_target)
            or self.output_estimate_ratio_per_target < 1
        ):
            raise LongTrackIOError("SEP_LONG_TRACK_ESTIMATE_RATIO_INVALID")
        if (
            not math.isfinite(self.max_output_ratio_per_target)
            or self.max_output_ratio_per_target < self.output_estimate_ratio_per_target
        ):
            raise LongTrackIOError("SEP_LONG_TRACK_MAX_RATIO_INVALID")
        if (
            self.minimum_estimated_stem_bytes <= 0
            or self.minimum_max_stem_bytes < self.minimum_estimated_stem_bytes
        ):
            raise LongTrackIOError("SEP_LONG_TRACK_MINIMUM_INVALID")
        if self.safety_reserve_bytes < 0:
            raise LongTrackIOError("SEP_LONG_TRACK_RESERVE_INVALID")
        # A15 deliberately supports one transfer at a time. This is a backpressure guarantee,
        # not a performance target; concurrency may be raised only with new stress evidence.
        if self.max_parallel_transfers != 1:
            raise LongTrackIOError("SEP_LONG_TRACK_CONCURRENCY_UNSUPPORTED")


@dataclass(frozen=True)
class StoragePreflight:
    source_bytes: int
    target_count: int
    estimated_stem_bytes: int
    estimated_output_bytes: int
    safety_reserve_bytes: int
    required_free_bytes: int
    observed_free_bytes: int
    max_single_stem_bytes: int
    max_parallel_transfers: int
    chunk_bytes: int


@dataclass(frozen=True)
class TransferStats:
    byte_count: int
    elapsed_milliseconds: int
    chunk_count: int
    max_chunk_bytes: int


class LongTrackIOGuard:
    def __init__(
        self,
        policy: LongTrackPolicy | None = None,
        *,
        free_bytes_provider: Callable[[Path], int] | None = None,
        monotonic: Callable[[], float] = time.monotonic,
    ):
        self.policy = policy or LongTrackPolicy()
        self.policy.validate()
        self.free_bytes_provider = free_bytes_provider or self._disk_free_bytes
        self.monotonic = monotonic

    @staticmethod
    def _disk_free_bytes(path: Path) -> int:
        return shutil.disk_usage(path).free

    def validate_source_size(self, source_bytes: int) -> None:
        if not isinstance(source_bytes, int) or source_bytes <= 0:
            raise LongTrackIOError("SEP_SOURCE_EMPTY")
        if source_bytes > self.policy.max_source_bytes:
            raise LongTrackIOError("SEP_SOURCE_TOO_LARGE")

    def estimate_storage(
        self, artifact_root: str | Path, *, source_bytes: int, target_count: int
    ) -> StoragePreflight:
        self.validate_source_size(source_bytes)
        if not isinstance(target_count, int) or target_count <= 0:
            raise LongTrackIOError("SEP_LONG_TRACK_TARGET_COUNT_INVALID")
        root = Path(artifact_root)
        root.mkdir(parents=True, exist_ok=True)
        estimated_stem = max(
            self.policy.minimum_estimated_stem_bytes,
            math.ceil(source_bytes * self.policy.output_estimate_ratio_per_target),
        )
        estimated_output = estimated_stem * target_count
        required = estimated_output + self.policy.safety_reserve_bytes
        observed = int(self.free_bytes_provider(root))
        if observed < 0:
            raise LongTrackIOError("SEP_STORAGE_FREE_BYTES_INVALID")
        max_stem = max(
            self.policy.minimum_max_stem_bytes,
            math.ceil(source_bytes * self.policy.max_output_ratio_per_target),
        )
        return StoragePreflight(
            source_bytes=source_bytes,
            target_count=target_count,
            estimated_stem_bytes=estimated_stem,
            estimated_output_bytes=estimated_output,
            safety_reserve_bytes=self.policy.safety_reserve_bytes,
            required_free_bytes=required,
            observed_free_bytes=observed,
            max_single_stem_bytes=max_stem,
            max_parallel_transfers=self.policy.max_parallel_transfers,
            chunk_bytes=self.policy.chunk_bytes,
        )

    def require_storage(
        self, artifact_root: str | Path, *, source_bytes: int, target_count: int
    ) -> StoragePreflight:
        preflight = self.estimate_storage(
            artifact_root, source_bytes=source_bytes, target_count=target_count
        )
        if preflight.observed_free_bytes < preflight.required_free_bytes:
            raise LongTrackIOError("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", retryable=True)
        return preflight

    def stream_copy_file(
        self,
        source: str | Path,
        destination: str | Path,
        *,
        max_bytes: int | None = None,
    ) -> TransferStats:
        """Bounded-memory local stress/copy primitive used by the A15 regression harness."""
        src = Path(source)
        dst = Path(destination)
        if not src.is_file():
            raise LongTrackIOError("SEP_STREAM_SOURCE_MISSING")
        dst.parent.mkdir(parents=True, exist_ok=True)
        started = self.monotonic()
        total = 0
        chunks = 0
        peak = 0
        try:
            with src.open("rb") as reader, dst.open("wb") as writer:
                while True:
                    chunk = reader.read(self.policy.chunk_bytes)
                    if not chunk:
                        break
                    total += len(chunk)
                    chunks += 1
                    peak = max(peak, len(chunk))
                    if max_bytes is not None and total > max_bytes:
                        raise LongTrackIOError("SEP_OUTPUT_STREAM_TOO_LARGE")
                    writer.write(chunk)
                writer.flush()
                os.fsync(writer.fileno())
        except LongTrackIOError:
            try:
                dst.unlink(missing_ok=True)
            except OSError:
                pass
            raise
        except OSError as exc:
            try:
                dst.unlink(missing_ok=True)
            except OSError:
                pass
            if exc.errno in {errno.ENOSPC, getattr(errno, "EDQUOT", 122)}:
                raise LongTrackIOError("SEP_STORAGE_EXHAUSTED", retryable=True) from exc
            raise LongTrackIOError("SEP_STREAM_COPY_FAILED", retryable=True) from exc
        elapsed = max(0, int(round((self.monotonic() - started) * 1000)))
        if total <= 0:
            try:
                dst.unlink(missing_ok=True)
            except OSError:
                pass
            raise LongTrackIOError("SEP_OUTPUT_COPY_EMPTY")
        return TransferStats(total, elapsed, chunks, peak)

    def transfer_stats_from_path(
        self,
        destination: str | Path,
        *,
        elapsed_seconds: float,
        max_chunk_bytes: int | None = None,
    ) -> TransferStats:
        path = Path(destination)
        if not path.is_file():
            raise LongTrackIOError("SEP_OUTPUT_COPY_MISSING")
        size = path.stat().st_size
        if size <= 0:
            raise LongTrackIOError("SEP_OUTPUT_COPY_EMPTY")
        return TransferStats(
            byte_count=size,
            elapsed_milliseconds=max(0, int(round(elapsed_seconds * 1000))),
            chunk_count=0,
            max_chunk_bytes=0 if max_chunk_bytes is None else max_chunk_bytes,
        )
