"""L1-A23 generated-stem timing / mix compatibility hardening (NON-PARITY)."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import struct
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A23-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")


class MixCompatibilityError(RuntimeError):
    def __init__(self, code: str, message: str = "generated stem mix compatibility failure"):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


def fail(code: str, message: str = "generated stem mix compatibility failure"):
    raise MixCompatibilityError(code, message)


def _sha(v: str, field: str) -> str:
    if not isinstance(v, str):
        fail("GEN_MIX_SHA_INVALID", field)
    x = v.strip().lower().removeprefix("sha256:")
    if not HEX64.fullmatch(x):
        fail("GEN_MIX_SHA_INVALID", field)
    return x


def _safe(v: str, field: str) -> str:
    if not isinstance(v, str) or not SAFE.fullmatch(v.strip()):
        fail("GEN_MIX_SAFE_ID_INVALID", field)
    return v.strip()


def _int(v, field: str, lo: int = 0) -> int:
    if isinstance(v, bool) or not isinstance(v, int) or v < lo:
        fail("GEN_MIX_INTEGER_INVALID", field)
    return v


def _bool(v, field: str) -> bool:
    if not isinstance(v, bool):
        fail("GEN_MIX_BOOL_INVALID", field)
    return v


def canonical_sha(value) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


def file_sha256(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            b = f.read(chunk_size)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


@dataclass(frozen=True)
class WAVFormat:
    artifact_sha256: str
    file_bytes: int
    audio_format: int
    sample_rate: int
    channels: int
    bits_per_sample: int
    block_align: int
    frame_count: int

    @property
    def duration_seconds(self) -> float:
        return self.frame_count / self.sample_rate

    def public_dict(self):
        return asdict(self) | {"duration_seconds": self.duration_seconds}


def inspect_wav(path) -> WAVFormat:
    raw_path = Path(path)
    if raw_path.is_symlink():
        fail("GEN_MIX_SYMLINK_FORBIDDEN")
    try:
        st = raw_path.stat()
    except OSError as e:
        raise MixCompatibilityError("GEN_MIX_FILE_UNREADABLE") from e
    if not raw_path.is_file() or st.st_size < 44:
        fail("GEN_MIX_WAV_TRUNCATED")
    digest = file_sha256(raw_path)
    with raw_path.open("rb") as f:
        head = f.read(12)
        if len(head) != 12 or head[0:4] != b"RIFF" or head[8:12] != b"WAVE":
            fail("GEN_MIX_WAV_INVALID")
        declared = struct.unpack_from("<I", head, 4)[0] + 8
        if declared != st.st_size:
            fail("GEN_MIX_RIFF_SIZE_MISMATCH")
        fmt = None
        data_bytes = None
        seen_fmt = seen_data = 0
        pos = 12
        while pos < declared:
            if declared - pos < 8:
                fail("GEN_MIX_WAV_TRUNCATED")
            f.seek(pos)
            hdr = f.read(8)
            if len(hdr) != 8:
                fail("GEN_MIX_WAV_TRUNCATED")
            cid, size = hdr[:4], struct.unpack_from("<I", hdr, 4)[0]
            payload = pos + 8
            padded = size + (size & 1)
            if payload + padded > declared:
                fail("GEN_MIX_WAV_CHUNK_OVERRUN")
            if cid == b"fmt ":
                seen_fmt += 1
                if seen_fmt != 1 or size < 16 or size > 1024:
                    fail("GEN_MIX_WAV_FMT_INVALID")
                f.seek(payload)
                b = f.read(size)
                if len(b) != size:
                    fail("GEN_MIX_WAV_TRUNCATED")
                audio_format, channels, sample_rate, byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", b, 0)
                if audio_format == 0xFFFE:
                    if size < 40 or struct.unpack_from("<H", b, 16)[0] < 22:
                        fail("GEN_MIX_WAV_EXTENSIBLE_INVALID")
                    audio_format = struct.unpack_from("<H", b, 24)[0]
                fmt = (audio_format, channels, sample_rate, byte_rate, block_align, bits)
            elif cid == b"data":
                seen_data += 1
                if seen_data != 1 or size <= 0:
                    fail("GEN_MIX_WAV_DATA_INVALID")
                data_bytes = size
            pos = payload + padded
        if pos != declared or fmt is None or data_bytes is None:
            fail("GEN_MIX_WAV_METADATA_INVALID")
    audio_format, channels, sample_rate, byte_rate, block_align, bits = fmt
    if audio_format not in {1, 3}:
        fail("GEN_MIX_WAV_CODEC_UNSUPPORTED")
    if not (1 <= channels <= 64 and 8000 <= sample_rate <= 384000 and bits > 0 and bits % 8 == 0):
        fail("GEN_MIX_WAV_METADATA_INVALID")
    supported = {8, 16, 24, 32} if audio_format == 1 else {32, 64}
    if bits not in supported:
        fail("GEN_MIX_WAV_SAMPLE_FORMAT_UNSUPPORTED")
    expected_block = channels * bits // 8
    if block_align != expected_block or byte_rate != sample_rate * block_align:
        fail("GEN_MIX_WAV_RATE_ALIGNMENT_INVALID")
    if data_bytes % block_align:
        fail("GEN_MIX_WAV_DATA_ALIGNMENT_INVALID")
    frames = data_bytes // block_align
    if frames <= 0:
        fail("GEN_MIX_WAV_METADATA_INVALID")
    return WAVFormat(digest, st.st_size, audio_format, sample_rate, channels, bits, block_align, frames)


@dataclass(frozen=True)
class SourceMixSpec:
    source_sha256: str
    sample_rate: int
    channels: int
    audio_format: int
    bits_per_sample: int
    frame_count: int

    @classmethod
    def from_wav(cls, path):
        w = inspect_wav(path)
        return cls(w.artifact_sha256, w.sample_rate, w.channels, w.audio_format, w.bits_per_sample, w.frame_count)

    def validate(self):
        _sha(self.source_sha256, "source_sha256")
        _int(self.sample_rate, "sample_rate", 8000)
        _int(self.channels, "channels", 1)
        _int(self.audio_format, "audio_format", 1)
        _int(self.bits_per_sample, "bits_per_sample", 1)
        _int(self.frame_count, "frame_count", 1)


@dataclass(frozen=True)
class MixPolicy:
    allow_resample: bool
    allow_channel_remix: bool
    allow_sample_format_convert: bool
    max_edge_adjustment_frames: int
    require_zero_timeline_origin: bool = True

    def validate(self):
        _bool(self.allow_resample, "allow_resample")
        _bool(self.allow_channel_remix, "allow_channel_remix")
        _bool(self.allow_sample_format_convert, "allow_sample_format_convert")
        _int(self.max_edge_adjustment_frames, "max_edge_adjustment_frames", 0)
        _bool(self.require_zero_timeline_origin, "require_zero_timeline_origin")

    @property
    def policy_sha256(self):
        self.validate()
        return canonical_sha({"schema_version": 1, **asdict(self)})


@dataclass(frozen=True)
class NormalizationPlan:
    schema_version: int
    tool_version: str
    evidence_state: str
    raw_artifact_sha256: str
    source_sha256: str
    policy_sha256: str
    timeline_origin_frames: int
    alignment_evidence_sha256: str
    actions: tuple[str, ...]
    projected_frame_count: int
    ready_without_normalization: bool

    def public_dict(self):
        d = asdict(self)
        d["actions"] = list(self.actions)
        d["parity_claim"] = "NONE"
        return d


def plan_normalization(
    *,
    raw_path,
    source: SourceMixSpec,
    policy: MixPolicy,
    timeline_origin_frames: int,
    alignment_evidence_sha256: str,
) -> NormalizationPlan:
    source.validate()
    policy.validate()
    origin = _int(timeline_origin_frames, "timeline_origin_frames", 0)
    align = _sha(alignment_evidence_sha256, "alignment_evidence_sha256")
    if policy.require_zero_timeline_origin and origin != 0:
        fail("GEN_MIX_NONZERO_TIMELINE_ORIGIN")
    raw = inspect_wav(raw_path)
    actions = []
    if raw.sample_rate != source.sample_rate:
        if not policy.allow_resample:
            fail("GEN_MIX_SAMPLE_RATE_MISMATCH")
        actions.append("RESAMPLE")
    if raw.channels != source.channels:
        if not policy.allow_channel_remix:
            fail("GEN_MIX_CHANNEL_MISMATCH")
        actions.append("CHANNEL_REMIX")
    if raw.audio_format != source.audio_format or raw.bits_per_sample != source.bits_per_sample:
        if not policy.allow_sample_format_convert:
            fail("GEN_MIX_SAMPLE_FORMAT_MISMATCH")
        actions.append("SAMPLE_FORMAT_CONVERT")
    projected = round(raw.frame_count * source.sample_rate / raw.sample_rate)
    delta = projected - source.frame_count
    if delta:
        if abs(delta) > policy.max_edge_adjustment_frames:
            fail("GEN_MIX_DURATION_MISMATCH")
        actions.append("TRIM_END" if delta > 0 else "PAD_END")
        projected = source.frame_count
    return NormalizationPlan(
        1, TOOL_VERSION, EVIDENCE_STATE, raw.artifact_sha256, source.source_sha256,
        policy.policy_sha256, origin, align, tuple(actions), projected, not actions
    )


@dataclass(frozen=True)
class NormalizationReceipt:
    schema_version: int
    tool_version: str
    evidence_state: str
    input_artifact_sha256: str
    output_artifact_sha256: str
    normalization_plan_sha256: str
    normalizer_artifact_sha256: str
    execution_evidence_sha256: str
    parity_claim: str = "NONE"

    def validate(self):
        if self.schema_version != 1 or self.tool_version != TOOL_VERSION or self.evidence_state != EVIDENCE_STATE or self.parity_claim != "NONE":
            fail("GEN_MIX_NORMALIZATION_RECEIPT_STATE_INVALID")
        for f in (
            "input_artifact_sha256", "output_artifact_sha256", "normalization_plan_sha256",
            "normalizer_artifact_sha256", "execution_evidence_sha256"
        ):
            _sha(getattr(self, f), f)

    @property
    def receipt_sha256(self):
        self.validate()
        return canonical_sha(asdict(self))


@dataclass(frozen=True)
class MixReadyReceipt:
    schema_version: int
    tool_version: str
    evidence_state: str
    source_sha256: str
    artifact_sha256: str
    artifact_bytes: int
    sample_rate: int
    channels: int
    audio_format: int
    bits_per_sample: int
    frame_count: int
    timeline_origin_frames: int
    alignment_evidence_sha256: str
    normalization_plan_sha256: str
    parity_claim: str = "NONE"

    @property
    def receipt_sha256(self):
        return canonical_sha(asdict(self))


def validate_mix_ready(
    *,
    candidate_path,
    source: SourceMixSpec,
    plan: NormalizationPlan,
    normalization_receipt: NormalizationReceipt | None = None,
) -> MixReadyReceipt:
    source.validate()
    if plan.source_sha256 != source.source_sha256:
        fail("GEN_MIX_PLAN_SOURCE_MISMATCH")
    if plan.timeline_origin_frames != 0:
        fail("GEN_MIX_NONZERO_TIMELINE_ORIGIN")
    w = inspect_wav(candidate_path)
    if (
        w.sample_rate != source.sample_rate
        or w.channels != source.channels
        or w.audio_format != source.audio_format
        or w.bits_per_sample != source.bits_per_sample
        or w.frame_count != source.frame_count
    ):
        fail("GEN_MIX_NORMALIZED_ARTIFACT_NOT_EXACT")
    plan_sha = canonical_sha(plan.public_dict())
    if plan.ready_without_normalization:
        if normalization_receipt is not None:
            fail("GEN_MIX_UNEXPECTED_NORMALIZATION_RECEIPT")
        if w.artifact_sha256 != plan.raw_artifact_sha256:
            fail("GEN_MIX_DIRECT_ARTIFACT_IDENTITY_MISMATCH")
    else:
        if normalization_receipt is None:
            fail("GEN_MIX_NORMALIZATION_PROVENANCE_REQUIRED")
        normalization_receipt.validate()
        if (
            normalization_receipt.input_artifact_sha256 != plan.raw_artifact_sha256
            or normalization_receipt.output_artifact_sha256 != w.artifact_sha256
            or normalization_receipt.normalization_plan_sha256 != plan_sha
        ):
            fail("GEN_MIX_NORMALIZATION_PROVENANCE_MISMATCH")
    return MixReadyReceipt(
        1, TOOL_VERSION, EVIDENCE_STATE, source.source_sha256, w.artifact_sha256, w.file_bytes,
        w.sample_rate, w.channels, w.audio_format, w.bits_per_sample, w.frame_count, 0,
        plan.alignment_evidence_sha256, plan_sha
    )


@dataclass(frozen=True)
class ActiveVariant:
    schema_version: int
    project_ref_hash: str
    role: str
    generation_ref_hash: str
    variant_index: int
    artifact_sha256: str
    artifact_bytes: int
    sample_rate: int
    channels: int
    audio_format: int
    bits_per_sample: int
    frame_count: int
    mix_ready_receipt_sha256: str

    def validate(self):
        if self.schema_version != 1:
            fail("GEN_MIX_VARIANT_SCHEMA_INVALID")
        for f in ("project_ref_hash", "generation_ref_hash", "artifact_sha256", "mix_ready_receipt_sha256"):
            _sha(getattr(self, f), f)
        _safe(self.role, "role")
        _int(self.variant_index, "variant_index", 0)
        _int(self.artifact_bytes, "artifact_bytes", 1)
        _int(self.sample_rate, "sample_rate", 8000)
        _int(self.channels, "channels", 1)
        _int(self.audio_format, "audio_format", 1)
        _int(self.bits_per_sample, "bits_per_sample", 1)
        _int(self.frame_count, "frame_count", 1)


class GeneratedStemVariantStore:
    def __init__(self, root, *, fault_injector: Callable[[str], None] | None = None):
        self.root = Path(root)
        self.objects = self.root / "objects"
        self.manifests = self.root / "manifests"
        self.active = self.root / "active"
        self.lock_path = self.root / ".lock"
        for p in (self.objects, self.manifests, self.active):
            p.mkdir(parents=True, exist_ok=True)
        self.fault_injector = fault_injector

    @contextmanager
    def locked(self):
        self.root.mkdir(parents=True, exist_ok=True)
        with self.lock_path.open("a+b") as h:
            try:
                import fcntl
                fcntl.flock(h.fileno(), fcntl.LOCK_EX)
            except ImportError as e:
                raise MixCompatibilityError("GEN_MIX_LOCK_UNAVAILABLE") from e
            try:
                yield
            finally:
                fcntl.flock(h.fileno(), fcntl.LOCK_UN)

    def _fault(self, phase):
        if self.fault_injector:
            self.fault_injector(phase)

    @staticmethod
    def _atomic_json(path: Path, payload):
        tmp = path.with_suffix(path.suffix + ".tmp")
        try:
            with tmp.open("w", encoding="utf-8") as h:
                json.dump(payload, h, sort_keys=True, separators=(",", ":"))
                h.write("\n")
                h.flush()
                os.fsync(h.fileno())
            os.replace(tmp, path)
            dfd = os.open(str(path.parent), os.O_RDONLY)
            try:
                os.fsync(dfd)
            finally:
                os.close(dfd)
        except OSError as e:
            tmp.unlink(missing_ok=True)
            raise MixCompatibilityError("GEN_MIX_ATOMIC_WRITE_FAILED") from e

    def _active_path(self, project_ref_hash, role):
        p = _sha(project_ref_hash, "project_ref_hash")
        r = _safe(role, "role").lower()
        return self.active / f"{p}.{r}.json"

    def get_active(self, *, project_ref_hash, role):
        path = self._active_path(project_ref_hash, role)
        if not path.exists():
            return None
        try:
            raw = json.loads(path.read_text())
            x = ActiveVariant(**raw)
            x.validate()
        except MixCompatibilityError:
            raise
        except Exception as e:
            raise MixCompatibilityError("GEN_MIX_ACTIVE_POINTER_CORRUPT") from e
        obj = self.objects / f"{x.artifact_sha256}.wav"
        if not obj.is_file() or obj.is_symlink():
            fail("GEN_MIX_ACTIVE_OBJECT_MISSING")
        w = inspect_wav(obj)
        if w.artifact_sha256 != x.artifact_sha256 or w.file_bytes != x.artifact_bytes:
            fail("GEN_MIX_ACTIVE_OBJECT_MUTATED")
        return x

    def commit_variant(
        self,
        *,
        project_ref_hash: str,
        role: str,
        generation_ref_hash: str,
        variant_index: int,
        candidate_path,
        receipt: MixReadyReceipt,
    ) -> ActiveVariant:
        project = _sha(project_ref_hash, "project_ref_hash")
        role_n = _safe(role, "role").lower()
        generation = _sha(generation_ref_hash, "generation_ref_hash")
        variant = _int(variant_index, "variant_index", 0)
        if receipt.parity_claim != "NONE" or receipt.evidence_state != EVIDENCE_STATE:
            fail("GEN_MIX_RECEIPT_STATE_INVALID")
        candidate = Path(candidate_path)
        if candidate.is_symlink() or not candidate.is_file():
            fail("GEN_MIX_CANDIDATE_INVALID")
        w = inspect_wav(candidate)
        if (
            w.artifact_sha256 != receipt.artifact_sha256
            or w.file_bytes != receipt.artifact_bytes
            or w.sample_rate != receipt.sample_rate
            or w.channels != receipt.channels
            or w.audio_format != receipt.audio_format
            or w.bits_per_sample != receipt.bits_per_sample
            or w.frame_count != receipt.frame_count
        ):
            fail("GEN_MIX_RECEIPT_ARTIFACT_MISMATCH")
        active_path = self._active_path(project, role_n)
        with self.locked():
            old = self.get_active(project_ref_hash=project, role=role_n)
            if old:
                if variant < old.variant_index:
                    fail("GEN_MIX_VARIANT_REGRESSION")
                if variant == old.variant_index:
                    if old.generation_ref_hash == generation and old.artifact_sha256 == w.artifact_sha256:
                        return old
                    fail("GEN_MIX_VARIANT_IDENTITY_CONFLICT")
            obj = self.objects / f"{w.artifact_sha256}.wav"
            if obj.exists():
                if obj.is_symlink() or file_sha256(obj) != w.artifact_sha256:
                    fail("GEN_MIX_OBJECT_COLLISION")
            else:
                tmp = self.objects / f".{w.artifact_sha256}.tmp"
                try:
                    with candidate.open("rb") as src, tmp.open("wb") as dst:
                        shutil.copyfileobj(src, dst, 1024 * 1024)
                        dst.flush()
                        os.fsync(dst.fileno())
                    if file_sha256(tmp) != w.artifact_sha256:
                        fail("GEN_MIX_OBJECT_COPY_HASH_MISMATCH")
                    os.replace(tmp, obj)
                    dfd = os.open(str(self.objects), os.O_RDONLY)
                    try:
                        os.fsync(dfd)
                    finally:
                        os.close(dfd)
                finally:
                    tmp.unlink(missing_ok=True)
            self._fault("after_object")
            item = ActiveVariant(
                1, project, role_n, generation, variant, w.artifact_sha256, w.file_bytes,
                w.sample_rate, w.channels, w.audio_format, w.bits_per_sample, w.frame_count,
                receipt.receipt_sha256
            )
            item.validate()
            manifest = self.manifests / f"{generation}.v{variant}.json"
            if manifest.exists():
                try:
                    existing = json.loads(manifest.read_text())
                except Exception as e:
                    raise MixCompatibilityError("GEN_MIX_MANIFEST_CORRUPT") from e
                if existing != asdict(item):
                    fail("GEN_MIX_MANIFEST_CONFLICT")
            else:
                self._atomic_json(manifest, asdict(item))
            self._fault("after_manifest")
            self._atomic_json(active_path, asdict(item))
            self._fault("after_pointer")
            return item

    def privacy_safe_evidence(self, item: ActiveVariant):
        item.validate()
        return {
            "schema_version": 1,
            "tool_version": TOOL_VERSION,
            "evidence_state": EVIDENCE_STATE,
            "project_ref_hash": item.project_ref_hash,
            "role": item.role,
            "generation_ref_hash": item.generation_ref_hash,
            "variant_index": item.variant_index,
            "artifact_sha256": item.artifact_sha256,
            "artifact_bytes": item.artifact_bytes,
            "sample_rate": item.sample_rate,
            "channels": item.channels,
            "audio_format": item.audio_format,
            "bits_per_sample": item.bits_per_sample,
            "frame_count": item.frame_count,
            "mix_ready_receipt_sha256": item.mix_ready_receipt_sha256,
            "path_emitted": False,
            "raw_audio_emitted": False,
            "parity_claim": "NONE",
        }
