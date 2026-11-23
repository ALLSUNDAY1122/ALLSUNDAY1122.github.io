#!/usr/bin/env python3
"""Render every newly certified source candidate from its original PDF region.

This creates evidence only, NOT human approval. Exact PDF SHA and clip,
numbered question, and all source verification gates remain independent.
"""
import json,pathlib,hashlib
import fitz
from PIL import Image,ImageDraw
ROOT=pathlib.Path(__file__).resolve().parents[1]
L=json.loads((ROOT/"audit/dual-engine-promotion-ledger-20261124.json").read_text())
OUT=ROOT/"audit/runs/latest-new-source-regions-20261124"
OUT.mkdir(parents=True,exist_ok=True)
rows=[];thumbs=[]
for e in L["eachItem"]:
    qid=e["id"];exam=e["exam"];sess=e["session"];page_n=e["sourcePdfPage"]
    geo=e.get("geometricCrosscheckEvidence") or e.get("coordinateBoundaryEvidence") or {}
    clip=geo.get("rectangle") or geo.get("clip")
    if not clip:raise ValueError("No unique coordinate proof "+qid)
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{sess}.pdf"
    source_sha=hashlib.sha256(pdf.read_bytes()).hexdigest()
    if source_sha!=e["sourcePdfSha256"]:raise ValueError("Source PDF hash drift "+qid)
    doc=fitz.open(pdf);page=doc[page_n-1]
    x0,y0,x1,y1=map(float,clip)
    if not(0<=x0<x1<=page.rect.width+.1 and 0<=y0<y1<=page.rect.height+.1):
        raise ValueError("Out-of-range question source clip "+qid)
    file=OUT/f"{qid}-official-region.png"
    page.get_pixmap(matrix=fitz.Matrix(2.6,2.6),clip=fitz.Rect(*clip),alpha=False).save(str(file))
    thumb=Image.open(file);thumb.thumbnail((660,420))
    box=Image.new("RGB",(680,465),"white")
    box.paste(thumb,((680-thumb.width)//2,34))
    ImageDraw.Draw(box).text((10,10),qid+"  PDF page "+str(page_n),fill="black")
    thumbs.append(box)
    rows.append({"id":qid,"exam":exam,"session":sess,"page":page_n,"choiceCountFromSourceEvidence":(geo.get("printedOptionCount") or (geo.get("fields",0)-1) or None),
        "officialAnswer":e.get("answer"),"clip":clip,"sourcePdfSha256":source_sha,
        "pngFilename":file.name,"pngSha256":hashlib.sha256(file.read_bytes()).hexdigest(),
        "status":"SOURCE_IMAGE_RENDERED_FIDELITY_NOT_HUMAN_SIGNED"})
# OCR-CMap promotions are proven by a separate image-pinned ledger.
# Include them in the same image count invariant, rather than counting only
# PyMuPDF/Poppler promotions in L["eachItem"].
ocr_proof=ROOT/"audit/ocr-cmap-repair-ledger-20261124.json"
if ocr_proof.exists():
    evidence=json.loads(ocr_proof.read_text())
    for e in evidence["perQuestion"]:
        if e["status"]!="REPAIRED_SOURCE_ONLY" or e["id"] not in set(L.get("newIds",[])):continue
        qid=e["id"];exam=e["sourceExam"];sess=e["session"];page_n=e["sourcePage"]
        if any(r["id"]==qid for r in rows):raise ValueError("Duplicate image evidence "+qid)
        clip=e["coordinateClip"]
        pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{sess}.pdf"
        source_sha=hashlib.sha256(pdf.read_bytes()).hexdigest()
        if source_sha!=e["sourcePdfSha256"]:raise ValueError("OCR proof PDF hash drift "+qid)
        doc=fitz.open(pdf); page=doc[page_n-1]
        x0,y0,x1,y1=map(float,clip)
        if not (0<=x0<x1<=page.rect.width+.1 and 0<=y0<y1<=page.rect.height+.1):
            raise ValueError("OCR proof out-of-range clip "+qid)
        original=ROOT/"audit/runs/residual-geometric-images-20261124"/(qid+"-source-region.png")
        if not original.is_file() or hashlib.sha256(original.read_bytes()).hexdigest()!=e["sourceImageSha256"]:
            raise ValueError("OCR image hash not pinned "+qid)
        file=OUT/f"{qid}-official-region.png"
        page.get_pixmap(matrix=fitz.Matrix(2.6,2.6),clip=fitz.Rect(*clip),alpha=False).save(str(file))
        thumb=Image.open(file);thumb.thumbnail((660,420))
        box=Image.new("RGB",(680,465),"white")
        box.paste(thumb,((680-thumb.width)//2,34))
        ImageDraw.Draw(box).text((10,10),qid+"  OCR PDF page "+str(page_n),fill="black")
        thumbs.append(box)
        rows.append({"id":qid,"exam":exam,"session":sess,"page":page_n,
            "clip":clip,"sourcePdfSha256":source_sha,"pngFilename":file.name,
            "pngSha256":hashlib.sha256(file.read_bytes()).hexdigest(),
            "originalOcrSourceImageSha256":e["sourceImageSha256"],
            "status":"OCR_CMAP_SOURCE_IMAGE_RENDERED_NO_HUMAN_SIGNOFF"})
coordinate_proof=ROOT/"audit/ocr-coordinate-repair-ledger-20261124.json"
if coordinate_proof.exists():
    evidence=json.loads(coordinate_proof.read_text())
    for e in evidence["perQuestion"]:
        if e.get("status")!="PROMOTED_SOURCE_ONLY" or e["id"] not in set(L.get("newIds",[])):continue
        qid=e["id"];exam=e["exam"];sess=e["session"];page_n=e["pdfPage"]
        if any(r["id"]==qid for r in rows):raise ValueError("Duplicate coordinate proof "+qid)
        clip=e["coordinateClip"]
        pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{sess}.pdf"
        source_sha=hashlib.sha256(pdf.read_bytes()).hexdigest()
        if source_sha!=e["originalPdfSha256"]:raise ValueError("Coordinate PDF SHA drift "+qid)
        page=fitz.open(pdf)[page_n-1]
        x0,y0,x1,y1=map(float,clip)
        if not(0<=x0<x1<=page.rect.width+.1 and 0<=y0<y1<=page.rect.height+.1):
            raise ValueError("Out-of-range coordinate OCR proof "+qid)
        file=OUT/f"{qid}-official-region.png"
        page.get_pixmap(matrix=fitz.Matrix(2.6,2.6),clip=fitz.Rect(*clip),alpha=False).save(str(file))
        thumb=Image.open(file);thumb.thumbnail((660,420))
        box=Image.new("RGB",(680,465),"white")
        box.paste(thumb,((680-thumb.width)//2,34))
        ImageDraw.Draw(box).text((10,10),qid+"  Coordinate OCR PDF "+str(page_n),fill="black")
        thumbs.append(box)
        rows.append({"id":qid,"exam":exam,"session":sess,"page":page_n,"clip":clip,
            "sourcePdfSha256":source_sha,"pngFilename":file.name,
            "pngSha256":hashlib.sha256(file.read_bytes()).hexdigest(),
            "status":"COORDINATE_OCR_SOURCE_IMAGE_RENDERED_NOT_HUMAN_SIGNED"})
noncmap_proof=ROOT/"audit/ocr-noncmap-repair-ledger-20261124.json"
if noncmap_proof.exists():
    evidence=json.loads(noncmap_proof.read_text())
    for e in evidence["perQuestion"]:
        if e.get("status")!="PROMOTED_SOURCE_ONLY" or e["id"] not in set(L.get("newIds",[])):continue
        qid=e["id"];exam=e["exam"];sess=e["session"];page_n=e["sourcePdfPage"]
        if any(r["id"]==qid for r in rows):raise ValueError("Duplicate 21 source proof "+qid)
        clip=e["coordinateClip"]
        pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{sess}.pdf"
        source_sha=hashlib.sha256(pdf.read_bytes()).hexdigest()
        if source_sha!=e["sourcePdfSha256"]:raise ValueError("21-case PDF SHA drift "+qid)
        page=fitz.open(pdf)[page_n-1]
        x0,y0,x1,y1=map(float,clip)
        if not(0<=x0<x1<=page.rect.width+.1 and 0<=y0<y1<=page.rect.height+.1):
            raise ValueError("Out-of-range 21 source proof "+qid)
        file=OUT/f"{qid}-official-region.png"
        page.get_pixmap(matrix=fitz.Matrix(2.6,2.6),clip=fitz.Rect(*clip),alpha=False).save(str(file))
        thumb=Image.open(file);thumb.thumbnail((660,420))
        box=Image.new("RGB",(680,465),"white")
        box.paste(thumb,((680-thumb.width)//2,34))
        ImageDraw.Draw(box).text((10,10),qid+"  OCR source page "+str(page_n),fill="black")
        thumbs.append(box)
        rows.append({"id":qid,"exam":exam,"session":sess,"page":page_n,"clip":clip,
          "sourcePdfSha256":source_sha,"pngFilename":file.name,
          "pngSha256":hashlib.sha256(file.read_bytes()).hexdigest(),
          "status":"NONCMAP_OCR_PDF_IMAGE_RENDERED_NO_HUMAN_SIGNOFF"})
if len(rows)!=L["newPromoted"]:raise ValueError("image evidence count differs from actual promotion ledger")
if rows:
    grid=Image.new("RGB",(680*4,465*((len(rows)+3)//4)),"#f0f0f0")
    for i,img in enumerate(thumbs):grid.paste(img,((i%4)*680,(i//4)*465))
    grid.save(OUT/"contact-sheet.jpg",quality=85)
result={"schemaVersion":1,"sourceRun":"GitHub Actions 2026-11-24","count":len(rows),
    "promotionCount":L["newPromoted"],"images":rows,
    "meaning":"High resolution official source PDF crops and SHA evidence; not a substitute for visual character review"}
(OUT/"index.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
(ROOT/"audit/latest-new-source-images-20261124.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"newPromoted":L["newPromoted"],"sourceImagesRendered":len(rows)},ensure_ascii=False))
