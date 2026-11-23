#!/usr/bin/env python3
"""Materialize exhaustive audit ledger, never infer visual PASS from structural parsing."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
reviews=json.loads((ROOT/"MANUAL_VISUAL_AUDIT_20261123.json").read_text())["reviewedQuestions"]
byid={r["id"]:r for r in reviews}
assert len(byid)==len(reviews)
result=[]
for year in range(2022,2027):
    src=json.loads((ROOT/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())
    key=json.loads((ROOT/f"ANSWERS_{year}_OFFICIAL.json").read_text())
    for number,q in enumerate(src["questions"],1):
        assert q["id"]==f"KSAI-{year}-{number:03d}" and q["questionNo"]==number
        ans=key["questions"][number-1]
        assert q["answerNumberOfficial"]==ans["official_answer"]
        reviewed=byid.get(q["id"])
        status=reviewed["status"] if reviewed else "PENDING_VISUAL_AUDIT"
        flags=[]
        if re.search(r"\n\s*[ぁ-ん]{1,8}\s*\n|\n\s*り\s*\n",q.get("rawOriginalText","")):flags.append("RUBY_LAYOUT")
        if "配合成分" in q["rawOriginalText"] or "組合せ" in q["rawOriginalText"]:flags.append("COMBINATION_OR_TABLE")
        if len(q.get("choices") or [])==4:flags.append("FOUR_OPTIONS")
        if q.get("choices") is None:flags.append("OPTION_EXTRACTION_HOLD")
        if q.get("excludeFromAccuracyDenominator"):flags.append("OFFICIAL_INVALID_EXCLUDED_FROM_SCORING")
        result.append({"id":q["id"],"year":year,"number":number,"status":status,
                       "candidateFile":f"QUESTIONS_{year}_APP_CANDIDATE.json",
                       "pdfUrl":q["sourceUrl"],"pdfPages":q["sourcePdfPages"],
                       "answerNumber":q["answerNumberOfficial"],
                       "sourceIndexMatches":True,"riskFlags":flags,
                       "reviewEvidence":reviewed.get("evidence","") if reviewed else ""})
assert len(result)==600
assert sum(r["status"]=="PASS" for r in result)==sum(r["status"]=="PASS" for r in reviews)
assert sum(r["status"]=="HOLD" for r in result)==sum(r["status"]=="HOLD" for r in reviews)
assert sum(r["status"]=="PENDING_VISUAL_AUDIT" for r in result)==600-len(reviews)
assert any(r["id"]=="KSAI-2023-090" and "OFFICIAL_INVALID_EXCLUDED_FROM_SCORING" in r["riskFlags"] for r in result)
out={"status":"VISUAL_AUDIT_IN_PROGRESS","yearlyTotals":{str(y):{"total":120,"PASS":sum(q["year"]==y and q["status"]=="PASS" for q in result),"HOLD":sum(q["year"]==y and q["status"]=="HOLD" for q in result),"PENDING":sum(q["year"]==y and q["status"]=="PENDING_VISUAL_AUDIT" for q in result)} for y in range(2022,2027)},
     "count":600,"visualPass":sum(r["status"]=="PASS" for r in result),"visualHold":sum(r["status"]=="HOLD" for r in result),"visualPending":600-len(reviews),
     "note":"Source index and five/four-choice structure PASS do not constitute per-question visual fidelity.",
     "questions":result}
(ROOT/"AUDIT_MATRIX_600.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("AUDIT MATRIX",len(result),"PASS",sum(r["status"]=="PASS" for r in result),"HOLD",sum(r["status"]=="HOLD" for r in result))
