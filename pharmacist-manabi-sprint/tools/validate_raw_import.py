#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "content" / "raw"
EXPECTED = {"必須":90,"理論":105,"実践":150}
EXAMS = (111,110,109)
errors=[]
warnings=[]
summaries=[]
all_ids=[]
normalized_stems=defaultdict(list)


def norm(s):
    return re.sub(r"\s+","",str(s or "")).casefold()

for exam in EXAMS:
    p=RAW/f"exam-{exam}-raw.json"
    if not p.exists():
        errors.append(f"exam {exam}: raw file missing")
        continue
    d=json.loads(p.read_text(encoding="utf-8"))
    qs=d.get("questions",[])
    if len(qs)!=345:
        errors.append(f"exam {exam}: expected 345, got {len(qs)}")
    counts=Counter(q.get("subject") for q in qs)
    for sec,n in EXPECTED.items():
        if counts[sec]!=n:
            errors.append(f"exam {exam}/{sec}: {counts[sec]}/{n}")
    seen=set(); media=0; parse_issues=0; excluded=0; flex=0; missing_expl=0
    for q in qs:
        qid=q.get("id")
        if not qid or qid in seen:
            errors.append(f"exam {exam}: duplicate/missing id {qid}")
        seen.add(qid); all_ids.append(qid)
        n=int(q.get("questionNo",0) or 0)
        if not (1<=n<=345): errors.append(f"{qid}: questionNo invalid {n}")
        stem=str(q.get("question") or "").strip()
        if len(stem)<2: errors.append(f"{qid}: empty/short stem")
        if re.search(r"(?:^|\s)問\s*\d{1,3}(?:\s|$)", stem):
            warnings.append(f"{qid}: another question marker remains in stem")
        normalized_stems[norm(stem)].append(qid)
        if not q.get("primary_source") or not q.get("source_url") or not q.get("answer_source_url"):
            errors.append(f"{qid}: source refs missing")
        if not q.get("rights_basis") or not q.get("effective_date"):
            errors.append(f"{qid}: rights/effective-date missing")
        choices=q.get("choices")
        if not isinstance(choices,list): errors.append(f"{qid}: choices not list"); choices=[]
        if q.get("requires_media"): media+=1
        if q.get("choiceParseStatus")!="parsed": parse_issues+=1
        status=q.get("scoring_status")
        ans=q.get("answer")
        if status=="excluded":
            excluded+=1
            if ans is not None: errors.append(f"{qid}: excluded has answer")
        elif status=="multiple_accepted":
            flex+=1
            if not isinstance(q.get("accepted_answers"),list) or len(q["accepted_answers"])<2:
                errors.append(f"{qid}: flexible accepted answers missing")
        elif status!="normal":
            errors.append(f"{qid}: scoring status invalid {status}")
        if status!="excluded" and not q.get("requires_media"):
            if q.get("answer_type")=="singleChoice":
                if not isinstance(ans,int) or not (0<=ans<len(choices)):
                    errors.append(f"{qid}: single answer/choice mismatch")
            elif q.get("answer_type")=="multiChoice":
                if not isinstance(ans,list) or len(ans)<2 or any(not isinstance(x,int) or x<0 or x>=len(choices) for x in ans):
                    errors.append(f"{qid}: multi answer/choice mismatch")
            else:
                errors.append(f"{qid}: answer type invalid {q.get('answer_type')}")
        if not q.get("explanation"): missing_expl+=1
    summaries.append({"exam":exam,"count":len(qs),"sections":dict(counts),"requiresMedia":media,"choiceParseIssues":parse_issues,"excluded":excluded,"multipleAccepted":flex,"missingExplanations":missing_expl})

for qid,c in Counter(all_ids).items():
    if c>1: errors.append(f"global duplicate id {qid}")

exact_dups=[]
for key,ids in normalized_stems.items():
    if key and len(ids)>1:
        exact_dups.append(ids)

report={
    "schemaVersion":1,
    "structuralErrors":errors,
    "warnings":warnings,
    "exams":summaries,
    "total":sum(x["count"] for x in summaries),
    "exactDuplicateOfficialStems":exact_dups,
    "rawImportPass":not errors and sum(x["count"] for x in summaries)==1035,
    "releaseAllowed":False,
    "note":"公式raw取込監査。raw PASSは公開許可ではない。解説・媒体・意味分類・重複/高類似・権利最終監査を別ゲートで必須とする。"
}
(RAW/"raw-audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report,ensure_ascii=False))
if not report["rawImportPass"]:
    sys.exit(1)
