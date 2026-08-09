#!/usr/bin/env python3
import glob,json
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

applied=[]; errors=[]
for filename in sorted(glob.glob(str(BATCH/'*.json'))):
    batch=json.loads(Path(filename).read_text(encoding='utf-8'))
    for row in batch.get('items',[]):
        qid=row.get('id'); q=index.get(qid)
        if not q:
            errors.append(f'{Path(filename).name}: unknown id {qid}'); continue
        point=str(row.get('point') or '').strip(); detail=str(row.get('detail') or '').strip()
        refs=row.get('explanationEvidenceRefs') or []
        checked=row.get('evidenceCheckedDate')
        if len(point)<8 or len(detail)<20 or not refs or not checked:
            errors.append(f'{Path(filename).name}: incomplete explanation row {qid}'); continue
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
report={'batchFiles':len(glob.glob(str(BATCH/'*.json'))),'appliedCount':len(applied),'appliedIds':applied}
(DRAFT/'batch-apply-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'batchFiles':report['batchFiles'],'appliedCount':report['appliedCount']},ensure_ascii=False))
