#!/usr/bin/env python3
import json,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
res_path=ROOT/'classification-warning-resolutions.json'
if not res_path.exists(): raise SystemExit('warning resolution file missing')

warnings=[]
for name in ('semantic-consistency-audit.json','situation-semantic-audit.json'):
    p=OUT/name
    if not p.exists(): raise SystemExit(f'audit missing: {name}')
    data=json.loads(p.read_text(encoding='utf-8'))
    warnings.extend(data.get('warnings',[]))

res=json.loads(res_path.read_text(encoding='utf-8'))
rules=res.get('resolutions',[])
errors=[]; resolved=[]
for w in warnings:
    matches=[]
    for row in rules:
        pattern=row.get('matchRegex')
        if pattern and re.fullmatch(pattern,w): matches.append(row)
    if len(matches)!=1:
        errors.append(f'warning resolution match count {len(matches)}: {w}')
        continue
    row=matches[0]
    if row.get('decision') not in {'accepted','fixed'}:
        errors.append(f'invalid decision: {w}'); continue
    reason=str(row.get('reason') or '').strip()
    if len(reason)<12:
        errors.append(f'reason missing/too short: {w}'); continue
    resolved.append({'warning':w,'ruleId':row.get('id'),'decision':row.get('decision'),'reason':reason})

report={
    'warningCount':len(warnings),
    'resolvedCount':len(resolved),
    'unresolvedCount':len(warnings)-len(resolved),
    'errors':errors,
    'resolvedWarnings':resolved,
    'pass':not errors and len(resolved)==len(warnings),
    'note':'各警告は対象IDを制限した正規表現ルール1件だけに一致する必要がある。未知の警告・未知IDは自動FAIL。'
}
(OUT/'warning-resolution-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'warningCount':len(warnings),'resolvedCount':len(resolved),'errorCount':len(errors),'pass':report['pass']},ensure_ascii=False))
if not report['pass']: sys.exit(1)
