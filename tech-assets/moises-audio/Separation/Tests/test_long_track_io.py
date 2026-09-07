import tempfile
import tracemalloc
import unittest
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from long_track_io import GIB, MIB, LongTrackIOError, LongTrackIOGuard, LongTrackPolicy


class LongTrackIOTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_policy_rejects_unproven_parallel_downloads(self):
        with self.assertRaisesRegex(LongTrackIOError, "SEP_LONG_TRACK_CONCURRENCY_UNSUPPORTED"):
            LongTrackPolicy(max_parallel_transfers=2).validate()

    def test_source_boundary_accepts_exact_limit_and_rejects_above(self):
        guard = LongTrackIOGuard(LongTrackPolicy(max_source_bytes=2 * GIB))
        guard.validate_source_size(2 * GIB)
        with self.assertRaisesRegex(LongTrackIOError, "SEP_SOURCE_TOO_LARGE"):
            guard.validate_source_size(2 * GIB + 1)

    def test_storage_formula_accounts_all_stems_plus_reserve(self):
        policy = LongTrackPolicy(
            output_estimate_ratio_per_target=2.0,
            max_output_ratio_per_target=4.0,
            minimum_estimated_stem_bytes=1,
            minimum_max_stem_bytes=1,
            safety_reserve_bytes=100,
        )
        guard = LongTrackIOGuard(policy, free_bytes_provider=lambda _: 10_000)
        result = guard.estimate_storage(self.root, source_bytes=1_000, target_count=4)
        self.assertEqual(result.estimated_stem_bytes, 2_000)
        self.assertEqual(result.estimated_output_bytes, 8_000)
        self.assertEqual(result.required_free_bytes, 8_100)
        self.assertEqual(result.max_single_stem_bytes, 4_000)

    def test_insufficient_storage_is_retryable_and_preflight_only(self):
        policy = LongTrackPolicy(
            output_estimate_ratio_per_target=1.0,
            max_output_ratio_per_target=2.0,
            minimum_estimated_stem_bytes=1,
            minimum_max_stem_bytes=1,
            safety_reserve_bytes=100,
        )
        guard = LongTrackIOGuard(policy, free_bytes_provider=lambda _: 500)
        with self.assertRaises(LongTrackIOError) as caught:
            guard.require_storage(self.root, source_bytes=1_000, target_count=1)
        self.assertEqual(caught.exception.code, "SEP_STORAGE_PREFLIGHT_INSUFFICIENT")
        self.assertTrue(caught.exception.retryable)

    def test_stream_limit_removes_partial_destination(self):
        source = self.root / "source.bin"
        source.write_bytes(b"x" * (3 * MIB))
        destination = self.root / "out.bin"
        guard = LongTrackIOGuard(LongTrackPolicy(chunk_bytes=MIB))
        with self.assertRaisesRegex(LongTrackIOError, "SEP_OUTPUT_STREAM_TOO_LARGE"):
            guard.stream_copy_file(source, destination, max_bytes=2 * MIB)
        self.assertFalse(destination.exists())

    def test_empty_stream_is_rejected_and_removed(self):
        source = self.root / "empty.bin"
        source.write_bytes(b"")
        destination = self.root / "out.bin"
        guard = LongTrackIOGuard()
        with self.assertRaisesRegex(LongTrackIOError, "SEP_OUTPUT_COPY_EMPTY"):
            guard.stream_copy_file(source, destination)
        self.assertFalse(destination.exists())

    def test_128_mib_stream_copy_has_bounded_python_memory(self):
        source = self.root / "large.bin"
        size = 128 * MIB + 123
        with source.open("wb") as handle:
            handle.truncate(size)
        destination = self.root / "copied.bin"
        guard = LongTrackIOGuard(LongTrackPolicy(chunk_bytes=MIB))
        tracemalloc.start()
        try:
            stats = guard.stream_copy_file(source, destination, max_bytes=size)
            _, peak = tracemalloc.get_traced_memory()
        finally:
            tracemalloc.stop()
        self.assertEqual(stats.byte_count, size)
        self.assertLessEqual(stats.max_chunk_bytes, MIB)
        self.assertLess(peak, 8 * MIB)
        self.assertEqual(destination.stat().st_size, size)


if __name__ == "__main__":
    unittest.main()
