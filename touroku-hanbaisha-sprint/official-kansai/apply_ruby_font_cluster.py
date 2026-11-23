#!/usr/bin/env python3
"""Conservative incorporation of font-cluster verified ruby; never override approved crops."""
import json
from pathlib import Path
B=Path(__file__).resolve().parent
IOS=B.parents[1]/'touroku-hanbaisha-ios'
report=json.loads((B/'RUBY_FONT_CLUSTER_ALL_20261124.json').read_text())
bp=B/'APPROVED_OFFICIAL_BANK.json'
bank=json.loads(bp.read_text())
sp=IOS/'release-status.json'
state=json.loads(sp.read_text())
existing=set(bank['approvedIds'])
assert bank['count']==len(existing)==len(bank['questions'])==430
assert report['reviewed']==len(report['records'])==130
assert sum(x['audit']['method']=='OFFICIAL_PDF_IMAGE_CROP_SCOPE_RIGHTS_MOBILE' for x in bank['questions'] if x.get('audit'))==44
promoted=[]
for r in report['records']:
    if r['status']!='FONT_CLUSTER_PASS' or r['id'] in existing:continue
    y=r['year'];n=r['questionNo'];id=r['id']
    q=json.loads((B/f'QUESTIONS_{y}_APP_CANDIDATE.json').read_text())['questions'][n-1]
    g=json.loads((B/f'GEOMETRY_AUDIT_{y}.json').read_text())['questions'][n-1]
    old=json.loads((B/f'ORDERED_RUBY_{y}.json').read_text())['records'][n-1]
    assert q['id']==g['id']==old['id']==id
    assert g['reasons']==['RUBY_RENDER_NOT_CERTIFIED'] and old['status']=='HOLD'
    assert q['answerNumberOfficial']==q['answer']+1 and not q['excludeFromAccuracyDenominator']
    assert r['reasonCodes']==[] and r['placements']
    parts=[r['questionParts'],*r['choicesParts']]
    assert len(parts)==len(q['choices'])+1
    fields=[''.join(z.get('text',z.get('rubyBase','')) for z in field) for field in parts]
    assert all(fields) and len(fields[0])>30
    assert sum('rubyBase' in z for field in parts for z in field)==len(r['placements'])
    assert all(len(z['rubyBase'])==1 and z.get('rubyText') for field in parts for z in field if 'rubyBase' in z)
    keys=('id','year','questionNo','chapter','answer','answerNumberOfficial','sourceIssuer',
      'sourceTitle','sourceUrl','answerSourceUrl','attributionDisplay','officialStatus',
      'excludeFromAccuracyDenominator','sourcePdfPages')
    item={k:q[k] for k in keys}
    item.update({'question':fields[0],'choices':fields[1:],'questionParts':r['questionParts'],
       'choicesParts':r['choicesParts'],'verbatimCertified':True,'needsVisualReview':False,
       'renderReady':True,'modificationDisclosureDisplay':'原典PDF座標からルビを照合してruby要素で再配置',
       'audit':{'status':'PASS','method':'PDF_RAW_FONT_CLUSTER_RUBY',
          'record':'RUBY_FONT_CLUSTER_ALL_20261124.json','placements':r['placements']}})
    bank['questions'].append(item);existing.add(id);promoted.append(id)
    bank['byYear'][str(y)]['rubyFontCluster']=bank['byYear'][str(y)].get('rubyFontCluster',0)+1
    bank['byYear'][str(y)]['hold']-=1
    assert bank['byYear'][str(y)]['hold']>=0
bank['questions'].sort(key=lambda q:(q['year'],q['questionNo']))
bank['approvedIds']=[q['id'] for q in bank['questions']]
bank['count']=len(bank['questions'])
assert bank['count']==len(set(bank['approvedIds']))==430+len(promoted)
assert 'KSAI-2023-090' not in bank['approvedIds']
bp.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+'\n')
state['question_bank'].update({
 'production_official_bank_count':bank['count'],
 'verified_official_imported':bank['count'],
 'official_question_text_imported':bank['count'],
 'ruby_font_cluster_audit':{
   'reviewed':130,'sourceAndCandidateComparisonImages':report['remainHold'],
   'newPass':report['newPass'],'newlyPromoted':len(promoted),'promotedIds':promoted,
   'remainingRubyHold':report['remainHold'],
   'evidence':'touroku-hanbaisha-sprint/official-kansai/RUBY_FONT_CLUSTER_ALL_20261124.json'},
 'ruby_unconfirmed_font_cluster_review':report['remainHold']})
state['release_gate']='BLOCKED';state['app_review_submitted']=False
state.setdefault('gates',{})['official_source_import']=f'PARTIAL_APPROVED_{bank["count"]}_OF_600'
state['gates']['content_complete']='BLOCKED';state['gates']['release_readiness']='BLOCKED'
uri='touroku-hanbaisha-sprint/official-kansai/RUBY_FONT_CLUSTER_ALL_20261124.json'
if uri not in state.setdefault('evidence',[]):state['evidence'].append(uri)
sp.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
md=IOS/'RELEASE_STATUS.md'
md.write_text(md.read_text()+ '\n\n## 2026-11-24：生フォント・座標ルビ再監査\n'
 +f'- ルビHOLD130問にPDF rawdictフォントサイズ・仮名グループ化・既存の本文BBox照合を適用。新PASS {report["newPass"]}、残HOLD {report["remainHold"]}。\n'
 +f'- 正式バンク追加 {len(promoted)}問（ID: {", ".join(promoted) or "なし"}）、合計 {bank["count"]}/600問。画像方式の既存44問は保持。\n'
 +'- 未確定問の原典PDF画像・375px候補表示PNGと比較HTMLは touroku-hanbaisha-sprint/official-kansai/ruby-font-review/ に保存。表示は比較用で正式アプリ実機検証ではない。\n'
 +'- 根拠不明の読みを生成せずHOLDを保持。App Review未送信、契約と課金は未確定、判定BLOCKED。\n')
print(json.dumps({'reviewed':130,'newPass':report['newPass'],'promoted':len(promoted),'ids':promoted,'bank':bank['count'],'hold':report['remainHold']},ensure_ascii=False))
