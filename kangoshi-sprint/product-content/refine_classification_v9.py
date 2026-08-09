#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

OVERRIDES={
 # 第115回 AM106-108: 1歳9か月、脳性麻痺。摂食・生活・家族支援を含む小児症例。
 'K115-AM107':('小児看護学','小児の生活・発達支援','1歳9か月の脳性麻痺児の生活援助を扱うため'),
 'K115-AM108':('小児看護学','小児の家族支援','同一の脳性麻痺児症例で家族を含む継続支援を扱うため'),
 # 第115回 PM100-102: 68歳、慢性硬膜下血腫術後。半側空間無視・リハビリ・転倒予防。
 'K115-PM100':('成人看護学','脳神経看護','慢性硬膜下血腫術後の神経症状評価を扱うため'),
 'K115-PM101':('成人看護学','脳神経・リハビリテーション看護','術後麻痺とリハビリ継続への看護支援を扱うため'),
 'K115-PM102':('成人看護学','脳神経・退院支援','慢性硬膜下血腫術後の転倒再発予防と生活支援を扱うため'),
 # 第115回 PM103-105: 102歳、介護老人福祉施設、老衰・看取り。
 'K115-PM103':('老年看護学','高齢者の終末期看護','102歳の施設入所者が自らの死・看取りについて意思を示す症例のため'),
 'K115-PM104':('老年看護学','高齢者の終末期看護','老衰が進行する超高齢者の看取り期ケアを扱うため'),
 'K115-PM105':('老年看護学','高齢者の終末期・家族支援','同一の102歳看取り症例で終末期・家族支援を扱うため'),
 # 第113回 AM100-102: 70歳、変形性股関節症、性生活・転倒予防を含む老年期の生活支援。
 'K113-AM100':('老年看護学','高齢者の運動機能・生活支援','70歳の変形性股関節症患者の日常生活と症状悪化予防を扱うため'),
 'K113-AM101':('老年看護学','高齢者のセクシュアリティ','高齢者の股関節症と性生活に関する相談支援を扱うため'),
 'K113-AM102':('老年看護学','高齢者の転倒予防','高齢者の歩行・排泄場面での転倒予防援助を扱うため'),
}

def set_high(q,major,subject,reason):
    q.update({
        'majorSubject':major,'subject':subject,'classificationStatus':'high','classificationScore':150,
        'classificationSignals':['v9-situation:'+reason],'classificationMethod':'situation-context-v9'
    })

ids=set(); counts=Counter()
report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'situation-context-v9'}
for sid in ('set1','set2','set3'):
    p=OUT/f'{sid}-classified.json'; d=json.loads(p.read_text(encoding='utf-8'))
    for q in d['questions']:
        ids.add(q['id'])
        if q['id'] in OVERRIDES: set_high(q,*OVERRIDES[q['id']])
        st=q.get('classificationStatus','unclassified'); report['total']+=1; report[st]+=1
        if q.get('majorSubject'): counts[q['majorSubject']]+=1
        if st!='high': report['needsReview'].append({'id':q['id'],'status':st,'question':q.get('question')})
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
missing=set(OVERRIDES)-ids
if missing: raise SystemExit(f'v9 override IDs missing: {sorted(missing)}')
report['majorCounts']=dict(sorted(counts.items())); report['situationOverrideIds']=sorted(OVERRIDES)
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print('needsReview='+str(len(report['needsReview'])))
