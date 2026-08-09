#!/usr/bin/env python3
"""Build question-image assets for media/layout-dependent official questions.

MHLW-owned official question content is cropped from the official PDF and saved with
source attribution metadata. Items with known or suspected third-party source markers
are not exported; they are routed to third-party-review.json instead.
"""
from __future__ import annotations

import csv
import io
import json
import os
import re
import urllib.request
from pathlib import Path

import fitz
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
REVIEW = CONTENT / "review"
RAW = CONTENT / "raw"
SOURCES = json.loads((CONTENT/"official-sources.json").read_text(encoding="utf-8"))
ASSET_ROOT = ROOT / "assets" / "official-questions"
REPORT_DIR = CONTENT / "media"
ASSET_ROOT.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)
CACHE = ROOT / ".media-pdf-cache"
CACHE.mkdir(parents=True, exist_ok=True)

KNOWN_THIRD_PARTY = {
    "P109-025": "総務省・公害等調整委員会事務局資料由来グラフ",
    "P110-122": "American Journal of Epidemiology掲載表を基にした設問",
    "P110-140": "国立環境研究所モニタリングデータ由来グラフ",
}
THIRD_RE = re.compile(r"(?:出典|引用|より作成|より引用|一部改変|Journal|厚生労働省以外|国立環境研究所|調整委員会)", re.I)
Q_RE = re.compile(r"問\s*([0-9]{1,3})")


def download(url,dst):
    if dst.exists() and dst.stat().st_size>1000:return
    req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 learning-sprint-media/1.0"})
    with urllib.request.urlopen(req,timeout=90) as r,dst.open("wb") as f:f.write(r.read())


def media_ids():
    out=[]
    with (REVIEW/"media-queue.tsv").open(encoding="utf-8",newline="") as f:
        for row in csv.DictReader(f,delimiter="\t"):
            out.append(row["id"])
    return out


def raw_questions():
    d={}
    for exam in (111,110,109):
        obj=json.loads((RAW/f"exam-{exam}-raw.json").read_text(encoding="utf-8"))
        for q in obj["questions"]: d[q["id"]]=q
    return d


def source_for(exam,n):
    ex=next(x for x in SOURCES["exams"] if int(x["exam"])==exam)
    part=next(x for x in ex["parts"] if int(x["from"])<=n<=int(x["to"]))
    return ex,part


def line_markers(doc,start,end):
    markers={}
    for pno,page in enumerate(doc):
        data=page.get_text("dict")
        for block in data.get("blocks",[]):
            for line in block.get("lines",[]):
                text="".join(span.get("text","") for span in line.get("spans",[])).strip()
                m=Q_RE.search(text)
                if not m: continue
                n=int(m.group(1))
                if start<=n<=end and n not in markers:
                    bbox=line.get("bbox",block.get("bbox",(0,0,0,0)))
                    markers[n]=(pno,float(bbox[1]))
    return markers


def render_clip(page,rect,out_path):
    rect=fitz.Rect(rect) & page.rect
    if rect.height<20: raise RuntimeError(f"clip too small {rect}")
    pix=page.get_pixmap(matrix=fitz.Matrix(1.75,1.75),clip=rect,alpha=False)
    img=Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")
    out_path.parent.mkdir(parents=True,exist_ok=True)
    img.save(out_path,"WEBP",quality=86,method=6)


def main():
    mids=set(media_ids()); qmap=raw_questions()
    manifest={}; third=[]; failures=[]; exported=0
    # Group media questions by PDF part.
    grouped={}
    for qid in sorted(mids):
        q=qmap[qid]; exam=int(q["sourceExam"]); n=int(q["questionNo"])
        ex,part=source_for(exam,n)
        grouped.setdefault((exam,part["id"],part["url"],int(part["from"]),int(part["to"])),[]).append(qid)

    for (exam,part_id,url,start,end),ids in grouped.items():
        pdf=CACHE/f"{exam}-{part_id}.pdf"; download(url,pdf); doc=fitz.open(pdf)
        markers=line_markers(doc,start,end)
        if len(markers)<(end-start+1):
            missing=[n for n in range(start,end+1) if n not in markers]
            failures.append({"part":f"{exam}-{part_id}","markerMissing":missing})
        for qid in ids:
            q=qmap[qid]; n=int(q["questionNo"])
            text=(q.get("question","")+" "+" ".join(q.get("choices",[])))
            reason=KNOWN_THIRD_PARTY.get(qid)
            if not reason and THIRD_RE.search(text): reason="source-marker-detected-in-extracted-text"
            if reason:
                third.append({"id":qid,"exam":exam,"questionNo":n,"reason":reason,"sourceUrl":url})
                continue
            if n not in markers:
                failures.append({"id":qid,"reason":"question-marker-not-found"}); continue
            sp,sy=markers[n]
            if n+1<=end and n+1 in markers:
                ep,ey=markers[n+1]
            else:
                ep,ey=len(doc)-1,doc[-1].rect.height-12
            assets=[]
            for pno in range(sp,ep+1):
                page=doc[pno]
                top=sy-8 if pno==sp else 18
                bottom=(ey-8 if pno==ep else page.rect.height-18)
                out=ASSET_ROOT/str(exam)/f"q{n:03d}-{len(assets)+1}.webp"
                try:
                    render_clip(page,(18,top,page.rect.width-18,bottom),out)
                    assets.append(str(out.relative_to(ROOT)).replace("\\","/"))
                except Exception as e:
                    failures.append({"id":qid,"page":pno+1,"reason":repr(e)})
            if assets:
                manifest[qid]={"assets":assets,"sourceUrl":url,"attribution":f"出典：厚生労働省『第{exam}回薬剤師国家試験問題及び解答』","modified":True,"license":"PDL1.0","releaseStatus":"asset_ready_pending_final_visual_review"}
                exported+=1
    (REPORT_DIR/"media-manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (REPORT_DIR/"third-party-review.json").write_text(json.dumps(third,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    report={"mediaQueue":len(mids),"assetReady":exported,"thirdPartyBlocked":len(third),"failures":failures,"complete":exported+len(third)==len(mids) and not failures}
    (REPORT_DIR/"media-build-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False))
    if failures or exported+len(third)!=len(mids): raise SystemExit(2)

if __name__=="__main__":main()
