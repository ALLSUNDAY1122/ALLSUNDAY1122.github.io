#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
RES=ROOT/'release-review-resolutions.json'

sets={}; index={}
for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'
    d=json.loads(p.read_text(encoding='utf-8'))
    sets[sid]=(p,d)
    for q in d.get('questions') or []:
        if q['id'] in index: raise SystemExit(f'duplicate id {q["id"]}')
        index[q['id']]=q

doc=json.loads(RES.read_text(encoding='utf-8'))
content=[]; expert=[]
for row in doc.get('contentConcernResolutions') or []:
    qid=row.get('id'); q=index.get(qid)
    if not q: raise SystemExit(f'unknown content resolution {qid}')
    if row.get('status')!='resolved': raise SystemExit(f'{qid}: invalid content status')
    if q.get('contentConcernStatus') in {None,'none'}: raise SystemExit(f'{qid}: no content concern to resolve')
    q['contentConcernStatus']='resolved'
    q['contentConcernResolutionNote']=row.get('note')
    q['contentConcernResolutionEvidenceRefs']=row.get('evidenceRefs') or []
    q['contentConcernResolvedAt']=doc.get('auditedAt')
    content.append(qid)

for row in doc.get('expertReviewResolutions') or []:
    qid=row.get('id'); q=index.get(qid)
    if not q: raise SystemExit(f'unknown expert resolution {qid}')
    # Never override explicit user/domain-expert holds from the situation queue.
    reasons=q.get('specialistQuarantineReasons') or []
    if any(str(r.get('status') or '').startswith('hold_user_review') for r in reasons):
        raise SystemExit(f'{qid}: explicit user/domain expert hold cannot be auto-resolved')
    q['expertReviewStatus']='resolved'
    q['expertReviewResolutionMode']=row.get('status')
    q['expertReviewResolutionNote']=row.get('note')
    q['expertReviewResolutionEvidenceRefs']=row.get('evidenceRefs') or []
    q['expertReviewResolvedAt']=doc.get('auditedAt')
    kept=[r for r in reasons if r.get('kind')!='expertReview']
    q['specialistQuarantineReasons']=kept
    q['specialistQuarantineStatus']='quarantined' if kept else 'clear'
    if q.get('dynamicEvidenceStatus')=='expert_review_required':
        q['dynamicEvidenceStatus']='verified'
    expert.append(qid)

for p,d in sets.values():
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schemaVersion':1,'contentResolvedIds':sorted(content),'expertResolvedIds':sorted(expert),'pass':True}
(DRAFT/'release-review-resolution-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
