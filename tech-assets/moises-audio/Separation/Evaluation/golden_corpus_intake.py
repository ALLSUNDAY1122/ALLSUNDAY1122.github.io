"""Lane 1 Golden G1/G2 corpus intake gate. NON-PARITY engineering evidence only."""
from __future__ import annotations
import argparse, hashlib, json, math, os, re, sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence
from evaluation_core import (
    EvaluationError, load_json, normalize_sha256, read_wav_info,
    safe_relative_path, sha256_file, validate_fixture_manifest,
)

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-A19-v1"
GROUP_BY_CLASS = {
    "PROJECT_OWNED_REAL_MULTITRACK": "G1",
    "RIGHTS_CLEARED_REAL_REFERENCE": "G2",
}
GROUPS = ("G1", "G2")
SAFE_TOKEN = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,63}$")
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")
INDEX_KEYS = {"schema_version","corpus_id","corpus_revision","fixtures"}
ENTRY_KEYS = {"manifest_path","manifest_sha256","expected_group","production_bucket"}
POLICY_KEYS = {
    "schema_version","policy_id","minimum_fixture_count_by_group",
    "minimum_distinct_genres","minimum_distinct_genres_by_group","duration_buckets",
    "required_duration_buckets","minimum_duration_buckets_by_group","required_role_sets",
    "minimum_distinct_production_buckets","minimum_distinct_production_buckets_by_group",
    "required_production_buckets","required_hard_cases","minimum_distinct_hard_cases",
    "reference_submission_required_groups","metadata_duration_tolerance_ms",
    "g1_reference_alignment_tolerance_ms","reject_duplicate_mixture_audio",
}

class GoldenIntakeError(EvaluationError):
    pass

@dataclass(frozen=True)
class FixtureEvidence:
    fixture_id: str
    group: str
    manifest_sha256: str
    mixture_sha256: str
    reference_sha256_by_role: dict[str, str]
    rights_record_ref_hash: str
    genre_bucket: str
    production_bucket: str
    duration_seconds: float
    duration_bucket: str
    sample_rate_hz: int
    channels: int
    requested_roles: tuple[str, ...]
    hard_cases: tuple[str, ...]

def err(code, message="intake validation failed"):
    return GoldenIntakeError(code, message)

def obj(v, f):
    if not isinstance(v, Mapping): raise err("GOLDEN_SCHEMA_TYPE", f"{f} must be object")
    return v

def arr(v, f):
    if not isinstance(v, list): raise err("GOLDEN_SCHEMA_TYPE", f"{f} must be array")
    return v

def exact(v, allowed, required, f):
    if set(required) - set(v): raise err("GOLDEN_SCHEMA_REQUIRED", f"{f} missing field")
    if set(v) - set(allowed): raise err("GOLDEN_SCHEMA_UNKNOWN_FIELD", f"{f} unknown field")

def text(v, f, *, token=False, ident=False):
    if not isinstance(v, str) or not v.strip(): raise err("GOLDEN_SCHEMA_REQUIRED", f"{f} empty")
    x = v.strip()
    if token and not SAFE_TOKEN.fullmatch(x): raise err("GOLDEN_TOKEN_INVALID", f)
    if ident and not SAFE_ID.fullmatch(x): raise err("GOLDEN_ID_INVALID", f)
    return x

def integer(v, f, minimum=0):
    if isinstance(v, bool) or not isinstance(v, int) or v < minimum:
        raise err("GOLDEN_SCHEMA_INTEGER", f)
    return v

def number(v, f, minimum=0.0):
    if isinstance(v, bool) or not isinstance(v, (int,float)) or not math.isfinite(float(v)) or float(v) < minimum:
        raise err("GOLDEN_SCHEMA_NUMBER", f)
    return float(v)

def boolean(v, f):
    if not isinstance(v, bool): raise err("GOLDEN_SCHEMA_BOOL", f)
    return v

def tokens(v, f):
    out = []
    for i, raw in enumerate(arr(v, f)):
        x = text(raw, f"{f}[{i}]", token=True)
        if x in out: raise err("GOLDEN_POLICY_DUPLICATE", f)
        out.append(x)
    return out

def groups(v, f, code):
    out = []
    for i, raw in enumerate(arr(v, f)):
        x = text(raw, f"{f}[{i}]")
        if x not in GROUPS: raise err(code, f)
        if x in out: raise err("GOLDEN_POLICY_DUPLICATE", f)
        out.append(x)
    return out

def canonical_sha(v):
    return hashlib.sha256(json.dumps(v, sort_keys=True, separators=(",",":"), ensure_ascii=False, allow_nan=False).encode()).hexdigest()

def rights_ref(v):
    return hashlib.sha256(("lane1-golden-rights-ref-v1\0"+v).encode()).hexdigest()

def no_symlink(root, rel_value, field):
    raw = text(rel_value, field)
    rel = Path(raw)
    if rel.is_absolute() or ".." in rel.parts: raise err("GOLDEN_PATH_UNSAFE", field)
    cur = root.resolve()
    for part in rel.parts:
        cur /= part
        if cur.is_symlink(): raise err("GOLDEN_SYMLINK_FORBIDDEN", field)

def group_map(v, f, minimum):
    m = obj(v, f)
    if set(m) != set(GROUPS): raise err("GOLDEN_POLICY_GROUP_MAP", f)
    return {g: integer(m[g], f"{f}.{g}", minimum) for g in GROUPS}

def validate_index(raw):
    x = obj(raw, "index")
    exact(x, INDEX_KEYS, INDEX_KEYS, "index")
    if x["schema_version"] != 1: raise err("GOLDEN_INDEX_SCHEMA")
    entries, seen = [], set()
    for i, raw_entry in enumerate(arr(x["fixtures"], "fixtures")):
        e = obj(raw_entry, f"fixtures[{i}]"); exact(e, ENTRY_KEYS, ENTRY_KEYS, f"fixtures[{i}]")
        path = text(e["manifest_path"], "manifest_path")
        if path in seen: raise err("GOLDEN_MANIFEST_PATH_DUPLICATE")
        seen.add(path)
        group = text(e["expected_group"], "expected_group")
        if group not in GROUPS: raise err("GOLDEN_GROUP_INVALID")
        entries.append({
            "manifest_path": path,
            "manifest_sha256": normalize_sha256(e["manifest_sha256"], "manifest_sha256"),
            "expected_group": group,
            "production_bucket": text(e["production_bucket"], "production_bucket", token=True),
        })
    if not entries: raise err("GOLDEN_CORPUS_EMPTY")
    return {
        "corpus_id": text(x["corpus_id"], "corpus_id", ident=True),
        "corpus_revision": text(x["corpus_revision"], "corpus_revision", ident=True),
        "fixtures": entries,
    }

def validate_policy(raw):
    p = obj(raw, "policy"); exact(p, POLICY_KEYS, POLICY_KEYS, "policy")
    if p["schema_version"] != 1: raise err("GOLDEN_POLICY_SCHEMA")
    buckets, seen, previous_max = [], set(), None
    for i, raw_bucket in enumerate(arr(p["duration_buckets"], "duration_buckets")):
        b = obj(raw_bucket, f"duration_buckets[{i}]")
        exact(b, {"id","min_seconds","max_seconds_exclusive"}, {"id","min_seconds","max_seconds_exclusive"}, "duration_bucket")
        bid = text(b["id"], "duration_bucket.id", token=True)
        if bid in seen: raise err("GOLDEN_DURATION_BUCKET_DUPLICATE")
        seen.add(bid)
        lo = number(b["min_seconds"], "min_seconds")
        hi = None if b["max_seconds_exclusive"] is None else number(b["max_seconds_exclusive"], "max_seconds_exclusive")
        if hi is not None and hi <= lo: raise err("GOLDEN_DURATION_BUCKET_RANGE")
        if previous_max is None and i > 0: raise err("GOLDEN_DURATION_BUCKET_AFTER_OPEN")
        if previous_max is not None and lo < previous_max: raise err("GOLDEN_DURATION_BUCKET_OVERLAP")
        previous_max = hi
        buckets.append({"id":bid,"min_seconds":lo,"max_seconds_exclusive":hi})
    if not buckets: raise err("GOLDEN_DURATION_BUCKETS_EMPTY")
    required_duration = tokens(p["required_duration_buckets"], "required_duration_buckets")
    if not set(required_duration) <= seen: raise err("GOLDEN_POLICY_DURATION_UNKNOWN")
    role_sets, role_ids = [], set()
    for raw_role_set in arr(p["required_role_sets"], "required_role_sets"):
        r = obj(raw_role_set, "role_set")
        exact(r, {"id","roles","groups"}, {"id","roles","groups"}, "role_set")
        rid = text(r["id"], "role_set.id", token=True)
        if rid in role_ids: raise err("GOLDEN_POLICY_ROLE_SET_DUPLICATE")
        role_ids.add(rid)
        roles = tokens(r["roles"], "role_set.roles")
        if len(roles) < 2: raise err("GOLDEN_POLICY_ROLE_SET_SMALL")
        group_values = groups(r["groups"], "role_set.groups", "GOLDEN_POLICY_ROLE_SET_GROUP")
        if not group_values: raise err("GOLDEN_POLICY_ROLE_SET_GROUP")
        role_sets.append({"id":rid,"roles":roles,"groups":group_values})
    if not role_sets: raise err("GOLDEN_POLICY_ROLE_SET_EMPTY")
    reference_groups = groups(p["reference_submission_required_groups"], "reference_submission_required_groups", "GOLDEN_POLICY_REFERENCE_GROUP")
    return {
        "schema_version":1,
        "policy_id":text(p["policy_id"], "policy_id", ident=True),
        "minimum_fixture_count_by_group":group_map(p["minimum_fixture_count_by_group"],"minimum_fixture_count_by_group",1),
        "minimum_distinct_genres":integer(p["minimum_distinct_genres"],"minimum_distinct_genres",1),
        "minimum_distinct_genres_by_group":group_map(p["minimum_distinct_genres_by_group"],"minimum_distinct_genres_by_group",1),
        "duration_buckets":buckets,
        "required_duration_buckets":required_duration,
        "minimum_duration_buckets_by_group":group_map(p["minimum_duration_buckets_by_group"],"minimum_duration_buckets_by_group",1),
        "required_role_sets":role_sets,
        "minimum_distinct_production_buckets":integer(p["minimum_distinct_production_buckets"],"minimum_distinct_production_buckets",1),
        "minimum_distinct_production_buckets_by_group":group_map(p["minimum_distinct_production_buckets_by_group"],"minimum_distinct_production_buckets_by_group",1),
        "required_production_buckets":tokens(p["required_production_buckets"],"required_production_buckets"),
        "required_hard_cases":tokens(p["required_hard_cases"],"required_hard_cases"),
        "minimum_distinct_hard_cases":integer(p["minimum_distinct_hard_cases"],"minimum_distinct_hard_cases",0),
        "reference_submission_required_groups":reference_groups,
        "metadata_duration_tolerance_ms":number(p["metadata_duration_tolerance_ms"],"metadata_duration_tolerance_ms"),
        "g1_reference_alignment_tolerance_ms":number(p["g1_reference_alignment_tolerance_ms"],"g1_reference_alignment_tolerance_ms"),
        "reject_duplicate_mixture_audio":boolean(p["reject_duplicate_mixture_audio"],"reject_duplicate_mixture_audio"),
    }

def duration_bucket(seconds, buckets):
    matches = [b["id"] for b in buckets if seconds >= b["min_seconds"] and (b["max_seconds_exclusive"] is None or seconds < b["max_seconds_exclusive"])]
    if len(matches) != 1: raise err("GOLDEN_DURATION_UNCLASSIFIED")
    return matches[0]

def safe_file(root, rel, field, missing_code):
    no_symlink(root, rel, field)
    p = safe_relative_path(root, rel, field)
    if not p.is_file(): raise err(missing_code, field)
    return p

def hard_cases(v, fid):
    out = []
    for raw in arr(v, f"{fid}.hard_cases"):
        x = text(raw, "hard_case", token=True)
        if x in out: raise err("GOLDEN_HARD_CASE_DUPLICATE")
        out.append(x)
    return tuple(sorted(out))

def fixture_evidence(root, entry, manifest, policy):
    summary = validate_fixture_manifest(manifest, root, purpose="PARITY_CANDIDATE", verify_hashes=True)
    fid = text(summary["fixture_id"], "fixture_id", ident=True)
    group = GROUP_BY_CLASS.get(summary["fixture_class"])
    if group is None: raise err("GOLDEN_FIXTURE_CLASS_FORBIDDEN")
    if group != entry["expected_group"]: raise err("GOLDEN_GROUP_CLASS_MISMATCH")
    genre = text(manifest["genre_bucket"], "genre_bucket", token=True)
    cases = hard_cases(manifest["hard_cases"], fid)
    if group in policy["reference_submission_required_groups"] and manifest.get("reference_service_submission_allowed") is not True:
        raise err("GOLDEN_REFERENCE_SUBMISSION_DENIED")
    mix = obj(manifest["mixture"], "mixture")
    mix_path = safe_file(root, mix["path"], "mixture.path", "GOLDEN_AUDIO_MISSING")
    mix_sha = normalize_sha256(mix["sha256"], "mixture.sha256")
    info = read_wav_info(mix_path)
    if info.sample_rate_hz != integer(manifest["sample_rate_hz"],"sample_rate_hz",8000): raise err("GOLDEN_MIX_SAMPLE_RATE_MISMATCH")
    if info.channels != integer(manifest["channels"],"channels",1): raise err("GOLDEN_MIX_CHANNEL_MISMATCH")
    declared_duration = number(manifest["duration_seconds"],"duration_seconds",0.001)
    if abs(info.duration_seconds-declared_duration)*1000 > policy["metadata_duration_tolerance_ms"]: raise err("GOLDEN_MIX_DURATION_MISMATCH")
    roles = tuple(sorted(text(r,"requested_role",token=True) for r in summary["requested_roles"]))
    refs = {}
    if group == "G1":
        ref_map = obj(manifest["reference_stems"], "reference_stems")
        seen = set()
        for role in roles:
            rec = obj(ref_map[role], f"reference_stems.{role}")
            rp = safe_file(root, rec["path"], f"reference_stems.{role}.path", "GOLDEN_AUDIO_MISSING")
            rh = normalize_sha256(rec["sha256"], f"reference_stems.{role}.sha256")
            if rh == mix_sha: raise err("GOLDEN_G1_MIXTURE_EQUALS_REFERENCE")
            if rh in seen: raise err("GOLDEN_G1_REFERENCE_HASH_DUPLICATE")
            seen.add(rh)
            ri = read_wav_info(rp)
            if ri.sample_rate_hz != info.sample_rate_hz: raise err("GOLDEN_G1_REFERENCE_SAMPLE_RATE_MISMATCH")
            if ri.channels != info.channels: raise err("GOLDEN_G1_REFERENCE_CHANNEL_MISMATCH")
            if abs(ri.frame_count-info.frame_count)/info.sample_rate_hz*1000 > policy["g1_reference_alignment_tolerance_ms"]:
                raise err("GOLDEN_G1_REFERENCE_DURATION_MISMATCH")
            refs[role] = rh
    return FixtureEvidence(
        fid, group, entry["manifest_sha256"], mix_sha, dict(sorted(refs.items())),
        rights_ref(text(manifest["rights_record_id"],"rights_record_id")), genre,
        entry["production_bucket"], info.duration_seconds,
        duration_bucket(info.duration_seconds, policy["duration_buckets"]),
        info.sample_rate_hz, info.channels, roles, cases,
    )

def coverage(fixtures, policy):
    by_group = {g:[f for f in fixtures if f.group==g] for g in GROUPS}
    for g in GROUPS:
        if len(by_group[g]) < policy["minimum_fixture_count_by_group"][g]: raise err("GOLDEN_COVERAGE_GROUP_COUNT")
    genres = {f.genre_bucket for f in fixtures}
    if len(genres) < policy["minimum_distinct_genres"]: raise err("GOLDEN_COVERAGE_GENRE")
    genres_by_group = {g:sorted({f.genre_bucket for f in by_group[g]}) for g in GROUPS}
    for g in GROUPS:
        if len(genres_by_group[g]) < policy["minimum_distinct_genres_by_group"][g]: raise err("GOLDEN_COVERAGE_GENRE_GROUP")
    durations = {f.duration_bucket for f in fixtures}
    if set(policy["required_duration_buckets"]) - durations: raise err("GOLDEN_COVERAGE_DURATION_BUCKET")
    durations_by_group = {g:sorted({f.duration_bucket for f in by_group[g]}) for g in GROUPS}
    for g in GROUPS:
        if len(durations_by_group[g]) < policy["minimum_duration_buckets_by_group"][g]: raise err("GOLDEN_COVERAGE_DURATION_GROUP")
    production = {f.production_bucket for f in fixtures}
    if len(production) < policy["minimum_distinct_production_buckets"]: raise err("GOLDEN_COVERAGE_PRODUCTION")
    if set(policy["required_production_buckets"]) - production: raise err("GOLDEN_COVERAGE_PRODUCTION_REQUIRED")
    production_by_group = {g:sorted({f.production_bucket for f in by_group[g]}) for g in GROUPS}
    for g in GROUPS:
        if len(production_by_group[g]) < policy["minimum_distinct_production_buckets_by_group"][g]: raise err("GOLDEN_COVERAGE_PRODUCTION_GROUP")
    cases = {c for f in fixtures for c in f.hard_cases}
    if len(cases) < policy["minimum_distinct_hard_cases"]: raise err("GOLDEN_COVERAGE_HARD_CASE")
    if set(policy["required_hard_cases"]) - cases: raise err("GOLDEN_COVERAGE_HARD_CASE_REQUIRED")
    role_status = []
    for requirement in policy["required_role_sets"]:
        req = set(requirement["roles"]); satisfied=[]
        for g in requirement["groups"]:
            if not any(req <= set(f.requested_roles) for f in by_group[g]): raise err("GOLDEN_COVERAGE_ROLE_SET")
            satisfied.append(g)
        role_status.append({"id":requirement["id"],"roles":requirement["roles"],"groups_satisfied":sorted(satisfied)})
    return {
        "fixture_count":len(fixtures),
        "fixture_count_by_group":{g:len(by_group[g]) for g in GROUPS},
        "genres":sorted(genres),"genres_by_group":genres_by_group,
        "duration_buckets":sorted(durations),"duration_buckets_by_group":durations_by_group,
        "production_buckets":sorted(production),"production_buckets_by_group":production_by_group,
        "hard_cases":sorted(cases),"role_set_status":role_status,
    }

def validate_golden_corpus(*, root:Path|str, index:Mapping[str,Any], policy:Mapping[str,Any]):
    root = Path(root).resolve()
    if not root.is_dir(): raise err("GOLDEN_ROOT_INVALID")
    index, policy = validate_index(index), validate_policy(policy)
    fixtures=[]; ids=set(); mix_hashes=set()
    for i, entry in enumerate(index["fixtures"]):
        mp = safe_file(root, entry["manifest_path"], f"fixtures[{i}].manifest_path", "GOLDEN_MANIFEST_MISSING")
        if sha256_file(mp) != entry["manifest_sha256"]: raise err("GOLDEN_MANIFEST_HASH_MISMATCH")
        evidence = fixture_evidence(root, entry, obj(load_json(mp),"fixture_manifest"), policy)
        if evidence.fixture_id in ids: raise err("GOLDEN_FIXTURE_ID_DUPLICATE")
        ids.add(evidence.fixture_id)
        if policy["reject_duplicate_mixture_audio"] and evidence.mixture_sha256 in mix_hashes: raise err("GOLDEN_MIXTURE_HASH_DUPLICATE")
        mix_hashes.add(evidence.mixture_sha256); fixtures.append(evidence)
    cov = coverage(fixtures, policy)
    policy_sha = canonical_sha(policy)
    lock_rows = [{
        "fixture_id":f.fixture_id,"group":f.group,"manifest_sha256":f.manifest_sha256,
        "mixture_sha256":f.mixture_sha256,"reference_sha256_by_role":f.reference_sha256_by_role,
        "production_bucket":f.production_bucket,
    } for f in sorted(fixtures,key=lambda x:x.fixture_id)]
    lock = hashlib.sha256((
        "lane1-golden-corpus-lock-v1\0"+index["corpus_id"]+"\0"+index["corpus_revision"]+
        "\0"+policy_sha+"\0"+json.dumps(lock_rows,sort_keys=True,separators=(",",":"))
    ).encode()).hexdigest()
    rows=[]
    for f in sorted(fixtures,key=lambda x:x.fixture_id):
        r=asdict(f); r["requested_roles"]=list(f.requested_roles); r["hard_cases"]=list(f.hard_cases); rows.append(r)
    return {
        "schema_version":1,"tool_version":TOOL_VERSION,"evidence_kind":"GOLDEN_G1_G2_CORPUS_INTAKE",
        "intake_state":"READY_FOR_HQ_GOLDEN_GATE","parity_state":"NON_PARITY_EVIDENCE_ONLY",
        "corpus_id":index["corpus_id"],"corpus_revision":index["corpus_revision"],
        "policy_id":policy["policy_id"],"policy_sha256":policy_sha,"corpus_lock_sha256":lock,
        "coverage":cov,"fixtures":rows,
        "privacy":{"source_paths_emitted":False,"media_titles_emitted":False,"raw_rights_record_ids_emitted":False,"raw_audio_emitted":False},
        "parity_reason":"Golden intake readiness only; live provider, current-iPhone differential, device evidence and HQ PARITY remain separate gates.",
    }

def validate_golden_corpus_files(*, root, index_path, policy_path):
    root=Path(root).resolve()
    for value,field in ((str(index_path),"index_path"),(str(policy_path),"policy_path")): no_symlink(root,value,field)
    ip=safe_relative_path(root,str(index_path),"index_path"); pp=safe_relative_path(root,str(policy_path),"policy_path")
    if not ip.is_file() or not pp.is_file(): raise err("GOLDEN_CONTROL_FILE_MISSING")
    return validate_golden_corpus(root=root,index=load_json(ip),policy=load_json(pp))

def atomic_dump(path, payload):
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_name(path.name+".tmp")
    try:
        with tmp.open("w",encoding="utf-8") as h:
            h.write(json.dumps(payload,indent=2,sort_keys=True,ensure_ascii=False,allow_nan=False)+"\n"); h.flush(); os.fsync(h.fileno())
        os.replace(tmp,path)
    except OSError as exc:
        try: tmp.unlink(missing_ok=True)
        except OSError: pass
        raise err("GOLDEN_REPORT_WRITE_FAILED") from exc

def main(argv:Sequence[str]|None=None):
    p=argparse.ArgumentParser(); p.add_argument("--root",required=True); p.add_argument("--index",required=True); p.add_argument("--policy",required=True); p.add_argument("--out",required=True)
    a=p.parse_args(argv)
    try:
        report=validate_golden_corpus_files(root=a.root,index_path=a.index,policy_path=a.policy); atomic_dump(a.out,report)
    except EvaluationError as exc:
        print(exc.code,file=sys.stderr); return 2
    print(report["corpus_lock_sha256"]); return 0

if __name__=="__main__":
    raise SystemExit(main())
