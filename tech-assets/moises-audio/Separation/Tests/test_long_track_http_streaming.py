import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from long_track_production_orchestrator import _download_https_streaming_bounded
from production_orchestrator import OrchestratorError


class FakeResponse:
    status = 200

    def __init__(self, chunks, content_length=None):
        self._chunks = list(chunks)
        self.headers = {}
        if content_length is not None:
            self.headers["Content-Length"] = str(content_length)
        self.read_calls = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self, requested):
        self.read_calls += 1
        if not self._chunks:
            return b""
        chunk = self._chunks.pop(0)
        if len(chunk) > requested:
            self._chunks.insert(0, chunk[requested:])
            return chunk[:requested]
        return chunk


class HTTPStreamingTests(unittest.TestCase):
    def test_declared_oversize_is_rejected_before_body_read(self):
        response = FakeResponse([b"x" * 16], content_length=101)
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "out.wav"
            with patch("long_track_production_orchestrator.urllib.request.urlopen", return_value=response):
                with self.assertRaisesRegex(OrchestratorError, "SEP_OUTPUT_STREAM_TOO_LARGE"):
                    _download_https_streaming_bounded(
                        "https://example.test/out.wav",
                        destination,
                        chunk_bytes=8,
                        max_bytes=100,
                    )
            self.assertEqual(response.read_calls, 0)
            self.assertFalse(destination.exists())

    def test_undeclared_oversize_is_rejected_during_stream_and_partial_removed(self):
        response = FakeResponse([b"a" * 8, b"b" * 8], content_length=None)
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "out.wav"
            with patch("long_track_production_orchestrator.urllib.request.urlopen", return_value=response):
                with self.assertRaisesRegex(OrchestratorError, "SEP_OUTPUT_STREAM_TOO_LARGE"):
                    _download_https_streaming_bounded(
                        "https://example.test/out.wav",
                        destination,
                        chunk_bytes=8,
                        max_bytes=12,
                    )
            self.assertFalse(destination.exists())

    def test_success_reports_bytes_chunks_and_peak_chunk(self):
        response = FakeResponse([b"a" * 8, b"b" * 5], content_length=13)
        clock = iter([10.0, 10.125])
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "out.wav"
            with patch("long_track_production_orchestrator.urllib.request.urlopen", return_value=response):
                stats = _download_https_streaming_bounded(
                    "https://example.test/out.wav",
                    destination,
                    chunk_bytes=8,
                    max_bytes=20,
                    monotonic=lambda: next(clock),
                )
            self.assertEqual(stats.byte_count, 13)
            self.assertEqual(stats.chunk_count, 2)
            self.assertEqual(stats.max_chunk_bytes, 8)
            self.assertEqual(stats.elapsed_milliseconds, 125)
            self.assertEqual(destination.stat().st_size, 13)

    def test_invalid_content_length_fails_closed(self):
        response = FakeResponse([b"x"], content_length=None)
        response.headers["Content-Length"] = "not-an-int"
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "out.wav"
            with patch("long_track_production_orchestrator.urllib.request.urlopen", return_value=response):
                with self.assertRaisesRegex(OrchestratorError, "SEP_OUTPUT_CONTENT_LENGTH_INVALID"):
                    _download_https_streaming_bounded(
                        "https://example.test/out.wav",
                        destination,
                        chunk_bytes=8,
                        max_bytes=20,
                    )
            self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
