#!/usr/bin/env python3
import json, re
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

root=Path('touroku-hanbaisha-sprint')
expected={'第1章':20,'第2章':20,'第3章':40,'第4章':20,'第5章':20}

def load_round(n):
    out=[]
    for ch in range(1,6):
        out += json.load(open(root/f'questions/exam-{n}/chapter-{ch}.json',encoding='utf-8'))
    return out

rounds=[load_round(1),load_round(2),load_round(3)]
errors=[]; allq=[]
for rn,qs in enumerate(rounds,1):
    if len(qs)!=120: errors.append(f'R{rn}: {len(qs)}/120')
    counts=Counter(q.get('chapter') for q in qs)
    for ch,n in expected.items():
        if counts[ch]!=n: errors.append(f'R{rn}/{ch}: {counts[ch]}/{n}')
    ids=[]; target_counts=Counter()
    for i,q in enumerate(qs):
        qid=q.get('id') or f'R{rn}-{i+1}'; ids.append(qid)
        if q.get('round')!=rn: errors.append(f'{qid}: round {q.get("round")}/{rn}')
        choices=q.get('choices'); ans=q.get('correct_index')
        if not isinstance(choices,list) or len(choices)!=5 or len(set(choices))!=5: errors.append(f'{qid}: choices')
        if not isinstance(ans,int) or not 0<=ans<5: errors.append(f'{qid}: answer')
        for key in ('subject','topic','question','explanation','source_url','reference_date','origin_type','rights_basis','chapter'):
            if not str(q.get(key,'')).strip(): errors.append(f'{qid}: missing {key}')
        m=re.search(r'(\d+)$',qid); target=(int(m.group(1))-1)%5 if m else i%5
        target_counts[target]+=1
        evidence=f"{q.get('point','')} {q.get('detail','')}" if rn==1 else str(q.get('explanation',''))
        allq.append((f'R{rn}:{qid}',str(q.get('topic','')),str(q.get('question','')),evidence))
    dups=[x for x,c in Counter(ids).items() if c>1]
    if dups: errors.append(f'R{rn}: duplicate ids {dups[:5]}')
    if [target_counts[i] for i in range(5)] != [24]*5: errors.append(f'R{rn}: runtime answer balance {dict(target_counts)}')

def norm(s): return re.sub(r'[\s、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]','',str(s).lower())
seen={}; normalized=[]
for qid,topic,text,evidence in allq:
    q=norm(text)
    if q in seen: errors.append(f'exact duplicate: {seen[q]} <-> {qid}')
    else: seen[q]=qid
    normalized.append((qid,norm(topic),q,norm(evidence)))
for i in range(len(normalized)):
    ida,ta,qa,ea=normalized[i]
    for j in range(i+1,len(normalized)):
        idb,tb,qb,eb=normalized[j]
        qratio=SequenceMatcher(None,qa,qb).ratio() if qa and qb else 0
        if qratio<0.90: continue
        eratio=SequenceMatcher(None,ea,eb).ratio() if ea and eb else 0
        if eratio>=0.72 or (ta and ta==tb): errors.append(f'semantic high similarity q={qratio:.2f} evidence={eratio:.2f}: {ida} <-> {idb}')

result={
    'canonical_questions':sum(map(len,rounds)),
    'round_counts':[len(q) for q in rounds],
    'chapter_distribution':expected,
    'errors':errors,
    'status':'PASS' if not errors else 'FAIL'
}
print(json.dumps(result,ensure_ascii=False,indent=2))
if errors:
    raise SystemExit(1)
