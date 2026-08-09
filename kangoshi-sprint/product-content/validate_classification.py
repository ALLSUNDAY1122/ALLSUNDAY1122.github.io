#!/usr/bin/env python3
import json,sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
MAJORS={
 '人体の構造と機能','疾病の成り立ちと回復の促進','健康支援と社会保障制度','基礎看護学','地域・在宅看護論',
 '成人看護学','老年看護学','小児看護学','母性看護学','精神看護学','看護の統合と実践'
}
errors=[]; counts=Counter(); total=0
for set_id in ('set1','set2','set3'):
    path=OUT/f'{set_id}-classified.json'
    if not path.exists(): errors.append(f'{set_id}: classified file missing'); continue
    data=json.loads(path.read_text(encoding='utf-8'))
    qs=data.get('questions',[])
    if len(qs)!=240: errors.append(f'{set_id}: expected 240, got {len(qs)}')
    for q in qs:
        total+=1; qid=q.get('id','?')
        major=q.get('majorSubject'); subject=q.get('subject'); status=q.get('classificationStatus')
        counts[status]+=1
        if major not in MAJORS: errors.append(f'{qid}: invalid/unclassified majorSubject {major!r}')
        if not subject: errors.append(f'{qid}: subject missing')
        if status!='high': errors.append(f'{qid}: classification confidence {status}')

report={'total':total,'statusCounts':dict(counts),'errors':errors,'pass':not errors}
(OUT/'classification-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'total':total,'statusCounts':dict(counts),'errorCount':len(errors),'pass':not errors},ensure_ascii=False))
if errors:
    print('\n'.join(errors[:120]))
    if len(errors)>120: print(f'... and {len(errors)-120} more')
    sys.exit(1)
