from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
from datetime import date
from pathlib import Path

EVALUATION = Path(__file__).resolve().parents[1] / "Evaluation"
if str(EVALUATION) not in sys.path:
    sys.path.insert(0, str(EVALUATION))

from rights_cleared_audio_intake import RightsIntakeError, sha256_file, validate_rights_packet_from_report

TODAY = date(2026, 8, 24)


def h(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def make_base(root: Path):
    corpus = root / "corpus"
    rights = root / "rights"
    corpus.mkdir()
    rights.mkdir()
    records = []
    golden_rows = []
    for fixture_id, group, reference_allowed in (("g1-rock", "G1", False), ("g2-pop", "G2", True)):
        manifest = {
            "schema_version": 1,
            "fixture_id": fixture_id,
            "rights_record_id": f"RIGHTS-{fixture_id}",
            "rights_status": "VERIFIED",
            "real_recorded_music": True,
            "synthetic": False,
            "commercial_engineering_use_allowed": True,
            "reference_service_submission_allowed": reference_allowed,
        }
        manifest_path = corpus / f"{fixture_id}.json"
        manifest_path.write_text(json.dumps(manifest, sort_keys=True), encoding="utf-8")
        manifest_sha = sha256_file(manifest_path)

        source_document = rights / f"{fixture_id}.txt"
        source_document.write_text(f"private source rights document for {fixture_id}", encoding="utf-8")
        document_sha = sha256_file(source_document)
        grant = {
            "schema_version": 1,
            "rights_record_id": f"RIGHTS-{fixture_id}",
            "fixture_id": fixture_id,
            "grant_state": "VERIFIED",
            "authority_reviewed": True,
            "revoked": False,
            "effective_date": "2026-01-01",
            "expires_date": None,
            "source_document": {"path": source_document.name, "sha256": document_sha},
            "provenance": {"real_recorded_music_attested": True, "synthetic_or_generated": False, "origin_record_id": f"ORIGIN-{fixture_id}"},
            "permissions": {
                "commercial_engineering_use": True,
                "project_processing_submission": True,
                "reference_service_submission": reference_allowed,
                "isolated_source_evaluation": group == "G1",
                "internal_stem_evaluation": group == "G1",
                "redistribution_allowed": False,
            },
        }
        grant_path = rights / f"{fixture_id}.grant.json"
        grant_path.write_text(json.dumps(grant, sort_keys=True), encoding="utf-8")
        grant_sha = sha256_file(grant_path)
        records.append({
            "fixture_id": fixture_id,
            "expected_group": group,
            "fixture_manifest_path": manifest_path.name,
            "fixture_manifest_sha256": manifest_sha,
            "grant_record_path": grant_path.name,
            "grant_record_sha256": grant_sha,
        })
        rights_ref = hashlib.sha256(("lane1-golden-rights-ref-v1\0" + f"RIGHTS-{fixture_id}").encode("utf-8")).hexdigest()
        golden_rows.append({
            "fixture_id": fixture_id,
            "group": group,
            "manifest_sha256": manifest_sha,
            "mixture_sha256": h((fixture_id + "-mix").encode()),
            "reference_sha256_by_role": {"vocals": h((fixture_id + "-vocals").encode())} if group == "G1" else {},
            "rights_record_ref_hash": rights_ref,
        })

    rights_index = {
        "schema_version": 1,
        "evidence_state": "NON_PARITY_EVIDENCE_ONLY",
        "corpus_id": "C1",
        "corpus_revision": "R1",
        "records": records,
    }
    golden = {
        "intake_state": "READY_FOR_HQ_GOLDEN_GATE",
        "parity_state": "NON_PARITY_EVIDENCE_ONLY",
        "corpus_lock_sha256": h(b"golden"),
        "corpus_id": "C1",
        "corpus_revision": "R1",
        "fixtures": golden_rows,
    }
    return corpus, rights, golden, rights_index


def mutate_grant(rights: Path, index: dict, fn, row: int = 0):
    record = index["records"][row]
    path = rights / record["grant_record_path"]
    grant = json.loads(path.read_text(encoding="utf-8"))
    fn(grant)
    path.write_text(json.dumps(grant, sort_keys=True), encoding="utf-8")
    record["grant_record_sha256"] = sha256_file(path)


def mutate_manifest(corpus: Path, golden: dict, index: dict, fn, row: int = 0):
    record = index["records"][row]
    path = corpus / record["fixture_manifest_path"]
    manifest = json.loads(path.read_text(encoding="utf-8"))
    fn(manifest)
    path.write_text(json.dumps(manifest, sort_keys=True), encoding="utf-8")
    digest = sha256_file(path)
    record["fixture_manifest_sha256"] = digest
    golden["fixtures"][row]["manifest_sha256"] = digest


def expect_code(mutator, expected: str):
    with tempfile.TemporaryDirectory() as tmp:
        corpus, rights, golden, index = make_base(Path(tmp))
        mutator(corpus, rights, golden, index)
        try:
            validate_rights_packet_from_report(corpus_root=corpus, rights_root=rights, golden_report=golden, rights_index=index, today=TODAY)
        except RightsIntakeError as exc:
            assert exc.code == expected, (exc.code, expected)
        else:
            raise AssertionError(f"expected {expected}")


def main() -> None:
    count = 0
    with tempfile.TemporaryDirectory() as tmp:
        corpus, rights, golden, index = make_base(Path(tmp))
        report = validate_rights_packet_from_report(corpus_root=corpus, rights_root=rights, golden_report=golden, rights_index=index, today=TODAY)
        assert report["intake_state"] == "READY_FOR_HQ_LIVE_AUDIO_GATE"; count += 1
        assert report["parity_state"] == "NON_PARITY_EVIDENCE_ONLY"; count += 1
        encoded = json.dumps(report, sort_keys=True)
        assert "RIGHTS-g1-rock" not in encoded and "ORIGIN-g1-rock" not in encoded; count += 1
        assert ".grant.json" not in encoded and "private source rights document" not in encoded; count += 1
        first_lock = report["e02_rights_intake_lock_sha256"]
        index["records"] = list(reversed(index["records"]))
        second = validate_rights_packet_from_report(corpus_root=corpus, rights_root=rights, golden_report=golden, rights_index=index, today=TODAY)
        assert second["e02_rights_intake_lock_sha256"] == first_lock; count += 1

    cases = [
        (lambda c,r,g,i: g.update(intake_state="PENDING"), "L1E02_A19_NOT_READY"),
        (lambda c,r,g,i: g.update(parity_state="PARITY"), "L1E02_A19_PARITY_STATE_INVALID"),
        (lambda c,r,g,i: i.update(corpus_id="C2"), "L1E02_CORPUS_IDENTITY_MISMATCH"),
        (lambda c,r,g,i: i["records"].pop(), "L1E02_RIGHTS_COVERAGE_MISMATCH"),
        (lambda c,r,g,i: i["records"][0].update(expected_group="G2"), "L1E02_GROUP_MISMATCH"),
        (lambda c,r,g,i: g["fixtures"][0].update(manifest_sha256="0"*64), "L1E02_A19_MANIFEST_BINDING_MISMATCH"),
        (lambda c,r,g,i: (c / i["records"][0]["fixture_manifest_path"]).write_text("tamper"), "L1E02_FIXTURE_MANIFEST_SHA_MISMATCH"),
        (lambda c,r,g,i: (r / i["records"][0]["grant_record_path"]).write_text("tamper"), "L1E02_GRANT_RECORD_SHA_MISMATCH"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(grant_state="PENDING")), "L1E02_GRANT_NOT_VERIFIED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(authority_reviewed=False)), "L1E02_AUTHORITY_UNVERIFIED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(revoked=True)), "L1E02_GRANT_REVOKED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(effective_date="2027-01-01")), "L1E02_GRANT_NOT_EFFECTIVE"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(expires_date="2026-01-01")), "L1E02_GRANT_EXPIRED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["source_document"].update(sha256="0"*64)), "L1E02_SOURCE_DOCUMENT_SHA_MISMATCH"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["provenance"].update(real_recorded_music_attested=False)), "L1E02_REAL_RECORDING_NOT_ATTESTED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["provenance"].update(synthetic_or_generated=True)), "L1E02_SYNTHETIC_OR_GENERATED_FORBIDDEN"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["permissions"].update(commercial_engineering_use=False)), "L1E02_COMMERCIAL_ENGINEERING_DENIED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["permissions"].update(project_processing_submission=False)), "L1E02_PROJECT_SUBMISSION_DENIED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["permissions"].update(isolated_source_evaluation=False),0), "L1E02_G1_ISOLATED_SOURCE_RIGHTS_REQUIRED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["permissions"].update(internal_stem_evaluation=False),0), "L1E02_G1_ISOLATED_SOURCE_RIGHTS_REQUIRED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["permissions"].update(reference_service_submission=False),1), "L1E02_G2_REFERENCE_SUBMISSION_REQUIRED"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x.update(rights_record_id="RIGHTS-OTHER"),0), "L1E02_RIGHTS_RECORD_ID_MISMATCH"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(rights_status="PENDING")), "L1E02_MANIFEST_RIGHTS_NOT_VERIFIED"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(real_recorded_music=False)), "L1E02_MANIFEST_REAL_AUDIO_REQUIRED"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(synthetic=True)), "L1E02_MANIFEST_REAL_AUDIO_REQUIRED"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(commercial_engineering_use_allowed=False)), "L1E02_MANIFEST_COMMERCIAL_DENIED"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(reference_service_submission_allowed=False),1), "L1E02_G2_MANIFEST_REFERENCE_RIGHT_REQUIRED"),
        (lambda c,r,g,i: mutate_manifest(c,g,i,lambda x:x.update(reference_service_submission_allowed=True),0), "L1E02_MANIFEST_REFERENCE_RIGHT_OVERCLAIM"),
        (lambda c,r,g,i: i.update(extra=True), "L1E02_SCHEMA_UNKNOWN_FIELD"),
        (lambda c,r,g,i: i["records"].append(copy.deepcopy(i["records"][0])), "L1E02_FIXTURE_DUPLICATE"),
        (lambda c,r,g,i: mutate_grant(r,i,lambda x:x["source_document"].update(path="missing.txt")), "L1E02_SOURCE_DOCUMENT_MISSING"),
        (lambda c,r,g,i: (c / i["records"][0]["fixture_manifest_path"]).unlink(), "L1E02_FIXTURE_MANIFEST_MISSING"),
    ]
    for mutator, expected in cases:
        expect_code(mutator, expected)
        count += 1

    assert count == 37, count
    print(f"L1-E02 rights intake: {count}/{count} PASS")


if __name__ == "__main__":
    main()
