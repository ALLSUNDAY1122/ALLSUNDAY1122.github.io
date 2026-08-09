#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

# Final cases left after six semantic passes. Each override is tied to the
# actual question ID and records why the subject is unambiguous. If source
# text changes, the raw-import loop regenerates IDs/content and this stage must
# be reviewed again rather than silently guessing.
OVERRIDES={
 'K115-PM081':('健康支援と社会保障制度','障害福祉制度','障害者総合支援法の地域移行支援を問う制度問題'),
 'K114-AM081':('疾病の成り立ちと回復の促進','神経症候','発音運動の障害＝構音障害という神経症候の識別問題'),
 'K114-PM001':('健康支援と社会保障制度','人口・保健統計','人口動態統計の悪性新生物死亡統計を問う問題'),
 'K114-PM081':('人体の構造と機能','神経・反射','腰髄分節と対応する反射・神経機能を問う解剖生理問題'),
 'K114-PM106':('小児看護学','成長発達・セルフケア支援','二分脊椎の学童が自己導尿を獲得する発達段階に応じた支援'),
 'K113-AM003':('疾病の成り立ちと回復の促進','感染・食中毒','化膿創を汚染源とする食中毒原因菌を問う感染症問題'),
 'K113-AM008':('成人看護学','成人期の発達・健康','壮年期男性の加齢に伴う身体変化を問う成人期問題'),
 'K113-AM009':('健康支援と社会保障制度','家族・社会構造','核家族という家族構成・社会構造の定義問題'),
 'K113-PM062':('精神看護学','ストレス・職業性メンタルヘルス','援助職の燃え尽き症候群を問う精神保健問題'),
}

def set_high(q,major,subject,reason):
    q['majorSubject']=major
    q['subject']=subject
    q['classificationStatus']='high'
    q['classificationScore']=100
    q['classificationSignals']=[f'v7-final:{reason}']
    q['classificationMethod']='explicit-final-review-v7'

seen=set()
report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'explicit-final-review-v7'}
counts=Counter()
for sid in ('set1','set2','set3'):
    path=OUT/f'{sid}-classified.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    for q in data['questions']:
        if q['id'] in OVERRIDES and q.get('classificationStatus')!='high':
            set_high(q,*OVERRIDES[q['id']]); seen.add(q['id'])
        status=q.get('classificationStatus','unclassified')
        report['total']+=1; report[status]+=1
        if q.get('majorSubject'): counts[q['majorSubject']]+=1
        if status!='high':
            report['needsReview'].append({'id':q['id'],'status':status,'question':q.get('question'),'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject')})
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

missing=set(OVERRIDES)-seen
# Overrides that were already classified high by an earlier stage are not an error;
# however all nine IDs must exist in the data.
all_ids=set()
for sid in ('set1','set2','set3'):
    data=json.loads((OUT/f'{sid}-classified.json').read_text(encoding='utf-8'))
    all_ids.update(q['id'] for q in data['questions'])
absent=set(OVERRIDES)-all_ids
if absent:
    raise SystemExit(f'final override IDs missing from source data: {sorted(absent)}')

report['majorCounts']=dict(sorted(counts.items()))
report['finalOverrideIds']=sorted(OVERRIDES)
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False))
print('needsReview='+str(len(report['needsReview'])))
