#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
DRAFT=ROOT/'enriched-draft'
MANIFEST=ROOT/'manifest.json'
REVIEW_QUEUE=ROOT/'situation-audit'/'expert-review-queue.json'
KNOWN_SPECIALIST_IDS={'K115-AM103','K115-AM114'}
QUARANTINE=ROOT/'release-quarantine-20261125.json'

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

review_doc=json.loads(REVIEW_QUEUE.read_text(encoding='utf-8'))
blocked={x.get('questionId') for x in review_doc.get('items') or [] if x.get('appEligible') is False}
blocked.discard(None)
if not blocked.issubset(KNOWN_SPECIALIST_IDS):
    raise SystemExit(f'unexpected review-blocked ids: {sorted(blocked-KNOWN_SPECIALIST_IDS)}')
# Official-PDF verification quarantine (unverifiable text / non-PDL media / incomplete items).
quarantine_doc=json.loads(QUARANTINE.read_text(encoding='utf-8'))
quarantined={x['id'] for x in quarantine_doc.get('items') or []}
draft_quarantined={q['id'] for q in all_questions if q.get('releaseQuarantineStatus')=='quarantined'}
if quarantined!=draft_quarantined:
    raise SystemExit(f'draft quarantine markers out of sync with {QUARANTINE.name}: run apply_official_pdf_text_repairs.py')
blocked|=quarantined

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
expected_eligible=720-len(blocked)
if len(eligible)!=expected_eligible:
    raise SystemExit(f'expected {expected_eligible} runtime eligible questions, got {len(eligible)}')

payload='(()=>{\n\'use strict\';\n'
payload+='const ALL='+json.dumps(runtime,ensure_ascii=False,separators=(',',':'))+';\n'
payload+='window.KANGOSHI_ALL_QUESTIONS=ALL;\n'
payload+='window.KANGOSHI_QUESTIONS=ALL.filter(q=>q.releaseEligible!==false);\n'
payload+='window.KANGOSHI_RUNTIME_META='+json.dumps({
    'schemaVersion':3,'canonicalTotal':720,'runtimeEligible':len(eligible),'releaseBlockedIds':sorted(blocked),
    'releaseQuarantined':len(quarantined),'releaseQuarantineRef':'product-content/'+QUARANTINE.name,
    'reviewBasis':'ai_ci_primary_source_audit','source':'product-content/enriched-draft','generatedBy':'build_product_runtime.py'
},ensure_ascii=False,separators=(',',':'))+';\n})();\n'
(APP/'questions-runtime.js').write_text(payload,encoding='utf-8')

manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
ready=[]; pending=[]
for s in manifest.get('sets') or []:
    exam=int(s.get('sourceExam') or 0)
    rows=[q for q in runtime if int(q.get('sourceExam') or 0)==exam]
    if len(rows)!=240:
        raise SystemExit(f'exam {exam}: runtime total {len(rows)}')
    blocked_ids=sorted(q['id'] for q in rows if not q['releaseEligible'])
    eligible_count=240-len(blocked_ids)
    s['questionCount']=240
    s['runtimeEligibleCount']=eligible_count
    s['releaseEligibleCount']=eligible_count
    s['releaseBlockedIds']=blocked_ids
    s['reviewBasis']='ai_ci_primary_source_audit'
    s.pop('expertReviewedCount',None)
    s.pop('expertBlockedIds',None)
    s['status']='ready' if eligible_count==240 else 'pending_release_review'
    (ready if eligible_count==240 else pending).append(exam)
manifest['runtime']={
    'schemaVersion':3,'canonicalTotal':720,'runtimeEligible':len(eligible),'releaseBlocked':sorted(blocked),
    'releaseQuarantined':len(quarantined),'releaseQuarantineRef':'product-content/'+QUARANTINE.name,
    'reviewBasis':'ai_ci_primary_source_audit',
    'readyExamSets':sorted(ready,reverse=True),'pendingExamSets':sorted(pending,reverse=True)
}
MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

audit={
    'schemaVersion':3,'canonicalTotal':len(runtime),'runtimeEligible':len(eligible),
    'blockedIds':sorted(blocked),'quarantinedIds':sorted(quarantined),'reviewBasis':'ai_ci_primary_source_audit',
    'byExam':{},'mediaResolved':0,'mediaMissingAssets':[],
    'readyExamSets':sorted(ready,reverse=True),'pendingExamSets':sorted(pending,reverse=True),
    'pass':True,'errors':[]
}
for exam in (115,114,113):
    rows=[q for q in runtime if q['sourceExam']==exam]
    audit['byExam'][str(exam)]={
        'total':len(rows),'eligible':sum(q['releaseEligible'] for q in rows),
        'eligibleMediaResolved':sum(1 for q in rows if q['releaseEligible'] and q.get('mediaReleaseStatus')=='resolved'),
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
by_id={q['id']:q for q in all_questions}
audit['eligibleMediaQuestions']=[]
for q in runtime:
    src=by_id[q['id']]
    if q['releaseEligible'] and src.get('requiresMedia'):
        audit['eligibleMediaQuestions'].append(q['id'])
        if q.get('mediaReleaseStatus')!='resolved' or q.get('mediaRightsStatus')!='verified_pdl1' or not q.get('mediaAttribution'):
            audit['errors'].append(f"{q['id']}: release-eligible media must be resolved, PDL1.0-verified and attributed")
audit['eligibleMediaCount']=len(audit['eligibleMediaQuestions'])
if audit['mediaMissingAssets']:
    audit['errors'].append('runtime media asset missing')
for exam,row in audit['byExam'].items():
    if (row['total'],row['required'],row['general'],row['situation'])!=(240,50,130,60):
        audit['errors'].append(f'exam {exam} composition mismatch {row}')
for exam in (115,114,113):
    expected=240-sum(1 for qid in blocked if qid.startswith(f'K{exam}-'))
    if audit['byExam'][str(exam)]['eligible']!=expected:
        audit['errors'].append(f'exam {exam} eligible count mismatch')
audit['pass']=not audit['errors']
(ROOT/'product-runtime-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if not audit['pass']:
    raise SystemExit(json.dumps(audit,ensure_ascii=False))
print(json.dumps(audit,ensure_ascii=False))
