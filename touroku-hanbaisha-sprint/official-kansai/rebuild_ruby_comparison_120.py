#!/usr/bin/env python3
"""Repair all 120 original-vs-candidate ruby comparison screenshots.

Japanese font and real ruby/rt are mandatory. No automatic release promotion.
For uncertain source base geometry: show candidate markup in a flagged review state.
"""
import collections,datetime,hashlib,html,json,re,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from playwright.sync_api import sync_playwright
from auto_diff_pdf import B,download
from geometry_second_gate import first_question_clip
from ruby_font_cluster_recovery import rawglyphs

BASE=B/'ruby-font-review'
OLD=B/'RUBY_FONT_CLUSTER_ALL_20261124.json'
OUT=B/'RUBY_REBUILT_COMPARISON_120_20261124.json'
FULLWIDTH='１２３４５６７８９０'
CJK=re.compile(r'^[\u3400-\u9fff々]$')
def field_parts(text, mappings):
    """Produce exact original plain-text roundtrip, replacing only standalone reading."""
    matches=[]
    for item in mappings:
        reading=item['reading']
        spans=list(re.finditer(r'(?m)^[ \t]*'+re.escape(reading)+r'[ \t]*$',text))
        if len(spans)!=1:
            return None,'READING_LINE_NONUNIQUE'
        matches.append((spans[0].start(),spans[0].end(),item))
    if len({m[0] for m in matches})!=len(matches):return None,'READING_LINES_OVERLAP'
    clean=text
    for start,end,_ in sorted(matches,key=lambda x:x[0],reverse=True):
        clean=clean[:start]+clean[end:]
    anchors=[]
    for _,__,item in matches:
        base=item['base']
        occ=[m.start() for m in re.finditer(re.escape(base),clean)]
        if len(occ)!=1:return None,'BASE_OCCURRENCE_NOT_UNIQUE'
        anchors.append((occ[0],item))
    anchors.sort(key=lambda z:z[0])
    if any(anchors[i][0]+len(anchors[i][1]['base'])>anchors[i+1][0] for i in range(len(anchors)-1)):
        return None,'OVERLAPPING_BASE'
    parts=[];cursor=0
    for pos,item in anchors:
        parts.extend([{'text':clean[cursor:pos]},
             {'rubyBase':item['base'],'rubyText':item['reading'],'sourcePage':item['page']}])
        cursor=pos+len(item['base'])
    parts.append({'text':clean[cursor:]})
    if ''.join(z.get('text',z.get('rubyBase','')) for z in parts)!=clean:raise ValueError('roundtrip')
    return parts,None
def source_glyph_candidates(g,source):
    """Rank full-size glyphs just below original-source small kana bbox."""
    rx0,ry0,rx1,ry1=g['bbox']; cx=(rx0+rx1)/2
    candidates=[]
    for ch in source:
        if ch['page']!=g['page'] or not CJK.fullmatch(ch['c']):continue
        if ch['size'] < g['fontSize']*1.35:continue
        x0,y0,x1,y1=ch['bbox'];cent=(x0+x1)/2
        if not -3<=y0-ry1<=26:continue
        if abs(cx-cent)>max(10,(rx1-rx0)*0.85):continue
        score=abs(cx-cent)+.18*abs((y0-ry1)-4.0)
        candidates.append((score,ch))
    candidates.sort(key=lambda z:z[0])
    unique={}
    for score,glyph in candidates:
        key=(glyph['page'],glyph['c'],tuple(round(v,1) for v in glyph['bbox']))
        unique[key]=(score,glyph)
    return sorted(unique.values(),key=lambda z:z[0])
def guess_mapping(q,group,prior,chars):
    """Use the actual PDF glyph under the ruby (not a pronunciation dictionary)."""
    choices=source_glyph_candidates(group,chars)
    if not choices:return None,'SOURCE_GLYPH_BENEATH_RUBY_NOT_FOUND'
    top=choices[0]
    if len(choices)>1 and choices[1][0]-top[0]<2.5:
        return None,'SOURCE_GLYPH_GEOMETRY_AMBIGUOUS'
    base=top[1]['c']
    if not CJK.fullmatch(base):return None,'KANJI_NOT_SINGLE_CHAR'
    reading=group['reading']
    fields=[q['question'],*q['choices']]
    candidates=[]
    for i,text in enumerate(fields):
        if len(re.findall(r'(?m)^[ \t]*'+re.escape(reading)+r'[ \t]*$',text))==1 and text.count(base)==1:
            candidates.append(i)
    if len(candidates)!=1:return None,'TEXT_FIELD_OR_BASE_AMBIGUOUS'
    return {'fieldIndex':candidates[0],'base':base,'reading':reading,
            'page':group['page'],'glyphBBox':[round(x,2) for x in top[1]['bbox']],
            'rubyBBox':group['bbox'],'method':'PDF_RAW_GLYPH_VERTICAL_XY'},None
def make_preview(row,q,mappings,issues):
    fields=[q['question'],*q['choices']]
    parts=[]
    for i,text in enumerate(fields):
        assigned=[m for m in mappings if m['fieldIndex']==i]
        if assigned:
            built,why=field_parts(text,assigned)
            if why:issues.append(why);parts.append([{'text':text}])
            else:parts.append(built)
        else:parts.append([{'text':text}])
    def render(seg):
        return ''.join(html.escape(p['text']) if 'text' in p else
          '<ruby>'+html.escape(p['rubyBase'])+'<rp>（</rp><rt>'+html.escape(p['rubyText'])+'</rt><rp>）</rp></ruby>' for p in seg)
    count=sum('rubyBase' in p for field in parts for p in field)
    warnings='、'.join(sorted(set(issues))) if issues else '候補の文字位置を原典と目視照合してください'
    safeid=html.escape(row['id'])
    css='''@font-face{font-family:AuditJP;src:local("Noto Sans CJK JP"),local("Noto Sans JP")}*{box-sizing:border-box}html{background:#fff8f0}body{font-family:AuditJP,"Noto Sans CJK JP","Noto Sans JP",sans-serif;font-size:15px;color:#25201a;margin:0;padding:12px}main{background:white;border:1px solid #e2d6cb;border-radius:12px;padding:13px;max-width:730px;margin:auto}.small{font-size:12px;color:#8b4b29}.warn{background:#fff2df;padding:8px;border-radius:6px;font-size:12px;overflow-wrap:anywhere}.q,.ch{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.85}.ch{border:1px solid #e6d8ca;padding:7px;margin-top:6px;border-radius:7px}ruby{ruby-position:over;ruby-align:center}rt{font-size:.55em;line-height:1.05}footer{font-size:12px;margin-top:12px;color:#69564a}'''
    return f'<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>{css}</style></head><body><main><div class="small">公式過去問｜監査専用ルビ表示（未確定）</div><h3>{safeid}　ruby/rt {count}箇所</h3><div class="warn">{html.escape(warnings)}</div><section class="q">{render(parts[0])}</section>'+''.join(f'<div class="ch">{i+1}．{render(seg)}</div>' for i,seg in enumerate(parts[1:]))+f'<footer>{html.escape(q["attributionDisplay"])}　原典の加工表示。判定前の候補です。</footer></main></body></html>',parts,count
def font_check(page):
    return page.evaluate("""() => {
      const c=document.createElement('canvas');const ctx=c.getContext('2d');
      ctx.font='20px "Noto Sans CJK JP"';
      const w1=ctx.measureText('罹患漢字日本語').width;
      ctx.font='20px monospace'; const w2=ctx.measureText('罹患漢字日本語').width;
      return {fontJP:document.fonts.check('16px "Noto Sans CJK JP"'),
        measuredJapanese:w1,monospaceJapanese:w2,
        domRuby:document.querySelectorAll('ruby').length,
        domRt:document.querySelectorAll('rt').length,
        rubyPositions:[...document.querySelectorAll('ruby')].map(e=>({base:e.firstChild?.textContent,
          reading:e.querySelector('rt')?.textContent}))};
    }""")
def make_sheet(rows,index):
    """Small contact sheet for human review. Each tile contains actual original+new preview."""
    selected=rows[index:index+8];tiles=[]
    for row in selected:
        ps=B/row['officialSourceImage']; pc=B/row['repairedCandidateScreenshot']
        if not ps.exists() or not pc.exists():continue
        src=Image.open(ps).convert('RGB');candidate=Image.open(pc).convert('RGB')
        maxw=550
        def shrink(im):
            if im.width>maxw:im=im.resize((maxw,max(1,int(im.height*maxw/im.width))))
            return im
        src=shrink(src);candidate=shrink(candidate)
        height=min(max(src.height,candidate.height),1150)
        canvas=Image.new('RGB',(maxw*2+16,height+42),'white')
        canvas.paste(src,(0,42));canvas.paste(candidate,(maxw+16,42))
        d=ImageDraw.Draw(canvas)
        d.text((10,12),row['id']+'  SOURCE',fill='black')
        d.text((maxw+22,12),'CANDIDATE '+str(row['rubyDomCount']),fill='black')
        tiles.append(canvas)
    if not tiles:return None
    sheet=Image.new('RGB',(tiles[0].width,sum(x.height for x in tiles)+10*(len(tiles)-1)),'#e4dbd3')
    y=0
    for im in tiles:sheet.paste(im,(0,y));y+=im.height+10
    name=f'ruby-font-review/CONTACT_SHEET_V2_{index//8+1:02d}.jpg'
    (B/name).parent.mkdir(exist_ok=True)
    sheet.save(B/name,quality=78,optimize=True)
    return name
def main():
    baseline=json.loads(OLD.read_text())
    rows=[r for r in baseline['records'] if r['status']=='HOLD']
    if len(rows)!=120:raise RuntimeError(f"hold count drift {len(rows)}")
    bank=json.loads((B/'APPROVED_OFFICIAL_BANK.json').read_text())
    if bank['count']!=440:raise RuntimeError("production bank changed; require fresh migration")
    candidate={};geos={}
    for y in range(2022,2027):
        candidate[y]=json.loads((B/f'QUESTIONS_{y}_APP_CANDIDATE.json').read_text())['questions']
        geos[y]=json.loads((B/f'GEOMETRY_AUDIT_{y}.json').read_text())['questions']
    years={v['year']:v for v in json.loads((B/'SOURCES_2022_2026.json').read_text())['years']}
    docs={};summary=collections.Counter()
    for y in range(2022,2027):
        shas=json.loads((B/f'PDF_SHA256_{y}.json').read_text())
        docs[y]={}
        for half,key in [('first_half','question_pdf_first_half'),('second_half','question_pdf_second_half')]:
            url=years[y][key]
            docs[y][half]=download(url,B/f'.tmp_compare_20261124_{y}_{half}.pdf',
                next(v['sha256'] for v in shas if v['half']==half))
    BASE.mkdir(exist_ok=True)
    records=[]
    for row in rows:
        y=row['year'];q=candidate[y][row['questionNo']-1]
        geo=geos[y][row['questionNo']-1]
        assert q['id']==row['id']==geo['id']
        doc=docs[y]['first_half' if q['questionNo']<=60 else 'second_half']
        clips=first_question_clip(doc,None,q)
        mapping=[];issues=[];candidates_placed=[]
        if clips:
            glyphs=rawglyphs(doc,clips)
            for group in row.get('sourceRubyGroups',[]):
                mapping_one,reason=guess_mapping(q,group,geo,glyphs)
                if mapping_one:mapping.append(mapping_one)
                else:issues.append(reason)
        else:issues.append('PDF_QUESTION_REGION_UNAVAILABLE')
        pageHtml,parts,tag_count=make_preview(row,q,mapping,issues)
        path=BASE/(row['id']+'-candidate-v2.html')
        path.write_text(pageHtml)
        review=BASE/(row['id']+'-review-v2.html')
        review.write_text(f'<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(row["id"])} 原典×ルビ候補</title><style>body{{font-family:"Noto Sans CJK JP",sans-serif;margin:12px}}section{{display:grid;grid-template-columns:1fr 1fr;gap:12px}}img{{max-width:100%;height:auto}}iframe{{width:100%;height:1100px}}@media(max-width:700px){{section{{grid-template-columns:1fr}}}}</style><h2>{html.escape(row["id"])}：原典と未確定候補</h2><p>画像/候補は要目視。自動プレビュー一致を監査PASSとみなさない。</p><section><img src="{row["id"]}-source.png"><iframe src="{row["id"]}-candidate-v2.html"></iframe></section></html>')
        new=dict(id=row['id'],year=y,questionNo=q['questionNo'],
            sourcePdfPages=q['sourcePdfPages'],officialSourceImage=row['originalPageImage'],
            repairedCandidateHtml=str(path.relative_to(B)),
            repairedReviewHtml=str(review.relative_to(B)),
            generatedMappings=mapping, issues=issues,
            rubyDomExpected=tag_count,originalHoldReasons=row.get('reasonCodes',[]),
            auditDecision='PENDING_DIRECT_VISUAL_REVIEW',promotionAllowed=False)
        records.append(new)
    # Use headless Chromium with explicit Japanese font. Fail if unavailable.
    with sync_playwright() as playwright:
        browser=playwright.chromium.launch(channel='chrome',headless=True)
        ctx=browser.new_context(viewport={'width':375,'height':850},device_scale_factor=1)
        page=ctx.new_page()
        for row in records:
            page.goto((B/row['repairedCandidateHtml']).resolve().as_uri(),wait_until='load')
            page.evaluate('document.fonts.ready')
            proof=font_check(page)
            if not proof['fontJP']:raise RuntimeError('Noto CJK JP font not available in screenshot Chrome')
            if proof['domRuby']!=row['rubyDomExpected'] or proof['domRt']!=row['rubyDomExpected']:
                raise RuntimeError('Ruby/rt DOM count mismatch '+row['id'])
            out=BASE/(row['id']+'-candidate-375-v2.png')
            page.screenshot(path=str(out),full_page=True)
            row['repairedCandidateScreenshot']=str(out.relative_to(B))
            row['fontProof']=proof
            row['rubyDomCount']=proof['domRuby']
            row['imageRegenerated']=out.exists() and out.stat().st_size>3000
            if not row['imageRegenerated']:raise RuntimeError('screenshot missing '+row['id'])
            summary['rubyWithMarkup' if row['rubyDomCount'] else 'rubyNoSafeInlineMarkup']+=1
            summary['imageRegenerated']+=1
            for reason in row['issues']:summary['issue:'+reason]+=1
        ctx.close();browser.close()
    for groupstart in range(0,120,8):
        name=make_sheet(records,groupstart)
        if not name:raise RuntimeError('contact sheet missing '+str(groupstart))
    for yearDocs in docs.values():
        for doc in yearDocs.values():doc.close()
    assert summary['imageRegenerated']==120
    result={'schema':'touhan-ruby-comparison-v2','generatedAtJST':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
        'sourceQuestionCount':120,'screenshotsRegenerated':120,'comparisonPagesRegenerated':120,
        'font':'Noto Sans CJK JP','fontInstalledAndDetected':True,
        'rubyMarkupQuestionCount':summary['rubyWithMarkup'],
        'rubyUnresolvedWithoutInlineMarkup':summary['rubyNoSafeInlineMarkup'],
        'contactSheets':[f'ruby-font-review/CONTACT_SHEET_V2_{i:02d}.jpg' for i in range(1,16)],
        'directVisuallyApproved':0,'newlyPromoted':0,
        'requiresVisualReview':120,
        'summary':dict(summary),'records':records,
        'caveat':'Generated Ruby DOM is a visual hypothesis, not verified identical to original PDF. Only direct image viewing plus separate authorized approval can promote.'}
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('screenshotsRegenerated','rubyMarkupQuestionCount','rubyUnresolvedWithoutInlineMarkup','newlyPromoted')},ensure_ascii=False))
if __name__=='__main__':main()
