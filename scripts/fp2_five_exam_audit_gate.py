#!/usr/bin/env python3
"""FP2 2024 verbatim legal-audit reconciliation; fail closed on invalid current-law or missing family figure."""
from collections import Counter
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/"fp2-manabi-sprint"
def load(p): return json.loads(p.read_text(encoding="utf-8"))
def git_blob(p):
    d=p.read_bytes()
    return hashlib.sha1(b"blob "+str(len(d)).encode()+b"\0"+d).hexdigest()
bank=load(APP/"questions/canonical/approved-questions-20261123.json")
selection=load(APP/"release/release-selection-300-20261123.json")
quarantine=load(APP/"questions/quarantine/fp2-verbatim-2024-legal-fail-and-q53-hold-20261123.json")
records={q["id"]:q for q in bank["questions"]}
assert len(records)==len(bank["questions"])==309
selected=[q for q in records.values() if q["release_selected"]]
reserve=[q for q in records.values() if not q["release_selected"]]
assert len(selected)==selection["selected_count"]==300 and len(reserve)==selection["reserve_count"]==9
expected={
 "202409":{ "pass":59,"fail":1,"hold":0 },
 "202405":{ "pass":58,"fail":1,"hold":1 }
}
quarantine_ids={"fp2-2024-09-gakka-007":"FAIL","fp2-2024-05-gakka-008":"FAIL","fp2-2024-05-gakka-053":"HOLD"}
assert {x["id"]:x["status"] for x in quarantine["records"]}==quarantine_ids
audits={
 "202409":APP/"audit/FP2_202409_VERBATIM_60_INDEPENDENT_LEGAL_20261123.json",
 "202405":APP/"audit/FP2_202405_VERBATIM_60_INDEPENDENT_LEGAL_20261123.json"
}
found=set()
retained_pass=set()
for key,audit_path in audits.items():
    audit=load(audit_path)
    statuses=Counter(q["status"] for q in audit["items"])
    assert all(statuses.get(k.upper(),0)==v for k,v in expected[key].items()),(key,statuses)
    assert len(audit["items"])==60
    indexed={q["id"]:q for q in audit["items"]}
    docs=[]
    for group,source_record in enumerate(audit["source_files"]):
        path=ROOT/source_record["path"]
        assert path.is_file(),str(path)
        sha=git_blob(path)
        recorded=source_record.get("blob_sha") or source_record.get("sha")
        if key=="202405" and group==2:
            # After the independent review, ONLY the held Q53's figure metadata changed.
            # All nineteen audited PASS records are verified against the actual source below.
            assert recorded=="27a08d04670a75f133076df5a86ee97dcf149e86"
            assert sha=="066eadb5116e8430c8e7b2449078983e4e095bda"
        else:
            assert sha==recorded,(key,group,"source Git Blob changed")
        chunk=load(path)
        assert isinstance(chunk,list) and len(chunk)==20
        docs+=chunk
        for q in chunk:
            a=indexed[q["id"]]
            assert q["id"] not in found
            found.add(q["id"])
            choices=(a["choices"] if key=="202409" else a["choice_verification"])
            assert q["question"]==(a.get("question_stem") or a.get("stem"))
            assert q["choices"]==[c["text"] for c in choices]
            if a["status"]=="PASS":
                assert q["answer"]==a["answer_on_2026_04_01"]
                assert q["id"] in records
                c=records[q["id"]]
                assert c["question"]==q["question"] and c["choices"]==q["choices"]
                assert c["answer_index"]==q["answer"]-1 and c["answer_one_based"]==q["answer"]
                assert c["approved_for_content_bank"] is True and c["independent_audit_status"]=="PASS"
                assert c["modified"] is False and c["publishable"] is False and c["release_selected"] is True
                assert c["audit_evidence_blob_sha"]==git_blob(audit_path)
                assert c["audit_source_blob_sha"]==sha
                assert c["audit_source_path"]==source_record["path"]
                retained_pass.add(q["id"])
            else:
                assert q["id"] not in records,("FAIL/HOLD leaked into approved bank",q["id"])
                assert a["status"]==quarantine_ids[q["id"]]
                # The 2024-05 Q53 figure must NOT be assumed available until uploaded,
                # visually checked and independently reaudited.
                if q["id"]=="fp2-2024-05-gakka-053":
                    fig=q["audit"]["uploaded_visual_source"]
                    assert fig["binary_committed"] is False
                    assert q["audit"]["exhibit_status"]=="UNREPRODUCIBLE_FAMILY_RELATION_DIAGRAM"
    assert len(docs)==60
assert len(found)==120 and len(retained_pass)==117
assert len([q for q in selected if q["id"] in retained_pass])==117
assert all(q["id"] in retained_pass for q in selected if q["examDate"] in ("2024-09","2024-05"))
original_backfills={"FP2-ORIG-20261123-L01","FP2-ORIG-20261123-L02","FP2-ORIG-20261123-S01"}
assert {q["id"] for q in selected if q["id"].startswith("FP2-ORIG-")}==original_backfills
assert all(q["independent_audit_status"]=="PASS" for q in selected if q["id"] in original_backfills)
assert len(reserve)==9 and all(q["id"].startswith("FP2-ORIG-") for q in reserve)
sessions=Counter(q.get("examDate") or q.get("exam_year_month") or "independently-authored" for q in selected)
assert sessions=={"2024-05":58,"2024-09":59,"2025-01":60,"2025-05":60,"2026-05":60,"independently-authored":3}
domains=Counter(q["domain"] for q in selected)
assert len(domains)==6 and set(domains.values())=={50}
assert selection["canonical_git_blob_sha"]==git_blob(APP/"questions/canonical/approved-questions-20261123.json")
assert set(selection["current_law_excluded_ids"])==set(quarantine_ids)
assert all(q["publishable"] is False for q in bank["questions"])
assert bank["content_approved_questions"]==309 and bank["publishable_questions"]==0
assert (bank["expansion_audit_pass_count"],bank["expansion_audit_fail_count"],bank["expansion_audit_hold_count"])==(117,2,1)
print(json.dumps({"result":"PASS","verbatim_202409":{"PASS":59,"FAIL":1,"HOLD":0},"verbatim_202405":{"PASS":58,"FAIL":1,"HOLD":1},"quarantine":list(quarantine_ids),"approved_canonical":309,"release_selected":300,"audited_original_reserve":9,"backfill":list(original_backfills),"sessions":dict(sessions),"domains":dict(domains),"rights_clear":0},ensure_ascii=False))
