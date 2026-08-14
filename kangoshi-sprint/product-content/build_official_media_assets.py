#!/usr/bin/env python3
import json,re,urllib.request,tempfile
from pathlib import Path
import fitz

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
DRAFT=ROOT/'enriched-draft'
ASSET_ROOT=APP/'media'/'official'
ASSET_ROOT.mkdir(parents=True,exist_ok=True)
SOURCES=json.loads((ROOT/'media-official-sources.json').read_text(encoding='utf-8'))
PACKET=json.loads((DRAFT/'media-audit-packet.json').read_text(encoding='utf-8'))
RIGHTS_MARKERS=('©','copyright','転載','出典','写真提供','画像提供','提供：','提供:')
DOC_CACHE={}
TMP=Path(tempfile.mkdtemp(prefix='kangoshi-media-'))


def norm_session(s): return 'AM' if str(s).upper() in {'AM','午前'} else 'PM'

def download(url,key):
    cache_key=(url,key)
    if cache_key in DOC_CACHE:return DOC_CACHE[cache_key]
    p=TMP/f'{key}.pdf'
    req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 LearningSprintMediaAudit/1.0'})
    with urllib.request.urlopen(req,timeout=60) as r:p.write_bytes(r.read())
    doc=fitz.open(p)
    DOC_CACHE[cache_key]=doc
    return doc

def find_question_page(doc,qno):
    pat=re.compile(rf'(?m)^\s*{int(qno)}\s+')
    candidates=[]
    for i,p in enumerate(doc):
        txt=p.get_text('text') or ''
        if pat.search(txt):candidates.append(i)
    if not candidates:
        return None
    return candidates[0]

def question_clip(page,qno):
    words=page.get_text('words') or []
    w=page.rect.width; h=page.rect.height
    def candidates(num):
        return [x for x in words if str(x[4]).strip()==str(num) and x[0] < w*0.23 and 35 < x[1] < h-35]
    starts=candidates(qno)
    if not starts:return fitz.Rect(28,35,w-28,h-35)
    start=min(starts,key=lambda x:x[1]); y0=max(35,start[1]-12)
    nexts=[x for x in candidates(int(qno)+1) if x[1]>y0+18]
    y1=min((x[1]-10 for x in nexts),default=h-35)
    if y1<=y0+50:y1=h-35
    return fitz.Rect(28,y0,w-28,min(h-35,y1))

def booklet_no(question):
    m=re.search(r'別\s*冊\s*No\.\s*(\d+)',str(question),re.I)
    return int(m.group(1)) if m else None

def booklet_span(doc,no):
    labels=[]
    for i,p in enumerate(doc):
        txt=p.get_text('text') or ''
        m=re.search(r'No\.\s*(\d+)',txt,re.I)
        if m:labels.append((int(m.group(1)),i))
    for pos,(n,start) in enumerate(labels):
        if n==no:
            end=(labels[pos+1][1]-1) if pos+1<len(labels) else len(doc)-1
            return list(range(start,end+1)),labels
    return None,labels

def page_rights_markers(page):
    txt=(page.get_text('text') or '').lower()
    return sorted({m for m in RIGHTS_MARKERS if m.lower() in txt})

def raster_intersects(page,clip):
    hits=[]
    for img in page.get_images(full=True):
        xref=img[0]
        try: rects=page.get_image_rects(xref)
        except Exception: rects=[]
        for rect in rects:
            inter=rect & clip
            if inter.is_empty:continue
            if inter.width*inter.height >= 3500:
                hits.append({'xref':xref,'rect':[round(rect.x0,1),round(rect.y0,1),round(rect.x1,1),round(rect.y1,1)]})
    return hits

def render(page,clip,out):
    pix=page.get_pixmap(matrix=fitz.Matrix(1.65,1.65),clip=clip,alpha=False)
    pix.save(str(out),jpg_quality=84)

def clean_old(qid):
    for p in ASSET_ROOT.glob(f'{qid}*'):p.unlink()

results=[]; resolutions=[]
for item in PACKET.get('items') or []:
    qid=item['id']; exam=int(item['sourceExam']); session=norm_session(item['session']); qno=int(item['questionNo'])
    key=f'{exam}-{session}'; cfg=SOURCES['documents'][key]
    qdoc=download(cfg['questionPdf'],f'{exam}-{session}-questions')
    qp=find_question_page(qdoc,qno)
    result={'id':qid,'sourceExam':exam,'session':session,'questionNo':qno,'questionPdf':cfg['questionPdf'],'questionPageIndex':qp,'bookletNo':booklet_no(item.get('question')),'assets':[],'rightsMarkers':[],'rasterSensitive':False,'status':'pending'}
    clean_old(qid)
    source_pages=[]
    if result['bookletNo'] is not None:
        burl=cfg.get('bookletPdf')
        if not burl:
            result['status']='needs_redraw';result['reason']='booklet referenced but booklet PDF missing from source config';results.append(result);continue
        bdoc=download(burl,f'{exam}-{session}-booklet')
        span,labels=booklet_span(bdoc,result['bookletNo'])
        result['bookletPdf']=burl;result['bookletLabels']=labels;result['bookletPageIndices']=span
        if not span:
            result['status']='needs_redraw';result['reason']='booklet page label could not be resolved deterministically';results.append(result);continue
        for idx in span:source_pages.append((bdoc,idx,fitz.Rect(28,35,bdoc[idx].rect.width-28,bdoc[idx].rect.height-35),'booklet'))
    else:
        if qp is None:
            result['status']='needs_redraw';result['reason']='question page could not be resolved deterministically';results.append(result);continue
        source_pages.append((qdoc,qp,question_clip(qdoc[qp],qno),'question'))

    markers=[]; raster=[]
    for doc,idx,clip,kind in source_pages:
        markers.extend(page_rights_markers(doc[idx]))
        raster.extend(raster_intersects(doc[idx],clip))
    result['rightsMarkers']=sorted(set(markers));result['rasterSensitive']=bool(raster);result['rasterIntersections']=raster
    if result['rightsMarkers']:
        result['status']='manual_rights_review';result['reason']='separate rights/source notation detected on the relevant source page';results.append(result);continue
    if result['rasterSensitive']:
        result['status']='needs_redraw';result['reason']='relevant area contains raster/photo content; do not republish until an original redraw is produced';results.append(result);continue

    assets=[]
    for n,(doc,idx,clip,kind) in enumerate(source_pages,1):
        name=f'{qid}.jpg' if len(source_pages)==1 else f'{qid}-{n}.jpg'
        out=ASSET_ROOT/name;render(doc[idx],clip,out);assets.append(f'media/official/{name}')
    result['assets']=assets;result['status']='verified_pdl1';result['reason']='MHLW source page has no separate rights notation and relevant content is vector/text; rendered excerpt with required attribution'
    result['attribution']=SOURCES['attributionTemplate'].format(exam=exam)
    resolutions.append({'id':qid,'mediaReleaseStatus':'resolved','mediaRightsStatus':'verified_pdl1','mediaAssets':assets,'mediaAttribution':result['attribution'],'mediaSourceUrl':cfg['questionPdf'] if result['bookletNo'] is None else cfg.get('bookletPdf'),'mediaProcessed':True})
    results.append(result)

audit={'schemaVersion':1,'checkedAt':SOURCES['checkedAt'],'usageTerms':SOURCES['usageTerms'],'total':len(results),'verifiedPdl1':sum(r['status']=='verified_pdl1' for r in results),'needsRedraw':sum(r['status']=='needs_redraw' for r in results),'manualRightsReview':sum(r['status']=='manual_rights_review' for r in results),'items':results}
(ROOT/'media-rights-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'media-release-resolutions.generated.json').write_text(json.dumps({'schemaVersion':1,'generatedAt':SOURCES['checkedAt'],'items':resolutions},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:audit[k] for k in ('total','verifiedPdl1','needsRedraw','manualRightsReview')},ensure_ascii=False))
if audit['manualRightsReview']:
    raise SystemExit(2)
