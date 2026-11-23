#!/usr/bin/env python3
"""Render each currently held question from official PDF geometric source evidence.

Anchor-only geometric cases are NOT approved: this creates focused visual
material to resolve text mapping, fifth options, media and scoring exceptions.
"""
import pathlib,json,hashlib,collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
from sys import path
path.insert(0,str(ROOT/"scripts"))
from boundary_context_verify import _region
from bulk_text_helpers import clean_font
hold=json.loads((ROOT/"audit/dual-engine-hold-20261124.json").read_text())["hold"]
held={q["id"]:q for q in hold}
out=ROOT/"audit/runs/residual-geometric-images-20261124"
out.mkdir(parents=True,exist_ok=True)
rows=[];per=collections.Counter()
for ex in (112,111):
 for ses in ("AM","PM"):
  src=ROOT/"product-content/keyed-candidates"/f"exam{ex}-{ses}-draft.json"
  bank=json.loads(src.read_text())
  pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ses}.pdf"
  doc=fitz.open(pdf);pdfsha=hashlib.sha256(pdf.read_bytes()).hexdigest()
  for q in bank["questions"]:
   if q["id"] not in held:continue
   pg=q.get("sourcePage");n=q["questionNo"]
   if not isinstance(pg,int) or not 1<=pg<=len(doc):
    rows.append({"id":q["id"],"status":"PAGE_INVALID","reasons":held[q["id"]]["reasons"]})
    per["PAGE_INVALID"]+=1;continue
   found=[]
   for candidate in range(max(1,pg-3),min(len(doc),pg+3)+1):
    region,geo=_region(doc[candidate-1],n,clean_font)
    if region is not None:found.append((candidate,geo))
   if len(found)==1:
    target,geo=found[0];clip=fitz.Rect(*geo["clip"]);status="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED"
   else:
    target=pg;geo=None;clip=doc[pg-1].rect;status="AMBIGUOUS_OR_MISSING_ANCHOR_FULL_PAGE_VISUAL"
   png=out/f"{q['id']}-source-region.png"
   doc[target-1].get_pixmap(matrix=fitz.Matrix(2.0,2.0),clip=clip,alpha=False).save(str(png))
   rows.append({"id":q["id"],"pageHint":pg,"renderedPage":target,"anchorMatchesInWindow":len(found),
                "anchorBox":geo["anchorBox"] if geo else None,
                "clip":[round(v,2) for v in clip],"reasons":held[q["id"]]["reasons"],
                "sourcePdfSha256":pdfsha,"imageFile":png.name,
                "imageSha256":hashlib.sha256(png.read_bytes()).hexdigest(),
                "status":status})
   per[status]+=1
if len(rows)!=len(hold):raise ValueError("not all held items accounted for")
meta={"schemaVersion":1,"count":len(rows),"statuses":dict(per),"items":rows,
      "note":"Source coordinate/page image hashes for all held candidates; text, scoring and rights gates still independent and unpassed."}
(out/"index.json").write_text(json.dumps(meta,ensure_ascii=False,indent=2)+"\n")
(ROOT/"audit/residual-geometric-source-index-20261124.json").write_text(json.dumps(meta,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"heldSourceImages":len(rows),"geometry":dict(per)},ensure_ascii=False))
