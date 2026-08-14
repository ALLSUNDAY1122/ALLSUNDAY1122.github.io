#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DRAFT = ROOT / 'enriched-draft'
QUESTIONS = ROOT / 'questions'
RESOLVED = {'pass', 'passed', 'resolved', 'complete', 'completed', 'closed'}
REQUIRED_L3 = ('point', 'detail', 'explanationEvidenceRefs', 'evidenceCheckedDate')


def load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def complete(row):
    return (
        len(str(row.get('point') or '').strip()) >= 8
        and len(str(row.get('detail') or '').strip()) >= 20
        and isinstance(row.get('explanationEvidenceRefs'), list)
        and any(str(x).startswith('https://') for x in row.get('explanationEvidenceRefs') or [])
        and bool(str(row.get('evidenceCheckedDate') or '').strip())
    )


required_report = load(ROOT / 'required-150' / 'canonical-build-report.json')
general_gate = load(QUESTIONS / 'general-canonical-gate.json')
situation_gate = load(QUESTIONS / 'situation-canonical-gate.json')
if str(required_report.get('status')).upper() != 'PASS' or required_report.get('counts', {}).get('requiredTotal') != 150:
    raise SystemExit('required canonical gate is not PASS/150')
if general_gate.get('pass') is not True or general_gate.get('build', {}).get('total') != 390:
    raise SystemExit('general canonical gate is not PASS/390')
if situation_gate.get('pass') is not True or situation_gate.get('build', {}).get('totalQuestions') != 180:
    raise SystemExit('situation canonical gate is not PASS/180')

sets = {}
index = {}
for sid in ('set1', 'set2', 'set3'):
    path = DRAFT / f'{sid}-draft.json'
    doc = load(path)
    sets[sid] = (path, doc)
    for q in doc.get('questions') or []:
        qid = q.get('id')
        if not qid or qid in index:
            raise SystemExit(f'duplicate/missing draft id: {qid}')
        index[qid] = q

canonical = {}
for exam in (115, 114, 113):
    for category in ('required', 'general', 'situation'):
        path = QUESTIONS / f'exam-{exam}' / f'{category}.json'
        doc = load(path)
        for row in doc.get('questions') or []:
            qid = row.get('id')
            if not qid or qid in canonical:
                raise SystemExit(f'duplicate/missing canonical id: {qid}')
            if not complete(row):
                raise SystemExit(f'{qid}: canonical L3 incomplete in {path.name}')
            canonical[qid] = row

if len(canonical) != 720 or set(canonical) != set(index):
    missing = sorted(set(index) - set(canonical))
    extra = sorted(set(canonical) - set(index))
    raise SystemExit(f'canonical coverage mismatch total={len(canonical)} missing={missing[:20]} extra={extra[:20]}')

filled = []
historical_normalized = []
for qid, q in index.items():
    # Historical-statistic rows were previously recorded as verified_historical.
    # The validator's canonical terminal state is simply "verified"; preserve the
    # audit trail while normalizing only this explicit legacy status.
    if q.get('dynamicEvidenceRequired') and str(q.get('dynamicEvidenceStatus') or '').lower() == 'verified_historical':
        refs = q.get('explanationEvidenceRefs') or []
        checked = str(q.get('evidenceCheckedDate') or '').strip()
        if not refs or not all(str(x).startswith('https://') for x in refs) or not checked:
            raise SystemExit(f'{qid}: verified_historical lacks evidence/date')
        q['dynamicEvidenceLegacyStatus'] = 'verified_historical'
        q['dynamicEvidenceStatus'] = 'verified'
        historical_normalized.append(qid)

    if q.get('explanationStatus') == 'ai_explained' and complete(q):
        continue
    source = canonical[qid]
    for field in REQUIRED_L3:
        q[field] = source.get(field)
    q['explanationStatus'] = 'ai_explained'
    q['canonicalL3FallbackSource'] = 'final-category-canonical'
    if q.get('dynamicEvidenceRequired'):
        candidate = str(source.get('dynamicEvidenceStatus') or '').lower()
        if candidate in {'verified', 'expert_review_required'}:
            q['dynamicEvidenceStatus'] = candidate
    filled.append(qid)

queue_path = ROOT / 'situation-audit' / 'expert-review-queue.json'
resolved_expert = []
if queue_path.exists():
    queue = load(queue_path)
    for row in queue.get('items') or []:
        status = str(row.get('status') or '').lower()
        if status not in RESOLVED:
            continue
        qid = row.get('questionId') or row.get('id')
        q = index.get(qid)
        if not q:
            raise SystemExit(f'resolved situation expert id missing from draft: {qid}')
        reasons = [x for x in (q.get('specialistQuarantineReasons') or []) if str(x.get('kind') or '') != 'situationExpertReview']
        q['specialistQuarantineReasons'] = reasons
        q['specialistQuarantineStatus'] = 'quarantined' if reasons else 'clear'
        q['expertReviewStatus'] = 'resolved'
        if q.get('dynamicEvidenceRequired') and q.get('dynamicEvidenceStatus') == 'expert_review_required':
            source_status = str(canonical[qid].get('dynamicEvidenceStatus') or '').lower()
            q['dynamicEvidenceStatus'] = source_status if source_status == 'verified' else 'pending'
        resolved_expert.append(qid)

for path, doc in sets.values():
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

report = {
    'schemaVersion': 2,
    'canonicalCoverage': len(canonical),
    'filledFromCanonicalCount': len(filled),
    'filledFromCanonicalIds': sorted(filled),
    'historicalDynamicStatusNormalizedCount': len(historical_normalized),
    'historicalDynamicStatusNormalizedIds': sorted(historical_normalized),
    'resolvedSituationExpertCount': len(resolved_expert),
    'resolvedSituationExpertIds': sorted(resolved_expert),
    'allCategoryCanonicalGatesPass': True
}
(DRAFT / 'canonical-l3-fallback-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'canonicalCoverage': 720, 'filledFromCanonicalCount': len(filled), 'historicalDynamicStatusNormalizedCount': len(historical_normalized), 'resolvedSituationExpertCount': len(resolved_expert)}, ensure_ascii=False))
