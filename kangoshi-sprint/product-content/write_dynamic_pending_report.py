#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DRAFT = ROOT / 'enriched-draft'
rows = []
for sid in ('set1','set2','set3'):
    doc = json.loads((DRAFT / f'{sid}-draft.json').read_text(encoding='utf-8'))
    for q in doc.get('questions') or []:
        if not q.get('dynamicEvidenceRequired'):
            continue
        if q.get('dynamicEvidenceStatus') in {'verified','expert_review_required'}:
            continue
        rows.append({
            'id': q.get('id'), 'sourceExam': q.get('sourceExam'), 'session': q.get('session'),
            'questionNo': q.get('questionNo'), 'category': q.get('category'),
            'majorSubject': q.get('majorSubject'), 'subject': q.get('subject'),
            'question': q.get('question'), 'choices': q.get('choices') or [], 'answer': q.get('answer'),
            'point': q.get('point'), 'detail': q.get('detail'),
            'explanationEvidenceRefs': q.get('explanationEvidenceRefs') or [],
            'evidenceCheckedDate': q.get('evidenceCheckedDate'),
            'dynamicEvidenceStatus': q.get('dynamicEvidenceStatus')
        })
report={'schemaVersion':1,'count':len(rows),'items':rows}
ids_report={'schemaVersion':1,'count':len(rows),'ids':[r['id'] for r in rows]}
(DRAFT/'dynamic-pending.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(DRAFT/'dynamic-pending-ids.json').write_text(json.dumps(ids_report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'dynamicPending':len(rows),'ids':ids_report['ids']},ensure_ascii=False))
