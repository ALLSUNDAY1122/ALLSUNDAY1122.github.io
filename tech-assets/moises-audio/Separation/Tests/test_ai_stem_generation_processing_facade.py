import hashlib
import json
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
SERVER = HERE.parent / "Server"
sys.path.insert(0, str(SERVER))

from ai_stem_generation_processing_facade import (
    FacadeRecord,
    GeneratedStemProcessingFacade,
    GenerationFacadeError,
    a22_output_path,
    generation_ref_hash,
)
from generated_stem_mix_compatibility import SourceMixSpec

H = lambda c: c * 64


def make_wav(path: Path, *, frames=4800, rate=48000, channels=2, byte=1):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        frame = bytes([byte, 0]) * channels
        w.writeframes(frame * frames)
    return path


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


class FakeNotFound(RuntimeError):
    code = "GEN_RECORD_NOT_FOUND"


class FakeContract:
    def __init__(self):
        self.records = {}
        self.cancel_calls = 0

    def seed(self, intent):
        self.records[intent.logical_generation_id] = SimpleNamespace(
            request_fingerprint=intent.request_fingerprint,
            project_ref_hash=intent.project_ref_hash,
            source_sha256=intent.source_sha256,
            target_role=intent.target_role,
            variant_index=intent.variant_index,
            execution_state="not_attempted",
            lifecycle_state="reserved",
            logical_cancelled=False,
            output_sha256=None,
            output_role=None,
        )

    def get(self, gid):
        if gid not in self.records:
            raise FakeNotFound()
        return self.records[gid]

    def request_cancel(self, gid, *, upstream_cancel_supported):
        self.cancel_calls += 1
        r = self.get(gid)
        r.logical_cancelled = True
        r.lifecycle_state = "cancelled"
        if r.execution_state == "not_attempted":
            r.execution_state = "confirmed_absent"


class FakeDescriptor:
    descriptor_sha256 = H("d")
    supports_cancel = True


class FakeRuntime:
    def __init__(self, contract, root):
        self.contract = contract
        self.descriptor = FakeDescriptor()
        self.project_output_root = Path(root)
        self.project_output_root.mkdir(parents=True, exist_ok=True)
        self.start_calls = 0
        self.reconcile_calls = 0
        self.observe_calls = 0
        self.cancel_calls = 0
        self.start_mode = "BOUND"
        self.observe_mode = "RUNNING"
        self.cancel_raises = False

    def start(self, *, intent, entitlement, source_path, prompt=None, reference_audio_path=None):
        self.start_calls += 1
        if intent.logical_generation_id not in self.contract.records:
            self.contract.seed(intent)
        r = self.contract.get(intent.logical_generation_id)
        if self.start_mode == "RAISE":
            r.execution_state = "ambiguous"
            r.lifecycle_state = "unknown"
            err = RuntimeError("timeout")
            err.code = "GENRT_TRANSPORT_TIMEOUT"
            raise err
        if self.start_mode == "AMBIGUOUS":
            r.execution_state = "ambiguous"
            r.lifecycle_state = "unknown"
        elif self.start_mode == "ABSENT":
            r.execution_state = "confirmed_absent"
            r.lifecycle_state = "failed"
        else:
            r.execution_state = "bound"
            r.lifecycle_state = "generating"
        return {"receipt_sha256": H("1")}

    def reconcile(self, *, logical_generation_id):
        self.reconcile_calls += 1
        r = self.contract.get(logical_generation_id)
        r.execution_state = "bound"
        r.lifecycle_state = "generating"
        return {"receipt_sha256": H("2")}

    def observe(self, *, logical_generation_id):
        self.observe_calls += 1
        r = self.contract.get(logical_generation_id)
        if self.observe_mode == "READY":
            r.execution_state = "bound"
            r.lifecycle_state = "ready"
            r.output_role = r.target_role
            p = a22_output_path(self.project_output_root, logical_generation_id, r.target_role)
            make_wav(p)
            r.output_sha256 = sha(p)
        elif self.observe_mode == "FAILED":
            r.lifecycle_state = "failed"
        elif self.observe_mode == "CANCELLED":
            r.lifecycle_state = "cancelled"
            r.logical_cancelled = True
        else:
            r.lifecycle_state = "generating"
        return {"receipt_sha256": H("3")}

    def cancel(self, *, logical_generation_id):
        self.cancel_calls += 1
        if self.cancel_raises:
            err = RuntimeError("io")
            err.code = "GENRT_TRANSPORT_IO"
            raise err
        r = self.contract.get(logical_generation_id)
        r.logical_cancelled = True
        r.lifecycle_state = "cancelled"
        return {"receipt_sha256": H("4")}

    def sanitized_receipt(self, *args, **kwargs):
        return {"receipt_sha256": H("5")}


class FakeMix:
    policy_sha256 = H("e")

    def __init__(self):
        self.calls = 0
        self.mode = "ACTIVE"

    def finalize(self, **kwargs):
        self.calls += 1
        if self.mode == "NORMALIZE":
            return {"state": "NORMALIZATION_REQUIRED", "plan_sha256": H("6")}
        return {
            "state": "ACTIVE",
            "plan_sha256": H("6"),
            "mix_ready_receipt_sha256": H("7"),
            "artifact_sha256": H("8"),
        }


class FakeRetention:
    retention_policy_sha256 = H("f")

    def __init__(self):
        self.register_calls = 0
        self.delete_calls = 0
        self.register_raises = False

    def register_variant(self, *, generation_ref_hash_value, variant_index):
        self.register_calls += 1
        if self.register_raises:
            self.register_raises = False
            raise RuntimeError("retention crash")
        return SimpleNamespace(generation_ref_hash=generation_ref_hash_value, artifact_sha256=H("8"))

    def request_delete(self, *, generation_ref_hash_value, variant_index, reason, runtime_delete=None, binding_store_path=None):
        self.delete_calls += 1
        return {
            "generation_ref_hash": generation_ref_hash_value,
            "variant_index": variant_index,
            "association_delete_confirmed": True,
        }

    def snapshot(self, **kwargs):
        return {}


class GenerationFacadeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source = make_wav(self.root / "source.wav")
        self.gid = "a" * 32
        self.intent = SimpleNamespace(
            logical_generation_id=self.gid,
            request_fingerprint=H("a"),
            project_ref_hash=H("b"),
            source_sha256=sha(self.source),
            target_role="guitar",
            variant_index=0,
        )
        self.entitlement = SimpleNamespace()
        self.contract = FakeContract()
        self.runtime = FakeRuntime(self.contract, self.root / "out")
        self.mix = FakeMix()
        self.retention = FakeRetention()
        self.facade = GeneratedStemProcessingFacade(
            contract=self.contract,
            runtime=self.runtime,
            mix_gateway=self.mix,
            retention=self.retention,
            journal_path=self.root / "facade.json",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def assertCode(self, code, fn):
        with self.assertRaises(GenerationFacadeError) as cm:
            fn()
        self.assertEqual(cm.exception.code, code)

    def begin(self):
        return self.facade.begin(intent=self.intent, entitlement=self.entitlement, source_path=self.source)

    def ready_runtime(self):
        self.begin()
        self.runtime.observe_mode = "READY"
        self.facade.advance_runtime(self.gid)

    def test_generation_ref_domain_matches_a21(self):
        expected = hashlib.sha256(("l1-a21-generation-ref-v1:" + self.gid).encode()).hexdigest()
        self.assertEqual(generation_ref_hash(self.gid), expected)

    def test_begin_binds_identity_and_starts_once(self):
        s = self.begin()
        self.assertEqual(s["directive"], "OBSERVE_RUNTIME")
        self.assertEqual(self.runtime.start_calls, 1)

    def test_repeated_begin_never_reissues_start(self):
        self.begin()
        self.begin()
        self.assertEqual(self.runtime.start_calls, 1)

    def test_crash_before_a21_record_allows_only_safe_start_retry(self):
        spec = SourceMixSpec.from_wav(self.source)
        rec = FacadeRecord(
            self.gid,
            self.intent.request_fingerprint,
            self.intent.project_ref_hash,
            self.intent.source_sha256,
            spec.sample_rate,
            spec.channels,
            spec.audio_format,
            spec.bits_per_sample,
            spec.frame_count,
            self.intent.target_role,
            self.intent.variant_index,
            generation_ref_hash(self.gid),
            H("d"),
            H("e"),
            H("f"),
            phase="START_CALL_IN_FLIGHT",
        )
        with self.facade.journal.locked() as records:
            records[self.gid] = rec
            self.facade.journal.save(records)
        self.assertNotIn(self.gid, self.contract.records)
        s = self.begin()
        self.assertEqual(self.runtime.start_calls, 1)
        self.assertEqual(s["directive"], "OBSERVE_RUNTIME")

    def test_start_ambiguous_requires_reconcile(self):
        self.runtime.start_mode = "AMBIGUOUS"
        s = self.begin()
        self.assertEqual(s["directive"], "RECONCILE_RUNTIME")
        self.assertEqual(s["phase"], "START_UNKNOWN")

    def test_start_transport_exception_persists_unknown_and_no_second_start(self):
        self.runtime.start_mode = "RAISE"
        with self.assertRaises(RuntimeError):
            self.begin()
        self.runtime.start_mode = "BOUND"
        s = self.begin()
        self.assertEqual(self.runtime.start_calls, 1)
        self.assertEqual(s["directive"], "RECONCILE_RUNTIME")

    def test_reconcile_then_observe(self):
        self.runtime.start_mode = "AMBIGUOUS"
        self.begin()
        s = self.facade.advance_runtime(self.gid)
        self.assertEqual(self.runtime.reconcile_calls, 1)
        self.assertEqual(s["directive"], "OBSERVE_RUNTIME")

    def test_observe_running_is_monotonic(self):
        self.begin()
        s = self.facade.advance_runtime(self.gid)
        self.assertEqual(s["phase"], "RUNTIME_RUNNING")
        self.assertEqual(s["directive"], "OBSERVE_RUNTIME")

    def test_observe_ready_moves_to_finalize_only(self):
        self.ready_runtime()
        s = self.facade.snapshot(self.gid)
        self.assertEqual(s["phase"], "RUNTIME_READY")
        self.assertEqual(s["directive"], "FINALIZE_MIX")
        self.assertEqual(self.mix.calls, 0)

    def test_finalize_mix_then_retention_then_ready(self):
        self.ready_runtime()
        s = self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9"))
        self.assertEqual(self.mix.calls, 1)
        self.assertEqual(self.retention.register_calls, 1)
        self.assertEqual(s["phase"], "READY")
        self.assertEqual(s["directive"], "READY")

    def test_normalization_required_does_not_register_retention(self):
        self.ready_runtime()
        self.mix.mode = "NORMALIZE"
        s = self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9"))
        self.assertEqual(s["phase"], "NORMALIZATION_REQUIRED")
        self.assertEqual(s["directive"], "PROVIDE_NORMALIZED_ARTIFACT")
        self.assertEqual(self.retention.register_calls, 0)

    def test_crash_after_variant_activation_resumes_retention_without_runtime_reexecution(self):
        self.ready_runtime()
        self.retention.register_raises = True
        with self.assertRaises(RuntimeError):
            self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9"))
        s = self.facade.snapshot(self.gid)
        self.assertEqual(s["phase"], "VARIANT_ACTIVE")
        self.assertEqual(s["directive"], "REGISTER_RETENTION")
        starts = self.runtime.start_calls
        observes = self.runtime.observe_calls
        s = self.facade.advance_local(self.gid)
        self.assertEqual(s["phase"], "READY")
        self.assertEqual(self.runtime.start_calls, starts)
        self.assertEqual(self.runtime.observe_calls, observes)

    def test_a22_output_mutation_fails_closed(self):
        self.ready_runtime()
        p = a22_output_path(self.runtime.project_output_root, self.gid, "guitar")
        with p.open("ab") as f:
            f.write(b"x")
        self.assertCode(
            "GEN_FACADE_A22_OUTPUT_MUTATED",
            lambda: self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9")),
        )

    def test_cancel_is_logical_before_external_and_repeated_cancel_does_not_resend(self):
        self.begin()
        s = self.facade.cancel(logical_generation_id=self.gid)
        self.assertTrue(self.contract.get(self.gid).logical_cancelled)
        self.assertEqual(self.runtime.cancel_calls, 1)
        self.facade.cancel(logical_generation_id=self.gid)
        self.assertEqual(self.runtime.cancel_calls, 1)
        self.assertIn(s["phase"], {"CANCELLED", "CANCEL_PENDING"})

    def test_cancel_transport_crash_never_blindly_resends(self):
        self.begin()
        self.runtime.cancel_raises = True
        with self.assertRaises(RuntimeError):
            self.facade.cancel(logical_generation_id=self.gid)
        self.runtime.cancel_raises = False
        s = self.facade.cancel(logical_generation_id=self.gid)
        self.assertEqual(self.runtime.cancel_calls, 1)
        self.assertEqual(s["directive"], "OBSERVE_RUNTIME_NO_CANCEL_RETRY")

    def test_cancelled_output_cannot_be_finalized(self):
        self.begin()
        self.facade.cancel(logical_generation_id=self.gid)
        self.assertCode(
            "GEN_FACADE_MIX_AFTER_CANCEL_FORBIDDEN",
            lambda: self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9")),
        )

    def test_delete_before_variant_forbidden(self):
        self.begin()
        self.assertCode(
            "GEN_FACADE_DELETE_BEFORE_VARIANT_FORBIDDEN",
            lambda: self.facade.request_delete(logical_generation_id=self.gid, reason="USER_DELETE"),
        )

    def test_delete_after_ready_delegates_a24(self):
        self.ready_runtime()
        self.facade.finalize_mix(logical_generation_id=self.gid, alignment_evidence_sha256=H("9"))
        s = self.facade.request_delete(logical_generation_id=self.gid, reason="USER_DELETE")
        self.assertEqual(self.retention.delete_calls, 1)
        self.assertEqual(s["phase"], "DELETED_ASSOCIATION")

    def test_identity_mismatch_fails_closed(self):
        self.begin()
        self.contract.get(self.gid).project_ref_hash = H("c")
        self.assertCode("GEN_FACADE_A21_IDENTITY_MISMATCH", lambda: self.facade.directive(self.gid))

    def test_source_sha_mismatch_fails_before_runtime(self):
        self.intent.source_sha256 = H("0")
        self.assertCode("GEN_FACADE_SOURCE_SHA_MISMATCH", lambda: self.begin())
        self.assertEqual(self.runtime.start_calls, 0)

    def test_constructor_rejects_missing_layer_surface(self):
        bad = SimpleNamespace()
        self.assertCode(
            "GEN_FACADE_A23_SURFACE_MISSING",
            lambda: GeneratedStemProcessingFacade(
                contract=self.contract,
                runtime=self.runtime,
                mix_gateway=bad,
                retention=self.retention,
                journal_path=self.root / "x.json",
            ),
        )

    def test_corrupt_journal_fails_closed(self):
        self.begin()
        (self.root / "facade.json").write_text("{broken")
        self.assertCode("GEN_FACADE_JOURNAL_CORRUPT", lambda: self.facade.snapshot(self.gid))

    def test_public_snapshot_redacts_private_identity_and_paths(self):
        s = self.begin()
        encoded = json.dumps(s)
        self.assertNotIn('"logical_generation_id"', encoded)
        self.assertNotIn(str(self.root), encoded)
        self.assertFalse(s["privacy"]["raw_logical_generation_id_emitted"])
        self.assertEqual(s["parity_claim"], "NONE")


if __name__ == "__main__":
    unittest.main()
