#!/usr/bin/env python3
"""Build review-only app schema from unapproved extracted 2026 official questions."""
import json,re
from pathlib import Path
BASE=Path(__file__).resolve().parent
import sys,os
YEAR=int(os.environ.get("EXAM_YEAR",sys.argv[1] if len(sys.argv)>1 else "2022"))
src=json.loads((BASE/f"QUESTIONS_{YEAR}_RAW_STAGING.json").read_text())
DIGITS="１２３４５"
ROWS=re.compile(r"(?m)^\s*([１２３４５1-5])\s+(?=\S)")
INLINE=re.compile(r"([１２３４５1-5])\s*[（(]([^）)\n]+)[）)]")
out=[]
holds=[]
for q in src["questions"]:
 raw=q["rawOriginalText"]
 starts=list(ROWS.finditer(raw))
 choices=None;prefix=None;mode=None
 def digits(ms):
  return "".join(str(DIGITS.index(m.group(1))+1) if m.group(1) in DIGITS else m.group(1) for m in ms)
 for length in (5,4):
  if len(starts)==length and digits(starts)=="12345"[:length]:
   prefix=raw[:starts[0].start()].strip()
   choices=[raw[starts[i].end():starts[i+1].start() if i<length-1 else len(raw)].strip() for i in range(length)]
   mode="row"
   break
 if choices is None:
  inline=list(INLINE.finditer(raw))
  for length in (5,4):
   if len(inline)==length and digits(inline)=="12345"[:length]:
    prefix=raw[:inline[0].start()].strip()
    choices=[m.group(2) for m in inline]
    mode="inline"
    break
 if choices is None or any(not c for c in choices) or not prefix:
  holds.append(q["questionNo"])
  choices=None
  prefix=raw
  mode="UNPARSED_HOLD"
 question={**q,"question":prefix,"choices":choices,"answer":q["answer"],"candidateParsingMode":mode,
           "needsVisualReview":True,"verbatimCertified":False,"renderReady":False}
 out.append(question)
if len(out)!=120:raise RuntimeError(f"question total mismatch: {len(out)}")
target=BASE/f"QUESTIONS_{YEAR}_APP_CANDIDATE.json"
target.write_text(json.dumps({"schema":"touroku-hanbaisha-official-v1",
  "status":"REVIEW_ONLY_NOT_FOR_PRODUCTION","year":YEAR,"count":120,
  "sourceKey":f"ANSWERS_{YEAR}_OFFICIAL.json",
  "warning":"No visual audit of 120 questions; PDF furigana, inline tables and choices may have errors.",
  "parseHolds":holds,"parsedChoiceCount":120-len(holds),"questions":out},ensure_ascii=False,indent=2)+"\n")
print("app-shaped candidate:",len(out),"row",sum(q["candidateParsingMode"]=="row" for q in out),
 "inline",sum(q["candidateParsingMode"]=="inline" for q in out),"hold",holds)
