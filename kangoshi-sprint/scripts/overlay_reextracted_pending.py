#!/usr/bin/env python3
"""Restore verified staged candidate fixes after fetching historical draft branch.

This overlays text only, never status/answer/rights; every entry must correspond
to one historical candidate and bear previous run evidence.
"""
import json,pathlib,copy
R=pathlib.Path(__file__).resolve().parents[1]
P=R/"product-content/coordinate-reextracted-pending-20261124.json"
data=json.loads(P.read_text())
assert data["count"]==len(data["questions"])==22
byid={q["id"]:q for q in data["questions"]}
assert len(byid)==22
assert all(q["publishable"] is False and q["releaseEligible"] is False for q in byid.values())
for exam in (111,112):
 for session in ("AM","PM"):
  path=R/"product-content/keyed-candidates"/f"exam{exam}-{session}-draft.json"
  bank=json.loads(path.read_text())
  for q in bank["questions"]:
   old=byid.get(q["id"])
   if not old:continue
   assert (q["answer"],q["officialKeyRaw"],q["officialKeyPdfSha256"])==(old["answer"],old["officialKeyRaw"],old["officialKeyPdfSha256"])
   for key in ("question","choices","sourcePage"):q[key]=copy.deepcopy(old[key])
   q["extractionValid"]=bool(old["extractionValid"])
   q["pendingSourceEvidence"]=old["coordinateReextractionAudit"]
  path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"overlayPending":len(byid),"sourceFile":str(P.relative_to(R))}))
