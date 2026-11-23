#!/usr/bin/env python3
"""Rehydrate only clean earlier PDF-glyph-reviewed source repairs for held items.

Restored text remains a candidate, never a PASS. The subsequent verifier must
prove actual geometric PDF identity, all four fields in two engines, and the
independent official answer. No scoring, media, or suspect glyph is waived.
"""
import json,pathlib,re,collections
ROOT=pathlib.Path(__file__).resolve().parents[1]
L=json.loads((ROOT/"audit/staging-repair-evidence/glyph-map-repair-ledger.json").read_text())
H=json.loads((ROOT/"audit/dual-engine-hold-20261124.json").read_text())
V=json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())
held={q["id"] for q in H["hold"]}
verified={q["id"] for q in V["questions"]}
assert not held&verified
byid={x["id"]:x for x in L["originalAndRepaired"]}
assert len(byid)==len(L["originalAndRepaired"])
bad=re.compile(r"[!?ïñèêçâ\ufffd\x00-\x1f\x7f-\x9f]|DKIX|[-−]H[-−]\d+")
records=[]
for ex in (111,112):
 for session in ("AM","PM"):
  path=ROOT/"product-content/keyed-candidates"/f"exam{ex}-{session}-draft.json"
  b=json.loads(path.read_text())
  for q in b["questions"]:
   if q["id"] not in held:continue
   old=byid.get(q["id"])
   if not old:continue
   to=old["to"];choices=to.get("choices") or []
   vals=[to.get("question") or ""]+choices
   if len(choices)!=4 or any(not v or bad.search(v) for v in vals):continue
   if not (isinstance(to.get("sourcePage"),int) and to["sourcePage"]>0):continue
   before={k:q.get(k) for k in ("question","choices","sourcePage","extractionValid")}
   if (before["question"],before["choices"],before["sourcePage"])==(to["question"],choices,to["sourcePage"]):continue
   q.update(question=to["question"],choices=choices,sourcePage=to["sourcePage"])
   # All reconstructed fields are nonempty; independent source proof remains required.
   q["extractionValid"]=True
   q["previousVisuallyReviewedGlyphMapCandidate"]={
       "ledger":"audit/staging-repair-evidence/glyph-map-repair-ledger.json",
       "evidenceRule":old.get("mappingRule"),"independentReauditPending":True}
   records.append({"id":q["id"],"before":before,"after":{k:q[k] for k in before},
                   "source":old.get("sourcePdf"),"previousRule":old.get("mappingRule"),
                   "status":"CANDIDATE_ONLY_UNVERIFIED"})
  path.write_text(json.dumps(b,ensure_ascii=False,indent=2)+"\n")
dest=ROOT/"audit/runs/dual-engine-20261124/prior-repair-overlay-evidence.json"
dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_text(json.dumps({"count":len(records),"questions":records,
"note":"Prior visual glyph ledger used for candidate restoration; independent 2-engine + official key gates still mandatory."},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"restoredToCandidate":len(records),"notAutomaticallyPromoted":len(records)},ensure_ascii=False))
