#!/usr/bin/env python3
"""Reconcile FP2 five-exam content with all seven per-batch independent reviews.

Scope: structural / persisted evidence, not legal rights or unarchived source verification.
"""
from collections import Counter
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "fp2-manabi-sprint"
BANK = json.loads((APP / "questions/canonical/approved-questions-20261123.json").read_text())
SEL = json.loads((APP / "release/release-selection-300-20261123.json").read_text())
ROWS = {q["id"]: q for q in BANK["questions"]}
PACKAGES = [
 ("202409-b01", "FP2_202409_B01_INDEPENDENT_PRELIMINARY_20261123.json", 20),
 ("202409-b02", "FP2_202409_B02_INDEPENDENT_20261123.json", 20),
 ("202409-b03", "FP2_202409_B03_INDEPENDENT_20261123.json", 20),
 ("202405-b02", "FP2_202405_B02_INDEPENDENT_20261123.json", 20),
 ("202405-b03", "FP2_202405_B03_INDEPENDENT_20261123.json", 20),
 ("202405-b04", "FP2_202405_B04_INDEPENDENT_20261123.json", 17),
]
def blob_sha(p):
    data=p.read_bytes()
    return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()

seen=set()
pass_count=0
for suffix,audit_name,expected in PACKAGES:
    draft_path=APP/"questions/draft"/("fp2-official-"+suffix+".json")
    audit_path=APP/"audit"/audit_name
    draft=json.loads(draft_path.read_text())
    audit=json.loads(audit_path.read_text())
    assert audit["source_blob_sha"]==blob_sha(draft_path),suffix+" draft sha"
    assert len(draft["questions"])==expected==len(audit["items"]),suffix+" counts"
    audited={q["id"]:q for q in audit["items"]}
    assert len(audited)==expected
    for q in draft["questions"]:
        v=audited[q["id"]]
        assert q["id"] not in seen,"duplicate id"
        seen.add(q["id"])
        assert v["status"]=="PASS" and v["canonical_content_eligible"] is True
        assert v["stem"]==q["stem"] and v["answer_zero_based"]==q["answer"]
        assert v["modified"] is True and q["modified"] is True
        assert v["applicable_on"]==q["applicable_on"]=="2026-04-01"
        assert len(v["choice_verification"])==len(q["choices"])==4
        for i,c in enumerate(v["choice_verification"]):
            assert c["text"]==q["choices"][i]
            if "correct" in c: assert c["correct"] is (i==q["answer"])
            if "correct_in_draft" in c: assert c["correct_in_draft"] is (i==q["answer"])
        row=ROWS[q["id"]]
        assert row["audit_evidence_blob_sha"]==blob_sha(audit_path)
        assert row["audit_source_blob_sha"]==blob_sha(draft_path)
        assert row["modification_note_draft"]==q["modification_note"]
        assert row["modification_note"]==v["modification_note_review"]
        assert row["modified"] is True and row["independent_audit_status"]=="PASS"
        assert row["release_selected"] is True and row["publishable"] is False
        assert row["answer_index"]==q["answer"] and row["answer_one_based"]==q["answer"]+1
        pass_count+=1
assert pass_count==117

resolution_path=APP/"audit/FP2_202405_B01_HOLD3_RESOLUTION_20261123.json"
resolution=json.loads(resolution_path.read_text())
existing=[]
assert len(resolution["items"])==3
for v in resolution["items"]:
    ident=v["id"]
    assert ident not in seen
    seen.add(ident)
    q=ROWS[ident]
    assert v["status"]=="PASS" and v["canonical_content_eligible"] is True
    assert q["original_question_number"]==v["original_question_number"]
    assert (q.get("question") or q.get("stem"))==v["stem"]
    assert q["answer_index"]==v["answer_zero_based"]
    assert q["choices"]==[c["text"] for c in v["choice_verification"]]
    assert q["modified"] is True and q["modification_note"]==v["modification_note_review"]
    assert q["expansion_202405_resolution_evidence_blob_sha"]==blob_sha(resolution_path)
    assert q["release_selected"] is True and q["publishable"] is False
    existing.append(ident)
assert sorted(existing)==["FP2-OFFICIAL-202405-Q01","FP2-OFFICIAL-202405-Q02","FP2-OFFICIAL-202405-Q06"]

assert len(ROWS)==len(BANK["questions"])==312
selected=[q for q in BANK["questions"] if q["release_selected"]]
reserve=[q for q in BANK["questions"] if not q["release_selected"]]
assert len(selected)==SEL["selected_count"]==300
assert len(reserve)==SEL["reserve_count"]==12
assert all(q["id"].startswith("FP2-ORIG-") for q in reserve)
assert set(seen)=={q["id"] for q in selected if (q.get("exam_year_month") or q.get("examDate")) in ("2024-05","2024-09")}
sessions=Counter(q.get("exam_year_month") or q.get("examDate") for q in selected)
domains=Counter(q["domain"] for q in selected)
assert set(sessions)=={"2024-05","2024-09","2025-01","2025-05","2026-05"}
assert set(sessions.values())=={60}
assert len(domains)==6 and set(domains.values())=={50}
assert SEL["canonical_git_blob_sha"]==blob_sha(APP/"questions/canonical/approved-questions-20261123.json")
assert all(q["publishable"] is False for q in BANK["questions"])
assert BANK["expansion_audit_pass_count"]==120 and BANK["expansion_audit_fail_count"]==BANK["expansion_audit_hold_count"]==0
print(json.dumps({"result":"PASS","batch_records":[20,20,20,20,20,17],"revalidated_202405":3,"expansion_pass":120,"expansion_fail":0,"expansion_hold":0,"canonical_total":312,"release_selected":300,"audited_original_reserve":12,"sessions":dict(sessions),"domains":dict(domains),"publication_clear":0},ensure_ascii=False))
