#!/usr/bin/env python3
"""Verify 500 IPA source-index and official answer records. NOT a verbatim release pass."""
import json,re
from pathlib import Path

root=Path(__file__).resolve().parents[1]/"questions"
answers=json.loads((root/"official-answer-index.json").read_text(encoding="utf-8"))
bank=json.loads((root/"official-candidate-index.json").read_text(encoding="utf-8"))
ledger=json.loads((root/"official-source-ledger.json").read_text(encoding="utf-8"))
manifest=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
published=json.loads((root/"official-verbatim.json").read_text(encoding="utf-8"))
assert len(published)==manifest["canonical"]["official"]["current"], "Official manifest/current mismatch"
assert len({x["id"] for x in published})==len(published), "Duplicate audited IDs"
for x in published:
    assert x["origin_type"]=="ipa_published_verbatim" and x["verbatim_visual_audit"]=="PASS"
    assert x["official_answer_audit"]=="PASS" and len(x["choices"])==4
    assert x["question"].strip() and all(t.strip() for t in x["choices"])
    assert re.fullmatch("[a-f0-9]{64}",x["source_image_sha256"])
    assert x["source_image_committed"] is False and x["publishable"] is False
    year=next(y for y in answers["years"] if y["year"]==x["year"])
    assert x["correct_label"]==year["answer_sequence_question_1_to_100"][x["question_number"]-1]
    assert x["correct_index"]=="アイウエ".index(x["correct_label"])
    assert x["source_question_pdf_sha256"]==year["question_sha256"]
    assert x["source_answer_pdf_sha256"]==year["answer_sha256"]
assert answers["answer_records_verified"]==500 and answers["sha256_match_to_user"]==10
assert len(bank["items"])==bank["candidate_count"]==500
assert bank["answer_audit_pass"]==500 and bank["question_verbatim_pass"]==len(published)
assert all(not x["publishable"] for x in bank["items"]), "Unverified question incorrectly publishable"
assert [x["year"] for x in answers["years"]]==list(range(2022,2027))
assert len(ledger["years"])==5
for a,source in zip(answers["years"],ledger["years"]):
    year=a["year"]; rows=[x for x in bank["items"] if x["year"]==year]
    assert len(rows)==100 and len(a["answer_sequence_question_1_to_100"])==100
    assert [x["question_number"] for x in rows]==list(range(1,101))
    assert a["question_sha256"]==source["question_pdf_sha256"]
    assert a["answer_sha256"]==source["answer_pdf_sha256"]
    assert re.fullmatch("[a-f0-9]{64}",a["question_sha256"])
    assert re.fullmatch("[a-f0-9]{64}",a["answer_sha256"])
    for item in rows:
        n=item["question_number"]
        assert item["correct_label"]==a["answer_sequence_question_1_to_100"][n-1]
        assert item["correct_index"]=="アイウエ".index(item["correct_label"])
        assert item["answer_audit"]=="PASS_TWO_PDF_TEXT_ENGINES"
        assert item["question_pdf_sha256"]==a["question_sha256"]
        assert item["answer_pdf_sha256"]==a["answer_sha256"]
        assert 1<=item["source_pdf_page"]<=60
        assert item["question_body_status"] in {"OCR_CANDIDATE_VISUAL_AUDIT_REQUIRED","PASS_INDEPENDENT_VISUAL"}
        assert item["choices_status"] in {"OCR_CANDIDATE_VISUAL_AUDIT_REQUIRED","PASS_INDEPENDENT_VISUAL"}
        assert item["origin_type"]=="ipa_published_exam_candidate"
print("PASS: 500 IPA source-question candidates / 500 official answers / 10 source hashes; no unverified question published")
