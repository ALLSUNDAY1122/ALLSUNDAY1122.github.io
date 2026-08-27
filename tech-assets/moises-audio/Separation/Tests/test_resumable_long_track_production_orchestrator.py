from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from production_orchestrator import OrchestratorError
from resumable_long_track_production_orchestrator import (
    _download_https_resumable_bounded,
)


class FakeResponse:
    def __init__(self, *, status: int, headers: dict[str, str], events: list[bytes | BaseException]):
        self.status = status
        self.headers = headers
        self._events = list(events)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self, _size: int) -> bytes:
        if not self._events:
            return b""
        event = self._events.pop(0)
        if isinstance(event, BaseException):
            raise event
        return event


class FakeOpener:
    def __init__(self, responses: list[FakeResponse]):
        self.responses = list(responses)
        self.requests = []

    def __call__(self, request, **_kwargs):
        self.requests.append(request)
        if not self.responses:
            raise AssertionError("unexpected network call")
        return self.responses.pop(0)


class CrashResumableLongTrackDownloadTests(unittest.TestCase):
    URL = "https://provider.example/output.wav?sig=private-token"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.data = self.root / "vocals.wav"
        self.state = self.root / "vocals.resume.json"

    def tearDown(self):
        self.tmp.cleanup()

    def _download(self, opener: FakeOpener, *, url: str | None = None, max_bytes: int = 64):
        return _download_https_resumable_bounded(
            url or self.URL,
            self.data,
            self.state,
            chunk_bytes=4,
            max_bytes=max_bytes,
            opener=opener,
        )

    def _create_resumable_prefix(self):
        first = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v1"', "Content-Length": "10"},
                    events=[b"abcd", TimeoutError("network interruption")],
                )
            ]
        )
        with self.assertRaises(OrchestratorError) as caught:
            self._download(first)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_DOWNLOAD_FAILED")
        self.assertEqual(self.data.read_bytes(), b"abcd")
        self.assertTrue(self.state.is_file())

    def test_interrupted_download_resumes_with_range_and_if_range(self):
        self._create_resumable_prefix()
        second = FakeOpener(
            [
                FakeResponse(
                    status=206,
                    headers={
                        "ETag": '"v1"',
                        "Content-Length": "6",
                        "Content-Range": "bytes 4-9/10",
                    },
                    events=[b"efgh", b"ij"],
                )
            ]
        )
        stats = self._download(second)
        headers = {key.lower(): value for key, value in second.requests[0].header_items()}
        self.assertEqual(headers.get("range"), "bytes=4-")
        self.assertEqual(headers.get("if-range"), '"v1"')
        self.assertEqual(self.data.read_bytes(), b"abcdefghij")
        self.assertEqual(stats.byte_count, 10)
        self.assertTrue(json.loads(self.state.read_text(encoding="utf-8"))["complete"])

    def test_completed_cache_reuses_bytes_without_network(self):
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v1"', "Content-Length": "4"},
                    events=[b"done"],
                )
            ]
        )
        self._download(opener)
        no_network = FakeOpener([])
        stats = self._download(no_network)
        self.assertEqual(stats.byte_count, 4)
        self.assertEqual(no_network.requests, [])

    def test_signed_url_rotation_discards_partial_and_restarts(self):
        self._create_resumable_prefix()
        rotated = "https://provider.example/output.wav?sig=rotated"
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v2"', "Content-Length": "6"},
                    events=[b"new123"],
                )
            ]
        )
        self._download(opener, url=rotated)
        headers = {key.lower(): value for key, value in opener.requests[0].header_items()}
        self.assertNotIn("range", headers)
        self.assertEqual(self.data.read_bytes(), b"new123")

    def test_validator_mismatch_fails_closed_and_removes_partial_pair(self):
        self._create_resumable_prefix()
        opener = FakeOpener(
            [
                FakeResponse(
                    status=206,
                    headers={
                        "ETag": '"v2"',
                        "Content-Length": "6",
                        "Content-Range": "bytes 4-9/10",
                    },
                    events=[b"efghij"],
                )
            ]
        )
        with self.assertRaises(OrchestratorError) as caught:
            self._download(opener)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_VALIDATOR_MISMATCH")
        self.assertFalse(self.data.exists())
        self.assertFalse(self.state.exists())

    def test_no_strong_etag_never_retains_unsafe_prefix(self):
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"Content-Length": "10"},
                    events=[b"abcd", TimeoutError("network interruption")],
                )
            ]
        )
        with self.assertRaises(OrchestratorError):
            self._download(opener)
        self.assertFalse(self.data.exists())
        self.assertFalse(self.state.exists())

    def test_declared_output_above_cap_is_rejected_before_body(self):
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v1"', "Content-Length": "65"},
                    events=[b"x"],
                )
            ]
        )
        with self.assertRaises(OrchestratorError) as caught:
            self._download(opener, max_bytes=64)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_STREAM_TOO_LARGE")
        self.assertFalse(self.data.exists())
        self.assertFalse(self.state.exists())

    def test_truncated_known_length_keeps_validator_bound_prefix(self):
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v1"', "Content-Length": "10"},
                    events=[b"abcd"],
                )
            ]
        )
        with self.assertRaises(OrchestratorError) as caught:
            self._download(opener)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_DOWNLOAD_TRUNCATED")
        self.assertEqual(self.data.read_bytes(), b"abcd")
        self.assertTrue(self.state.exists())

    def test_resume_sidecar_never_persists_raw_signed_url(self):
        opener = FakeOpener(
            [
                FakeResponse(
                    status=200,
                    headers={"ETag": '"v1"', "Content-Length": "4"},
                    events=[b"done"],
                )
            ]
        )
        self._download(opener)
        raw = self.state.read_text(encoding="utf-8")
        self.assertNotIn(self.URL, raw)
        parsed = json.loads(raw)
        self.assertRegex(parsed["url_ref_sha256"], r"^[0-9a-f]{64}$")

    def test_hardlink_materialization_keeps_data_after_cache_link_removed(self):
        cache = self.root / "cache.wav"
        destination = self.root / "staging.wav"
        cache.write_bytes(b"stem-data")
        os.link(cache, destination)
        self.assertEqual(cache.stat().st_ino, destination.stat().st_ino)
        cache.unlink()
        self.assertEqual(destination.read_bytes(), b"stem-data")


if __name__ == "__main__":
    unittest.main()
