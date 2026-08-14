#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
DRAFT=ROOT/'enriched-draft'
MANIFEST=ROOT/'manifest.json'
EXPERT_QUEUE=ROOT/'situation-audit'/'expert-review-queue.json'

sets=[]
all_questions=[]
for sid in ('set1','set2','set3'):
    doc=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    qs=doc.get('questions') or []
    if len(qs)!=240:
        raise SystemExit(f'{sid}: expected 240 questions, got {len(qs)}')
    sets.append((sid,doc,qs))
    all_questions.extend(qs)

if len(all_questions)!=720 or len({q['id'] for q in all_questions})!=720:
    raise SystemExit('runtime requires 720 unique canonical questions')

expert_doc=json.loads(EXPERT_QUEUE.read_text(encoding='utf-8'))
blocked={x.get('questionId') for x in expert_doc.get('items') or [] if x.get('appEligible') is False}
blocked.discard(None)
if blocked != {'K115-AM103','K115-AM114'}:
    raise SystemExit(f'unexpected expert-blocked set: {sorted(blocked)}')

def compact(q):
    keep=(
        'id','sourceExam','session','questionNo','category','majorSubject','subject',
        'answerType','selectCount','question','choices','answer','point','detail','reason',
        'scenario','scenarioId','scenarioIndex','scenarioTotal','unit','tolerance',
        'officialAcceptedAnswers','officialScoringStatus','scoringException','scoringExceptionStatus',
        'scoringRuntimeMode','mediaReleaseStatus','mediaRightsStatus','mediaAssets','mediaAttribution',
        'mediaResolutionMethod'
    )
    out={k:q[k] for k in keep if k in q and q[k] is not None}
    out['releaseEligible']=q['id'] not in blocked
    return out

runtime=[compact(q) for q in all_questions]
eligible=[q for q in runtime if q['releaseEligible']]
if len(eligible)!=718:
    raise SystemExit(f'expected 718 runtime eligible questions, got {len(eligible)}')

payload='(()=>{\n\'use strict\';\n'
payload+='const ALL='+json.dumps(runtime,ensure_ascii=False,separators=(',',':'))+';\n'
payload+='window.KANGOSHI_ALL_QUESTIONS=ALL;\n'
payload+='window.KANGOSHI_QUESTIONS=ALL.filter(q=>q.releaseEligible!==false);\n'
payload+='window.KANGOSHI_RUNTIME_META='+json.dumps({
    'schemaVersion':1,'canonicalTotal':720,'runtimeEligible':718,'expertBlockedIds':sorted(blocked),
    'source':'product-content/enriched-draft','generatedBy':'build_product_runtime.py'
},ensure_ascii=False,separators=(',',':'))+';\n})();\n'
(APP/'questions-runtime.js').write_text(payload,encoding='utf-8')

manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
by_exam={115:'set1',114:'set2',113:'set3'}
for s in manifest.get('sets') or []:
    exam=int(s.get('sourceExam') or 0)
    rows=[q for q in runtime if int(q.get('sourceExam') or 0)==exam]
    if len(rows)!=240:
        raise SystemExit(f'exam {exam}: runtime total {len(rows)}')
    blocked_ids=sorted(q['id'] for q in rows if not q['releaseEligible'])
    eligible_count=240-len(blocked_ids)
    s['questionCount']=240
    s['runtimeEligibleCount']=eligible_count
    s['expertReviewedCount']=eligible_count
    s['expertBlockedIds']=blocked_ids
    s['status']='ready' if eligible_count==240 else 'pending_expert_review'
manifest['runtime']={
    'schemaVersion':1,'canonicalTotal':720,'runtimeEligible':718,'blocked':sorted(blocked),
    'readyExamSets':[114,113],'pendingExamSets':[115]
}
MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

audit={
    'schemaVersion':1,'canonicalTotal':len(runtime),'runtimeEligible':len(eligible),
    'blockedIds':sorted(blocked),'byExam':{},'mediaResolved':0,'mediaMissingAssets':[],
    'pass':True,'errors':[]
}
for exam in (115,114,113):
    rows=[q for q in runtime if q['sourceExam']==exam]
    audit['byExam'][str(exam)]={
        'total':len(rows),'eligible':sum(q['releaseEligible'] for q in rows),
        'required':sum(q['category']=='必修' for q in rows),
        'general':sum(q['category']=='一般' for q in rows),
        'situation':sum(q['category']=='状況設定' for q in rows)
    }
for q in runtime:
    assets=q.get('mediaAssets') or []
    if q.get('mediaReleaseStatus')=='resolved':
        audit['mediaResolved']+=1
        for rel in assets:
            if not (APP/rel).exists(): audit['mediaMissingAssets'].append({'id':q['id'],'asset':rel})
if audit['mediaResolved']!=38:
    audit['errors'].append(f"expected 38 resolved media questions, got {audit['mediaResolved']}")
if audit['mediaMissingAssets']:
    audit['errors'].append('runtime media asset missing')
for exam,row in audit['byExam'].items():
    if (row['total'],row['required'],row['general'],row['situation'])!=(240,50,130,60):
        audit['errors'].append(f'exam {exam} composition mismatch {row}')
if audit['byExam']['115']['eligible']!=238 or audit['byExam']['114']['eligible']!=240 or audit['byExam']['113']['eligible']!=240:
    audit['errors'].append('eligible count mismatch')
audit['pass']=not audit['errors']
(ROOT/'product-runtime-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if not audit['pass']:
    raise SystemExit(json.dumps(audit,ensure_ascii=False))
print(json.dumps(audit,ensure_ascii=False))
