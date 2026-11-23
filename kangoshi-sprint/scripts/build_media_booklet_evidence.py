#!/usr/bin/env python3
"""Render independent Ministry of Health nurse exam illustration BOOKLET sources.
Q PDFs refer to 別冊No.; a question PDF screenshot alone is not the source image.
"""
import json,pathlib,urllib.request,io,hashlib
from PIL import Image,ImageDraw,ImageFont
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
SOURCE=json.loads((ROOT/"product-content/media-official-sources.json").read_text())
OUT=ROOT/"audit/runs/media-booklets";OUT.mkdir(parents=True,exist_ok=True)
for ex in (115,114,113):
   key=f"{ex}-AM"
   url=SOURCE["documents"][key].get("bookletPdf")
   if not url:continue
   req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 NurseExamSourceAudit/1.0"})
   with urllib.request.urlopen(req,timeout=90) as h: raw=h.read()
   if not raw.startswith(b"%PDF-"):raise ValueError("not PDF "+url)
   doc=fitz.open(stream=raw,filetype="pdf")
   cells=[];pages=[]
   for i,page in enumerate(doc):
       pix=page.get_pixmap(matrix=fitz.Matrix(1.25,1.25),alpha=False)
       image=Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")
       image.thumbnail((610,800))
       canvas=Image.new("RGB",(650,850),"white")
       canvas.paste(image,((650-image.width)//2,32))
       ImageDraw.Draw(canvas).text((12,10),f"EXAM {ex} BOOKLET PDF page {i+1}",fill="black")
       cells.append(canvas)
       pages.append({"page":i+1,"textPreview":page.get_text("text",sort=True)[:700]})
   cols=3;out=Image.new("RGB",(cols*650,((len(cells)+cols-1)//cols)*850),"#ddd")
   for i,c in enumerate(cells):out.paste(c,((i%cols)*650,(i//cols)*850))
   out.save(OUT/f"exam{ex}-booklet-contact.jpg",quality=78,optimize=True)
   (OUT/f"exam{ex}-booklet-index.json").write_text(json.dumps({"exam":ex,"sourceUrl":url,"sha256":hashlib.sha256(raw).hexdigest(),"pageCount":len(doc),"pages":pages},ensure_ascii=False,indent=2)+"\n")
   print(json.dumps({"exam":ex,"source":url,"pages":len(doc),"sha256":hashlib.sha256(raw).hexdigest()}))
