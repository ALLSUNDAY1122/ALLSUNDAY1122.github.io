from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from production_orchestrator import OrchestratorError
from resumable_long_track_production_orchestrator import _download_https_resumable_bounded
from test_resumable_long_track_production_orchestrator import FakeOpener, FakeResponse


class A41ResumeHTTPContractTests(unittest.TestCase):
    URL = "https://provider.example/stem.wav?sig=token"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.data = root / "stem.wav"
        self.state = root / "stem.resume.json"

    def tearDown(self):
        self.tmp.cleanup()

    def _call(self, opener):
        return _download_https_resumable_bounded(
            self.URL,
            self.data,
            self.state,
            chunk_bytes=4,
            max_bytes=64,
            opener=opener,
        )

    def _prefix(self):
        opener = FakeOpener([
            FakeResponse(
                status=200,
                headers={"ETag": '"v1"', "Content-Length": "10"},
                events=[b"abcd", TimeoutError("cut")],
            )
        ])
        with self.assertRaises(OrchestratorError):
            self._call(opener)

    def test_server_ignoring_range_restarts_from_zero_instead_of_splicing(self):
        self._prefix()
        opener = FakeOpener([
            FakeResponse(
                status=200,
                headers={"ETag": '"v1"', "Content-Length": "10"},
                events=[b"0123", b"4567", b"89"],
            )
        ])
        self._call(opener)
        request_headers = {key.lower(): value for key, value in opener.requests[0].header_items()}
        self.assertEqual(request_headers["range"], "bytes=4-")
        self.assertEqual(self.data.read_bytes(), b"0123456789")

    def test_wrong_content_range_start_fails_closed(self):
        self._prefix()
        opener = FakeOpener([
            FakeResponse(
                status=206,
                headers={
                    "ETag": '"v1"',
                    "Content-Length": "5",
                    "Content-Range": "bytes 5-9/10",
                },
                events=[b"fghij"],
            )
        ])
        with self.assertRaises(OrchestratorError) as caught:
            self._call(opener)
        self.assertEqual(caught.exception.code, "SEP_OUTPUT_RESUME_RANGE_MISMATCH")
        self.assertFalse(self.data.exists())
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
