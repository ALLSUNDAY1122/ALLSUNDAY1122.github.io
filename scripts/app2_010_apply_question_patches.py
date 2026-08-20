#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path('touroku-hanbaisha-sprint/questions')
PATCH_PATH = Path('automation/app2-010-touhan-question-patches.json')

patch_doc = json.loads(PATCH_PATH.read_text(encoding='utf-8'))
patches = patch_doc.get('patches', [])
if not isinstance(patches, list) or not patches:
    raise SystemExit('No patches supplied')

by_id = {}
for p in patches:
    qid = p.get('id')
    if not qid or qid in by_id:
        raise SystemExit(f'Invalid/duplicate patch id: {qid}')
    by_id[qid] = p

seen = set()
changed_files = []
for path in sorted(ROOT.glob('exam-*/chapter-*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    changed = False
    for q in data:
        qid = q.get('id')
        patch = by_id.get(qid)
        if not patch:
            continue
        seen.add(qid)
        for key, value in patch.items():
            if key == 'id':
                continue
            q[key] = value
        q['reference_date'] = patch_doc.get('reference_date', q.get('reference_date'))
        changed = True
    if changed:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        changed_files.append(str(path))

missing = sorted(set(by_id) - seen)
if missing:
    raise SystemExit(f'Patch ids not found: {missing}')

print(json.dumps({'patched': len(seen), 'files': changed_files}, ensure_ascii=False))
