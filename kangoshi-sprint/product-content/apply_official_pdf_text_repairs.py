#!/usr/bin/env python3
"""Apply verified official-PDF glyph repairs and the release quarantine to enriched drafts.

Idempotent. Each edit records the exact draft text it replaces; if the current text is
neither the recorded `before` nor `after`, the run fails instead of guessing.
Questions listed in release-quarantine-*.json are marked releaseQuarantineStatus=quarantined
and are excluded from the web runtime and the native iOS bundle.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DRAFT = ROOT / 'enriched-draft'
REPAIRS = ROOT / 'official-pdf-text-repairs-20261125.json'
QUARANTINE = ROOT / 'release-quarantine-20261125.json'
# Residual extraction artefacts that must not appear in any release-eligible text.
BAD = re.compile('[\x00-\x08\x0b-\x1f\ufffd\x80-\x9f¹¼ôâçÉ]')

repairs = json.loads(REPAIRS.read_text(encoding='utf-8'))
quarantine = json.loads(QUARANTINE.read_text(encoding='utf-8'))
qids = {x['id']: x['reasons'] for x in quarantine['items']}
by_id = {e['id']: e for e in repairs['questions']}
errors = []; applied = 0; already = 0; seen = set()

def get(q, field):
    if field.startswith('choices['):
        return q['choices'][int(field[8:-1])]
    return q.get(field)

def put(q, field, value):
    if field.startswith('choices['):
        q['choices'][int(field[8:-1])] = value
    else:
        q[field] = value

for sid in ('set1', 'set2', 'set3'):
    path = DRAFT / f'{sid}-draft.json'
    doc = json.loads(path.read_text(encoding='utf-8'))
    for q in doc['questions']:
        e = by_id.get(q['id'])
        if e:
            seen.add(q['id'])
            for ed in e['edits']:
                cur = get(q, ed['field'])
                if cur == ed['before']:
                    put(q, ed['field'], ed['after']); applied += 1
                elif cur == ed['after']:
                    already += 1
                else:
                    errors.append(f"{q['id']} {ed['field']}: draft text drifted from recorded before/after")
            q['officialPdfTextRepairStatus'] = 'glyph_repair_verified_20261125'
            q['officialPdfTextRepairRef'] = 'product-content/official-pdf-text-repairs-20261125.json'
        if q['id'] in qids:
            q['releaseQuarantineStatus'] = 'quarantined'
            q['releaseQuarantineReasons'] = qids[q['id']]
        else:
            q.pop('releaseQuarantineStatus', None); q.pop('releaseQuarantineReasons', None)
            texts = [q.get('question') or '', q.get('scenario') or ''] + list(q.get('choices') or [])
            if any(BAD.search(t) for t in texts):
                errors.append(f"{q['id']}: residual PDF extraction artefact in release-eligible text")
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

missing = sorted(set(by_id) - seen)
if missing: errors.append(f'repair ids not found in drafts: {missing[:5]}')
report = {'applied': applied, 'alreadyApplied': already, 'repairQuestions': len(by_id),
          'quarantined': len(qids), 'releaseEligible': 720 - len(qids), 'errors': errors}
print(json.dumps(report, ensure_ascii=False))
if errors:
    sys.exit(1)
