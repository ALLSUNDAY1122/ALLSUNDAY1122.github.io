"""Crash-resumable long-track output transfer for Lane 1.

A41 layers a validator-bound download cache over A15. Partial bytes are reusable only when the
provider response exposes a strong ETag and a stable total length. This is engineering hardening,
not current-iPhone or Moises PARITY evidence.
"""
from __future__ import annotations

import errno
import hashlib
import json
import os
import re
import shutil
import ssl
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urlparse

from long_track_io import LongTrackIOError, TransferStats
from long_track_production_orchestrator import (
    LongTrackProductionSeparationOrchestrator,
)
from production_orchestrator import OrchestratorError

TOOL_VERSION = "L1-A41-v1"
RESUME_SCHEMA_VERSION = 1
_CONTENT_RANGE = re.compile(r"^bytes\s+(\d+)-(\d+)/(\d+)$")


@dataclass(frozen=True)
class ResumableDownloadState:
    schema_version: int
    url_ref_sha256: str
    strong_etag: str
    expected_total_bytes: int
    complete: bool


def _url_ref(url: str) -> str:
    return hashlib.sha256(url.encode("utf-8")).hexdigest()


def _strong_etag(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    value = value.strip()
    if value.startswith("W/"):
        return None
    if len(value) < 2 or not value.startswith('"') or not value.endswith('"'):
        return None
    if "\r" in value or "\n" in value:
        return None
    return value


def _fsync_directory(path: Path) -> None:
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    try:
        fd = os.open(path, flags)
    except OSError:
        return
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _atomic_write_state(path: Path, state: ResumableDownloadState) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_UNSAFE")
    payload = json.dumps(asdict(state), indent=2, sort_keys=True) + "\n"
    tmp = path.with_name(path.name + ".tmp")
    try:
        with tmp.open("w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
        _fsync_directory(path.parent)
    except OSError as exc:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_WRITE_FAILED", retryable=True) from exc


def _load_state(path: Path) -> ResumableDownloadState | None:
    if not path.exists():
        return None
    if path.is_symlink() or not path.is_file():
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_UNSAFE")
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        state = ResumableDownloadState(**raw)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, TypeError, ValueError) as exc:
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_CORRUPT") from exc
    if state.schema_version != RESUME_SCHEMA_VERSION:
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_SCHEMA_INVALID")
    if not re.fullmatch(r"[0-9a-f]{64}", state.url_ref_sha256):
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_CORRUPT")
    if _strong_etag(state.strong_etag) is None:
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_CORRUPT")
    if not isinstance(state.expected_total_bytes, int) or state.expected_total_bytes <= 0:
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_CORRUPT")
    if not isinstance(state.complete, bool):
        raise OrchestratorError("SEP_OUTPUT_RESUME_STATE_CORRUPT")
    return state


def _delete_pair(data_path: Path, state_path: Path) -> None:
    for path in (data_path, state_path):
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass


def _parse_content_length(headers: Any) -> int | None:
    raw = headers.get("Content-Length") if headers is not None else None
    if raw is None:
        return None
    try:
        value = int(raw)
    except (TypeError, ValueError) as exc:
        raise OrchestratorError("SEP_OUTPUT_CONTENT_LENGTH_INVALID") from exc
    if value <= 0:
        raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
    return value


def _parse_content_range(headers: Any) -> tuple[int, int, int]:
    raw = headers.get("Content-Range") if headers is not None else None
    if not isinstance(raw, str):
        raise OrchestratorError("SEP_OUTPUT_RESUME_RANGE_INVALID")
    match = _CONTENT_RANGE.fullmatch(raw.strip())
    if match is None:
        raise OrchestratorError("SEP_OUTPUT_RESUME_RANGE_INVALID")
    start, end, total = (int(match.group(i)) for i in range(1, 4))
    if start < 0 or end < start or total <= end:
        raise OrchestratorError("SEP_OUTPUT_RESUME_RANGE_INVALID")
    return start, end, total


def _download_https_resumable_bounded(
    url: str,
    data_path: Path,
    state_path: Path,
    *,
    chunk_bytes: int,
    max_bytes: int,
    monotonic: Callable[[], float] = time.monotonic,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> TransferStats:
    """Download into a durable cache and resume only across validator-bound byte ranges."""
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise OrchestratorError("SEP_OUTPUT_URL_INVALID")
    if not isinstance(chunk_bytes, int) or chunk_bytes <= 0 or chunk_bytes > 8 * 1024 * 1024:
        raise OrchestratorError("SEP_LONG_TRACK_CHUNK_TOO_LARGE")
    if not isinstance(max_bytes, int) or max_bytes <= 0:
        raise OrchestratorError("SEP_OUTPUT_STREAM_LIMIT_INVALID")

    data_path.parent.mkdir(parents=True, exist_ok=True)
    if data_path.is_symlink():
        raise OrchestratorError("SEP_OUTPUT_RESUME_DATA_UNSAFE")

    url_ref = _url_ref(url)
    state = _load_state(state_path)

    if state is not None and state.expected_total_bytes > max_bytes:
        _delete_pair(data_path, state_path)
        raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")

    if state is not None and state.complete:
        if state.url_ref_sha256 == url_ref and data_path.is_file():
            size = data_path.stat().st_size
            if size == state.expected_total_bytes:
                return TransferStats(size, 0, 0, 0)
        _delete_pair(data_path, state_path)
        state = None

    existing = data_path.stat().st_size if data_path.is_file() else 0
    if state is None or state.url_ref_sha256 != url_ref:
        if existing or state is not None:
            _delete_pair(data_path, state_path)
        state = None
        existing = 0
    elif existing <= 0 or existing >= state.expected_total_bytes:
        _delete_pair(data_path, state_path)
        state = None
        existing = 0

    headers = {"User-Agent": "moises-equivalence/long-track-resume-v1"}
    resume_attempt = state is not None and existing > 0
    if resume_attempt:
        headers["Range"] = f"bytes={existing}-"
        headers["If-Range"] = state.strong_etag

    request = urllib.request.Request(url, method="GET", headers=headers)
    started = monotonic()
    total = existing if resume_attempt else 0
    chunks = 0
    peak = 0
    retain_partial = False

    try:
        with opener(request, timeout=120, context=ssl.create_default_context()) as response:
            status = int(getattr(response, "status", 200))
            response_headers = getattr(response, "headers", None)
            response_etag = _strong_etag(
                response_headers.get("ETag") if response_headers is not None else None
            )
            declared = _parse_content_length(response_headers)

            if resume_attempt and status == 206:
                start, end, expected_total = _parse_content_range(response_headers)
                if start != existing:
                    raise OrchestratorError("SEP_OUTPUT_RESUME_RANGE_MISMATCH")
                if response_etag != state.strong_etag:
                    raise OrchestratorError("SEP_OUTPUT_RESUME_VALIDATOR_MISMATCH")
                if expected_total != state.expected_total_bytes:
                    raise OrchestratorError("SEP_OUTPUT_RESUME_TOTAL_MISMATCH")
                if declared is not None and declared != end - start + 1:
                    raise OrchestratorError("SEP_OUTPUT_CONTENT_LENGTH_INVALID")
                mode = "ab"
                expected_total_bytes = expected_total
                retain_partial = True
            elif status == 200:
                # A server may legally ignore Range. Restarting from byte zero avoids splice corruption.
                if resume_attempt:
                    _delete_pair(data_path, state_path)
                    total = 0
                if declared is not None and declared > max_bytes:
                    raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")
                mode = "wb"
                expected_total_bytes = declared
                retain_partial = response_etag is not None and declared is not None
                if retain_partial:
                    _atomic_write_state(
                        state_path,
                        ResumableDownloadState(
                            RESUME_SCHEMA_VERSION,
                            url_ref,
                            response_etag,
                            declared,
                            False,
                        ),
                    )
            else:
                raise OrchestratorError("SEP_OUTPUT_HTTP_FAILED", retryable=True)

            if expected_total_bytes is not None and expected_total_bytes > max_bytes:
                raise OrchestratorError("SEP_OUTPUT_STREAM_TOO_LARGE")

            with data_path.open(mode) as handle:
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

            if total <= 0:
                raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
            if expected_total_bytes is not None and total != expected_total_bytes:
                raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_TRUNCATED", retryable=True)

            if response_etag is not None and expected_total_bytes is not None:
                _atomic_write_state(
                    state_path,
                    ResumableDownloadState(
                        RESUME_SCHEMA_VERSION,
                        url_ref,
                        response_etag,
                        expected_total_bytes,
                        True,
                    ),
                )
            else:
                # Completed downloads need no resume metadata if the provider exposes no validator.
                state_path.unlink(missing_ok=True)

    except OrchestratorError as exc:
        safe_retryable_prefix = retain_partial and exc.code in {
            "SEP_OUTPUT_DOWNLOAD_TRUNCATED",
            "SEP_OUTPUT_DOWNLOAD_FAILED",
        }
        if not safe_retryable_prefix:
            _delete_pair(data_path, state_path)
        raise
    except OSError as exc:
        if exc.errno in {errno.ENOSPC, getattr(errno, "EDQUOT", 122)}:
            _delete_pair(data_path, state_path)
            raise OrchestratorError("SEP_STORAGE_EXHAUSTED", retryable=True) from exc
        if not retain_partial:
            _delete_pair(data_path, state_path)
        raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_FAILED", retryable=True) from exc
    except Exception as exc:
        if not retain_partial:
            _delete_pair(data_path, state_path)
        raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_FAILED", retryable=True) from exc

    elapsed = max(0, int(round((monotonic() - started) * 1000)))
    return TransferStats(total, elapsed, chunks, peak)


class CrashResumableLongTrackProductionSeparationOrchestrator(
    LongTrackProductionSeparationOrchestrator
):
    """A15 production wrapper with durable, validator-bound A41 output download resumption."""

    def _guarded_downloader(self, url: str, destination: Path) -> None:
        if self._custom_downloader is not None:
            return super()._guarded_downloader(url, destination)

        staging_key = str(destination.parent.resolve())
        with self._transfer_lock:
            max_bytes = self._max_bytes_by_staging.get(staging_key)
        if max_bytes is None:
            raise OrchestratorError("SEP_LONG_TRACK_DOWNLOAD_CONTEXT_MISSING")

        if not destination.parent.name.endswith(".staging"):
            raise OrchestratorError("SEP_OUTPUT_STAGING_CONTEXT_INVALID")
        logical_job_id = destination.parent.name[: -len(".staging")]
        if not re.fullmatch(r"[0-9a-f]{32}", logical_job_id):
            raise OrchestratorError("SEP_LOGICAL_JOB_ID_INVALID")

        cache_root = self.artifact_root / f"{logical_job_id}.download-cache"
        if cache_root.exists() and (cache_root.is_symlink() or not cache_root.is_dir()):
            raise OrchestratorError("SEP_OUTPUT_RESUME_CACHE_UNSAFE")
        cache_root.mkdir(parents=True, exist_ok=True)

        cache_file = cache_root / destination.name
        state_file = cache_root / (destination.stem + ".resume.json")

        with self._transfer_semaphore:
            stats = _download_https_resumable_bounded(
                url,
                cache_file,
                state_file,
                chunk_bytes=self.long_track_guard.policy.chunk_bytes,
                max_bytes=max_bytes,
                monotonic=self.long_track_guard.monotonic,
            )
            try:
                destination.unlink(missing_ok=True)
                os.link(cache_file, destination)
            except OSError as exc:
                try:
                    destination.unlink(missing_ok=True)
                except OSError:
                    pass
                raise OrchestratorError("SEP_OUTPUT_CACHE_LINK_FAILED", retryable=True) from exc

        with self._transfer_lock:
            self._stats_by_destination[str(destination.resolve())] = stats

    def collect_ready_outputs(self, logical_job_id: str) -> Any:
        result = super().collect_ready_outputs(logical_job_id)
        cache_root = self.artifact_root / f"{logical_job_id}.download-cache"
        shutil.rmtree(cache_root, ignore_errors=True)
        return result
