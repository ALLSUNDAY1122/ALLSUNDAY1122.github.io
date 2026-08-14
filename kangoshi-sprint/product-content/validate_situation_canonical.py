#!/usr/bin/env python3
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RAW = ROOT / 'raw'
QROOT = ROOT / 'questions'
EXAMS = {115: 'set1', 114: 'set2', 113: 'set3'}
URL = re.compile(r'^https://', re.I)
DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
errors = []
summary = {}
all_ids = []
all_scenarios = []


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


for exam, set_id in EXAMS.items():
    raw = load(RAW / f'{set_id}-raw.json')
    raw_rows = [q for q in raw.get('questions') or [] if q.get('category') == '状況設定']
    raw_map = {q.get('id'): q for q in raw_rows if q.get('id')}
    can = load(QROOT / f'exam-{exam}' / 'situation.json')
    qs = can.get('questions') or []
    counts = {
        'questions': len(qs),
        'scenarios': 0,
        'normal': 0,
        'quarantined': 0,
        'missingExplanation': 0,
        'missingEvidence': 0,
        'missingDate': 0,
        'rightsMissing': 0,
        'answerMismatch': 0,
        'scoringMismatch': 0,
        'stemChoiceMismatch': 0,
        'scenarioMismatch': 0,
        'scenarioStructureErrors': 0,
    }
    if len(raw_map) != 60:
        errors.append(f'{exam}: raw situation {len(raw_map)}/60')
    if len(qs) != 60:
        errors.append(f'{exam}: canonical situation {len(qs)}/60')

    groups = defaultdict(list)
    for q in qs:
        qid = q.get('id')
        all_ids.append(qid)
        r = raw_map.get(qid)
        if not r:
            errors.append(f'{exam}:{qid}: missing in normalized raw')
            continue
        if q.get('answer') != r.get('answer') or q.get('officialAcceptedAnswers') != r.get('officialAcceptedAnswers'):
            counts['answerMismatch'] += 1
            errors.append(f'{qid}: official answer changed')
        if q.get('officialScoringStatus') != r.get('officialScoringStatus'):
            counts['scoringMismatch'] += 1
            errors.append(f'{qid}: official scoring changed')
        if q.get('question') != r.get('question') or (q.get('choices') or []) != (r.get('choices') or []):
            counts['stemChoiceMismatch'] += 1
            errors.append(f'{qid}: canonical stem/choices diverge from normalized raw')
        for field in ('scenarioId', 'scenarioIndex', 'scenarioTotal', 'scenario'):
            if q.get(field) != r.get(field):
                counts['scenarioMismatch'] += 1
                errors.append(f'{qid}: {field} diverges from normalized raw')
                break

        status = q.get('canonicalReleaseStatus')
        if status == 'normal':
            counts['normal'] += 1
        elif status == 'quarantined':
            counts['quarantined'] += 1
        else:
            errors.append(f'{qid}: canonicalReleaseStatus invalid {status}')

        if len(str(q.get('point') or '').strip()) < 8 or len(str(q.get('detail') or '').strip()) < 20:
            counts['missingExplanation'] += 1
        refs = q.get('explanationEvidenceRefs') or []
        if not refs or not all(URL.match(str(x)) for x in refs):
            counts['missingEvidence'] += 1
        if not DATE.fullmatch(str(q.get('evidenceCheckedDate') or '')):
            counts['missingDate'] += 1
        if not str(q.get('rightsStatus') or '').strip():
            counts['rightsMissing'] += 1

        sid = q.get('scenarioId')
        if sid:
            groups[sid].append(q)

    counts['scenarios'] = len(groups)
    if len(groups) != 20:
        errors.append(f'{exam}: canonical scenarios {len(groups)}/20')
    for sid, group in groups.items():
        all_scenarios.append(sid)
        indexes = sorted(q.get('scenarioIndex') for q in group)
        totals = {q.get('scenarioTotal') for q in group}
        scenarios = {q.get('scenario') for q in group}
        ids = [q.get('id') for q in group]
        if len(group) != 3 or len(set(ids)) != 3 or indexes != [0, 1, 2] or totals != {3} or len(scenarios) != 1:
            counts['scenarioStructureErrors'] += 1
            errors.append(f'{sid}: invalid 3-question scenario structure ids={ids} indexes={indexes} totals={totals} scenarioTexts={len(scenarios)}')

    for key in ('missingExplanation', 'missingEvidence', 'missingDate', 'rightsMissing', 'answerMismatch', 'scoringMismatch', 'stemChoiceMismatch', 'scenarioMismatch', 'scenarioStructureErrors'):
        if counts[key]:
            errors.append(f'{exam}: {key}={counts[key]}')
    summary[str(exam)] = counts

if len(all_ids) != 180:
    errors.append(f'total ids {len(all_ids)}/180')
if len(set(all_ids)) != len(all_ids):
    errors.append('duplicate canonical situation ids')
if len(all_scenarios) != 60:
    errors.append(f'total scenarios {len(all_scenarios)}/60')
if len(set(all_scenarios)) != len(all_scenarios):
    errors.append('duplicate canonical scenario ids across exam/session groups')

report = {
    'schemaVersion': 1,
    'scope': 'situation-180-60scenario-canonical',
    'counts': summary,
    'totalQuestions': len(all_ids),
    'totalScenarios': len(all_scenarios),
    'duplicateQuestionIds': len(all_ids) - len(set(all_ids)),
    'duplicateScenarioIds': len(all_scenarios) - len(set(all_scenarios)),
    'errorCount': len(errors),
    'errors': errors,
    'pass': not errors,
    'releaseAllowed': False,
    'note': 'Canonical content PASS does not release expert/media/scoring/content quarantines. Those release gates remain separate.',
}
(QROOT / 'situation-canonical-integrity-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
