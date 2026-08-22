"""Minimal server-side AudioShake API adapter for MOI-SEP-002.

This module intentionally keeps the vendor API key on the server side. It does not imply that
AudioShake has been commercially approved for shipping; production enablement still requires HQ
terms/privacy/cost review and real-audio quality evidence.
"""

from __future__ import annotations

import http.client
import json
import os
import ssl
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse


AUDIOSHAKE_MAX_ASSET_BYTES = 2 * 1024 * 1024 * 1024
SUPPORTED_CORE_MODELS = frozenset({"vocals", "drums", "bass", "other", "instrumental"})


class AudioShakeAPIError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool = False, status: int | None = None):
        super().__init__(code)
        self.code = code
        self.retryable = retryable
        self.status = status


@dataclass(frozen=True)
class AudioShakeConfig:
    api_key: str
    base_url: str = "https://api.audioshake.ai"
    timeout_seconds: float = 120.0

    def validate(self) -> None:
        parsed = urlparse(self.base_url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise AudioShakeAPIError("AUDIOSHAKE_INSECURE_BASE_URL")
        if not self.api_key or "\r" in self.api_key or "\n" in self.api_key:
            raise AudioShakeAPIError("AUDIOSHAKE_API_KEY_INVALID")


@dataclass(frozen=True)
class AudioShakeTargetState:
    model: str
    status: str
    output_url: str | None
    error_code: str | None


@dataclass(frozen=True)
class AudioShakeTaskState:
    task_id: str
    phase: str
    fraction_complete: float
    retryable: bool
    stable_error_code: str | None
    targets: tuple[AudioShakeTargetState, ...]


class AudioShakeClient:
    def __init__(self, config: AudioShakeConfig):
        config.validate()
        self.config = config
        self._parsed = urlparse(config.base_url)

    def upload_asset(self, source_path: str | Path) -> str:
        path = Path(source_path)
        if not path.is_file():
            raise AudioShakeAPIError("AUDIOSHAKE_SOURCE_MISSING")
        size = path.stat().st_size
        if size <= 0:
            raise AudioShakeAPIError("AUDIOSHAKE_SOURCE_EMPTY")
        if size > AUDIOSHAKE_MAX_ASSET_BYTES:
            raise AudioShakeAPIError("AUDIOSHAKE_SOURCE_TOO_LARGE")

        boundary = f"moises-equivalence-{uuid.uuid4().hex}"
        filename = path.name.replace('"', "_").replace("\r", "_").replace("\n", "_")
        prefix = (
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"file\"; filename=\"{filename}\"\r\n"
            "Content-Type: application/octet-stream\r\n\r\n"
        ).encode("utf-8")
        suffix = f"\r\n--{boundary}--\r\n".encode("utf-8")

        conn = self._connection()
        try:
            conn.putrequest("POST", self._path("/assets"))
            conn.putheader("x-api-key", self.config.api_key)
            conn.putheader("Content-Type", f"multipart/form-data; boundary={boundary}")
            conn.putheader("Content-Length", str(len(prefix) + size + len(suffix)))
            conn.putheader("Accept", "application/json")
            conn.endheaders()
            conn.send(prefix)
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    conn.send(chunk)
            conn.send(suffix)
            payload = self._read_json_response(conn.getresponse())
        finally:
            conn.close()

        asset_id = payload.get("id")
        if not isinstance(asset_id, str) or not asset_id:
            raise AudioShakeAPIError("AUDIOSHAKE_ASSET_RESPONSE_INVALID")
        return asset_id

    def create_separation_task(
        self,
        asset_id: str,
        models: Iterable[str],
        *,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        selected = tuple(dict.fromkeys(models))
        if not asset_id:
            raise AudioShakeAPIError("AUDIOSHAKE_ASSET_ID_MISSING")
        if not selected:
            raise AudioShakeAPIError("AUDIOSHAKE_NO_TARGETS")
        unknown = [model for model in selected if model not in SUPPORTED_CORE_MODELS]
        if unknown:
            raise AudioShakeAPIError("AUDIOSHAKE_UNSUPPORTED_TARGET:" + ",".join(sorted(unknown)))

        body: dict[str, Any] = {
            "assetId": asset_id,
            "targets": [{"model": model, "formats": ["wav"]} for model in selected],
        }
        if metadata is not None:
            encoded_metadata = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
            if len(encoded_metadata.encode("utf-8")) > 4096:
                raise AudioShakeAPIError("AUDIOSHAKE_METADATA_TOO_LARGE")
            body["metadata"] = encoded_metadata

        payload = self._json_request("POST", "/tasks", body)
        task_id = payload.get("id")
        if not isinstance(task_id, str) or not task_id:
            raise AudioShakeAPIError("AUDIOSHAKE_TASK_RESPONSE_INVALID")
        return task_id

    def get_task_state(self, task_id: str) -> AudioShakeTaskState:
        if not task_id or "/" in task_id or "?" in task_id:
            raise AudioShakeAPIError("AUDIOSHAKE_TASK_ID_INVALID")
        payload = self._json_request("GET", f"/tasks/{task_id}")
        return parse_task_state(payload)

    def _json_request(self, method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        encoded = None if body is None else json.dumps(body, separators=(",", ":")).encode("utf-8")
        conn = self._connection()
        headers = {"x-api-key": self.config.api_key, "Accept": "application/json"}
        if encoded is not None:
            headers["Content-Type"] = "application/json"
        try:
            conn.request(method, self._path(path), body=encoded, headers=headers)
            return self._read_json_response(conn.getresponse())
        finally:
            conn.close()

    def _connection(self) -> http.client.HTTPSConnection:
        return http.client.HTTPSConnection(
            self._parsed.hostname,
            self._parsed.port or 443,
            timeout=self.config.timeout_seconds,
            context=ssl.create_default_context(),
        )

    def _path(self, path: str) -> str:
        prefix = self._parsed.path.rstrip("/")
        return f"{prefix}{path}" if prefix else path

    @staticmethod
    def _read_json_response(response: http.client.HTTPResponse) -> dict[str, Any]:
        raw = response.read()
        if not 200 <= response.status < 300:
            retryable = response.status in {408, 429} or response.status >= 500
            raise AudioShakeAPIError(
                f"AUDIOSHAKE_HTTP_{response.status}", retryable=retryable, status=response.status
            )
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise AudioShakeAPIError("AUDIOSHAKE_RESPONSE_INVALID_JSON") from exc
        if not isinstance(payload, dict):
            raise AudioShakeAPIError("AUDIOSHAKE_RESPONSE_INVALID_SHAPE")
        return payload


def parse_task_state(payload: dict[str, Any]) -> AudioShakeTaskState:
    task_id = payload.get("id")
    targets = payload.get("targets")
    if not isinstance(task_id, str) or not task_id or not isinstance(targets, list) or not targets:
        raise AudioShakeAPIError("AUDIOSHAKE_TASK_STATE_INVALID")

    parsed_targets: list[AudioShakeTargetState] = []
    completed = 0
    first_error: str | None = None

    for target in targets:
        if not isinstance(target, dict):
            raise AudioShakeAPIError("AUDIOSHAKE_TARGET_STATE_INVALID")
        model = target.get("model")
        status = target.get("status")
        if not isinstance(model, str) or not model or status not in {"processing", "completed", "error"}:
            raise AudioShakeAPIError("AUDIOSHAKE_TARGET_STATE_INVALID")

        output_url: str | None = None
        error_code: str | None = None
        if status == "completed":
            completed += 1
            outputs = target.get("output")
            if not isinstance(outputs, list) or not outputs:
                raise AudioShakeAPIError("AUDIOSHAKE_COMPLETED_WITHOUT_OUTPUT")
            wav_outputs = [item for item in outputs if isinstance(item, dict) and item.get("format") == "wav"]
            if not wav_outputs or not isinstance(wav_outputs[0].get("link"), str):
                raise AudioShakeAPIError("AUDIOSHAKE_WAV_OUTPUT_MISSING")
            candidate = wav_outputs[0]["link"]
            if urlparse(candidate).scheme != "https":
                raise AudioShakeAPIError("AUDIOSHAKE_OUTPUT_URL_INSECURE")
            output_url = candidate
        elif status == "error":
            error = target.get("error")
            vendor_code = error.get("code") if isinstance(error, dict) else None
            error_code = f"AUDIOSHAKE_TARGET_ERROR_{vendor_code if vendor_code is not None else 'UNKNOWN'}"
            first_error = first_error or error_code

        parsed_targets.append(AudioShakeTargetState(model, status, output_url, error_code))

    if first_error:
        phase = "failed"
        retryable = False
    elif completed == len(parsed_targets):
        phase = "ready"
        retryable = False
    else:
        phase = "separating"
        retryable = True

    return AudioShakeTaskState(
        task_id=task_id,
        phase=phase,
        fraction_complete=completed / len(parsed_targets),
        retryable=retryable,
        stable_error_code=first_error,
        targets=tuple(parsed_targets),
    )


def api_key_from_environment(name: str = "AUDIOSHAKE_API_KEY") -> str:
    value = os.environ.get(name, "")
    if not value:
        raise AudioShakeAPIError("AUDIOSHAKE_API_KEY_MISSING")
    return value
