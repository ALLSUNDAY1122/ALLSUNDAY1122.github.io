import tempfile
import unittest
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from audioshake_api import AudioShakeClient, AudioShakeConfig


class FakeHTTPResponse:
    status = 200

    def read(self):
        return b'{"id":"asset-streamed"}'


class RecordingConnection:
    def __init__(self):
        self.sent_sizes = []
        self.headers = {}

    def putrequest(self, method, path):
        self.method = method
        self.path = path

    def putheader(self, name, value):
        self.headers[name.lower()] = value

    def endheaders(self):
        pass

    def send(self, data):
        self.sent_sizes.append(len(data))

    def getresponse(self):
        return FakeHTTPResponse()

    def close(self):
        pass


class StreamingClient(AudioShakeClient):
    def __init__(self):
        super().__init__(AudioShakeConfig(api_key="server-secret"))
        self.connection = RecordingConnection()

    def _connection(self):
        return self.connection


class AudioShakeStreamingTests(unittest.TestCase):
    def test_upload_sends_large_asset_in_one_mib_or_smaller_chunks(self):
        client = StreamingClient()
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "large.wav"
            size = 8 * 1024 * 1024 + 123
            with source.open("wb") as handle:
                handle.truncate(size)
            asset_id = client.upload_asset(source)
        self.assertEqual(asset_id, "asset-streamed")
        # First/last sends are multipart prefix/suffix. Every file-body send must remain <= 1 MiB.
        body_sends = client.connection.sent_sizes[1:-1]
        self.assertGreater(len(body_sends), 1)
        self.assertLessEqual(max(body_sends), 1024 * 1024)
        self.assertEqual(sum(body_sends), size)
        self.assertEqual(
            int(client.connection.headers["content-length"]),
            sum(client.connection.sent_sizes),
        )


if __name__ == "__main__":
    unittest.main()
