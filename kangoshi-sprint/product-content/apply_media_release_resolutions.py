#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
FILES=[ROOT/'media-release-resolutions.generated.json',ROOT/'media-redraw-resolutions.json']
sets={}; index={}
for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'; d=json.loads(p.read_text(encoding='utf-8'));sets[sid]=(p,d)
    for q in d.get('questions') or []: index[q['id']]=q

rows={}
for path in FILES:
    if not path.exists():continue
    doc=json.loads(path.read_text(encoding='utf-8'))
    for row in doc.get('items') or []:
        qid=row.get('id')
        if not qid or qid in rows: raise SystemExit(f'duplicate/missing media resolution id: {qid}')
        rows[qid]=row

applied=[]
for qid,row in rows.items():
    q=index.get(qid)
    if not q: raise SystemExit(f'unknown media resolution id: {qid}')
    if row.get('mediaReleaseStatus')!='resolved':raise SystemExit(f'{qid}: mediaReleaseStatus must be resolved')
    assets=row.get('mediaAssets') or []
    if not assets:raise SystemExit(f'{qid}: no mediaAssets')
    for rel in assets:
        p=ROOT.parent/rel
        if not p.exists():raise SystemExit(f'{qid}: missing asset {rel}')
    q['mediaReleaseStatus']='resolved'
    q['mediaRightsStatus']=row.get('mediaRightsStatus')
    q['mediaAssets']=assets
    q['mediaAttribution']=row.get('mediaAttribution')
    q['mediaSourceUrl']=row.get('mediaSourceUrl')
    q['mediaProcessed']=bool(row.get('mediaProcessed'))
    q['mediaResolutionMethod']=row.get('mediaResolutionMethod') or ('official_pdl1_excerpt' if row.get('mediaRightsStatus')=='verified_pdl1' else 'original_redraw')
    reasons=[r for r in (q.get('specialistQuarantineReasons') or []) if r.get('kind')!='mediaDependent']
    q['specialistQuarantineReasons']=reasons
    q['specialistQuarantineStatus']='quarantined' if reasons else 'clear'
    applied.append(qid)

for p,d in sets.values():p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schemaVersion':1,'resolutionCount':len(rows),'appliedCount':len(applied),'appliedIds':sorted(applied),'pass':len(rows)==len(applied)}
(DRAFT/'media-release-resolution-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
