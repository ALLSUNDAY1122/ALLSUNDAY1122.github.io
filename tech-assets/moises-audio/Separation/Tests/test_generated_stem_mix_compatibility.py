import json
import tempfile
import unittest
import wave
from pathlib import Path

from generated_stem_mix_compatibility import (
    EVIDENCE_STATE,
    TOOL_VERSION,
    GeneratedStemVariantStore,
    MixCompatibilityError,
    MixPolicy,
    NormalizationReceipt,
    SourceMixSpec,
    canonical_sha,
    file_sha256,
    plan_normalization,
    validate_mix_ready,
)

H = lambda c: c * 64


def make_wav(path: Path, *, rate=48000, channels=2, frames=4800, width=2, byte_value=1):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(width)
        w.setframerate(rate)
        frame = bytes([byte_value, 0]) * channels if width == 2 else bytes([byte_value]) * width * channels
        w.writeframes(frame * frames)
    return path


class GeneratedStemMixCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source_path = make_wav(self.root / "source.wav")
        self.source = SourceMixSpec.from_wav(self.source_path)
        self.strict = MixPolicy(False, False, False, 0, True)
        self.flex = MixPolicy(True, True, True, 240, True)

    def tearDown(self):
        self.tmp.cleanup()

    def assertCode(self, code, fn):
        with self.assertRaises(MixCompatibilityError) as cm:
            fn()
        self.assertEqual(cm.exception.code, code)

    def plan(self, path, *, policy=None, origin=0):
        return plan_normalization(
            raw_path=path,
            source=self.source,
            policy=policy or self.strict,
            timeline_origin_frames=origin,
            alignment_evidence_sha256=H("a"),
        )

    def normalization_receipt(self, plan, output_path):
        return NormalizationReceipt(
            1,
            TOOL_VERSION,
            EVIDENCE_STATE,
            plan.raw_artifact_sha256,
            file_sha256(output_path),
            canonical_sha(plan.public_dict()),
            H("b"),
            H("c"),
        )

    def test_exact_format_is_direct_mix_ready(self):
        candidate = make_wav(self.root / "candidate.wav")
        plan = self.plan(candidate)
        self.assertTrue(plan.ready_without_normalization)
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=plan)
        self.assertEqual(receipt.frame_count, self.source.frame_count)
        self.assertEqual(receipt.sample_rate, self.source.sample_rate)

    def test_sample_rate_mismatch_fails_closed_by_default(self):
        candidate = make_wav(self.root / "candidate.wav", rate=44100, frames=4410)
        self.assertCode("GEN_MIX_SAMPLE_RATE_MISMATCH", lambda: self.plan(candidate))

    def test_channel_mismatch_fails_closed_by_default(self):
        candidate = make_wav(self.root / "candidate.wav", channels=1)
        self.assertCode("GEN_MIX_CHANNEL_MISMATCH", lambda: self.plan(candidate))

    def test_sample_format_mismatch_fails_closed_by_default(self):
        candidate = make_wav(self.root / "candidate.wav", width=1)
        self.assertCode("GEN_MIX_SAMPLE_FORMAT_MISMATCH", lambda: self.plan(candidate))

    def test_duration_mismatch_fails_closed_by_default(self):
        candidate = make_wav(self.root / "candidate.wav", frames=self.source.frame_count + 1)
        self.assertCode("GEN_MIX_DURATION_MISMATCH", lambda: self.plan(candidate))

    def test_nonzero_timeline_origin_rejected(self):
        candidate = make_wav(self.root / "candidate.wav")
        self.assertCode("GEN_MIX_NONZERO_TIMELINE_ORIGIN", lambda: self.plan(candidate, origin=1))

    def test_explicit_conversion_plan_lists_actions(self):
        candidate = make_wav(self.root / "candidate.wav", rate=44100, channels=1, frames=4410, width=1)
        plan = self.plan(candidate, policy=self.flex)
        self.assertIn("RESAMPLE", plan.actions)
        self.assertIn("CHANNEL_REMIX", plan.actions)
        self.assertIn("SAMPLE_FORMAT_CONVERT", plan.actions)
        self.assertFalse(plan.ready_without_normalization)

    def test_conversion_requires_normalization_provenance(self):
        raw = make_wav(self.root / "raw.wav", rate=44100, frames=4410)
        plan = self.plan(raw, policy=self.flex)
        normalized = make_wav(self.root / "normalized.wav")
        self.assertCode(
            "GEN_MIX_NORMALIZATION_PROVENANCE_REQUIRED",
            lambda: validate_mix_ready(candidate_path=normalized, source=self.source, plan=plan),
        )

    def test_normalization_provenance_binds_raw_plan_and_output(self):
        raw = make_wav(self.root / "raw.wav", rate=44100, frames=4410)
        plan = self.plan(raw, policy=self.flex)
        normalized = make_wav(self.root / "normalized.wav")
        nr = self.normalization_receipt(plan, normalized)
        receipt = validate_mix_ready(candidate_path=normalized, source=self.source, plan=plan, normalization_receipt=nr)
        self.assertEqual(receipt.artifact_sha256, file_sha256(normalized))

    def test_wrong_raw_identity_in_normalization_receipt_is_rejected(self):
        raw = make_wav(self.root / "raw.wav", rate=44100, frames=4410)
        plan = self.plan(raw, policy=self.flex)
        normalized = make_wav(self.root / "normalized.wav")
        nr = self.normalization_receipt(plan, normalized)
        nr = NormalizationReceipt(
            nr.schema_version, nr.tool_version, nr.evidence_state, H("d"), nr.output_artifact_sha256,
            nr.normalization_plan_sha256, nr.normalizer_artifact_sha256, nr.execution_evidence_sha256,
        )
        self.assertCode(
            "GEN_MIX_NORMALIZATION_PROVENANCE_MISMATCH",
            lambda: validate_mix_ready(candidate_path=normalized, source=self.source, plan=plan, normalization_receipt=nr),
        )

    def test_direct_ready_rejects_substituted_artifact(self):
        raw = make_wav(self.root / "raw.wav", byte_value=1)
        plan = self.plan(raw)
        other = make_wav(self.root / "other.wav", byte_value=2)
        self.assertCode(
            "GEN_MIX_DIRECT_ARTIFACT_IDENTITY_MISMATCH",
            lambda: validate_mix_ready(candidate_path=other, source=self.source, plan=plan),
        )

    def test_normalized_artifact_must_exactly_match_source_mix_format(self):
        raw = make_wav(self.root / "raw.wav", rate=44100, frames=4410)
        plan = self.plan(raw, policy=self.flex)
        wrong = make_wav(self.root / "wrong.wav", rate=48000, frames=4799)
        nr = self.normalization_receipt(plan, wrong)
        self.assertCode(
            "GEN_MIX_NORMALIZED_ARTIFACT_NOT_EXACT",
            lambda: validate_mix_ready(candidate_path=wrong, source=self.source, plan=plan, normalization_receipt=nr),
        )

    def test_symlink_audio_rejected(self):
        real = make_wav(self.root / "real.wav")
        link = self.root / "link.wav"
        try:
            link.symlink_to(real)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        self.assertCode("GEN_MIX_SYMLINK_FORBIDDEN", lambda: self.plan(link))

    def test_variant_commit_and_readback(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        item = store.commit_variant(
            project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0,
            candidate_path=candidate, receipt=receipt,
        )
        self.assertEqual(store.get_active(project_ref_hash=H("1"), role="guitar"), item)

    def test_same_variant_is_idempotent(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        a = store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        b = store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        self.assertEqual(a, b)

    def test_same_variant_different_identity_conflicts(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        self.assertCode(
            "GEN_MIX_VARIANT_IDENTITY_CONFLICT",
            lambda: store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("3"), variant_index=0, candidate_path=candidate, receipt=receipt),
        )

    def test_variant_regression_rejected(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=2, candidate_path=candidate, receipt=receipt)
        self.assertCode(
            "GEN_MIX_VARIANT_REGRESSION",
            lambda: store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("3"), variant_index=1, candidate_path=candidate, receipt=receipt),
        )

    def test_new_variant_replaces_pointer_only_after_manifest(self):
        first = make_wav(self.root / "first.wav", byte_value=1)
        second = make_wav(self.root / "second.wav", byte_value=2)
        r1 = validate_mix_ready(candidate_path=first, source=self.source, plan=self.plan(first))
        r2 = validate_mix_ready(candidate_path=second, source=self.source, plan=self.plan(second))
        store = GeneratedStemVariantStore(self.root / "store")
        store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=first, receipt=r1)
        def fault(phase):
            if phase == "after_manifest":
                raise RuntimeError("crash")
        store.fault_injector = fault
        with self.assertRaises(RuntimeError):
            store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("3"), variant_index=1, candidate_path=second, receipt=r2)
        active = store.get_active(project_ref_hash=H("1"), role="guitar")
        self.assertEqual(active.generation_ref_hash, H("2"))

    def test_object_copy_before_pointer_does_not_change_active_variant(self):
        first = make_wav(self.root / "first.wav", byte_value=1)
        second = make_wav(self.root / "second.wav", byte_value=2)
        r1 = validate_mix_ready(candidate_path=first, source=self.source, plan=self.plan(first))
        r2 = validate_mix_ready(candidate_path=second, source=self.source, plan=self.plan(second))
        store = GeneratedStemVariantStore(self.root / "store")
        store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=first, receipt=r1)
        def fault(phase):
            if phase == "after_object":
                raise RuntimeError("crash")
        store.fault_injector = fault
        with self.assertRaises(RuntimeError):
            store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("3"), variant_index=1, candidate_path=second, receipt=r2)
        self.assertEqual(store.get_active(project_ref_hash=H("1"), role="guitar").generation_ref_hash, H("2"))

    def test_mutated_active_object_fails_closed(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        item = store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        obj = store.objects / f"{item.artifact_sha256}.wav"
        with obj.open("ab") as h:
            h.write(b"x")
        self.assertCode("GEN_MIX_RIFF_SIZE_MISMATCH", lambda: store.get_active(project_ref_hash=H("1"), role="guitar"))

    def test_corrupt_active_pointer_fails_closed(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        p = store._active_path(H("1"), "guitar")
        p.write_text("not-json")
        self.assertCode("GEN_MIX_ACTIVE_POINTER_CORRUPT", lambda: store.get_active(project_ref_hash=H("1"), role="guitar"))

    def test_public_evidence_contains_no_path_or_audio(self):
        candidate = make_wav(self.root / "candidate.wav")
        receipt = validate_mix_ready(candidate_path=candidate, source=self.source, plan=self.plan(candidate))
        store = GeneratedStemVariantStore(self.root / "store")
        item = store.commit_variant(project_ref_hash=H("1"), role="guitar", generation_ref_hash=H("2"), variant_index=0, candidate_path=candidate, receipt=receipt)
        evidence = store.privacy_safe_evidence(item)
        self.assertFalse(evidence["path_emitted"])
        self.assertFalse(evidence["raw_audio_emitted"])
        self.assertEqual(evidence["parity_claim"], "NONE")
        self.assertNotIn(str(self.root), json.dumps(evidence))


if __name__ == "__main__":
    unittest.main()
