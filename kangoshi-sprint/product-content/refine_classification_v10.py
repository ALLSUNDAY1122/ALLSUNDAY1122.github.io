#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent; OUT=ROOT/'classified'
OVERRIDES={
 'K113-PM097':('老年看護学','高齢者の排泄・生活機能','71歳・要介護・老人保健施設入所中の高齢者の排泄機能を扱うため'),
 'K113-PM098':('老年看護学','高齢者の排泄・生活支援','同一の施設入所高齢者の尿失禁と生活支援を扱うため'),
 'K113-PM099':('老年看護学','高齢者の生活・自立支援','同一の施設入所高齢者の生活機能と自立支援を扱うため'),
}
def high(q,m,s,r): q.update({'majorSubject':m,'subject':s,'classificationStatus':'high','classificationScore':160,'classificationSignals':['v10-geriatric:'+r],'classificationMethod':'geriatric-context-v10'})
ids=set(); cnt=Counter(); report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'geriatric-context-v10'}
for sid in ('set1','set2','set3'):
 p=OUT/f'{sid}-classified.json'; d=json.loads(p.read_text(encoding='utf-8'))
 for q in d['questions']:
  ids.add(q['id'])
  if q['id'] in OVERRIDES: high(q,*OVERRIDES[q['id']])
  st=q.get('classificationStatus','unclassified'); report['total']+=1; report[st]+=1
  if q.get('majorSubject'): cnt[q['majorSubject']]+=1
  if st!='high': report['needsReview'].append({'id':q['id'],'status':st})
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
missing=set(OVERRIDES)-ids
if missing: raise SystemExit(f'v10 override IDs missing: {sorted(missing)}')
report['majorCounts']=dict(sorted(cnt.items())); report['geriatricOverrideIds']=sorted(OVERRIDES)
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print('needsReview='+str(len(report['needsReview'])))
