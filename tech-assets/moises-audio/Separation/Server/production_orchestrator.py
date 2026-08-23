"""Production separation backend orchestration for Lane 1.

Provider-neutral orchestration. A concrete provider client exposes upload_asset(path),
create_separation_task(asset_id, models, metadata=...) and get_task_state(task_id).
The existing AudioShakeClient satisfies that surface.

This module does not claim commercial approval or PARITY. Secrets are injected through the
provider object and are never serialized by this module.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import ssl
import urllib.request
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Protocol
from urllib.parse import urlparse

SCHEMA_VERSION = 1
_SAFE_ID = re.compile(r"^[A-Za-z0-9._:-]{1,160}$")
_SAFE_MODEL = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")


class OrchestratorError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class ProviderClient(Protocol):
    def upload_asset(self, source_path: str | Path) -> str: ...
    def create_separation_task(
        self, asset_id: str, models: Iterable[str], *, metadata: dict[str, Any] | None = None
    ) -> str: ...
    def get_task_state(self, task_id: str) -> Any: ...


@dataclass
class JobRecord:
    logical_job_id: str
    idempotency_key_hash: str
    request_fingerprint: str
    project_id: str
    asset_id: str
    source_sha256: str
    source_bytes: int
    requested_models: list[str]
    state: str
    provider_asset_id: str | None = None
    provider_task_id: str | None = None
    provider_phase: str | None = None
    fraction_complete: float = 0.0
    stable_error_code: str | None = None
    retryable: bool = False
    outputs_committed: bool = False
    outputs: list[dict[str, Any]] = field(default_factory=list)


class AtomicJobRegistry:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def load(self) -> dict[str, JobRecord]:
        if not self.path.exists():
            return {}
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise OrchestratorError("SEP_REGISTRY_CORRUPT") from exc
        if not isinstance(raw, dict) or raw.get("schema_version") != SCHEMA_VERSION:
            raise OrchestratorError("SEP_REGISTRY_SCHEMA_INVALID")
        jobs = raw.get("jobs")
        if not isinstance(jobs, dict):
            raise OrchestratorError("SEP_REGISTRY_JOBS_INVALID")
        parsed: dict[str, JobRecord] = {}
        try:
            for key, value in jobs.items():
                if not isinstance(key, str) or not isinstance(value, dict):
                    raise TypeError
                parsed[key] = JobRecord(**value)
        except (TypeError, ValueError) as exc:
            raise OrchestratorError("SEP_REGISTRY_RECORD_INVALID") from exc
        return parsed

    def save(self, jobs: dict[str, JobRecord]) -> None:
        payload = {
            "schema_version": SCHEMA_VERSION,
            "jobs": {key: asdict(value) for key, value in sorted(jobs.items())},
        }
        encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
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
            raise OrchestratorError("SEP_REGISTRY_WRITE_FAILED", retryable=True) from exc


class ProductionSeparationOrchestrator:
    def __init__(
        self,
        *,
        provider: ProviderClient,
        source_root: str | Path,
        artifact_root: str | Path,
        registry_path: str | Path,
        downloader: Callable[[str, Path], None] | None = None,
    ):
        self.provider = provider
        self.source_root = Path(source_root).resolve()
        self.artifact_root = Path(artifact_root).resolve()
        self.artifact_root.mkdir(parents=True, exist_ok=True)
        self.registry = AtomicJobRegistry(registry_path)
        self.downloader = downloader or _download_https_streaming

    def start(
        self,
        *,
        source_path: str | Path,
        project_id: str,
        asset_id: str,
        models: Iterable[str],
        idempotency_key: str,
    ) -> JobRecord:
        project_id = _validate_id(project_id, "SEP_PROJECT_ID_INVALID")
        asset_id = _validate_id(asset_id, "SEP_ASSET_ID_INVALID")
        selected_models = _normalize_models(models)
        source = _contained_file(source_path, self.source_root)
        if not idempotency_key or "\r" in idempotency_key or "\n" in idempotency_key:
            raise OrchestratorError("SEP_IDEMPOTENCY_KEY_INVALID")

        source_sha, source_bytes = _sha256_file(source)
        fingerprint = _request_fingerprint(project_id, asset_id, source_sha, selected_models)
        key_hash = hashlib.sha256(idempotency_key.encode("utf-8")).hexdigest()
        logical_job_id = hashlib.sha256(("lane1:" + idempotency_key).encode("utf-8")).hexdigest()[:32]

        jobs = self.registry.load()
        existing = jobs.get(logical_job_id)
        if existing is not None:
            if existing.idempotency_key_hash != key_hash or existing.request_fingerprint != fingerprint:
                raise OrchestratorError("SEP_IDEMPOTENCY_CONFLICT")
            return existing

        record = JobRecord(
            logical_job_id=logical_job_id,
            idempotency_key_hash=key_hash,
            request_fingerprint=fingerprint,
            project_id=project_id,
            asset_id=asset_id,
            source_sha256=source_sha,
            source_bytes=source_bytes,
            requested_models=list(selected_models),
            state="uploading",
        )
        jobs[logical_job_id] = record
        self.registry.save(jobs)

        try:
            provider_asset_id = self.provider.upload_asset(source)
        except Exception as exc:
            record.state = "upload_failed"
            record.stable_error_code = _stable_error(exc, "SEP_PROVIDER_UPLOAD_FAILED")
            record.retryable = bool(getattr(exc, "retryable", True))
            self.registry.save(jobs)
            raise OrchestratorError(record.stable_error_code, retryable=record.retryable) from exc

        record.provider_asset_id = _validate_id(provider_asset_id, "SEP_PROVIDER_ASSET_ID_INVALID")
        record.state = "starting"
        self.registry.save(jobs)

        # Persist `starting` before remote POST. An ambiguous exception after vendor acceptance is
        # never auto-retried into a possible duplicate provider job/charge.
        try:
            provider_task_id = self.provider.create_separation_task(
                record.provider_asset_id,
                selected_models,
                metadata={
                    "logical_job_id": logical_job_id,
                    "project_id": project_id,
                    "asset_id": asset_id,
                    "source_sha256": source_sha,
                },
            )
        except Exception as exc:
            record.state = "start_ambiguous"
            record.stable_error_code = _stable_error(exc, "SEP_PROVIDER_START_AMBIGUOUS")
            record.retryable = False
            self.registry.save(jobs)
            raise OrchestratorError(record.stable_error_code, retryable=False) from exc

        record.provider_task_id = _validate_id(provider_task_id, "SEP_PROVIDER_TASK_ID_INVALID")
        record.state = "separating"
        record.provider_phase = "separating"
        record.stable_error_code = None
        record.retryable = True
        self.registry.save(jobs)
        return record

    def observe(self, logical_job_id: str) -> JobRecord:
        jobs = self.registry.load()
        record = _require_job(jobs, logical_job_id)
        if record.provider_task_id is None:
            return record
        try:
            state = self.provider.get_task_state(record.provider_task_id)
        except Exception as exc:
            record.stable_error_code = _stable_error(exc, "SEP_PROVIDER_OBSERVE_FAILED")
            record.retryable = bool(getattr(exc, "retryable", True))
            self.registry.save(jobs)
            raise OrchestratorError(record.stable_error_code, retryable=record.retryable) from exc

        phase = getattr(state, "phase", None)
        fraction = getattr(state, "fraction_complete", None)
        if phase not in {"separating", "ready", "failed"}:
            raise OrchestratorError("SEP_PROVIDER_PHASE_INVALID")
        if not isinstance(fraction, (int, float)) or not 0.0 <= float(fraction) <= 1.0:
            raise OrchestratorError("SEP_PROVIDER_PROGRESS_INVALID")
        record.provider_phase = phase
        record.fraction_complete = float(fraction)
        record.retryable = bool(getattr(state, "retryable", False))
        record.stable_error_code = getattr(state, "stable_error_code", None)
        record.state = phase
        self.registry.save(jobs)
        return record

    def collect_ready_outputs(self, logical_job_id: str) -> JobRecord:
        jobs = self.registry.load()
        record = _require_job(jobs, logical_job_id)
        if record.outputs_committed:
            return record
        if record.provider_task_id is None:
            raise OrchestratorError("SEP_PROVIDER_TASK_MISSING")

        state = self.provider.get_task_state(record.provider_task_id)
        if getattr(state, "phase", None) != "ready":
            raise OrchestratorError("SEP_OUTPUT_NOT_READY", retryable=True)
        targets = tuple(getattr(state, "targets", ()))
        by_model: dict[str, Any] = {}
        for target in targets:
            model = getattr(target, "model", None)
            if not isinstance(model, str) or model in by_model:
                raise OrchestratorError("SEP_OUTPUT_TARGET_SET_INVALID")
            by_model[model] = target
        if set(by_model) != set(record.requested_models):
            raise OrchestratorError("SEP_OUTPUT_TARGET_SET_INVALID")

        final_dir = self.artifact_root / record.logical_job_id
        staging_dir = self.artifact_root / (record.logical_job_id + ".staging")
        if staging_dir.exists():
            shutil.rmtree(staging_dir)
        staging_dir.mkdir(parents=True, exist_ok=False)

        outputs: list[dict[str, Any]] = []
        try:
            for model in record.requested_models:
                target = by_model[model]
                if getattr(target, "status", None) != "completed":
                    raise OrchestratorError("SEP_OUTPUT_TARGET_INCOMPLETE")
                url = getattr(target, "output_url", None)
                if not isinstance(url, str) or urlparse(url).scheme != "https":
                    raise OrchestratorError("SEP_OUTPUT_URL_INVALID")
                destination = staging_dir / f"{model}.wav"
                self.downloader(url, destination)
                if not destination.is_file() or destination.stat().st_size <= 0:
                    raise OrchestratorError("SEP_OUTPUT_COPY_EMPTY")
                digest, byte_count = _sha256_file(destination)
                outputs.append({
                    "model": model,
                    "relative_path": f"{record.logical_job_id}/{model}.wav",
                    "sha256": digest,
                    "bytes": byte_count,
                })

            manifest = {
                "schema_version": 1,
                "logical_job_id": record.logical_job_id,
                "project_id": record.project_id,
                "asset_id": record.asset_id,
                "source_sha256": record.source_sha256,
                "requested_models": record.requested_models,
                "provider_task_id": record.provider_task_id,
                "outputs": outputs,
                "parity_state": "NON_PARITY_EVIDENCE_ONLY",
            }
            (staging_dir / "manifest.json").write_text(
                json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            if final_dir.exists():
                raise OrchestratorError("SEP_OUTPUT_FINAL_ALREADY_EXISTS")
            os.replace(staging_dir, final_dir)
        except Exception:
            shutil.rmtree(staging_dir, ignore_errors=True)
            raise

        record.outputs = outputs
        record.outputs_committed = True
        record.state = "ready"
        record.provider_phase = "ready"
        record.fraction_complete = 1.0
        record.retryable = False
        record.stable_error_code = None
        self.registry.save(jobs)
        return record

    def get(self, logical_job_id: str) -> JobRecord:
        return _require_job(self.registry.load(), logical_job_id)


def _validate_id(value: str, code: str) -> str:
    if not isinstance(value, str) or not _SAFE_ID.fullmatch(value):
        raise OrchestratorError(code)
    return value


def _normalize_models(models: Iterable[str]) -> tuple[str, ...]:
    selected = tuple(dict.fromkeys(models))
    if not selected:
        raise OrchestratorError("SEP_MODELS_EMPTY")
    if any(not isinstance(model, str) or not _SAFE_MODEL.fullmatch(model) for model in selected):
        raise OrchestratorError("SEP_MODEL_INVALID")
    return selected


def _contained_file(path: str | Path, root: Path) -> Path:
    candidate = Path(path).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise OrchestratorError("SEP_SOURCE_OUTSIDE_ROOT") from exc
    if not candidate.is_file():
        raise OrchestratorError("SEP_SOURCE_MISSING")
    if candidate.stat().st_size <= 0:
        raise OrchestratorError("SEP_SOURCE_EMPTY")
    return candidate


def _sha256_file(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    total = 0
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
            total += len(chunk)
    return digest.hexdigest(), total


def _request_fingerprint(project_id: str, asset_id: str, source_sha: str, models: tuple[str, ...]) -> str:
    payload = json.dumps(
        {"project_id": project_id, "asset_id": asset_id, "source_sha256": source_sha, "models": models},
        separators=(",", ":"),
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _stable_error(exc: Exception, fallback: str) -> str:
    code = getattr(exc, "code", None)
    return code if isinstance(code, str) and code else fallback


def _require_job(jobs: dict[str, JobRecord], logical_job_id: str) -> JobRecord:
    if not isinstance(logical_job_id, str) or not re.fullmatch(r"[0-9a-f]{32}", logical_job_id):
        raise OrchestratorError("SEP_LOGICAL_JOB_ID_INVALID")
    try:
        return jobs[logical_job_id]
    except KeyError as exc:
        raise OrchestratorError("SEP_JOB_NOT_FOUND") from exc


def _download_https_streaming(url: str, destination: Path) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise OrchestratorError("SEP_OUTPUT_URL_INVALID")
    request = urllib.request.Request(url, method="GET", headers={"User-Agent": "moises-equivalence/1"})
    try:
        with urllib.request.urlopen(request, timeout=120, context=ssl.create_default_context()) as response:
            if getattr(response, "status", 200) < 200 or getattr(response, "status", 200) >= 300:
                raise OrchestratorError("SEP_OUTPUT_HTTP_FAILED", retryable=True)
            with destination.open("wb") as handle:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    handle.write(chunk)
                handle.flush()
                os.fsync(handle.fileno())
    except OrchestratorError:
        raise
    except Exception as exc:
        raise OrchestratorError("SEP_OUTPUT_DOWNLOAD_FAILED", retryable=True) from exc
