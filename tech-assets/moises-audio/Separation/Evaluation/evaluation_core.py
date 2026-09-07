from __future__ import annotations

import hashlib
import json
import math
import os
import struct
import wave
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

SCHEMA_VERSION = 1
REAL_CLASSES = {"PROJECT_OWNED_REAL_MULTITRACK", "RIGHTS_CLEARED_REAL_REFERENCE"}
OBJECTIVE_CLASSES = {"PROJECT_OWNED_REAL_MULTITRACK"}
NON_PARITY_CLASSES = {"PUBLIC_RESEARCH_NONCOMMERCIAL", "LICENSED_SYNTHETIC", "GENERATED_SIGNAL"}
ALLOWED_CLASSES = REAL_CLASSES | NON_PARITY_CLASSES
ALLOWED_ROLES = {
    "vocals", "drums", "bass", "other", "instrumental", "guitar", "piano",
    "keys", "strings", "wind", "voice", "background_vocals", "percussion",
}
LISTENING_DIMENSIONS = (
    "target_preservation",
    "bleed",
    "musical_noise",
    "transient_integrity",
    "timbre_formant_integrity",
    "stereo_phase_integrity",
    "low_frequency_integrity",
    "reverb_ambience",
    "overall_practice_usability",
)


class EvaluationError(ValueError):
    """Stable fail-closed validation error for separation evidence."""

    def __init__(self, code: str, message: str):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message


@dataclass(frozen=True)
class WavInfo:
    sample_rate_hz: int
    channels: int
    sample_width_bytes: int
    frame_count: int

    @property
    def duration_seconds(self) -> float:
        return self.frame_count / self.sample_rate_hz


def load_json(path: os.PathLike[str] | str) -> Any:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise EvaluationError("EVAL_JSON_INVALID", f"cannot read JSON {path}: {exc}") from exc


def dump_json(path: os.PathLike[str] | str, value: Any) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n"
    target.write_text(payload, encoding="utf-8")


def parse_iso8601(value: str, field: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise EvaluationError("EVAL_TIME_MISSING", f"{field} must be a non-empty ISO-8601 timestamp")
    normalized = value.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise EvaluationError("EVAL_TIME_INVALID", f"{field} is not ISO-8601") from exc
    if parsed.tzinfo is None:
        raise EvaluationError("EVAL_TIME_TZ_REQUIRED", f"{field} must include timezone")
    return parsed.astimezone(timezone.utc)


def require_mapping(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise EvaluationError("EVAL_SCHEMA_TYPE", f"{field} must be an object")
    return value


def require_nonempty_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise EvaluationError("EVAL_SCHEMA_REQUIRED", f"{field} must be a non-empty string")
    return value.strip()


def require_bool(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise EvaluationError("EVAL_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def require_number(value: Any, field: str, minimum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise EvaluationError("EVAL_SCHEMA_TYPE", f"{field} must be a finite number")
    number = float(value)
    if minimum is not None and number < minimum:
        raise EvaluationError("EVAL_SCHEMA_RANGE", f"{field} must be >= {minimum}")
    return number


def safe_relative_path(root: Path, value: str, field: str) -> Path:
    raw = require_nonempty_string(value, field)
    candidate_rel = Path(raw)
    if candidate_rel.is_absolute() or ".." in candidate_rel.parts:
        raise EvaluationError("EVAL_PATH_UNSAFE", f"{field} must be a safe relative path")
    root_resolved = root.resolve()
    candidate = (root_resolved / candidate_rel).resolve()
    try:
        candidate.relative_to(root_resolved)
    except ValueError as exc:
        raise EvaluationError("EVAL_PATH_OUTSIDE_ROOT", f"{field} escapes evaluation root") from exc
    return candidate


def normalize_sha256(value: Any, field: str) -> str:
    raw = require_nonempty_string(value, field).lower()
    if raw.startswith("sha256:"):
        raw = raw[7:]
    if len(raw) != 64 or any(ch not in "0123456789abcdef" for ch in raw):
        raise EvaluationError("EVAL_HASH_INVALID", f"{field} must be SHA-256 hex")
    return raw


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while True:
                block = handle.read(chunk_size)
                if not block:
                    break
                digest.update(block)
    except OSError as exc:
        raise EvaluationError("EVAL_FILE_UNREADABLE", f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def verify_file_hash(root: Path, record: Mapping[str, Any], field: str) -> Path:
    path = safe_relative_path(root, record.get("path"), f"{field}.path")
    expected = normalize_sha256(record.get("sha256"), f"{field}.sha256")
    if not path.is_file():
        raise EvaluationError("EVAL_FILE_MISSING", f"{field} file does not exist: {path}")
    actual = sha256_file(path)
    if actual != expected:
        raise EvaluationError("EVAL_HASH_MISMATCH", f"{field} hash mismatch")
    return path


def _required_roles(manifest: Mapping[str, Any]) -> list[str]:
    roles = manifest.get("requested_roles")
    if not isinstance(roles, list) or len(roles) < 2:
        raise EvaluationError("EVAL_ROLES_INVALID", "requested_roles must contain at least two roles")
    normalized: list[str] = []
    for index, role in enumerate(roles):
        name = require_nonempty_string(role, f"requested_roles[{index}]").lower()
        if name not in ALLOWED_ROLES:
            raise EvaluationError("EVAL_ROLE_UNKNOWN", f"unsupported role: {name}")
        if name in normalized:
            raise EvaluationError("EVAL_ROLE_DUPLICATE", f"duplicate requested role: {name}")
        normalized.append(name)
    return normalized


def validate_fixture_manifest(
    manifest: Mapping[str, Any],
    root: Path,
    *,
    purpose: str = "REGRESSION",
    verify_hashes: bool = True,
) -> dict[str, Any]:
    require_mapping(manifest, "fixture")
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise EvaluationError("EVAL_FIXTURE_SCHEMA", "unsupported fixture schema_version")
    fixture_id = require_nonempty_string(manifest.get("fixture_id"), "fixture_id")
    fixture_class = require_nonempty_string(manifest.get("class"), "class")
    if fixture_class not in ALLOWED_CLASSES:
        raise EvaluationError("EVAL_FIXTURE_CLASS", f"unsupported fixture class {fixture_class}")
    require_nonempty_string(manifest.get("title_alias"), "title_alias")
    rights_record_id = require_nonempty_string(manifest.get("rights_record_id"), "rights_record_id")
    require_nonempty_string(manifest.get("rights_basis"), "rights_basis")
    rights_status = require_nonempty_string(manifest.get("rights_status"), "rights_status")
    if rights_status != "VERIFIED":
        raise EvaluationError("EVAL_RIGHTS_UNVERIFIED", "rights_status must be VERIFIED")
    require_bool(manifest.get("redistribution_allowed"), "redistribution_allowed")
    commercial_allowed = require_bool(manifest.get("commercial_engineering_use_allowed"), "commercial_engineering_use_allowed")
    reference_allowed = require_bool(manifest.get("reference_service_submission_allowed"), "reference_service_submission_allowed")
    real_recorded = require_bool(manifest.get("real_recorded_music"), "real_recorded_music")
    synthetic = require_bool(manifest.get("synthetic"), "synthetic")
    roles = _required_roles(manifest)
    require_nonempty_string(manifest.get("genre_bucket"), "genre_bucket")
    hard_cases = manifest.get("hard_cases")
    if not isinstance(hard_cases, list) or any(not isinstance(item, str) for item in hard_cases):
        raise EvaluationError("EVAL_HARD_CASES_TYPE", "hard_cases must be an array of strings")
    require_number(manifest.get("duration_seconds"), "duration_seconds", 0.001)
    require_number(manifest.get("sample_rate_hz"), "sample_rate_hz", 8000)
    channels = require_number(manifest.get("channels"), "channels", 1)
    if int(channels) != channels:
        raise EvaluationError("EVAL_CHANNELS_INVALID", "channels must be an integer")

    if fixture_class in REAL_CLASSES:
        if not real_recorded or synthetic:
            raise EvaluationError("EVAL_REAL_FIXTURE_FALSE", f"{fixture_class} must be real recorded and non-synthetic")
        if not commercial_allowed:
            raise EvaluationError("EVAL_RIGHTS_COMMERCIAL_DENIED", "commercial engineering use is not established")
    if fixture_class == "PROJECT_OWNED_REAL_MULTITRACK":
        refs = require_mapping(manifest.get("reference_stems"), "reference_stems")
        missing = [role for role in roles if role not in refs]
        if missing:
            raise EvaluationError("EVAL_REFERENCE_STEM_MISSING", f"G1 reference stems missing roles: {missing}")
    if fixture_class == "RIGHTS_CLEARED_REAL_REFERENCE" and not reference_allowed:
        raise EvaluationError("EVAL_REFERENCE_SUBMISSION_DENIED", "G2 requires reference-service submission rights")

    purpose_upper = purpose.upper()
    if purpose_upper == "PARITY_CANDIDATE" and fixture_class not in REAL_CLASSES:
        raise EvaluationError("EVAL_SYNTHETIC_ONLY_PARITY_FORBIDDEN", f"{fixture_class} cannot support PARITY")
    if purpose_upper == "PARITY_CANDIDATE" and not commercial_allowed:
        raise EvaluationError("EVAL_RIGHTS_COMMERCIAL_DENIED", "PARITY candidate requires commercial engineering rights")

    mixture = require_mapping(manifest.get("mixture"), "mixture")
    if verify_hashes:
        verify_file_hash(root, mixture, "mixture")
        if fixture_class == "PROJECT_OWNED_REAL_MULTITRACK":
            refs = require_mapping(manifest.get("reference_stems"), "reference_stems")
            for role in roles:
                verify_file_hash(root, require_mapping(refs.get(role), f"reference_stems.{role}"), f"reference_stems.{role}")

    return {
        "fixture_id": fixture_id,
        "fixture_class": fixture_class,
        "rights_record_id": rights_record_id,
        "requested_roles": roles,
        "real_audio": fixture_class in REAL_CLASSES,
        "objective_reference_available": fixture_class in OBJECTIVE_CLASSES,
        "reference_submission_allowed": reference_allowed,
        "parity_input_eligible": fixture_class in REAL_CLASSES and commercial_allowed,
    }


def validate_run_manifest(
    run: Mapping[str, Any],
    fixture: Mapping[str, Any],
    root: Path,
    *,
    now: datetime | None = None,
    verify_hashes: bool = True,
) -> dict[str, Any]:
    require_mapping(run, "run")
    if run.get("schema_version") != SCHEMA_VERSION:
        raise EvaluationError("EVAL_RUN_SCHEMA", "unsupported run schema_version")
    require_nonempty_string(run.get("run_id"), "run_id")
    if run.get("fixture_id") != fixture.get("fixture_id"):
        raise EvaluationError("EVAL_RUN_FIXTURE_MISMATCH", "run.fixture_id does not match fixture")

    provider = require_mapping(run.get("provider"), "provider")
    for key in ("provider_id", "provider_kind", "model_name", "model_version", "execution_topology"):
        require_nonempty_string(provider.get(key), f"provider.{key}")
    require_nonempty_string(provider.get("commercial_approval_basis_id"), "provider.commercial_approval_basis_id")

    timing = require_mapping(run.get("timing_ms"), "timing_ms")
    for key in ("upload", "queue", "inference", "download", "total"):
        require_number(timing.get(key), f"timing_ms.{key}", 0)
    component_total = sum(float(timing[key]) for key in ("upload", "queue", "inference", "download"))
    if float(timing["total"]) + 1e-6 < component_total:
        raise EvaluationError("EVAL_TIMING_INCONSISTENT", "timing_ms.total cannot be less than timed components")

    cost = require_mapping(run.get("cost"), "cost")
    require_nonempty_string(cost.get("currency"), "cost.currency")
    require_number(cost.get("total"), "cost.total", 0)
    if "credits" in cost and cost.get("credits") is not None:
        require_number(cost.get("credits"), "cost.credits", 0)
    require_nonempty_string(cost.get("basis"), "cost.basis")

    roles = _required_roles(fixture)
    results = run.get("results")
    if not isinstance(results, list):
        raise EvaluationError("EVAL_RESULTS_TYPE", "results must be an array")
    by_role: dict[str, Mapping[str, Any]] = {}
    now_utc = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    for index, raw in enumerate(results):
        result = require_mapping(raw, f"results[{index}]")
        role = require_nonempty_string(result.get("role"), f"results[{index}].role").lower()
        if role in by_role:
            raise EvaluationError("EVAL_RESULT_ROLE_DUPLICATE", f"duplicate result role {role}")
        by_role[role] = result
        require_nonempty_string(result.get("container"), f"results[{index}].container")
        require_number(result.get("sample_rate_hz"), f"results[{index}].sample_rate_hz", 8000)
        for integer_field, minimum in (("channels", 1), ("frame_count", 1)):
            integer_value = require_number(result.get(integer_field), f"results[{index}].{integer_field}", minimum)
            if int(integer_value) != integer_value:
                raise EvaluationError("EVAL_SCHEMA_INTEGER", f"results[{index}].{integer_field} must be an integer")
        require_number(result.get("duration_seconds"), f"results[{index}].duration_seconds", 0.001)

        local_path = result.get("artifact_path")
        remote_url = result.get("source_url")
        expiry = result.get("source_url_expires_at")
        local_ok = False
        if local_path:
            path = safe_relative_path(root, local_path, f"results[{index}].artifact_path")
            if path.is_file():
                local_ok = True
                expected_hash = normalize_sha256(result.get("sha256"), f"results[{index}].sha256")
                if verify_hashes and sha256_file(path) != expected_hash:
                    raise EvaluationError("EVAL_RESULT_HASH_MISMATCH", f"result role {role} hash mismatch")
        if not local_ok:
            require_nonempty_string(remote_url, f"results[{index}].source_url")
            expires_at = parse_iso8601(expiry, f"results[{index}].source_url_expires_at")
            if expires_at <= now_utc:
                raise EvaluationError("EVAL_RESULT_REMOTE_EXPIRED", f"result role {role} has no local copy and remote URL expired")

    missing = [role for role in roles if role not in by_role]
    extra = [role for role in by_role if role not in roles]
    if missing:
        raise EvaluationError("EVAL_RESULT_STEM_MISSING", f"missing result roles: {missing}")
    if extra:
        raise EvaluationError("EVAL_RESULT_STEM_EXTRA", f"unexpected result roles: {extra}")

    return {"roles": roles, "result_count": len(results)}


def read_wav_info(path: Path) -> WavInfo:
    try:
        with wave.open(str(path), "rb") as handle:
            if handle.getcomptype() != "NONE":
                raise EvaluationError("EVAL_WAV_COMPRESSED", f"compressed WAV unsupported for objective metrics: {path}")
            width = handle.getsampwidth()
            if width not in (1, 2, 3, 4):
                raise EvaluationError("EVAL_WAV_WIDTH", f"unsupported PCM sample width {width}")
            return WavInfo(handle.getframerate(), handle.getnchannels(), width, handle.getnframes())
    except wave.Error as exc:
        raise EvaluationError("EVAL_WAV_INVALID", f"invalid WAV {path}: {exc}") from exc


def _decode_pcm(data: bytes, width: int) -> list[float]:
    if width == 1:
        return [(byte - 128) / 128.0 for byte in data]
    if width == 2:
        count = len(data) // 2
        return [sample / 32768.0 for sample in struct.unpack("<" + "h" * count, data)]
    if width == 4:
        count = len(data) // 4
        return [sample / 2147483648.0 for sample in struct.unpack("<" + "i" * count, data)]
    out: list[float] = []
    for offset in range(0, len(data), 3):
        chunk = data[offset: offset + 3]
        if len(chunk) < 3:
            break
        integer = int.from_bytes(chunk, "little", signed=False)
        if integer & 0x800000:
            integer -= 1 << 24
        out.append(integer / 8388608.0)
    return out


def _iter_pcm_chunks(handle: wave.Wave_read, frames_per_chunk: int = 8192) -> Iterator[list[float]]:
    width = handle.getsampwidth()
    while True:
        data = handle.readframes(frames_per_chunk)
        if not data:
            break
        yield _decode_pcm(data, width)


def streaming_si_sdr(reference_path: Path, estimate_path: Path, max_alignment_ms: float = 20.0) -> dict[str, float]:
    ref_info = read_wav_info(reference_path)
    est_info = read_wav_info(estimate_path)
    if ref_info.sample_rate_hz != est_info.sample_rate_hz:
        raise EvaluationError("EVAL_SAMPLE_RATE_MISMATCH", "reference and estimate sample rates differ")
    if ref_info.channels != est_info.channels:
        raise EvaluationError("EVAL_CHANNEL_MISMATCH", "reference and estimate channel counts differ")
    if ref_info.sample_width_bytes != est_info.sample_width_bytes:
        raise EvaluationError("EVAL_SAMPLE_WIDTH_MISMATCH", "reference and estimate PCM widths differ")
    alignment_ms = abs(ref_info.frame_count - est_info.frame_count) / ref_info.sample_rate_hz * 1000.0
    if alignment_ms > max_alignment_ms:
        raise EvaluationError("EVAL_DURATION_MISMATCH", f"duration mismatch {alignment_ms:.3f}ms exceeds {max_alignment_ms}ms")

    dot = 0.0
    ref_energy = 0.0
    est_energy = 0.0
    sample_count = 0
    with wave.open(str(reference_path), "rb") as ref, wave.open(str(estimate_path), "rb") as est:
        while True:
            ref_data = ref.readframes(8192)
            est_data = est.readframes(8192)
            if not ref_data or not est_data:
                break
            ref_samples = _decode_pcm(ref_data, ref.getsampwidth())
            est_samples = _decode_pcm(est_data, est.getsampwidth())
            count = min(len(ref_samples), len(est_samples))
            for r, e in zip(ref_samples[:count], est_samples[:count]):
                dot += e * r
                ref_energy += r * r
                est_energy += e * e
            sample_count += count
    if sample_count == 0 or ref_energy <= 1e-20:
        raise EvaluationError("EVAL_REFERENCE_SILENT", "reference stem has no measurable energy")
    alpha = dot / ref_energy
    target_energy = alpha * alpha * ref_energy
    noise_energy = est_energy - 2.0 * alpha * dot + alpha * alpha * ref_energy
    noise_energy = max(noise_energy, 1e-20)
    target_energy = max(target_energy, 1e-20)
    si_sdr_db = 10.0 * math.log10(target_energy / noise_energy)
    si_sdr_db = max(-120.0, min(120.0, si_sdr_db))
    rmse = math.sqrt(max(est_energy + ref_energy - 2.0 * dot, 0.0) / sample_count)
    return {
        "si_sdr_db": si_sdr_db,
        "rmse": rmse,
        "duration_alignment_ms": alignment_ms,
        "sample_count": float(sample_count),
    }


def streaming_reconstruction_error(mixture_path: Path, estimate_paths: Sequence[Path]) -> dict[str, float]:
    if not estimate_paths:
        raise EvaluationError("EVAL_RECONSTRUCTION_NO_STEMS", "at least one estimate stem is required")
    mix_info = read_wav_info(mixture_path)
    stem_infos = [read_wav_info(path) for path in estimate_paths]
    for info in stem_infos:
        if (info.sample_rate_hz, info.channels, info.sample_width_bytes) != (
            mix_info.sample_rate_hz, mix_info.channels, mix_info.sample_width_bytes
        ):
            raise EvaluationError("EVAL_RECONSTRUCTION_FORMAT_MISMATCH", "mixture/stem PCM formats differ")
        alignment_ms = abs(info.frame_count - mix_info.frame_count) / mix_info.sample_rate_hz * 1000.0
        if alignment_ms > 20.0:
            raise EvaluationError("EVAL_RECONSTRUCTION_DURATION_MISMATCH", "mixture/stem duration mismatch exceeds 20ms")

    mix_energy = 0.0
    error_energy = 0.0
    peak_sum = 0.0
    sample_count = 0
    with wave.open(str(mixture_path), "rb") as mix_handle:
        stem_handles = [wave.open(str(path), "rb") for path in estimate_paths]
        try:
            while True:
                mix_data = mix_handle.readframes(8192)
                if not mix_data:
                    break
                mix_samples = _decode_pcm(mix_data, mix_handle.getsampwidth())
                stem_samples = []
                for handle in stem_handles:
                    block = handle.readframes(8192)
                    stem_samples.append(_decode_pcm(block, handle.getsampwidth()))
                count = min([len(mix_samples)] + [len(values) for values in stem_samples])
                if count == 0:
                    break
                for index in range(count):
                    mixture = mix_samples[index]
                    reconstructed = sum(values[index] for values in stem_samples)
                    diff = reconstructed - mixture
                    mix_energy += mixture * mixture
                    error_energy += diff * diff
                    peak_sum = max(peak_sum, abs(reconstructed))
                sample_count += count
        finally:
            for handle in stem_handles:
                handle.close()
    if sample_count == 0:
        raise EvaluationError("EVAL_RECONSTRUCTION_EMPTY", "no samples available for reconstruction")
    rmse = math.sqrt(error_energy / sample_count)
    mix_rms = math.sqrt(max(mix_energy / sample_count, 1e-20))
    return {
        "rmse": rmse,
        "normalized_rmse": rmse / mix_rms,
        "reconstructed_peak": peak_sum,
        "sample_count": float(sample_count),
    }


def validate_listening_records(records: Any, fixture: Mapping[str, Any], *, purpose: str = "REGRESSION") -> dict[str, Any]:
    if not isinstance(records, list) or not records:
        raise EvaluationError("EVAL_LISTENING_EMPTY", "listening records must be a non-empty array")
    roles = set(_required_roles(fixture))
    systems_by_role: dict[str, set[str]] = {role: set() for role in roles}
    for index, raw in enumerate(records):
        record = require_mapping(raw, f"listening[{index}]")
        if record.get("fixture_id") != fixture.get("fixture_id"):
            raise EvaluationError("EVAL_LISTENING_FIXTURE_MISMATCH", "listening fixture_id mismatch")
        require_nonempty_string(record.get("run_id"), f"listening[{index}].run_id")
        blind_id = require_nonempty_string(record.get("system_blind_id"), f"listening[{index}].system_blind_id")
        if blind_id not in {"A", "B"}:
            raise EvaluationError("EVAL_LISTENING_BLIND_ID", "system_blind_id must be A or B")
        system = require_nonempty_string(record.get("revealed_system"), f"listening[{index}].revealed_system")
        if system not in {"PROJECT", "REFERENCE"}:
            raise EvaluationError("EVAL_LISTENING_SYSTEM", "revealed_system must be PROJECT or REFERENCE")
        role = require_nonempty_string(record.get("stem"), f"listening[{index}].stem").lower()
        if role not in roles:
            raise EvaluationError("EVAL_LISTENING_ROLE", f"unexpected listening role {role}")
        scores = require_mapping(record.get("scores"), f"listening[{index}].scores")
        for dimension in LISTENING_DIMENSIONS:
            value = scores.get(dimension)
            if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 4:
                raise EvaluationError("EVAL_LISTENING_SCORE", f"{dimension} must be integer 0..4")
        require_nonempty_string(record.get("listener_id"), f"listening[{index}].listener_id")
        parse_iso8601(record.get("timestamp"), f"listening[{index}].timestamp")
        systems_by_role[role].add(system)

    if purpose.upper() == "PARITY_CANDIDATE":
        if fixture.get("class") != "RIGHTS_CLEARED_REAL_REFERENCE":
            if not bool(fixture.get("reference_service_submission_allowed")):
                raise EvaluationError("EVAL_LISTENING_REFERENCE_RIGHTS", "PARITY listening requires reference submission rights")
        missing_pairs = [role for role, systems in systems_by_role.items() if systems != {"PROJECT", "REFERENCE"}]
        if missing_pairs:
            raise EvaluationError("EVAL_LISTENING_PAIR_MISSING", f"missing PROJECT/REFERENCE pair for roles: {missing_pairs}")
    return {"record_count": len(records), "roles": sorted(roles)}


def evaluate_run(
    fixture: Mapping[str, Any],
    run: Mapping[str, Any],
    root: Path,
    *,
    purpose: str = "REGRESSION",
    listening_records: Any | None = None,
    now: datetime | None = None,
) -> dict[str, Any]:
    fixture_summary = validate_fixture_manifest(fixture, root, purpose=purpose, verify_hashes=True)
    run_summary = validate_run_manifest(run, fixture, root, now=now, verify_hashes=True)
    roles = run_summary["roles"]
    by_role = {item["role"]: item for item in run["results"]}
    objective: dict[str, Any] = {"per_stem": {}, "mixture_reconstruction": None}

    if fixture_summary["objective_reference_available"]:
        refs = require_mapping(fixture.get("reference_stems"), "reference_stems")
        estimate_paths: list[Path] = []
        for role in roles:
            ref_path = safe_relative_path(root, require_mapping(refs[role], f"reference_stems.{role}")["path"], f"reference_stems.{role}.path")
            result = require_mapping(by_role[role], f"result.{role}")
            if not result.get("artifact_path"):
                raise EvaluationError("EVAL_OBJECTIVE_LOCAL_COPY_REQUIRED", "objective metrics require a verified local result copy")
            est_path = safe_relative_path(root, result["artifact_path"], f"result.{role}.artifact_path")
            objective["per_stem"][role] = streaming_si_sdr(ref_path, est_path)
            estimate_paths.append(est_path)
        mixture_path = safe_relative_path(root, require_mapping(fixture["mixture"], "mixture")["path"], "mixture.path")
        objective["mixture_reconstruction"] = streaming_reconstruction_error(mixture_path, estimate_paths)

    listening_summary = None
    if listening_records is not None:
        listening_summary = validate_listening_records(listening_records, fixture, purpose=purpose)
    elif purpose.upper() == "PARITY_CANDIDATE" and fixture_summary["reference_submission_allowed"]:
        raise EvaluationError("EVAL_LISTENING_REQUIRED", "PARITY candidate with reference rights requires blinded listening records")

    return {
        "schema_version": SCHEMA_VERSION,
        "evidence_kind": "SEPARATION_EVALUATION_RUN",
        "run_id": run["run_id"],
        "fixture_id": fixture["fixture_id"],
        "fixture_class": fixture["class"],
        "purpose": purpose.upper(),
        "provider": run["provider"],
        "timing_ms": run["timing_ms"],
        "cost": run["cost"],
        "results": run["results"],
        "objective_metrics": objective,
        "listening_summary": listening_summary,
        "rights_record_id": fixture["rights_record_id"],
        "real_audio": fixture_summary["real_audio"],
        "parity_state": "NON_PARITY_EVIDENCE_ONLY",
        "parity_reason": "One run cannot satisfy required multi-track/multi-genre coverage, differential review, runtime/device and HQ gates.",
    }
