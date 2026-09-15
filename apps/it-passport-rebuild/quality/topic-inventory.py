#!/usr/bin/env python3
"""Fail early on topic reuse before staging the next generated batch."""
from pathlib import Path
import argparse, json, re, unicodedata

ROOT=Path(__file__).resolve().parents[1]
QP=ROOT/'questions'
norm=lambda s: re.sub(r'\s+','',unicodedata.normalize('NFKC',str(s)).lower())

p=argparse.ArgumentParser()
p.add_argument('--candidate', help='candidate batch JSON; when omitted print canonical/staged inventory')
a=p.parse_args()

sources=[QP/'original-mock.json']
# Include staged batches that have not yet merged so the next batch cannot reuse them.
for f in sorted(QP.glob('batch-*.json')):
    if f not in sources: sources.append(f)

inventory={}
for f in sources:
    try: rows=json.loads(f.read_text(encoding='utf-8'))
    except Exception as e: raise SystemExit(f'FAIL {f}: {e}')
    for q in rows:
        t=norm(q.get('topic',''))
        if not t: raise SystemExit(f'FAIL {f}: empty topic in {q.get("id")}')
        inventory.setdefault(t,[]).append((f.name,q.get('id'),q.get('topic')))

if not a.candidate:
    print(f'unique_topics={len(inventory)} source_files={len(sources)}')
    for k in sorted(inventory):
        refs='; '.join(f'{f}:{i}:{t}' for f,i,t in inventory[k])
        print(refs)
    raise SystemExit(0)

cand=Path(a.candidate)
rows=json.loads(cand.read_text(encoding='utf-8'))
seen={}; errors=[]
for q in rows:
    t=norm(q.get('topic',''))
    if t in inventory:
        errors.append(f'{q.get("id")}: topic already exists: {q.get("topic")} -> {inventory[t]}')
    if t in seen:
        errors.append(f'{q.get("id")}: duplicate candidate topic: {q.get("topic")} / {seen[t]}')
    seen[t]=q.get('id')
if errors:
    print('TOPIC INVENTORY GATE: FAIL')
    print('\n'.join('- '+x for x in errors))
    raise SystemExit(1)
print(f'TOPIC INVENTORY GATE: PASS candidate={cand} topics={len(rows)}')
