#!/usr/bin/env python3
"""Render source pages for all residual independently reextracted question holds.

Evidence only. This script never declares fidelity PASS from text extractor
agreement: CMap mapping can be wrong identically in both parsers.
"""
import pathlib, json, collections, hashlib, re
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
PENDING=json.loads((ROOT/"product-content/coordinate-reextracted-pending-20261124.json").read_text())
CAN=json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())
HOLD=json.loads((ROOT/"audit/dual-engine-hold-20261124.json").read_text())
approved={q["id"] for q in CAN["questions"]}
by_hold={q["id"]:q["reasons"] for q in HOLD["hold"]}
OUT=ROOT/"audit/runs/context-control-visual-20261124"
OUT.mkdir(parents=True,exist_ok=True)
rows=[]
for q in PENDING["questions"]:
    if q["id"] in approved:continue
    n=q["questionNo"];pg=q["sourcePage"];ex=q["sourceExam"];ses=q["session"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ses}.pdf"
    doc=fitz.open(pdf)
    for page_number in sorted({pg,max(1,pg-1),max(1,pg-2),max(1,pg-3)}):
        page=doc[page_number-1]
        png=OUT/f"{q['id']}-p{page_number}.png"
        page.get_pixmap(matrix=fitz.Matrix(2.1,2.1),alpha=False).save(str(png))
    source=doc[pg-1].get_text("text",sort=False)
    unknown=collections.Counter(hex(ord(c)) for c in source if ord(c)<32 and c not in "\\n\\r\\t" and ord(c) not in {2,4,5,6,7,8,11,12,31})
    rows.append({"id":q["id"],"exam":ex,"session":ses,"number":n,"sourcePage":pg,
                 "pagesRendered":sorted({pg,max(1,pg-1),max(1,pg-2),max(1,pg-3)}),
                 "reasons":by_hold.get(q["id"],[]),"sourcePdfSha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),
                 "unmappedControlOnQuestionPage":dict(unknown),"status":"VISUAL_INSPECTION_PENDING"})
# Additional sole-glyph holds: produce source-page evidence, never auto-approve.
already={x["id"] for x in rows}
extras={"K111-PM054","K112-PM001","K112-PM027","K112-PM066"}
for target in sorted(extras):
    if target in already or target not in by_hold:continue
    ex=int(target[1:4]);ses=target[5:7];no=int(target[7:])
    draft=ROOT/"product-content/keyed-candidates"/f"exam{ex}-{ses}-draft.json"
    bank=json.loads(draft.read_text())
    hits=[q for q in bank["questions"] if q["id"]==target]
    if len(hits)!=1:raise ValueError("Unresolvable source "+target)
    q=hits[0];pg=q["sourcePage"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ses}.pdf"
    pdf_doc=fitz.open(pdf)
    pglist=sorted({pg,max(1,pg-1)})
    for pageno in pglist:
        pdf_doc[pageno-1].get_pixmap(matrix=fitz.Matrix(2.1,2.1),alpha=False).save(str(OUT/f"{target}-p{pageno}.png"))
    rows.append({"id":target,"exam":ex,"session":ses,"number":no,"sourcePage":pg,
                 "pagesRendered":pglist,"reasons":by_hold[target],
                 "sourcePdfSha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),
                 "status":"VISUAL_INSPECTION_PENDING"})
doc={"count":len(rows),"items":rows,"note":"Images show true PDF page glyphs. No OCR or model inspection pass inferred automatically."}
(OUT/"index.json").write_text(json.dumps(doc,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"pending":len(rows),"rendered":sum(len(x["pagesRendered"]) for x in rows)},ensure_ascii=False))
