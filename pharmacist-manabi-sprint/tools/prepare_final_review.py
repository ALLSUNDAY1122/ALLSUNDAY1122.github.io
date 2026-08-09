#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "content" / "raw"
OUT = ROOT / "content" / "review"
OUT.mkdir(parents=True, exist_ok=True)

cols = [
    "id","sourceExam","questionNo","subject","domain","question","choices_json",
    "answer_type","answer_json","accepted_answers_json","scoring_status",
    "requires_media","choiceParseStatus","correctionStatus_json","caseGroupId",
    "source_url","answer_source_url","effective_date","rights_basis"
]
text_rows=[]
media_rows=[]
exceptions=[]
all_rows=[]

for exam in (111,110,109):
    data=json.loads((RAW/f"exam-{exam}-raw.json").read_text(encoding="utf-8"))
    for q in data["questions"]:
        row={
            "id":q["id"],"sourceExam":q["sourceExam"],"questionNo":q["questionNo"],
            "subject":q["subject"],"domain":q["domain"],"question":q["question"],
            "choices_json":json.dumps(q.get("choices",[]),ensure_ascii=False,separators=(",",":")),
            "answer_type":q.get("answer_type"),
            "answer_json":json.dumps(q.get("answer"),ensure_ascii=False,separators=(",",":")),
            "accepted_answers_json":json.dumps(q.get("accepted_answers"),ensure_ascii=False,separators=(",",":")),
            "scoring_status":q.get("scoring_status"),
            "requires_media":str(bool(q.get("requires_media"))).lower(),
            "choiceParseStatus":q.get("choiceParseStatus"),
            "correctionStatus_json":json.dumps(q.get("correctionStatus",[]),ensure_ascii=False,separators=(",",":")),
            "caseGroupId":q.get("caseGroupId") or "",
            "source_url":q.get("source_url"),"answer_source_url":q.get("answer_source_url"),
            "effective_date":q.get("effective_date"),"rights_basis":q.get("rights_basis")
        }
        all_rows.append(row)
        if q.get("requires_media") or q.get("choiceParseStatus") != "parsed":
            media_rows.append(row)
        else:
            text_rows.append(row)
        if q.get("scoring_status") != "normal" or q.get("correctionStatus") != ["none"]:
            exceptions.append({k:q.get(k) for k in ["id","sourceExam","questionNo","scoring_status","answer","accepted_answers","correctionStatus","source_url","answer_source_url"]})

for name,rows in [("all-queue.tsv",all_rows),("text-queue.tsv",text_rows),("media-queue.tsv",media_rows)]:
    with (OUT/name).open("w",encoding="utf-8",newline="") as f:
        w=csv.DictWriter(f,fieldnames=cols,delimiter="\t",lineterminator="\n")
        w.writeheader(); w.writerows(rows)

(OUT/"exceptions.json").write_text(json.dumps(exceptions,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
summary={
    "schemaVersion":1,"total":len(all_rows),"textQueue":len(text_rows),"mediaQueue":len(media_rows),
    "exceptions":len(exceptions),"explanationReviewed":0,"mediaRebuilt":0,"releaseAllowed":False,
    "nextGate":"Complete explanation overlay for every non-excluded question; rebuild/restate media queue; then run final semantic/duplicate/high-similarity/rights audits."
}
(OUT/"summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(summary,ensure_ascii=False))
if len(all_rows)!=1035:
    raise SystemExit(f"expected 1035 rows, got {len(all_rows)}")
