#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
CLASSIFIED=ROOT/'classified'
DRAFT=ROOT/'enriched-draft'
DRAFT.mkdir(exist_ok=True)

DYNAMIC_PATTERNS=[
    r'法律',r'法に基づ',r'制度',r'保険',r'給付',r'届出',r'人口動態',r'患者調査',r'国民.*調査',r'食事摂取基準',
    r'平均寿命',r'健康寿命',r'死亡率',r'出生率',r'受療率',r'有訴者率',r'最新',r'令和\s*\d+年',r'20\d{2}年'
]
DYNAMIC=re.compile('|'.join(DYNAMIC_PATTERNS),re.I)

summary=[]
for sid in ('set1','set2','set3'):
    src=CLASSIFIED/f'{sid}-classified.json'
    data=json.loads(src.read_text(encoding='utf-8'))
    dynamic_count=0
    for q in data.get('questions',[]):
        text=' '.join([str(q.get('question') or ''),str(q.get('scenario') or ''),' '.join(q.get('choices') or [])])
        dynamic=bool(DYNAMIC.search(text))
        if dynamic: dynamic_count+=1
        q['point']=None
        q['detail']=None
        q['explanationStatus']='pending'
        q['answerEvidenceRefs']=list(dict.fromkeys(q.get('sourceRefs') or []))
        q['explanationEvidenceRefs']=[]
        q['evidenceCheckedDate']=None
        q['dynamicEvidenceRequired']=dynamic
        q['dynamicEvidenceStatus']='pending' if dynamic else 'not_required'
        q['expertReviewStatus']='pending'
        q['releaseEligible']=False
    out={
        'schemaVersion':1,
        'setId':sid,
        'sourceExam':data.get('sourceExam'),
        'questionCount':len(data.get('questions',[])),
        'releaseStatus':'draft_enrichment_only',
        'questions':data.get('questions',[])
    }
    (DRAFT/f'{sid}-draft.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary.append({'set':sid,'count':out['questionCount'],'dynamicEvidenceRequired':dynamic_count})
(DRAFT/'draft-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
