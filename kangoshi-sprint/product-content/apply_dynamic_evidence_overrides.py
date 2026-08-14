#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DRAFT = ROOT / 'enriched-draft'
OVERRIDES = ROOT / 'dynamic-evidence-overrides.json'
ALLOWED = {'verified', 'expert_review_required'}


def load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


doc = load(OVERRIDES)
items = doc.get('items') or []
seen = set()
index = {}
sets = {}
for sid in ('set1', 'set2', 'set3'):
    path = DRAFT / f'{sid}-draft.json'
    data = load(path)
    sets[sid] = (path, data)
    for q in data.get('questions') or []:
        qid = q.get('id')
        if qid in index:
            raise SystemExit(f'duplicate draft id: {qid}')
        index[qid] = q

applied = []
for row in items:
    qid = row.get('id')
    if not qid or qid in seen:
        raise SystemExit(f'duplicate/missing override id: {qid}')
    seen.add(qid)
    q = index.get(qid)
    if not q:
        raise SystemExit(f'override id not found: {qid}')
    if q.get('dynamicEvidenceRequired') is not True:
        raise SystemExit(f'{qid}: override targets non-dynamic question')
    status = str(row.get('status') or '')
    refs = row.get('evidenceRefs') or []
    checked = str(row.get('checkedDate') or '')
    note = str(row.get('note') or '').strip()
    if status not in ALLOWED:
        raise SystemExit(f'{qid}: invalid status {status}')
    if not refs or not all(str(x).startswith('https://') for x in refs):
        raise SystemExit(f'{qid}: invalid evidenceRefs')
    if len(checked) != 10 or checked[4] != '-' or checked[7] != '-':
        raise SystemExit(f'{qid}: invalid checkedDate {checked}')
    if len(note) < 12:
        raise SystemExit(f'{qid}: audit note too short')
    existing = list(q.get('explanationEvidenceRefs') or [])
    for ref in refs:
        if ref not in existing:
            existing.append(ref)
    q['explanationEvidenceRefs'] = existing
    q['dynamicEvidenceStatus'] = status
    q['dynamicEvidenceAuditStatus'] = status
    q['dynamicEvidenceAuditRefs'] = refs
    q['dynamicEvidenceAuditCheckedDate'] = checked
    q['dynamicEvidenceAuditNote'] = note
    # Keep the question-level evidence date at the newest completed audit date.
    if str(q.get('evidenceCheckedDate') or '') < checked:
        q['evidenceCheckedDate'] = checked
    applied.append(qid)

for path, data in sets.values():
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

report = {
    'schemaVersion': 1,
    'overrideCount': len(items),
    'appliedCount': len(applied),
    'appliedIds': sorted(applied),
    'verifiedCount': sum(1 for r in items if r.get('status') == 'verified'),
    'expertReviewRequiredCount': sum(1 for r in items if r.get('status') == 'expert_review_required'),
    'pass': len(applied) == len(items)
}
(DRAFT / 'dynamic-evidence-override-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
