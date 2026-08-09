#!/usr/bin/env python3
import json,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
errors=[]
ids=set()
counts={
    'total':0,
    'explained':0,
    'pending':0,
    'dynamicRequired':0,
    'dynamicVerified':0,
    'dynamicExpertReview':0,
    'dynamicPending':0
}
URL=re.compile(r'^https://',re.I)

for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'
    if not p.exists():
        errors.append(f'{sid}: draft missing')
        continue
    data=json.loads(p.read_text(encoding='utf-8'))
    qs=data.get('questions',[])
    if len(qs)!=240:
        errors.append(f'{sid}: expected 240, got {len(qs)}')
    for q in qs:
        qid=q.get('id','?')
        counts['total']+=1
        if qid in ids:
            errors.append(f'{qid}: duplicate id')
        ids.add(qid)

        answer_refs=q.get('answerEvidenceRefs') or []
        if not answer_refs or not all(URL.match(str(x)) for x in answer_refs):
            errors.append(f'{qid}: official answer evidence missing/invalid')

        status=q.get('explanationStatus')
        if status=='ai_explained':
            counts['explained']+=1
            point=str(q.get('point') or '').strip()
            detail=str(q.get('detail') or '').strip()
            refs=q.get('explanationEvidenceRefs') or []
            date=q.get('evidenceCheckedDate')
            if len(point)<8:
                errors.append(f'{qid}: point too short')
            if len(detail)<20:
                errors.append(f'{qid}: detail too short')
            if not refs or not all(URL.match(str(x)) for x in refs):
                errors.append(f'{qid}: explanation evidence missing/invalid')
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',str(date or '')):
                errors.append(f'{qid}: evidenceCheckedDate invalid')
        else:
            counts['pending']+=1

        if q.get('dynamicEvidenceRequired'):
            counts['dynamicRequired']+=1
            ds=q.get('dynamicEvidenceStatus')
            if ds=='verified':
                counts['dynamicVerified']+=1
            elif ds=='expert_review_required':
                counts['dynamicExpertReview']+=1
            else:
                counts['dynamicPending']+=1

if counts['total']!=720:
    errors.append(f'total expected 720, got {counts["total"]}')
if counts['explained']!=720:
    errors.append(f'explanations incomplete {counts["explained"]}/720')
if counts['dynamicPending']!=0:
    errors.append(
        f'dynamic evidence pending {counts["dynamicPending"]}/'
        f'{counts["dynamicRequired"]} '
        f'(verified={counts["dynamicVerified"]}, expert-review={counts["dynamicExpertReview"]})'
    )

report={
    'counts':counts,
    'errorCount':len(errors),
    'errors':errors,
    'pass':not errors,
    'releaseAllowed':False,
    'note':'L3解説・一次根拠監査。expert_review_requiredは専門監査キューへ明示移管済みとしてL3未処理から除外する。L3 PASS後も専門監査・メディア権利監査前のため製品解放は禁止。'
}
(DRAFT/'enrichment-audit.json').write_text(
    json.dumps(report,ensure_ascii=False,indent=2)+'\n',
    encoding='utf-8'
)
print(json.dumps({'counts':counts,'errorCount':len(errors),'pass':not errors},ensure_ascii=False))
if errors:
    print('\n'.join(errors[:80]))
    if len(errors)>80:
        print(f'... and {len(errors)-80} more')
    sys.exit(1)
