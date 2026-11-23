#!/usr/bin/env python3
"""Replace five unfaithful SVG renderings with clipped pixels from their actual official PDF question/booklet pages.
All crops remain unpublished pending checking of diagram position and underlying rights.
"""
import json, pathlib, hashlib, urllib.request, io, math
from PIL import Image
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
MEDIA=ROOT/"media"
OUT=MEDIA/"official-crops"
OUT.mkdir(parents=True,exist_ok=True)
REG=ROOT/"audit"/"official-pdf-crop-replacements-20261124.json"
SOURCES=json.loads((ROOT/"product-content/media-official-sources.json").read_text())
TARGETS=[
    {"id":"K115-AM063","exam":115,"source":"booklet","sessions":"AM","pages":[4,5],"reason":"4 separate original photographic items"},
    {"id":"K115-PM020","exam":115,"source":"question","sessions":"PM","pages":[12],"reason":"4 respiratory waveform choices on original question page"},
    {"id":"K114-AM013","exam":114,"source":"booklet","sessions":"AM","pages":[4,5],"reason":"4 ECG waveforms across two booklet pages"},
    {"id":"K114-AM051","exam":114,"source":"booklet","sessions":"AM","pages":[9],"reason":"original CT medical image"},
    {"id":"K114-AM107","exam":114,"source":"booklet","sessions":"AM","pages":[13],"reason":"original child bed medical tubes"}
]
CACHE={}
def fetch(u):
  if u not in CACHE:
    r=urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0 NurseExamStudyQA/1.0"})
    with urllib.request.urlopen(r,timeout=75) as f:b=f.read()
    if not b.startswith(b"%PDF-"):raise ValueError("Invalid official PDF "+u)
    CACHE[u]=(fitz.open(stream=b,filetype="pdf"),hashlib.sha256(b).hexdigest())
  return CACHE[u]
def trim(p,pageNo,kind):
  # Keeps all original choices and their labels, no guessed bounding boxes or redraws.
  rect=p.rect
  clip=fitz.Rect(rect.x0+24,rect.y0+48,rect.x1-24,rect.y1-52)
  if kind=="question":
    # page may include other questions; keep full PDF's original figure, mark region recheck.
    words=p.get_text("words")
    top=[w for w in words if str(w[4]).strip()=="20" and w[0]<rect.width*0.3]
    bottom=[w for w in words if str(w[4]).strip()=="21" and w[0]<rect.width*0.3]
    if len(top)==1:
      y0=max(rect.y0+25,top[0][1]-15)
      y1=min(rect.y1-25,bottom[0][1]-12) if len(bottom)==1 and bottom[0][1]>y0 else rect.y1-45
      if y1-y0>115:clip=fitz.Rect(rect.x0+20,y0,rect.x1-20,y1)
  pix=p.get_pixmap(matrix=fitz.Matrix(2,2),clip=clip,alpha=False)
  return Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB"),list(map(lambda x:round(x,2),[clip.x0,clip.y0,clip.x1,clip.y1]))
rows=[]
for t in TARGETS:
  exam=t["exam"];session=t["sessions"]
  docinfo=SOURCES["documents"][f"{exam}-{session}"]
  if t["source"]=="booklet":
    url=docinfo["bookletPdf"]
  else:
    url=docinfo["questionPdf"]
  doc,sha=fetch(url)
  images=[];clips=[]
  for pg in t["pages"]:
    if pg<1 or pg>len(doc):raise ValueError(f"{t['id']}: invalid page {pg}/{len(doc)}")
    im,clip=trim(doc[pg-1],pg,t["source"])
    images.append(im);clips.append(clip)
  # preserves source labels 1-4 by stacking both booklet pages, not re-drawing any labels.
  width=max(x.width for x in images);height=sum(x.height for x in images)
  if width*height>35_000_000:raise ValueError("unreasonably large crop")
  canvas=Image.new("RGB",(width,height),"white");y=0
  for im in images:
    canvas.paste(im,(0,y));y+=im.height
  destination=OUT/f"{t['id']}.png"
  canvas.save(destination,optimize=True)
  content=destination.read_bytes()
  rows.append({"id":t["id"],"previousAsset":f"media/redraw/{t['id']}.svg",
    "replacementAsset":f"media/official-crops/{t['id']}.png","sourceUrl":url,
    "pdfSha256":sha,"sourcePdfPagesOneBased":t["pages"],"sourceClipRects":clips,
    "newAssetSha256":hashlib.sha256(content).hexdigest(),"bytes":len(content),
    "newAssetSizePixels":[width,height],"sourceType":t["source"],"reason":t["reason"],
    "renderSelection":"OFFICIAL_PDF_PIXEL_CROP_NOT_VECTOR_REDRAW",
    "stagingStatus":"REPLACEMENT_CROP_PREPARED", "published":False,
    "fullRightsVerified":False,"contentRecheckStatus":"PENDING_IMAGE_LAYOUT_COMPARE",
    "attribution":f"出典：厚生労働省『第{exam}回看護師国家試験』（{url}）の該当ページから図版部分を切り出し・加工"})
REG.write_text(json.dumps({"schemaVersion":1,"date":"2026-11-24","count":len(rows),
 "sourceURLPolicy":"MHLW PDL1.0 with attribution and modifications, but any embedded third party media needs item-specific rights review",
 "allPublished":False,"items":rows},ensure_ascii=False,indent=2)+"\n",encoding="utf8")
print(json.dumps({"cropsGenerated":len(rows),"ids":[x["id"] for x in rows],
 "status":"NONPUBLISHABLE_UNTIL_SOURCE_IMAGE_AND_RIGHTS_REVIEW"},ensure_ascii=False))
