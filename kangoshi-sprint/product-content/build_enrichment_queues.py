#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
queues={'textPending':[],'mediaPending':[],'dynamicPending':[],'explained':[]}
for sid in ('set1','set2','set3'):
    data=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    for q in data.get('questions',[]):
        row={
            'id':q['id'],'setId':sid,'sourceExam':q.get('sourceExam'),'session':q.get('session'),
            'questionNo':q.get('questionNo'),'category':q.get('category'),'majorSubject':q.get('majorSubject'),
            'subject':q.get('subject'),'question':q.get('question'),'answerType':q.get('answerType'),
            'answer':q.get('answer'),'choices':q.get('choices') or [],'requiresMedia':bool(q.get('requiresMedia'))
        }
        if q.get('explanationStatus')=='ai_explained': queues['explained'].append(q['id'])
        elif q.get('requiresMedia'): queues['mediaPending'].append(row)
        else: queues['textPending'].append(row)
        if q.get('dynamicEvidenceRequired') and q.get('dynamicEvidenceStatus')!='verified':
            queues['dynamicPending'].append(row)
summary={k:len(v) for k,v in queues.items()}
(DRAFT/'pending-queues.json').write_text(json.dumps({'summary':summary,**queues},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
