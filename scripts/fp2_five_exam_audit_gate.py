#!/usr/bin/env python3
"""Five-exam FP2 integration gate: 298 official PASS selected, 12 originals reserved.

A structural and recorded independent-audit reconciliation, NOT copyright or App Store approval.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "fp2-manabi-sprint"
def load(path):
    return json.loads(path.read_text(encoding="utf-8"))
def blob(path):
    data = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
bank = load(APP / "questions/canonical/approved-questions-20261123.json")
manifest = load(APP / "release/release-selection-300-20261123.json")
quarantine = load(APP / "questions/quarantine/fp2-verbatim-2024-legal-fail-and-q53-hold-20261123.json")
questions = bank["questions"]
indexed = {q["id"]: q for q in questions}
assert len(indexed) == len(questions) == bank["content_approved_questions"] == 310
selected = [q for q in questions if q["release_selected"] is True]
reserves = [q for q in questions if q["release_selected"] is False]
assert len(selected) == manifest["selected_count"] == 298
assert len(reserves) == manifest["reserve_count"] == 12
assert all(q["id"].startswith("FP2-ORIG-") for q in reserves)
assert not any(q["id"].startswith("FP2-ORIG-") for q in selected)
assert all(q["publishable"] is False for q in questions)
excluded = {"fp2-2024-09-gakka-007": "FAIL", "fp2-2024-05-gakka-008": "FAIL"}
assert {r["id"]: r["status"] for r in quarantine["records"]} == excluded
assert not (set(excluded) & set(indexed))
total = Counter()
seen = set()
for exam in ("202405", "202409", "202501", "202505", "202605"):
    record = load(APP / f"audit/FP2_{exam}_VERBATIM_60_INDEPENDENT_LEGAL_20261123.json")
    status = Counter((item.get("status") or item.get("legal_verdict")) for item in record["items"])
    assert sum(status.values()) == 60, (exam, status)
    assert status["PASS"] == (59 if exam in ("202405", "202409") else 60), (exam, status)
    assert status["FAIL"] == (1 if exam in ("202405", "202409") else 0), (exam, status)
    assert status["HOLD"] == 0, (exam, status)
    total.update(status)
    for item in record["items"]:
        id = item["id"]
        assert id not in seen, id
        seen.add(id)
        verdict = item.get("status") or item.get("legal_verdict")
        if verdict == "FAIL":
            assert id in excluded and id not in indexed, id
            continue
        assert verdict == "PASS" and id in indexed, id
        q = indexed[id]
        assert q["release_selected"] is True
        assert q["independent_audit_status"] == "PASS"
        assert q["answer_one_based"] == q["answer"] and q["answer_index"] == q["answer"] - 1
        answer = item.get("answer_on_2026_04_01") or item.get("current_answer_one_based") or item.get("legal_answer_one_based")
        assert q["answer"] == answer, (id, q["answer"], answer)
        assert q["audit_evidence_path"] == f"fp2-manabi-sprint/audit/FP2_{exam}_VERBATIM_60_INDEPENDENT_LEGAL_20261123.json" if exam in ("202405","202409") else True
        path = ROOT / q["audit_evidence_path"]
        assert path.exists() and blob(path) == q["audit_evidence_blob_sha"], id
    for batch in ("b01", "b02", "b03"):
        path = APP / f"questions/verbatim/fp2-official-{exam}-{batch}-verbatim.json"
        assert path.is_file(), path
        source = load(path)
        assert len(source) == 20, path
        for item in source:
            if item["id"] not in indexed:
                assert item["id"] in excluded
                continue
            q = indexed[item["id"]]
            assert q["question"] == item["question"], item["id"]
            assert q["choices"] == item["choices"], item["id"]
            assert q["answer"] == item["answer"], item["id"]
assert len(seen) == 300 and total == {"PASS": 298, "FAIL": 2}
scope = [id for group in manifest["domains"] for id in group["selected_ids"]]
assert len(scope) == len(set(scope)) == 298
assert set(scope) == {q["id"] for q in selected}
distribution = Counter(q["domain"] for q in selected)
assert sorted(distribution.values()) == [48, 50, 50, 50, 50, 50], distribution
for id, fig in [("fp2-2024-05-gakka-053", "fp2-202405-q53-family-diagram.png"), ("fp2-2026-05-gakka-055", "fp2-202605-q55-family-diagram.png")]:
    assert id in indexed and indexed[id]["release_selected"] is True
    path = APP / "questions/verbatim/assets" / fig
    assert path.is_file() and path.stat().st_size > 1000, path
    assert indexed[id]["audit"]["uploaded_visual_source"].get("binary_committed") is True
assert manifest["canonical_git_blob_sha"] == blob(APP / "questions/canonical/approved-questions-20261123.json")
print(json.dumps({"status":"PASS","official_audit":dict(total),"canonical":310,"selected":298,"original_reserve":12,"quarantine":list(excluded),"distribution":dict(distribution),"publishable":0,"rights_clear":False},ensure_ascii=False))
