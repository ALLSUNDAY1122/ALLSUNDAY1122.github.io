#!/usr/bin/env python3
"""Build cropped question-image assets using Poppler only.

The first renderer (PyMuPDF pixmap) segfaulted on the GitHub runner. This version
uses `pdftotext -bbox-layout` for coordinates and `pdftoppm` for rendering, keeping
media generation deterministic and crash-isolated from Python PDF libraries.
"""
from __future__ import annotations

import csv
import argparse
import hashlib
import json
import re
import subprocess
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
REVIEW = CONTENT / "review"
RAW = CONTENT / "raw"
SOURCES = json.loads((CONTENT / "official-sources.json").read_text(encoding="utf-8"))
ASSET_ROOT = ROOT / "assets" / "official-questions"
REPORT_DIR = CONTENT / "media"
CACHE = ROOT / ".media-pdf-cache"
PAGE_CACHE = ROOT / ".media-page-cache"
for p in (ASSET_ROOT, REPORT_DIR, CACHE, PAGE_CACHE): p.mkdir(parents=True, exist_ok=True)

KNOWN_THIRD_PARTY = {
    "P109-025": "総務省・公害等調整委員会事務局資料由来グラフ",
    "P109-124": "総務省統計局人口推計由来グラフ",
    "P110-122": "American Journal of Epidemiology掲載表を基にした設問",
    "P110-140": "国立環境研究所モニタリングデータ由来グラフ",
}
# This item explicitly says it was prepared from MHLW's own STI statistics, so it
# remains within the MHLW PDL1.0 source set and must not be blocked as third-party.
MHLW_SELF_SOURCE = {"P110-124"}
THIRD_RE = re.compile(r"(?:出典|引用|より作成|より引用|一部改変|Journal|国立環境研究所|調整委員会)", re.I)
Q_RE = re.compile(r"問\s*([0-9]{1,3})")
DPI = 170

# Visually verified omissions in the original text-only classifier. Coordinates
# are PDF points, page numbers are one-based, and each segment retains the full
# question/choices on that page. Q255 additionally needs the shared ECG page.
VERIFIED_MEDIA_CROPS = {
    'P109-115': [(24, 75, 380), (25, 75, 545)],
    'P109-116': [(26, 75, 505), (27, 75, 560)],
    'P109-119': [(29, 75, 752)],
    'P109-121': [(31, 75, 565)],
    'P109-184': [(26, 75, 650)],
    'P110-255': [(9, 333, 520)],
    'P111-002': [(2, 352, 582)],
    'P111-078': [(32, 285, 548)],
    'P111-086': [(36, 75, 435)],
    # Q97's B is the additional titrant after the first endpoint. Its shared
    # procedure must be visible with the question to retain that definition.
    'P111-097': [(4, 75, 355), (5, 452, 660)],
    'P111-098': [(6, 75, 488)],
    # The second page includes the molecular structure in option 5.
    'P111-107': [(14, 75, 750), (15, 75, 325)],
    'P111-109': [(17, 75, 515)],
    'P111-114': [(20, 75, 712)],
}
VERIFIED_SHARED_ASSETS = {
    'P110-255': ['assets/official-questions/110/q254-1.webp'],
}


def build_verified_assets(qid, pdf, key, url):
    exam, number = (int(x) for x in qid[1:].split('-'))
    pdf_sha256 = hashlib.sha256(pdf.read_bytes()).hexdigest()
    # Official A4 page dimensions. No marker-based inference is used here:
    # continuation pages and shared graphics were checked directly in the PDF.
    pages = [{'width': 595.2755737304688, 'height': 841.8895874023438}] * max(x[0] for x in VERIFIED_MEDIA_CROPS[qid])
    assets = list(VERIFIED_SHARED_ASSETS.get(qid, []))
    for donor in assets:
        if not (ROOT / donor).is_file():
            raise RuntimeError(f'{qid}: shared ECG donor asset missing: {donor}')
    segments = []
    for index, (page, top, bottom) in enumerate(VERIFIED_MEDIA_CROPS[qid], 1):
        out = ASSET_ROOT / str(exam) / f'q{number:03d}-{index}.webp'
        crop_segment(pdf, f'{key}-{pdf_sha256[:12]}', pages, page - 1, top, bottom, out, cropbox=True)
        asset = out.relative_to(ROOT).as_posix()
        assets.append(asset)
        segments.append({'pdfPage': page, 'cropPoints': [16, top, pages[page-1]['width'] - 16, bottom], 'asset': asset})
    return {
        'assets': assets, 'sourceUrl': url,
        'attribution': f"出典：厚生労働省『第{exam}回薬剤師国家試験問題及び解答』",
        'modified': True, 'license': 'PDL1.0',
        'releaseStatus': 'asset_ready_pending_independent_visual_review',
        'verification': {
            'date': '2026-11-08',
            'scope': 'restore omitted official graphics and complete question/choices; no answer or explanation quality approval',
            'sourcePdfSha256': pdf_sha256,
            'renderer': {'name': 'pdftoppm', 'pageBox': 'CropBox', 'dpi': DPI, 'webpQuality': 88, 'webpMethod': 6},
            'segments': segments, 'sharedAssets': list(VERIFIED_SHARED_ASSETS.get(qid, [])),
            'sharedSourcePdfPages': [8] if qid == 'P110-255' else [],
            'assetSha256': {asset: hashlib.sha256((ROOT / asset).read_bytes()).hexdigest() for asset in assets},
        },
    }


def rebuild_verified_only(official_pdf_dir=None):
    """Rebuild audited additions without changing pre-existing manifest entries."""
    path = REPORT_DIR / 'media-manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    for qid in sorted(VERIFIED_MEDIA_CROPS):
        exam, number = (int(x) for x in qid[1:].split('-'))
        _, part = source_for(exam, number)
        if official_pdf_dir:
            pdf = Path(official_pdf_dir) / part['url'].rsplit('/', 1)[-1]
        else:
            pdf = CACHE / f"{exam}-{part['id']}.pdf"
            download(part['url'], pdf)
        manifest[qid] = build_verified_assets(qid, pdf, f"{exam}-{part['id']}", part['url'])
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'verifiedRebuilt': sorted(VERIFIED_MEDIA_CROPS), 'manifestCount': len(manifest)}))


def lname(tag): return tag.rsplit('}',1)[-1]
def download(url,dst):
    if dst.exists() and dst.stat().st_size > 1000: return
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0 learning-sprint-media/2.0"})
    with urllib.request.urlopen(req, timeout=90) as r, dst.open("wb") as f: f.write(r.read())
def media_ids():
    with (REVIEW/"media-queue.tsv").open(encoding="utf-8", newline="") as f: return [r["id"] for r in csv.DictReader(f, delimiter="\t")]
def raw_questions():
    out={}
    for exam in (111,110,109):
        d=json.loads((RAW/f"exam-{exam}-raw.json").read_text(encoding="utf-8")); out.update({q["id"]:q for q in d["questions"]})
    return out
def source_for(exam,n):
    ex=next(x for x in SOURCES["exams"] if int(x["exam"])==exam); part=next(x for x in ex["parts"] if int(x["from"])<=n<=int(x["to"])); return ex,part
def bbox_pages(pdf: Path):
    out=pdf.with_suffix('.bbox.html')
    subprocess.run(['pdftotext','-bbox-layout','-enc','UTF-8',str(pdf),str(out)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    root=ET.parse(out).getroot(); pages=[]
    for pe in [x for x in root.iter() if lname(x.tag)=='page']:
        width=float(pe.attrib.get('width','595')); height=float(pe.attrib.get('height','842')); lines=[]
        for le in [x for x in pe.iter() if lname(x.tag)=='line']:
            words=[x for x in le if lname(x.tag)=='word']
            if not words: continue
            text=''.join((w.text or '') for w in words).replace('\u3000',' '); y=float(le.attrib.get('yMin',words[0].attrib.get('yMin','0'))); lines.append((text,y))
        pages.append({'width':width,'height':height,'lines':lines})
    return pages
def markers_from_bbox(pages,start,end):
    markers={}
    for pno,p in enumerate(pages):
        for text,y in p['lines']:
            m=Q_RE.search(re.sub(r'\s+','',text))
            if m:
                n=int(m.group(1))
                if start<=n<=end and n not in markers: markers[n]=(pno,y)
    return markers
def rendered_page(pdf:Path,key:str,pageno:int,cropbox=False):
    suffix=f'-cropbox-r{DPI}' if cropbox else ''
    prefix=PAGE_CACHE/f'{key}-p{pageno+1:03d}{suffix}'; jpg=Path(str(prefix)+'.jpg')
    if not jpg.exists(): subprocess.run(['pdftoppm',*(['-cropbox'] if cropbox else []),'-f',str(pageno+1),'-l',str(pageno+1),'-r',str(DPI),'-jpeg','-singlefile',str(pdf),str(prefix)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    return Image.open(jpg).convert('RGB')
def crop_segment(pdf,key,pages,pageno,top,bottom,out,cropbox=False):
    img=rendered_page(pdf,key,pageno,cropbox=cropbox); meta=pages[pageno]; sx=img.width/meta['width']; sy=img.height/meta['height']; x0=max(0,int(16*sx)); x1=min(img.width,int((meta['width']-16)*sx)); y0=max(0,int(top*sy)); y1=min(img.height,int(bottom*sy))
    if y1-y0<35 or x1-x0<100: raise RuntimeError(f'clip too small {(x0,y0,x1,y1)}')
    crop=img.crop((x0,y0,x1,y1)); out.parent.mkdir(parents=True,exist_ok=True); crop.save(out,'WEBP',quality=88,method=6)

def main():
    # Q207 detector figure was omitted by the text-only source classifier.
    mids=set(media_ids()) | {'P110-207'} | set(VERIFIED_MEDIA_CROPS); qmap=raw_questions(); manifest={}; third=[]; failures=[]; exported=0; grouped={}
    for qid in sorted(mids):
        q=qmap[qid]; exam=int(q['sourceExam']); n=int(q['questionNo']); ex,part=source_for(exam,n); grouped.setdefault((exam,part['id'],part['url'],int(part['from']),int(part['to'])),[]).append(qid)
    for (exam,part_id,url,start,end),ids in grouped.items():
        pdf=CACHE/f'{exam}-{part_id}.pdf'; download(url,pdf)
        try: pages=bbox_pages(pdf); markers=markers_from_bbox(pages,start,end)
        except Exception as e: failures.append({'part':f'{exam}-{part_id}','reason':f'bbox failure {e!r}'}); continue
        if len(markers)<end-start+1: failures.append({'part':f'{exam}-{part_id}','markerMissing':[n for n in range(start,end+1) if n not in markers]})
        for qid in ids:
            q=qmap[qid]; n=int(q['questionNo']); text=(q.get('question','')+' '+' '.join(q.get('choices',[]))); reason=KNOWN_THIRD_PARTY.get(qid)
            if qid in VERIFIED_MEDIA_CROPS:
                try:
                    manifest[qid] = build_verified_assets(qid, pdf, f'{exam}-{part_id}', url)
                    exported += 1
                except Exception as e:
                    failures.append({'id': qid, 'reason': repr(e)})
                continue
            if qid not in MHLW_SELF_SOURCE and not reason and THIRD_RE.search(text): reason='source-marker-detected-in-extracted-text'
            if reason: third.append({'id':qid,'exam':exam,'questionNo':n,'reason':reason,'sourceUrl':url}); continue
            if n not in markers: failures.append({'id':qid,'reason':'question-marker-not-found'}); continue
            sp,sy=markers[n]
            if n+1<=end and n+1 in markers: ep,ey=markers[n+1]
            else: ep,ey=len(pages)-1,pages[-1]['height']-12
            assets=[]
            try:
                for pno in range(sp,ep+1):
                    top=max(8,sy-7) if pno==sp else 16; bottom=(ey-7 if pno==ep else pages[pno]['height']-16); out=ASSET_ROOT/str(exam)/f'q{n:03d}-{len(assets)+1}.webp'; crop_segment(pdf,f'{exam}-{part_id}',pages,pno,top,bottom,out); assets.append(str(out.relative_to(ROOT)).replace('\\','/'))
            except Exception as e: failures.append({'id':qid,'reason':repr(e)}); continue
            # The first Q220 crop is the shared prescription printed before the
            # official capsule-unit correction (001677936.pdf). Display the
            # corrected sharedStem text and retain only the reaction/choice page.
            if qid == 'P111-220':
                assets = [a for a in assets if not a.endswith('/q220-1.webp')]
                if assets != ['assets/official-questions/111/q220-2.webp']:
                    raise RuntimeError('Q220 crop layout changed; visual review required')
            if qid == 'P110-207':
                # The following page only starts Q208; retain Q207's complete figure page.
                assets = [a for a in assets if a.endswith('/q207-1.webp')]
                if assets != ['assets/official-questions/110/q207-1.webp']:
                    raise RuntimeError('Q207 crop layout changed; visual review required')
            manifest[qid]={'assets':assets,'sourceUrl':url,'attribution':f"出典：厚生労働省『第{exam}回薬剤師国家試験問題及び解答』",'modified':True,'license':'PDL1.0','releaseStatus':'asset_ready_pending_final_visual_review'}; exported+=1
    (REPORT_DIR/'media-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); (REPORT_DIR/'third-party-review.json').write_text(json.dumps(third,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report={'mediaQueue':len(mids),'assetReady':exported,'thirdPartyBlocked':len(third),'failures':failures,'complete':exported+len(third)==len(mids) and not failures}; (REPORT_DIR/'media-build-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(report,ensure_ascii=False))
    if failures or exported+len(third)!=len(mids): raise SystemExit(2)
if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--verified-only', action='store_true', help='Rebuild only the visually verified original-graphic restorations')
    parser.add_argument('--official-pdf-dir', type=Path, help='Local directory containing the original numbered official PDF files')
    args = parser.parse_args()
    if args.verified_only:
        rebuild_verified_only(args.official_pdf_dir)
    else:
        main()
