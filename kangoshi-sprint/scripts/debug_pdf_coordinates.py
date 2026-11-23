#!/usr/bin/env python3
"""Finite non-mutating diagnostics for numbered anchors and printed PDF coordinates."""
import json,pathlib,fitz,sys
R=pathlib.Path(__file__).resolve().parents[1]
for exam,session,nums in [(111,"AM",[4,106,109]),(111,"PM",[91,106]),(112,"PM",[98,113])]:
  pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
  doc=fitz.open(pdf)
  data=json.loads((R/"product-content/keyed-candidates"/f"exam{exam}-{session}-draft.json").read_text())
  for n in nums:
    q=next(x for x in data["questions"] if x["questionNo"]==n)
    pg=q["sourcePage"]
    print("COORD_DEBUG",exam,session,n,"page",pg,"stem",repr(q["question"][:60]))
    for p in range(max(1,pg-1),min(len(doc),pg+1)+1):
      page=doc[p-1]; words=page.get_text("words",sort=True)
      left=[(round(w[0],1),round(w[1],1),str(w[4])) for w in words if w[0] < page.rect.width*.3]
      print("COORD_PAGE",p,"size",(page.rect.width,page.rect.height),"left_first",repr(left[:100]))
      print("COORD_NUM_HITS",repr([(round(w[0],1),round(w[1],1),w[4]) for w in words if str(n) in str(w[4])][:20]))
