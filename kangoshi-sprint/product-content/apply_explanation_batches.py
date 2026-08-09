#!/usr/bin/env python3
import glob,json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
BATCH=ROOT/'explanation-batches'
BATCH.mkdir(exist_ok=True)

sets={}
index={}
for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'
    data=json.loads(p.read_text(encoding='utf-8'))
    sets[sid]=(p,data)
    for q in data.get('questions',[]):
        if q['id'] in index: raise SystemExit(f'duplicate draft id: {q["id"]}')
        index[q['id']]=q

files=sorted(glob.glob(str(BATCH/'*.json')))
applied=[]; errors=[]; seen_qids={}; seen_batch_ids={}
for filename in files:
    name=Path(filename).name
    batch=json.loads(Path(filename).read_text(encoding='utf-8'))
    batch_id=str(batch.get('batchId') or '').strip()
    if not batch_id:
        errors.append(f'{name}: batchId missing')
    elif batch_id in seen_batch_ids:
        errors.append(f'{name}: duplicate batchId {batch_id} also in {seen_batch_ids[batch_id]}')
    else:
        seen_batch_ids[batch_id]=name
    items=batch.get('items')
    if not isinstance(items,list) or not items:
        errors.append(f'{name}: items missing/empty')
        continue
    for row in items:
        qid=row.get('id'); q=index.get(qid)
        if qid in seen_qids:
            errors.append(f'{name}: duplicate question id {qid} also in {seen_qids[qid]}')
            continue
        seen_qids[qid]=name
        if not q:
            errors.append(f'{name}: unknown id {qid}'); continue
        point=str(row.get('point') or '').strip(); detail=str(row.get('detail') or '').strip()
        refs=row.get('explanationEvidenceRefs') or []
        checked=str(row.get('evidenceCheckedDate') or '').strip()
        if len(point)<8 or len(detail)<20 or not refs or not checked:
            errors.append(f'{name}: incomplete explanation row {qid}'); continue
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',checked):
            errors.append(f'{name}: invalid evidenceCheckedDate {qid}: {checked}'); continue
        if not all(str(ref).startswith('https://') for ref in refs):
            errors.append(f'{name}: non-https explanation evidence {qid}'); continue
        q['point']=point; q['detail']=detail
        q['explanationEvidenceRefs']=refs
        q['evidenceCheckedDate']=checked
        q['explanationStatus']='ai_explained'
        if q.get('dynamicEvidenceRequired'):
            q['dynamicEvidenceStatus']=row.get('dynamicEvidenceStatus','pending')
        applied.append(qid)

if errors:
    print('\n'.join(errors)); raise SystemExit(1)
for p,data in sets.values(): p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={
    'batchFiles':len(files),'batchIds':sorted(seen_batch_ids),
    'appliedCount':len(applied),'uniqueAppliedCount':len(set(applied)),
    'duplicateQuestionIds':0,'duplicateBatchIds':0,'appliedIds':applied
}
(DRAFT/'batch-apply-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'batchFiles':report['batchFiles'],'appliedCount':report['appliedCount'],'uniqueAppliedCount':report['uniqueAppliedCount']},ensure_ascii=False))
