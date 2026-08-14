#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
source=json.loads((DRAFT/'pending-queues.json').read_text(encoding='utf-8'))
keys=('mediaPending','contentConcerns','scoringExceptionPending','expertReviewPending','releaseQuarantined')
out={'schemaVersion':1,'summary':source.get('summary') or {}}
for key in keys:
    out[key]=sorted({row.get('id') for row in source.get(key,[]) if row.get('id')})
(DRAFT/'release-queue-ids.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:len(out[k]) for k in keys},ensure_ascii=False))
