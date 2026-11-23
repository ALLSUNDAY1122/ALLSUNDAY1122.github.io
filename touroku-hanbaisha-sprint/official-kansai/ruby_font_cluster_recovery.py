#!/usr/bin/env python3
"""Conservative PDF raw-glyph ruby clustering: source proof, independent review evidence.
Only unique-sized, contiguous source reading and base text / app field can be certified.
No candidate text is guessed; all unproved cases are retained as HOLD.
"""
import argparse, collections, hashlib, html, json, re
from pathlib import Path
from playwright.sync_api import sync_playwright
import fitz
from auto_diff_pdf import B, download
from geometry_second_gate import first_question_clip
from reconstruct_ruby import ISOLATED

KANJI = re.compile(r'^[\u3400-\u9fff々]+$')
KANA = re.compile(r'^[ぁ-んァ-ンー]+$')
SHA = B/'RUBY_FONT_CLUSTER_ALL_20261124.json'
REV = B/'ruby-font-review'
def rawglyphs(doc,clips):
    glyphs=[]
    for pi,rect in clips:
        for block in doc[pi].get_text('rawdict',clip=rect).get('blocks',[]):
            for line in block.get('lines',[]):
                for span in line.get('spans',[]):
                    for ch in span.get('chars',[]):
                        c=ch.get('c','')
                        if c and c.strip():
                            glyphs.append({'c':c,'page':pi+1,'size':float(span['size']),
                                'font':span.get('font',''),
                                'bbox':[float(v) for v in ch['bbox']]})
    # Protect against text overlay duplicate glyphs.
    dedup={}
    for g in glyphs:
        key=(g['page'],g['c'],tuple(round(x,1) for x in g['bbox']),round(g['size'],1))
        dedup[key]=g
    return list(dedup.values())
def clusters(chars):
    candidates=[g for g in chars if KANA.fullmatch(g['c']) and g['size']<=8.5]
    candidates.sort(key=lambda g:(g['page'],(g['bbox'][1]+g['bbox'][3])/2,g['bbox'][0]))
    buckets=[]
    for g in candidates:
        mid=(g['bbox'][1]+g['bbox'][3])/2
        matching=[b for b in buckets if b['page']==g['page'] and abs(b['mid']-mid)<2 and abs(b['size']-g['size'])<1]
        if len(matching)==1:matching[0]['chars'].append(g)
        else:buckets.append({'page':g['page'],'mid':mid,'size':g['size'],'chars':[g]})
    groups=[]
    for bucket in buckets:
        line=sorted(bucket['chars'],key=lambda c:c['bbox'][0])
        parts=[[line[0]]]
        for g in line[1:]:
            prev=parts[-1][-1]
            gap=g['bbox'][0]-prev['bbox'][2]
            if -1<=gap<=max(2.3,1.25*g['size']):parts[-1].append(g)
            else:parts.append([g])
        for part in parts:
            val=''.join(c['c'] for c in part)
            if not KANA.fullmatch(val) or len(val)>12:continue
            rect=[min(x['bbox'][0] for x in part),min(x['bbox'][1] for x in part),
                max(x['bbox'][2] for x in part),max(x['bbox'][3] for x in part)]
            groups.append({'reading':val,'page':part[0]['page'],'bbox':rect,
                'fontSize':round(part[0]['size'],2),'font':part[0]['font'],
                'glyphs':len(part)})
    return groups
def base_for(group,chars,prior_bbox,prior_base_text):
    rx0,ry0,rx1,ry1=group['bbox'];cx=(rx0+rx1)/2
    cand=[]
    for g in chars:
        if g['page']!=group['page'] or not re.fullmatch(r'[\u3400-\u9fff々]',g['c']):continue
        if g['size']<group['fontSize']*1.45:continue
        x0,y0,x1,y1=g['bbox']
        if not -2.5<=y0-ry1<=12:continue
        # The prior independent PDF span is the authoritative base line.
        if not (prior_bbox[0]-1<=x0 and x1<=prior_bbox[2]+1 and
                prior_bbox[1]-1<=y0 and y1<=prior_bbox[3]+1):continue
        if g['c'] not in prior_base_text:continue
        if x1<rx0-2 or x0>rx1+2:continue
        cand.append(g)
    if not cand:return None,'NO_FULL_SIZE_KANJI_BELOW'
    # A source text line is defined by font-size and baseline, not by extracted reading.
    lines={}
    for g in cand:
        key=(g['page'],round(g['bbox'][1]/3),round(g['size']/2))
        lines.setdefault(key,[]).append(g)
    if len(lines)!=1:return None,'MULTIPLE_BASE_LINES'
    glyphs=sorted(next(iter(lines.values())),key=lambda g:g['bbox'][0])
    # Include only kanji whose center lies within expanded small-reading horizontal footprint.
    selected=[g for g in glyphs if rx0-2 <= (g['bbox'][0]+g['bbox'][2])/2 <= rx1+2]
    if not selected:return None,'BASE_GLYPHS_OUTSIDE_READING'
    base=''.join(g['c'] for g in selected)
    if not KANJI.fullmatch(base):return None,'BASE_NOT_KANJI'
    if len(selected)>1 and any(selected[i+1]['bbox'][0]-selected[i]['bbox'][2]>3 for i in range(len(selected)-1)):
        return None,'NONCONTIGUOUS_BASE_GLYPHS'
    return {'base':base,'page':group['page'],
            'bbox':[min(g['bbox'][0] for g in selected),min(g['bbox'][1] for g in selected),
                max(g['bbox'][2] for g in selected),max(g['bbox'][3] for g in selected)]},None

def certify(q,geom,doc,clips):
    fields=[q['question'],*q['choices']]
    if not clips or not all(isinstance(x,str) for x in fields):
        return None,['SOURCE_OR_APP_FIELD_MISSING'],[]
    chars=rawglyphs(doc,clips)
    small=clusters(chars)
    prior=(geom.get('ruby') or {}).get('associations') or []
    # Every expected published reading in the prior geometry must have exactly one
    # raw-font source group. Missing/extra readings fail closed.
    if not prior:return None,['SOURCE_ASSOCIATIONS_MISSING'],small
    assigned=[];reasons=[]
    for a in prior:
        compatible=[g for g in small if g['page']==a['page'] and
                    abs((g['bbox'][0]+g['bbox'][2])/2 -(a['rubyBBox'][0]+a['rubyBBox'][2])/2)<4 and
                    abs((g['bbox'][1]+g['bbox'][3])/2 -(a['rubyBBox'][1]+a['rubyBBox'][3])/2)<4]
        if len(compatible)!=1:
            reasons.append('RUBY_GROUP_SOURCE_NONUNIQUE');continue
        g=compatible[0]
        if g['reading']!=a['ruby']:
            reasons.append('RUBY_TEXT_DIFF_FROM_PDF_ASSOCIATION');continue
        base,error=base_for(g,chars,a['baseBBox'],a['baseText'])
        if error:reasons.append(error);continue
        if base['base'] not in a['baseText']:
            reasons.append('SOURCE_BASE_SPAN_TEXT_MISMATCH');continue
        fields_with_read=[i for i,f in enumerate(fields) if len(list(ISOLATED(g['reading']).finditer(f)))==1]
        if len(fields_with_read)!=1:
            reasons.append('DETACHED_READING_FIELD_NONUNIQUE');continue
        fi=fields_with_read[0]
        cleaned=ISOLATED(g['reading']).sub('',fields[fi])
        # Unique literal base in the exact chosen field; never infer base from reading.
        if cleaned.count(base['base'])!=1:
            reasons.append('BASE_LITERAL_NONUNIQUE');continue
        assigned.append({'field':fi,'reading':g['reading'],'base':base['base'],'page':g['page'],
             'rubyBBox':[round(v,2) for v in g['bbox']],
             'baseBBox':[round(v,2) for v in base['bbox']],
             'fontSize':g['fontSize'],'baseText':base['base']})
    if len(assigned)!=len(prior):reasons.append('INCOMPLETE_RUBY_MAPPING')
    # Strictly detect conflicting duplicate reading lines and overlapping base replacements.
    if reasons:return None,sorted(set(reasons)),small
    processed=[];used=set()
    for i,field in enumerate(fields):
        matches=[a for a in assigned if a['field']==i]
        clean=field
        for a in matches:
            reading=a['reading']
            if (i,reading) in used:return None,['DUPLICATE_READING_IN_FIELD'],small
            used.add((i,reading));clean=ISOLATED(reading).sub('',clean)
        if not matches:processed.append([{'text':field}]);continue
        offsets=[(clean.index(a['base']),a) for a in matches]
        offsets.sort(key=lambda x:x[0])
        if any(offsets[z][0]+len(offsets[z][1]['base'])>offsets[z+1][0] for z in range(len(offsets)-1)):
            return None,['OVERLAPPING_BASE'],small
        phys=sorted(matches,key=lambda a:(a['page'],a['baseBBox'][1],a['baseBBox'][0]))
        if [id(x) for x in phys]!=[id(a) for _,a in offsets]:
            return None,['PDF_APP_BASE_ORDER_MISMATCH'],small
        parts=[];pos=0
        for offset,a in offsets:
            parts.append({'text':clean[pos:offset]})
            # Client renderer currently accepts exactly one Kanji per ruby element.
            # Native HTML ruby can carry a multi-kanji base; DOM audit checks full base and reading.
            if not re.fullmatch(r'[\u3400-\u9fff々]+',a['base']):
                return None,['RUBY_BASE_NOT_KANJI'],small
            parts.append({'rubyBase':a['base'],'rubyText':a['reading'],'sourcePage':a['page']})
            pos=offset+len(a['base'])
        parts.append({'text':clean[pos:]})
        if ''.join(p.get('text',p.get('rubyBase','')) for p in parts)!=clean:
            return None,['RICH_ROUNDTRIP_FAIL'],small
        processed.append(parts)
    return {'questionParts':processed[0],'choicesParts':processed[1:],
            'placements':assigned},[],small

def run():
    sources=json.loads((B/'SOURCES_2022_2026.json').read_text())['years']
    years={y['year']:y for y in sources}
    bank=json.loads((B/'APPROVED_OFFICIAL_BANK.json').read_text())
    assert bank['count']==430,'Changed production bank; do not overwrite'
    existing=set(bank['approvedIds'])
    reviews=[];passed=[];candidates={};sourceclips={}
    docs={}
    for year in range(2022,2027):
        hashes=json.loads((B/f'PDF_SHA256_{year}.json').read_text())
        docs[year]={}
        for half,key in [('first_half','question_pdf_first_half'),('second_half','question_pdf_second_half')]:
            url=years[year][key]
            docs[year][half]=download(url,B/f'.tmp_font_cluster_{year}_{half}.pdf',
                next(h['sha256'] for h in hashes if h['half']==half))
        prior=json.loads((B/f'ORDERED_RUBY_{year}.json').read_text())
        geometry=json.loads((B/f'GEOMETRY_AUDIT_{year}.json').read_text())
        qlist=json.loads((B/f'QUESTIONS_{year}_APP_CANDIDATE.json').read_text())['questions']
        for q,old,geo in zip(qlist,prior['records'],geometry['questions']):
            if old['status']!='HOLD':continue
            assert q['id']==old['id']==geo['id']
            id=q['id'];candidates[id]=q
            row={'id':id,'year':year,'questionNo':q['questionNo'],
                'originalReasons':old['reasons'],'sourceUrl':q['sourceUrl'],
                'sourcePdfPages':q['sourcePdfPages'],'method':'PDF_RAWDICT_FONT_SIZE_CLUSTER_BASE_GEOMETRY',
                'status':'HOLD','reasonCodes':[]}
            blockers=[s for s in geo['reasons'] if s!='RUBY_RENDER_NOT_CERTIFIED']
            if blockers:
                row['reasonCodes']=['OTHER_LAYOUT_HOLD']
            elif id in existing:
                row['reasonCodes']=['ALREADY_APPROVED_BY_IMAGE']
            else:
                half='first_half' if q['questionNo']<=60 else 'second_half'
                doc=docs[year][half];clips=first_question_clip(doc,None,q)
                sourceclips[id]=(doc,clips)
                rich,problems,groups=certify(q,geo,doc,clips)
                row['sourceRubyGroups']=[{'reading':g['reading'],'page':g['page'],
                        'bbox':[round(x,2) for x in g['bbox']],'fontSize':g['fontSize']} for g in groups]
                if rich:
                    row.update(status='FONT_CLUSTER_PASS',reasonCodes=[],**rich)
                    passed.append(row)
                else:row['reasonCodes']=problems
            reviews.append(row)
    assert len(reviews)==130,('Initial 130 mismatch',len(reviews))
    REV.mkdir(exist_ok=True)
    # Hold evidence: source PDF question area and app-style preview independently captured.
    # These are explicitly review-only, not proof of a published UI state.
    hold_rows=[r for r in reviews if r['status']=='HOLD']
    for row in hold_rows:
        id=row['id'];q=candidates[id]
        half='first_half' if q['questionNo']<=60 else 'second_half'
        doc=docs[row['year']][half]
        clips=first_question_clip(doc,None,q)
        path=REV/f'{id}-source.png'
        if clips:
            pix=doc[clips[0][0]].get_pixmap(matrix=fitz.Matrix(1.55,1.55),clip=clips[0][1],alpha=False)
            pix.save(path)
            row['originalPageImage']=str(path.relative_to(B))
        else:row['reasonCodes'].append('SOURCE_CROP_UNAVAILABLE')
        row['candidatePreviewHtml']=f'ruby-font-review/{id}-candidate.html'
        htmltext='''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>
        body{font-family:-apple-system,"Noto Sans JP",sans-serif;background:#fdf6ef;color:#30291f;margin:0;padding:15px}
        main{background:white;border-radius:15px;padding:15px;border:1px solid #e8dbcd;max-width:650px;margin:auto}
        .question{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.9}
        .choice{white-space:pre-wrap;border:1px solid #d9c7b7;border-radius:8px;padding:12px;margin:8px 0}
        small{color:#8f3924}</style><main><small>監査専用：未公開の候補表示。ルビ位置は未確定</small><h3>'''+html.escape(id)+'''</h3><div class="question">'''+html.escape(q['question'])+'''</div>'''+''.join('<div class="choice">'+str(i+1)+'． '+html.escape(choice)+'</div>' for i,choice in enumerate(q['choices']))+'''<p>'''+html.escape(q['attributionDisplay'])+'''</p></main></html>'''
        (B/row['candidatePreviewHtml']).write_text(htmltext)
        row['reviewUrl']=f'ruby-font-review/{id}-review.html'
        source_rel=html.escape(f'{id}-source.png')
        preview_rel=html.escape(f'{id}-candidate.html')
        (B/row['reviewUrl']).write_text(f'<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{id} ルビ比較</title><style>body{{font-family:sans-serif}}section{{display:flex;gap:10px;flex-wrap:wrap}}section>*{{flex:1 1 330px;max-width:100%}}img{{width:100%;object-fit:contain}}iframe{{height:900px;border:1px solid #ccc}}</style><h1>{id} 原典と候補表示</h1><p>未公開。正誤やルビを確定した証拠ではありません。</p><section><img src="{source_rel}" alt="原典PDF設問画像"><iframe src="{preview_rel}" title="候補アプリ風表示"></iframe></section></html>')
        row['sourceImageAndPreviewSaved']=bool(clips)
    # Review-only screenshot of the candidate surface at 375px, never production certification.
    with sync_playwright() as engine:
        browser=engine.chromium.launch(channel='chrome',headless=True)
        page=browser.new_page(viewport={'width':375,'height':850},device_scale_factor=1)
        for row in hold_rows:
            page.goto((B/row['candidatePreviewHtml']).resolve().as_uri(),wait_until='load')
            img=REV/(row['id']+'-candidate-375.png')
            page.screenshot(path=str(img),full_page=True)
            row['candidatePreviewScreenshot']=str(img.relative_to(B))
        browser.close()
    for d in docs.values():
        for doc in d.values():doc.close()
    # Promote only if the normalized candidate can safely render in current rich UI and
    # has no other holds. Source answer verification is inherited from existing pinned reports.
    for row in passed:
        q=candidates[row['id']]
        assert q['answerNumberOfficial']==q['answer']+1 and not q['excludeFromAccuracyDenominator']
    report={'method':'RAW_FONT_CLUSTER_GROUP_AND_EXACT_BASE','year':2026,'reviewed':130,
       'newPass':len(passed),'remainHold':len(hold_rows),'records':reviews,
       'safety':'No inferred pronunciation; ambiguous base/field/position/layout stays HOLD. Source image and candidate display are comparison evidence only.'}
    SHA.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'reviewed':len(reviews),'PASS':len(passed),'HOLD':len(hold_rows),
       'holdReasons':dict(collections.Counter(x for row in hold_rows for x in row['reasonCodes']))},ensure_ascii=False))
if __name__=='__main__':run()
