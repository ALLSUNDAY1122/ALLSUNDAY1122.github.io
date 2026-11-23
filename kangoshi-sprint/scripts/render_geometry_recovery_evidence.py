#!/usr/bin/env python3
"""Render audited question-specific exact PDF rectangles and cryptographic index.

The attached crops are evidence for per-question human visual review, NOT
automatic OCR claims. Two-engine field verification and official key checks
are recorded separately in the frozen promotion batch.
"""
import pathlib,json,hashlib
import fitz
from PIL import Image,ImageOps,ImageDraw
ROOT=pathlib.Path(__file__).resolve().parents[1]
batch=json.loads((ROOT/"audit/geometry-recovery-batch-20261124.json").read_text())
OUT=ROOT/"audit/runs/geometry-recovery-images-20261124"
OUT.mkdir(parents=True,exist_ok=True)
records=[];thumbs=[]
for item in batch["items"]:
    ex,session,pg=item["exam"],item["session"],item["page"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf"
    srcsha=hashlib.sha256(pdf.read_bytes()).hexdigest()
    if srcsha!=item["sourcePdfSha256"]:raise RuntimeError("PDF source drift "+item["id"])
    doc=fitz.open(pdf)
    page=doc[pg-1]
    clip=item["geometry"]["rectangle"]
    x0,y0,x1,y1=map(float,clip)
    if not(0<=x0<x1<=page.rect.width+0.1 and 0<=y0<y1<=page.rect.height+0.1):
        raise RuntimeError("Invalid clip "+item["id"])
    if item["geometry"].get("fields")!=5:raise RuntimeError("5-field gate missing "+item["id"])
    rect=fitz.Rect(x0,y0,x1,y1)
    png=OUT/f"{item['id']}-question-region.png"
    page.get_pixmap(matrix=fitz.Matrix(2.8,2.8),clip=rect,alpha=False).save(str(png))
    rendered=Image.open(png)
    stamp=f"{item['id']}  {ex}/{session} Q{item['number']:03d}  PDF p{pg}"
    thumb=rendered.copy()
    thumb.thumbnail((690,450))
    framed=Image.new("RGB",(720,490),"white")
    framed.paste(thumb,((720-thumb.width)//2,34))
    ImageDraw.Draw(framed).text((12,11),stamp,fill="black")
    thumbs.append(framed)
    records.append({"id":item["id"],"page":pg,"clip":clip,"sourcePdfSha256":srcsha,
      "image":png.name,"regionPngSha256":hashlib.sha256(png.read_bytes()).hexdigest(),
      "officialKeyPdfSha256":item["officialKeyPdfSha256"],"answer":item["answer"],
      "geometricVerification":item["geometry"]["method"],"status":"SOURCE_ONLY_IMAGE_EVIDENCE_READY"})
assert len(records)==batch["newPromoted"]==20
sheet=Image.new("RGB",(720*4,490*5),"#ededed")
for i,thumb in enumerate(thumbs):sheet.paste(thumb,((i%4)*720,(i//4)*490))
sheet.save(OUT/"contact-sheet-20.jpg",quality=83)
index={"schemaVersion":1,"count":len(records),"sourceRun":batch["run"],
       "imagesPurpose":"individually inspect printed source question numbers and all four choices; does not alone establish glyph verification",
       "contactSheet":"contact-sheet-20.jpg","items":records}
(OUT/"index.json").write_text(json.dumps(index,ensure_ascii=False,indent=2)+"\n")
(ROOT/"audit/geometry-recovery-image-index-20261124.json").write_text(json.dumps(index,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"imageEvidence":len(records),"index":"audit/geometry-recovery-image-index-20261124.json","contactSheet":"contact-sheet-20.jpg"}))
