"""A15 long-track hardening wrapper for the A06/A07 production orchestrator.

Adds two-stage disk preflight, globally bounded downloads, per-stem streaming caps and a
privacy-safe durable transfer ledger. This is engineering evidence only, not PARITY evidence.
"""
from __future__ import annotations

import errno
import hashlib
import json
import os
import re
import shutil
import ssl
import threading
import time
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urlparse

from long_track_io import LongTrackIOError, LongTrackIOGuard, StoragePreflight, TransferStats
from production_orchestrator import (
    OrchestratorError,
    ProductionSeparationOrchestrator,
    _contained_file,
    _normalize_models,
)

_SAFE_LOGICAL_JOB = re.compile(r"^[0-9a-f]{32}$")


@dataclass
class LongTrackRunTelemetry:
    logical_job_id: str
    policy_version: int
    source_bytes: int
    target_count: int
    upload_bytes: int = 0
    upload_milliseconds: int = 0
    storage_preflight_state: str = "not_run"
    storage_required_bytes: int | None = None
    storage_free_bytes: int | None = None
    storage_estimated_output_bytes: int | None = None
    max_single_stem_bytes: int | None = None
    download_bytes: int = 0
    download_milliseconds: int = 0
    download_count: int = 0
    max_transfer_chunk_bytes: int = 0
    max_parallel_transfers: int = 1
    stable_error_code: str | None = None


class AtomicLongTrackTelemetryStore:
    SCHEMA_VERSION = 1

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        # get() delegates to _load(); use a re-entrant lock so one store instance cannot deadlock
        # itself while still serializing read/modify/write operations across worker threads.
        self._lock = threading.RLock()

    def get(self, logical_job_id: str) -> LongTrackRunTelemetry | None:
        return self._load().get(logical_job_id)

    def _load(self) -> dict[str, LongTrackRunTelemetry]:
        with self._lock:
            if not self.path.exists():
                return {}
            try:
                raw = json.loads(self.path.read_text(encoding="utf-8"))
                if raw.get("schema_version") != self.SCHEMA_VERSION or not isinstance(raw.get("jobs"), dict):
                    raise ValueError
                return {key: LongTrackRunTelemetry(**value) for key, value in raw["jobs"].items()}
            except (OSError, UnicodeDecodeError, json.JSONDecodeError, TypeError, ValueError) as exc:
                raise OrchestratorError("SEP_LONG_TRACK_TELEMETRY_CORRUPT") from exc

    def save(self, telemetry: LongTrackRunTelemetry) -> None:
        if not _SAFE_LOGICAL_JOB.fullmatch(telemetry.logical_job_id):
            raise OrchestratorError("SEP_LOGICAL_JOB_ID_INVALID")
        with self._lock:
            jobs: dict[str, Any] = {}
            if self.path.exists():
                try:
                    raw = json.loads(self.path.read_text(encoding="utf-8"))
                    if raw.get("schema_version") != self.SCHEMA_VERSION or not isinstance(raw.get("jobs"), dict):
                        raise ValueError
                    jobs = raw["jobs"]
                except (OSError, UnicodeDecodeError, json.JSONDecodeError, TypeError, ValueError) as exc:
                    raise OrchestratorError("SEP_LONG_TRACK_TELEMETRY_CORRUPT") from exc
            jobs[telemetry.logical_job_id] = asdict(telemetry)
            encoded = json.dumps(
                {"schema_version": self.SCHEMA_VERSION, "jobs": dict(sorted(jobs.items()))},
                indent=2,
                sort_keys=True,
            ) + "\n"
            tmp = self.path.with_name(self.path.name + ".tmp")
            try:
                with tmp.open("w", encoding="utf-8") as handle:
                    handle.write(encoded)
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(tmp, self.path)
            except OSError as exc:
                try:
                    tmp.unlink(missing_ok=True)
                except OSError:
                    pass
                raise OrchestratorError("SEP_LONG_TRACK_TELEMETRY_WRITE_FAILED", retryable=True) from exc


class _InstrumentedProviderProxy:
    def __init__(self, provider: Any, monotonic: Callable[[], float]):
        self._provider = provider
        self._monotonic = monotonic
        self._local = threading.local()

    def upload_asset(self, source_path: str | Path) -> str:
        path = Path(source_path)
        byte_count = path.stat().st_size if path.is_file() else 0
        started = self._monotonic()
        succeeded = False
        try:
            result = self._provider.upload_asset(source_path)
            succeeded = True
            return result
        finally:
            elapsed = max(0, int(round((self._monotonic() - started) * 1000)))
            self._local.upload_stats = (byte_count, elapsed, succeeded)

    def consume_upload_stats(self) -> tuple[int, int, bool] | None:
        result = getattr(self._local, "upload_stats", None)
        self._local.upload_stats = None
        return result

    def __getattr__(self, name: str) -> Any:
        return getattr(self._provider, name)


class LongTrackProductionSeparationOrchestrator(ProductionSeparationOrchestrator):
    def __init__(
        self,
        *,
        provider: Any,
        source_root: str | Path,
        artifact_root: str | Path,
        registry_path: str | Path,
        downloader: Callable[[str, Path], Any] | None = None,
        long_track_guard: LongTrackIOGuard | None = None,
        long_track_telemetry_path: str | Path | None = None,
    ):
        self.long_track_guard = long_track_guard or LongTrackIOGuard()
        self.long_track_guard.policy.validate()
        self._provider_proxy = _InstrumentedProviderProxy(provider, self.long_track_guard.monotonic)
        self._custom_downloader = downloader
        self._transfer_semaphore = threading.BoundedSemaphore(
            self.long_track_guard.policy.max_parallel_transfers
        )
        self._transfer_lock = threading.Lock()
        self._max_bytes_by_staging: dict[str, int] = {}
        self._stats_by_destination: dict[str, TransferStats] = {}
        registry_path = Path(registry_path)
        telemetry_path = long_track_telemetry_path or registry_path.with_name(
            registry_path.stem + ".long-track.json"
        )
        self.long_track_telemetry = AtomicLongTrackTelemetryStore(telemetry_path)
        super().__init__(
            provider=self._provider_proxy,
            source_root=source_root,
            artifact_root=artifact_root,
            registry_path=registry_path,
            downloader=self._guarded_downloader,
        )

    def start(
        self,
        *,
        source_path: str | Path,
        project_id: str,
        asset_id: str,
        models: Any,
        idempotency_key: str,
    ) -> Any:
        selected = _normalize_models(models)
        source = _contained_file(source_path, self.source_root)
        source_bytes = source.stat().st_size
        try:
            self.long_track_guard.validate_source_size(source_bytes)
        except LongTrackIOError as exc:
            raise OrchestratorError(exc.code, retryable=exc.retryable) from exc
        if not isinstance(idempotency_key, str) or not idempotency_key or "\r" in idempotency_key or "\n" in idempotency_key:
            raise OrchestratorError("SEP_IDEMPOTENCY_KEY_INVALID")

        logical_job_id = hashlib.sha256(("lane1:" + idempotency_key).encode("utf-8")).hexdigest()[:32]
        telemetry = self.long_track_telemetry.get(logical_job_id) or LongTrackRunTelemetry(
            logical_job_id=logical_job_id,
            policy_version=self.long_track_guard.policy.policy_version,
            source_bytes=source_bytes,
            target_count=len(selected),
            max_parallel_transfers=self.long_track_guard.policy.max_parallel_transfers,
        )
        preflight = self._preflight(source_bytes, len(selected), telemetry, "before_provider")
        self._apply_preflight(telemetry, preflight, "passed_before_provider")
        telemetry.stable_error_code = None
        self.long_track_telemetry.save(telemetry)

        try:
            record = super().start(
                source_path=source,
                project_id=project_id,
                asset_id=asset_id,
                models=selected,
                idempotency_key=idempotency_key,
            )
        except Exception:
            self._persist_upload_stats(logical_job_id, telemetry)
            raise
        self._persist_upload_stats(record.logical_job_id, telemetry)
        return record

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        record = self.get(logical_job_id)
        if record.outputs_committed:
            return record

        staging_dir = self.artifact_root / (record.logical_job_id + ".staging")
        if staging_dir.exists():
            shutil.rmtree(staging_dir, ignore_errors=True)

        telemetry = self.long_track_telemetry.get(logical_job_id) or LongTrackRunTelemetry(
            logical_job_id=logical_job_id,
            policy_version=self.long_track_guard.policy.policy_version,
            source_bytes=record.source_bytes,
            target_count=len(record.requested_models),
            max_parallel_transfers=self.long_track_guard.policy.max_parallel_transfers,
        )
        preflight = self._preflight(
            record.source_bytes,
            len(record.requested_models),
            telemetry,
            "before_download",
        )
        self._apply_preflight(telemetry, preflight, "passed_before_download")
        telemetry.stable_error_code = None
        self.long_track_telemetry.save(telemetry)

        staging_key = str(staging_dir.resolve())
        with self._transfer_lock:
            self._max_bytes_by_staging[staging_key] = preflight.max_single_stem_bytes
            self._clear_stats_for_parent(staging_key)

        try:
            result = super().collect_ready_outputs(logical_job_id)
        except Exception as exc:
            telemetry = self.long_track_telemetry.get(logical_job_id) or telemetry
            telemetry.stable_error_code = getattr(exc, "code", "SEP_LONG_TRACK_OUTPUT_COLLECTION_FAILED")
            self.long_track_telemetry.save(telemetry)
            with self._transfer_lock:
                self._clear_stats_for_parent(staging_key)
            raise
        finally:
            with self._transfer_lock:
                self._max_bytes_by_staging.pop(staging_key, None)

        final_dir = self.artifact_root / record.logical_job_id
        stats = self._consume_stats(final_dir, record.requested_models)
        telemetry = self.long_track_telemetry.get(logical_job_id) or telemetry
        telemetry.download_bytes = sum(item.byte_count for item in stats)
        telemetry.download_milliseconds = sum(item.elapsed_milliseconds for item in stats)
        telemetry.download_count = len(stats)
        telemetry.max_transfer_chunk_bytes = max((item.max_chunk_bytes for item in stats), default=0)
        telemetry.stable_error_code = None
        self.long_track_telemetry.save(telemetry)
        return result

    def long_track_status(self, logical_job_id: str) -> LongTrackRunTelemetry | None:
        return self.long_track_telemetry.get(logical_job_id)

    def _preflight(
        self,
        source_bytes: int,
        target_count: int,
        telemetry: LongTrackRunTelemetry,
        phase: str,
    ) -> StoragePreflight:
        try:
            preflight = self.long_track_guard.estimate_storage(
                self.artifact_root,
                source_bytes=source_bytes,
                target_count=target_count,
            )
        except LongTrackIOError as exc:
            telemetry.stable_error_code = exc.code
            self.long_track_telemetry.save(telemetry)
            raise OrchestratorError(exc.code, retryable=exc.retryable) from exc
        if preflight.observed_free_bytes < preflight.required_free_bytes:
            self._apply_preflight(telemetry, preflight, "insufficient_" + phase)
            telemetry.stable_error_code = "SEP_STORAGE_PREFLIGHT_INSUFFICIENT"
            self.long_track_telemetry.save(telemetry)
            raise OrchestratorError("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", retryable=True)
        return preflight

    @staticmethod
    def _apply_preflight(
        telemetry: LongTrackRunTelemetry, preflight: StoragePreflight, state: str
    ) -> None:
        telemetry.storage_preflight_state = state
        telemetry.storage_required_bytes = preflight.required_free_bytes
        telemetry.storage_free_bytes = preflight.observed_free_bytes
        telemetry.storage_estimated_output_bytes = preflight.estimated_output_bytes
        telemetry.max_single_stem_bytes = preflight.max_single_stem_bytes
        telemetry.max_parallel_transfers = preflight.max_parallel_transfers

    def _persist_upload_stats(
        self, logical_job_id: str, fallback: LongTrackRunTelemetry
    ) -> None:
        telemetry = self.long_track_telemetry.get(logical_job_id) or fallback
        stats = self._provider_proxy.consume_upload_stats()
        if stats is not None:
            byte_count, elapsed, succeeded = stats
            telemetry.upload_bytes = byte_count
            telemetry.upload_milliseconds = elapsed
            if not succeeded:
                telemetry.stable_error_code = "SEP_PROVIDER_UPLOAD_FAILED"
        self.long_track_telemetry.save(telemetry)

    def _guarded_downloader(self, url: str, destination: Path) -> None:
        staging_key = str(destination.parent.resolve())
        with self._transfer_lock:
            max_bytes = self._max_bytes_by_staging.get(staging_key)
        if max_bytes is None:
            raise OrchestratorError("SEP_LONG_TRACK_DOWNLOAD_CONTEXT_MISSING")

        started = self.long_track_guard.monotonic()
        try:
            with self._transfer_semaphore:
                if self._custom_downloader is None:
                    stats = _download_https_streaming_bounded(
                        url,
                        destination,
                        chunk_bytes=self.long_track_guard.policy.chunk_bytes,
                        max_bytes=max_bytes,
                        monotonic=self.long_track_guard.monotonic,
                    )
                else:
                    maybe_stats = self._custom_downloader(url, destination)
                    if not destination.is_file() or destination.stat().st_size <= 0:
                        raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
                    if destination.stat().st_size > max_bytes:
                        destination.unlink(missing_ok=True)
                        raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")
                    if isinstance(maybe_stats, TransferStats):
                        stats = maybe_stats
                    else:
                        stats = self.long_track_guard.transfer_stats_from_path(
                            destination,
                            elapsed_seconds=self.long_track_guard.monotonic() - started,
                        )
        except LongTrackIOError as exc:
            raise OrchestratorError(exc.code, retryable=exc.retryable) from exc
        except OSError as exc:
            try:
                destination.unlink(missing_ok=True)
            except OSError:
                pass
            if exc.errno in {errno.ENOSPC, getattr(errno, "EDQUOT", 122)}:
                raise OrchestratorError("SEP_STORAGE_EXHAUSTED", retryable=True) from exc
            raise

        with self._transfer_lock:
            self._stats_by_destination[str(destination.resolve())] = stats

    def _clear_stats_for_parent(self, staging_key: str) -> None:
        for key in list(self._stats_by_destination):
            if str(Path(key).parent.resolve()) == staging_key:
                self._stats_by_destination.pop(key, None)

    def _consume_stats(self, final_dir: Path, models: list[str]) -> list[TransferStats]:
        staging_dir = self.artifact_root / (final_dir.name + ".staging")
        result: list[TransferStats] = []
        with self._transfer_lock:
            for model in models:
                staging_key = str((staging_dir / f"{model}.wav").resolve())
                final_key = str((final_dir / f"{model}.wav").resolve())
                stats = self._stats_by_destination.pop(staging_key, None)
                if stats is None:
                    stats = self._stats_by_destination.pop(final_key, None)
                if stats is not None:
                    result.append(stats)
        return result


def _download_https_streaming_bounded(
    url: str,
    destination: Path,
    *,
    chunk_bytes: int,
    max_bytes: int,
    monotonic: Callable[[], float] = time.monotonic,
) -> TransferStats:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise OrchestratorError("SEP_OUTPUT_URL_INVALID")
    request = urllib.request.Request(
        url,
        method="GET",
        headers={"User-Agent": "moises-equivalence/long-track-v1"},
    )
    started = monotonic()
    total = 0
    chunks = 0
    peak = 0
    try:
        with urllib.request.urlopen(
            request, timeout=120, context=ssl.create_default_context()
        ) as response:
            status = getattr(response, "status", 200)
            if status < 200 or status >= 300:
                raise OrchestratorError("SEP_OUTPUT_HTTP_FAILED", retryable=True)
            length = response.headers.get("Content-Length") if getattr(response, "headers", None) else None
            if length is not None:
                try:
                    declared = int(length)
                except ValueError as exc:
                    raise OrchestratorError("SEP_OUTPUT_CONTENT_LENGTH_INVALID") from exc
                if declared <= 0:
                    raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
                if declared > max_bytes:
                    raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")
            with destination.open("wb") as handle:
                while True:
                    chunk = response.read(chunk_bytes)
                    if not chunk:
                        break
                    total += len(chunk)
                    chunks += 1
                    peak = max(peak, len(chunk))
                    if total > max_bytes:
                        raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")
                    handle.write(chunk)
                handle.flush()
                os.fsync(handle.fileno())
    except OrchestratorError:
        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass
        raise
    except OSError as exc:
        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass
        if exc.errno in {errno.ENOSPC, getattr(errno, "EDQUOT", 122)}:
            raise OrchestratorError("SEP_STORAGE_EXHAUSTED", retryable=True) from exc
        raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_FAILED", retryable=True) from exc
    except Exception as exc:
        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass
        raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_FAILED", retryable=True) from exc

    if total <= 0:
        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass
        raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
    elapsed = max(0, int(round((monotonic() - started) * 1000)))
    return TransferStats(total, elapsed, chunks, peak)
