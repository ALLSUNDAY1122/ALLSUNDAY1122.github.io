#!/usr/bin/env python3
"""Validate all 500 official scanned question-image evidence records; fail closed for release."""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
Q=ROOT/"questions"

def load(name):
    return json.loads((Q/name).read_text(encoding="utf-8"))

def main(release=False):
    repairs=load("official-image-boundary-repairs.json")
    evidence=load("official-image-audit-500.json")
    candidates=load("official-candidate-index.json")["items"]
    published=load("official-verbatim.json")
    assert len(repairs["items"])==repairs["repaired_questions"]==21
    assert repairs["current_page_fallbacks"]==0
    assert len(evidence["items"])==len(candidates)==500
    assert evidence["source_raster_equivalent_count"]==500
    assert evidence["repaired_boundary_count"]==21
    assert evidence["independent_verbatim_content_pass_count"]==0
    assert evidence["publishable_count"]==len(published)==0
    ids={x["id"] for x in candidates}
    assert len(ids)==500
    rep={(x["year"],x["number"]):x for x in repairs["items"]}
    assert len(rep)==21
    seen=set()
    for x in evidence["items"]:
        ident=(x["year"],x["question_number"])
        assert x["id"] in ids and ident not in seen
        seen.add(ident)
        assert x["official_answer_audit"]=="PASS_TWO_ENGINES"
        assert x["source_raster_equivalence"]=="PASS"
        assert x["verbatim_text_audit"]=="PENDING"
        assert x["choices_verbatim_audit"]=="PENDING"
        assert x["figures_visual_audit"]=="PENDING"
        assert x["promoted"] is False
        assert x["git_binary_committed"] is False
        if ident in rep:
            fix=rep[ident]
            assert x["boundary_status"]=="REPAIRED_MANUAL_BOUNDARY_VISUAL_PASS"
            assert fix["source_pdf_page"]==x["source_pdf_page"]
            assert fix["bbox_native_pixels"][0]==80 and fix["bbox_native_pixels"][2]==1352
            assert 0<=fix["bbox_native_pixels"][1]<fix["bbox_native_pixels"][3]<=2026
        else:
            assert x["boundary_status"]=="AUTOMATED_BOUNDARY_RASTER_MATCH_VISUAL_REVIEW_PENDING"
    assert len(seen)==500
    if release:
        assert all(x["git_binary_committed"] for x in evidence["items"]), "500 image asset bytes missing from GitHub"
        assert all(x["verbatim_text_audit"]=="PASS" for x in evidence["items"]), "Question wording not independently verified"
        assert len(published)==500, "500 release questions not yet promoted"
    print("PASS: 21 source-image crop repairs; 500 raster-equivalent source crop candidates; 0 false release approvals")

if __name__=="__main__":
    try:main("--release" in sys.argv)
    except (AssertionError,KeyError,ValueError) as ex:
        print(f"BLOCKED: {ex}",file=sys.stderr)
        sys.exit(1)
