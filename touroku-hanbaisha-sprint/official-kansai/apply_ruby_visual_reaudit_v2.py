#!/usr/bin/env python3
"""Promote directly visually checked ruby/rt questions only, using pinned PDF evidence."""
import json,re,hashlib
from pathlib import Path
from datetime import datetime,timezone,timedelta
B=Path(__file__).resolve().parent
ROOT=B.parents[1]; IOS=ROOT/'touroku-hanbaisha-ios'
AUDIT=json.loads((B/'RUBY_VISUAL_REAUDIT_V2_20261124.json').read_text())
COMP=json.loads((B/'RUBY_REBUILT_COMPARISON_120_20261124.json').read_text())
COMP_BY_ID={x['id']:x for x in COMP['records']}
original=json.loads((B/'APPROVED_OFFICIAL_BANK.json').read_text())
state=json.loads((IOS/'release-status.json').read_text())
existing={x['id']:x for x in original['questions']}
if len(existing)!=original['count'] or len(set(original['approvedIds']))!=original['count']:raise ValueError('Existing bank corrupt')
if original['count'] not in (440,468):raise ValueError('Unexpected starting bank size')
if len(AUDIT['records'])!=120 or AUDIT['approved']!=28:raise ValueError('Audit counts invalid')
approved=[r for r in AUDIT['records'] if r['decision']=='PASS']
if len(approved)!=28 or {r['id'] for r in approved}!=set(AUDIT['approvedIds']):raise ValueError('Approved ID mismatch')
CAND={}; DIFF={}; GEO={}; KEY={}; CROSS={}
for y in range(2022,2027):
    CAND[y]=json.loads((B/f'QUESTIONS_{y}_APP_CANDIDATE.json').read_text())['questions']
    DIFF[y]=json.loads((B/f'AUTO_DIFF_{y}.json').read_text())['questions']
    GEO[y]=json.loads((B/f'GEOMETRY_AUDIT_{y}.json').read_text())['questions']
    KEY[y]=json.loads((B/f'ANSWERS_{y}_OFFICIAL.json').read_text())['questions']
    CROSS[y]={v['id'] for v in json.loads((B/f'CROSSCHECK_{y}.json').read_text())['results'] if v['status']=='REVIEW_EXTRACTOR_DISAGREEMENT'}
ISOLATED=lambda rd:re.compile(r'(?m)^[ \t]*'+re.escape(rd)+r'[ \t]*$')
def parts_for(text,maps):
    if not maps:return [{'text':text}]
    spans=[]
    for m in maps:
        a=list(ISOLATED(m['reading']).finditer(text))
        if len(a)!=1:raise ValueError('Reading occurrence not unique')
        spans.append((a[0].start(),a[0].end(),m))
    if len({a for a,_,_ in spans})!=len(spans):raise ValueError('Reading overlap')
    clean=text
    for a,b,_ in sorted(spans,reverse=True):clean=clean[:a]+clean[b:]
    offsets=[]
    for _,__,m in spans:
        base=m['base']
        if len(base)!=1 or clean.count(base)!=1:raise ValueError('Base is ambiguous')
        offsets.append((clean.index(base),m))
    offsets.sort(key=lambda x:x[0]);items=[];cursor=0
    for at,m in offsets:
        if at<cursor:raise ValueError('Glyphs overlap')
        items.append({'text':clean[cursor:at]})
        items.append({'rubyBase':m['base'],'rubyText':m['reading'],'sourcePage':m['page']})
        cursor=at+len(m['base'])
    items.append({'text':clean[cursor:]})
    if ''.join(x.get('text',x.get('rubyBase','')) for x in items)!=clean:raise ValueError('Round trip failed')
    return items
added=[]
for row in approved:
    id=row['id'];year=row['year'];n=row['questionNo']
    q=CAND[year][n-1];a=DIFF[year][n-1];g=GEO[year][n-1];key=KEY[year][n-1]
    comp=COMP_BY_ID[id]
    if id in CROSS[year]:raise ValueError('Cross engine disagreement '+id)
    if not (q['id']==a['id']==g['id']==id and q['year']==year and q['questionNo']==n):raise ValueError('Candidate order '+id)
    if a['candidateNormalizedSha256']!=a['sourceNormalizedSha256']:raise ValueError('Source text differs '+id)
    if g['reasons']!=['RUBY_RENDER_NOT_CERTIFIED']:raise ValueError('Other layout hold '+id)
    if key['question_no']!=n or q['answerNumberOfficial']!=key['official_answer'] or q['answer']+1!=key['official_answer']:raise ValueError('Official key '+id)
    if q['excludeFromAccuracyDenominator'] or id=='KSAI-2023-090':raise ValueError('Invalid question must hold')
    if comp['issues'] or comp['rubyDomCount']<1 or not comp['fontProof']['fontJP']:raise ValueError('Ruby screenshot not reliable '+id)
    if len(comp['generatedMappings'])!=comp['rubyDomCount']:raise ValueError('Mapped dom count differs')
    if not (B/comp['officialSourceImage']).exists() or not (B/comp['repairedCandidateScreenshot']).exists():raise ValueError('Missing source preview')
    source_png=(B/comp['officialSourceImage']).read_bytes()
    display_png=(B/comp['repairedCandidateScreenshot']).read_bytes()
    if source_png[:8]!=b'\x89PNG\r\n\x1a\n' or display_png[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Not PNG')
    if not all(x['method']=='PDF_RAW_GLYPH_VERTICAL_XY' for x in comp['generatedMappings']):raise ValueError('Glyph mapping provenance')
    fields=[q['question'],*q['choices']]
    rich=[parts_for(text,[m for m in comp['generatedMappings'] if m['fieldIndex']==i]) for i,text in enumerate(fields)]
    num=sum('rubyBase' in z for p in rich for z in p)
    if num!=comp['rubyDomCount']:raise ValueError('Ruby parts count '+id)
    strings=[''.join(z.get('text',z.get('rubyBase','')) for z in p) for p in rich]
    if len(strings)!=len(q['choices'])+1 or any(not s for s in strings):raise ValueError('Empty question')
    fields_to_copy=['id','year','questionNo','chapter','answer','answerNumberOfficial','sourceIssuer','sourceTitle','sourceUrl','answerSourceUrl','attributionDisplay','officialStatus','excludeFromAccuracyDenominator','sourcePdfPages']
    item={k:q[k] for k in fields_to_copy}
    item.update({'question':strings[0],'choices':strings[1:],
        'questionParts':rich[0],'choicesParts':rich[1:],
        'verbatimCertified':True,'needsVisualReview':False,'renderReady':True,
        'modificationDisclosureDisplay':'原典PDFのルビ位置・読みを目視照合し、ruby/rtで表示用に加工',
        'audit':{'status':'PASS','method':'DIRECT_VISUAL_PDF_JP_RUBY_RT_COMPARED_V2',
          'evidence':'RUBY_VISUAL_REAUDIT_V2_20261124.json',
          'sourceImage':comp['officialSourceImage'],
          'sourceImageSha256':hashlib.sha256(source_png).hexdigest(),
          'candidateScreenshot':comp['repairedCandidateScreenshot'],
          'candidateScreenshotSha256':hashlib.sha256(display_png).hexdigest(),
          'glyphMappings':comp['generatedMappings'],'font':'Noto Sans CJK JP',
          'rubyElementCount':num,'visualSource':'8 high-resolution side-by-side contact sheets independently inspected'}})
    if id in existing:
        if existing[id]['audit']['method']!=item['audit']['method']:raise ValueError('Already approved by different method '+id)
        continue
    existing[id]=item
    original['byYear'][str(year)]['visualRubyV2']=original['byYear'][str(year)].get('visualRubyV2',0)+1
    original['byYear'][str(year)]['hold']-=1
    if original['byYear'][str(year)]['hold']<0:raise ValueError('Negative hold')
    added.append(id)
original['questions']=sorted(existing.values(),key=lambda x:(x['year'],x['questionNo']))
original['approvedIds']=[x['id'] for x in original['questions']]
original['count']=len(original['questions'])
if original['count']!=468 or len(set(original['approvedIds']))!=468:raise ValueError('Expected exactly 468/600')
if len(added) not in (0,28):raise ValueError('Unexpected partial approval')
if 'KSAI-2023-090' in original['approvedIds']:raise ValueError('2023 invalid question')
(B/'APPROVED_OFFICIAL_BANK.json').write_text(json.dumps(original,ensure_ascii=False,indent=2)+'\n')
now=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')
state['updated_at']=now;state['release_gate']='BLOCKED';state['app_review_submitted']=False
qb=state['question_bank'];qb['verified_official_imported']=468;qb['official_question_text_imported']=468;qb['production_official_bank_count']=468
qb['ruby_comparison_repair_v2']={
    'status':'COMPLETE_120_SCREENSHOTS_AND_28_DIRECT_VISUAL_MATCHES',
    'target':120,'screenshotCountVerified':120,'comparisonPagesVerified':120,
    'font':'Noto Sans CJK JP','rubyMarkupQuestionCount':62,'withoutConfidentInlineRuby':58,
    'visuallyComparedCleanShortlist':32,'visuallyCertified':28,'visuallyHeld':92,
    'newPromotions':28,'promotedIds':AUDIT['approvedIds'],
    'comparisonEvidence':'touroku-hanbaisha-sprint/official-kansai/RUBY_REBUILT_COMPARISON_120_20261124.json',
    'visualAudit':'touroku-hanbaisha-sprint/official-kansai/RUBY_VISUAL_REAUDIT_V2_20261124.json',
    'visualHoldNote':'4 table-heavy visually inspected cases and 88 ambiguous/not directly certified cases remain HOLD'
}
qb['ruby_unconfirmed_font_cluster_review']=92
state['gates']['ruby_visual_comparison_v2']='PASS_120_SCREENSHOTS_28_VISUAL_PROMOTION_92_HOLD'
state['gates']['official_source_import']='PARTIAL_APPROVED_468_OF_600'
state['gates']['content_complete']='BLOCKED';state['gates']['release_readiness']='BLOCKED'
for name in ['RUBY_REBUILT_COMPARISON_120_20261124.json','RUBY_VISUAL_REAUDIT_V2_20261124.json','RUBY_VISUAL_SHORTLIST_V2.json']:
    uri='touroku-hanbaisha-sprint/official-kansai/'+name
    if uri not in state.setdefault('evidence',[]):state['evidence'].append(uri)
(IOS/'release-status.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
md=IOS/'RELEASE_STATUS.md'
section=f"""
## 【最新】2026-11-24 ルビ120問 Noto日本語フォント＋真正ruby/rtの比較画像再監査

- **正式バンク468/600問**（作業前440問、今回28問昇格）。本審査BLOCKED、未収録132問。
- 原典PDF原図と候補のNoto Sans CJK JP／Chrome 375pxレンダリングを再作成。**120問のスクリーンショット・120問の比較HTML・15枚の全件比較シート**を生成し読戻し確認。日本語の四角い欠字を修復。
- 候補の単語ルビ対応と文字座標から62問に真正なHTML \`ruby\`・\`rt\`を生成。58問はルビ対応が一意に定まらずHOLD。
- 警告なし32問の原典画像と候補画像を8枚の高解像度比較シートで実際に確認。**視覚一致確認28問をPASS**。表・成分配置の忠実再現が不確かな4問（2024問40、2025問44・52、2026問36）はHOLD。ほか88問も原典ルビの全部の位置対応を確認できずHOLD。
- 昇格ID：{', '.join(AUDIT['approvedIds'])}
- 各昇格問は公式正答索引、正規化された原典PDF text hash、原典字形座標、画面画像、\`ruby/rt\`構造一致、既存バンクの重複、2023問90例外を検証。古いHOLD記録を残し、V2の直接目視PASSを追加証跡として保存。
- 保存：\`official-kansai/RUBY_REBUILT_COMPARISON_120_20261124.json\`、\`RUBY_VISUAL_REAUDIT_V2_20261124.json\`、\`ruby-font-review/SHORTLIST_REVIEW_01.jpg\`～\`08.jpg\`、正式バンク \`APPROVED_OFFICIAL_BANK.json\`。
- **Apple実機／Safari／TestFlight検証は未完了。App Review最終送信、課金・契約確定を行わない。**
"""
if '【最新】2026-11-24 ルビ120問 Noto日本語フォント' not in md.read_text():
    md.write_text(md.read_text()+'\n'+section)
print(json.dumps({'newlyPromoted':len(added),'bank':original['count'],'held':92,'ids':added},ensure_ascii=False))
