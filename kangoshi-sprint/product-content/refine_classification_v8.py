#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

# Contextual corrections discovered by the independent semantic audit.
# These are based on the actual official question/case content, not on target counts.
OVERRIDES={
 'K115-AM120':('看護の統合と実践','災害看護','同一症例118-120が大地震発災後の避難所対応を扱うため'),
 'K115-PM069':('精神看護学','地域精神看護・ピアサポート','統合失調症当事者のセルフヘルプグループの機能を問うため'),
 'K114-AM106':('小児看護学','小児救急・トリアージ','4歳6か月女児のボタン電池誤飲と待合室の患児優先度を扱うため'),
 'K114-PM087':('健康支援と社会保障制度','障害福祉制度','障害者総合支援法上の制度内容を問うため'),
 'K114-PM107':('小児看護学','小児の排泄・セルフケア','二分脊椎の学童の自己導尿を扱う小児症例のため'),
 'K114-PM108':('小児看護学','小児の発達・セルフケア支援','同じ二分脊椎学童の自己導尿継続支援を扱うため'),
 'K113-AM072':('看護の統合と実践','災害看護','災害時対応を直接問う設問のため'),
 'K113-PM103':('小児看護学','小児の発達・検査支援','7歳男児・自閉スペクトラム症の検査前説明と恐怖軽減を扱うため'),
 'K113-PM104':('小児看護学','小児のセルフケア・家族支援','7歳男児の成長ホルモン自己注射を家庭生活へ組み込む支援を扱うため'),
 'K113-PM105':('小児看護学','小児のセルフケア・家族支援','同一の7歳男児症例で成長ホルモン注射の継続支援を扱うため'),
}

def high(q,m,s,r):
    q.update({'majorSubject':m,'subject':s,'classificationStatus':'high','classificationScore':120,'classificationSignals':['v8-context:'+r],'classificationMethod':'contextual-semantic-v8'})

ids=set()
report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'contextual-semantic-v8'}
counts=Counter()
for sid in ('set1','set2','set3'):
    p=OUT/f'{sid}-classified.json'; d=json.loads(p.read_text(encoding='utf-8'))
    for q in d['questions']:
        ids.add(q['id'])
        if q['id'] in OVERRIDES:
            high(q,*OVERRIDES[q['id']])
        st=q.get('classificationStatus','unclassified'); report['total']+=1; report[st]+=1
        if q.get('majorSubject'): counts[q['majorSubject']]+=1
        if st!='high': report['needsReview'].append({'id':q['id'],'status':st,'question':q.get('question'),'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject')})
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
absent=set(OVERRIDES)-ids
if absent: raise SystemExit(f'v8 override IDs missing: {sorted(absent)}')
report['majorCounts']=dict(sorted(counts.items())); report['contextOverrideIds']=sorted(OVERRIDES)
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print('needsReview='+str(len(report['needsReview'])))
