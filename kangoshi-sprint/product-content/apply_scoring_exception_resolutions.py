#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
AUDIT=ROOT/'scoring-runtime-audit.json'
audit=json.loads(AUDIT.read_text(encoding='utf-8'))
if audit.get('pass') is not True or audit.get('exceptionCount') != 8:
    raise SystemExit('scoring runtime audit is not PASS/8')
expected=audit.get('expected') or {}
sets={}; index={}
for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'; d=json.loads(p.read_text(encoding='utf-8')); sets[sid]=(p,d)
    for q in d.get('questions') or []: index[q['id']]=q
resolved=[]
for qid,mode in expected.items():
    q=index.get(qid)
    if not q: raise SystemExit(f'missing scoring exception id {qid}')
    if q.get('officialScoringStatus')=='normal': raise SystemExit(f'{qid}: expected special scoring but raw is normal')
    q['scoringExceptionStatus']='resolved'
    q['scoringRuntimeMode']=mode
    q['scoringRuntimeAudit']='product-content/scoring-runtime-audit.json'
    resolved.append(qid)
for p,d in sets.values(): p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schemaVersion':1,'resolvedCount':len(resolved),'resolvedIds':sorted(resolved),'pass':len(resolved)==8}
(DRAFT/'scoring-exception-resolution-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
