#!/usr/bin/env python3
import json,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
audit_path=OUT/'semantic-consistency-audit.json'
res_path=ROOT/'classification-warning-resolutions.json'
if not audit_path.exists(): raise SystemExit('semantic audit missing')
if not res_path.exists(): raise SystemExit('warning resolution file missing')

audit=json.loads(audit_path.read_text(encoding='utf-8'))
res=json.loads(res_path.read_text(encoding='utf-8'))
warnings=audit.get('warnings',[])
entries=res.get('resolutions',[])
by_warning={x.get('warning'):x for x in entries if x.get('warning')}
errors=[]
for w in warnings:
    row=by_warning.get(w)
    if not row:
        errors.append(f'unresolved warning: {w}'); continue
    if row.get('decision') not in {'accepted','fixed'}:
        errors.append(f'invalid decision for warning: {w}')
    if len(str(row.get('reason') or '').strip())<8:
        errors.append(f'reason missing/too short: {w}')
extra=[w for w in by_warning if w not in warnings]
# Stale resolutions are not a release error; record them so the file can be cleaned.
report={'warningCount':len(warnings),'resolvedCount':sum(1 for w in warnings if w in by_warning),'unresolvedCount':sum(1 for w in warnings if w not in by_warning),'staleResolutionCount':len(extra),'errors':errors,'pass':not errors}
(OUT/'warning-resolution-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
if errors:
    sys.exit(1)
