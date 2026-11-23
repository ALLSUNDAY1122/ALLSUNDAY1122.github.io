#!/usr/bin/env python3
"""Repair ONLY independently recognizable printed page-control footer contamination.
Do not attempt C0 glyph decoding. Preserve source before/after audit.
"""
import json,pathlib,re,collections,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
STAGE=ROOT/"product-content/keyed-candidates"
OUT=ROOT/"audit/runs/footer-repair-20261124";OUT.mkdir(parents=True,exist_ok=True)
FOOTER=re.compile(r"(?:\s*DKIX[-\s0-9A-Za-z\u524d\u5f8c]+[-‐−]?H[-‐−]?\d+\s*)$")
# conservative match EXACT page footer, optionally trailing extracted sequence number
EXACT=re.compile(r"\s*DKIX-\d{2}-(?:前|後)H-\d+(?:\s+\d+)?\s*$")
revisions=[]
for ex in (111,112):
 for ss in ("AM","PM"):
    path=STAGE/f"exam{ex}-{ss}-draft.json"
    d=json.loads(path.read_text(encoding="utf8"))
    for q in d["questions"]:
      before=[str(x) for x in q.get("choices",[])]
      after=[EXACT.sub("",c).rstrip() for c in before]
      # A footer sometimes became a spurious fifth choice; remove ONLY when its page number matches sourcePage.
      safe=[]
      for c in after:
        original=before[len(safe)] if len(safe)<len(before) else c
        m=re.search(r"DKIX-\\d{2}-(?:前|後)H-(\\d+)",original)
        if not c and m and int(m.group(1))==q.get("sourcePage"):
          continue
        safe.append(c)
      after=safe
      for index,(b,a) in enumerate(zip(before,after)):
        if not b and not a:continue
        if b!=a:
          revisions.append({"id":q["id"],"field":f"choices[{index}]","before":b,"after":a,
            "reason":"Remove printed MHLW page-control footer DKIX-XX-前/後H-N which is outside answer options",
            "officialQuestionUrl":(q.get("sourceRefs") or [None])[0]})
      if len(after)<len(before):
        revisions.append({"id":q["id"],"field":"choices","before":before,"after":after,"reason":"Dropped page footer masquerading as an extra choice after matching printed page number","officialQuestionUrl":(q.get("sourceRefs") or [None])[0]})
      q["choices"]=after
      if len(after)==4 and all(after) and not any("DKIX" in x for x in after):
        q["extractionValid"]=True
      q["transcriptionRepairStatus"]="PAGE_FOOTER_STRIPPED_REVIEW_UNCHANGED" if before!=after else q.get("transcriptionRepairStatus","NOT_TOUCHED")
    path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
out={"schemaVersion":1,"repairedFields":len(revisions),"repairedQuestions":len({x["id"] for x in revisions}),
"changes":revisions,"scope":"Footer-only repairs; source C0 glyphs, missing numerals and visual references remain quarantined.","safeForReleaseWithoutSecondEngine":False}
(OUT/"footer-repairs.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
print(json.dumps({"footerRepairs":len(revisions),"affected":out["repairedQuestions"]},ensure_ascii=False))
