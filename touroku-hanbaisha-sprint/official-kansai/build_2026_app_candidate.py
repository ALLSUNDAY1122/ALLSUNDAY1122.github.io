#!/usr/bin/env python3
"""Build review-only app schema from unapproved extracted 2026 official questions."""
import json,re
from pathlib import Path
BASE=Path(__file__).resolve().parent
src=json.loads((BASE/"QUESTIONS_2026_RAW_STAGING.json").read_text())
FULL="１２３４５"
ROWS=re.compile(r"(?m)^\s*([１２３４５])\s+(?=\S)")
INLINE=re.compile(r"([１２３４５])（([^）\n]+)）")
out=[]
fail=[]
for q in src["questions"]:
 raw=q["rawOriginalText"]
 starts=list(ROWS.finditer(raw))
 choices=None;prefix=None;mode=None
 if len(starts)==5 and [m.group(1) for m in starts]==list(FULL):
  prefix=raw[:starts[0].start()].strip()
  choices=[raw[starts[i].end():starts[i+1].start() if i<4 else len(raw)].strip() for i in range(5)]
  mode="row"
 else:
  inline=list(INLINE.finditer(raw))
  if len(inline)==5 and [m.group(1) for m in inline]==list(FULL):
   prefix=raw[:inline[0].start()].strip()
   choices=[m.group(2) for m in inline]
   mode="inline"
 if choices is None or any(not c for c in choices):
  fail.append(q["questionNo"]);continue
 question={**q,"question":prefix,"choices":choices,"answer":q["answer"],"officialStatus":"NORMAL","excludeFromAccuracyDenominator":False,"scoringPolicy":"SINGLE_ANSWER","candidateParsingMode":mode,
           "needsVisualReview":True,"verbatimCertified":False,"renderReady":False}
 out.append(question)
if fail or len(out)!=120:raise RuntimeError(f"choice parsing failed: {fail}, count={len(out)}")
target=BASE/"QUESTIONS_2026_APP_CANDIDATE.json"
target.write_text(json.dumps({"schema":"touroku-hanbaisha-official-v1",
  "status":"REVIEW_ONLY_NOT_FOR_PRODUCTION","year":2026,"count":120,
  "sourceKey":"ANSWERS_2026_OFFICIAL.json",
  "warning":"No visual audit of 120 questions; PDF furigana, inline tables and choices may have errors.",
  "questions":out},ensure_ascii=False,indent=2)+"\n")
print("app-shaped candidate:",len(out),"row",sum(q["candidateParsingMode"]=="row" for q in out),
 "inline",sum(q["candidateParsingMode"]=="inline" for q in out))
