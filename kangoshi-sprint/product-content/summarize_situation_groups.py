#!/usr/bin/env python3
import json,re
from collections import Counter,defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
groups=defaultdict(list)

def compact(v): return re.sub(r'\s+',' ',str(v or '')).strip()

for sid in ('set1','set2','set3'):
    data=json.loads((OUT/f'{sid}-classified.json').read_text(encoding='utf-8'))
    for q in data['questions']:
        if q.get('category')!='状況設定': continue
        groups[q['scenarioId']].append(q)

rows=[]
for scenario_id,qs in sorted(groups.items()):
    qs=sorted(qs,key=lambda q:q['questionNo'])
    majors=Counter(q['majorSubject'] for q in qs)
    rows.append({
        'scenarioId':scenario_id,
        'sourceExam':qs[0]['sourceExam'],
        'session':qs[0]['session'],
        'scenario':compact(qs[0].get('scenario'))[:420],
        'majorPattern':dict(majors),
        'questions':[
            {'id':q['id'],'stem':compact(q['question'])[:220],'major':q['majorSubject'],'subject':q['subject'],'method':q.get('classificationMethod')}
            for q in qs
        ]
    })
report={'groupCount':len(rows),'questionCount':sum(len(x['questions']) for x in rows),'groups':rows}
(OUT/'situation-group-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'groupCount':report['groupCount'],'questionCount':report['questionCount']},ensure_ascii=False))
