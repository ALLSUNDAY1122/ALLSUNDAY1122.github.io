#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
CORR=ROOT/'situation-audit'/'classification-corrections.json'

if not CORR.exists():
    print('{"corrections":0,"applied":0}')
    raise SystemExit(0)

doc=json.loads(CORR.read_text(encoding='utf-8'))
rows=doc.get('corrections') or []
by_id={}
for row in rows:
    qid=row.get('id')
    if not qid:
        raise SystemExit('situation classification correction without id')
    if qid in by_id:
        raise SystemExit(f'duplicate situation classification correction: {qid}')
    to=row.get('to') or {}
    if not to.get('majorSubject') or not to.get('subject'):
        raise SystemExit(f'{qid}: target majorSubject/subject missing')
    by_id[qid]=row

seen=set(); applied=[]
for sid in ('set1','set2','set3'):
    path=OUT/f'{sid}-classified.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    for q in data.get('questions',[]):
        qid=q.get('id')
        row=by_id.get(qid)
        if not row:
            continue
        seen.add(qid)
        if q.get('category')!='状況設定':
            raise SystemExit(f'{qid}: correction out of situation scope')
        expected=row.get('from') or {}
        # The exact old classification may evolve when an upstream refinement improves.
        # Refuse only if the correction points to a different question/category; record
        # the observed prior values for audit instead of requiring stale from-values.
        observed={
            'majorSubject':q.get('majorSubject'),
            'subject':q.get('subject'),
            'classificationMethod':q.get('classificationMethod')
        }
        target=row['to']
        q['majorSubject']=target['majorSubject']
        q['subject']=target['subject']
        q['classificationStatus']='high'
        q['classificationScore']=max(int(q.get('classificationScore') or 0),180)
        q['classificationMethod']=target.get('classificationMethod') or 'situation-context-specialist-correction-v1'
        sig=list(q.get('classificationSignals') or [])
        marker=f"situation-specialist:{row.get('scenarioId')}:{row.get('reason','')}"
        if marker not in sig:
            sig.append(marker)
        q['classificationSignals']=sig
        q['classificationSpecialistCorrection']={
            'scenarioId':row.get('scenarioId'),
            'observedBeforeApply':observed,
            'declaredFrom':expected,
            'target':target,
            'reason':row.get('reason'),
            'detectedAt':row.get('detectedAt'),
            'appliedBy':'apply_situation_classification_corrections.py'
        }
        applied.append(qid)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

missing=sorted(set(by_id)-seen)
if missing:
    raise SystemExit(f'situation correction IDs missing from classified data: {missing}')
if len(applied)!=len(by_id):
    raise SystemExit(f'correction application count mismatch {len(applied)}/{len(by_id)}')

report={
    'schemaVersion':1,
    'correctionCount':len(by_id),
    'appliedCount':len(applied),
    'appliedIds':sorted(applied),
    'source':'situation-audit/classification-corrections.json'
}
(OUT/'situation-classification-correction-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
