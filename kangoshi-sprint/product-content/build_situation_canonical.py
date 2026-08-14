#!/usr/bin/env python3
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DRAFT = ROOT / 'enriched-draft'
OUT = ROOT / 'questions'
SUMMARY = ROOT / 'classified' / 'situation-group-summary.json'
BATCH_DIR = ROOT / 'explanation-batches'
EXPERT_QUEUE = ROOT / 'situation-audit' / 'expert-review-queue.json'
MEDIA_AUDIT = ROOT / 'situation-audit' / 'media-audit.json'

EXAMS = {115: 'set1', 114: 'set2', 113: 'set3'}
REQUIRED_L3 = ('point', 'detail', 'explanationEvidenceRefs', 'evidenceCheckedDate')


def load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def complete_item(item):
    return (
        bool(str(item.get('point') or '').strip())
        and bool(str(item.get('detail') or '').strip())
        and isinstance(item.get('explanationEvidenceRefs'), list)
        and any(str(x).strip() for x in item.get('explanationEvidenceRefs') or [])
        and bool(str(item.get('evidenceCheckedDate') or '').strip())
    )


def pending_expert_ids():
    if not EXPERT_QUEUE.exists():
        return set()
    doc = load(EXPERT_QUEUE)
    rows = doc.get('items') if isinstance(doc, dict) else doc
    result = set()
    for row in rows or []:
        status = str(row.get('status') or '').lower()
        if status not in {'pass', 'passed', 'resolved', 'complete', 'completed', 'closed'}:
            qid = row.get('questionId') or row.get('question_id')
            if qid:
                result.add(qid)
    return result


def verified_media_overrides():
    if not MEDIA_AUDIT.exists():
        return {}
    doc = load(MEDIA_AUDIT)
    items = doc.get('items') if isinstance(doc, dict) else None
    if not isinstance(items, dict):
        raise SystemExit('situation media-audit.json must contain an items object')
    result = {}
    for qid, row in items.items():
        if str(row.get('mediaAuditStatus') or '').lower() != 'verified':
            continue
        if not str(row.get('rightsStatus') or '').strip():
            raise SystemExit(f'{qid}: verified media audit missing rightsStatus')
        if not str(row.get('checkedDate') or '').strip():
            raise SystemExit(f'{qid}: verified media audit missing checkedDate')
        result[qid] = row
    return result


summary_doc = load(SUMMARY)
expected_by_sid = {}
qid_to_sid = {}
for group in summary_doc.get('groups') or []:
    sid = group.get('scenarioId')
    qids = [q.get('id') for q in group.get('questions') or [] if q.get('id')]
    if not sid:
        continue
    if len(qids) != 3 or len(set(qids)) != 3:
        raise SystemExit(f'{sid}: expected exactly 3 unique question ids, got {qids}')
    expected_by_sid[sid] = qids
    for qid in qids:
        if qid in qid_to_sid:
            raise SystemExit(f'duplicate situation question id in summary: {qid}')
        qid_to_sid[qid] = sid

if len(expected_by_sid) != 60 or len(qid_to_sid) != 180:
    raise SystemExit(f'situation summary expected 60/180, got {len(expected_by_sid)}/{len(qid_to_sid)}')

# Gather only scenario-declared explanation batches. Generic required/general batches
# are ignored so this lane cannot overwrite the other specialist workstreams.
versions = defaultdict(list)
for path in sorted(BATCH_DIR.glob('*.json')):
    try:
        batch = load(path)
    except Exception as exc:
        raise SystemExit(f'{path.name}: invalid JSON: {exc}')
    sid = batch.get('scenarioId') if isinstance(batch, dict) else None
    if sid not in expected_by_sid:
        continue
    for item in batch.get('items') or []:
        qid = item.get('id')
        if qid in qid_to_sid:
            versions[qid].append((path.name, item))

canonical_l3 = {}
for qid, sid in sorted(qid_to_sid.items()):
    candidates = versions.get(qid) or []
    if not candidates:
        raise SystemExit(f'{qid}: no situation explanation batch')
    complete = [(name, item) for name, item in candidates if complete_item(item)]
    if not complete:
        raise SystemExit(f'{qid}: no complete situation L3 item')
    fingerprints = defaultdict(list)
    for name, item in complete:
        fp = json.dumps({k: item.get(k) for k in REQUIRED_L3}, ensure_ascii=False, sort_keys=True)
        fingerprints[fp].append(name)
    if len(fingerprints) > 1:
        raise SystemExit(f'{qid}: conflicting complete situation L3 versions: {sorted(name for name, _ in complete)}')
    canonical_l3[qid] = complete[-1][1]

expert_pending = pending_expert_ids()
media_overrides = verified_media_overrides()
unknown_media_ids = sorted(set(media_overrides) - set(qid_to_sid))
if unknown_media_ids:
    raise SystemExit(f'media audit contains non-situation ids: {unknown_media_ids}')

all_questions = []
by_exam = {}
for exam, set_id in EXAMS.items():
    draft = load(DRAFT / f'{set_id}-draft.json')
    rows = [q for q in draft.get('questions') or [] if q.get('category') == '状況設定']
    if len(rows) != 60:
        raise SystemExit(f'{exam}: expected 60 situation questions in draft, got {len(rows)}')
    seen = set()
    canonical = []
    scenario_groups = defaultdict(list)
    for original in rows:
        q = dict(original)
        qid = q.get('id')
        if not qid or qid in seen:
            raise SystemExit(f'{exam}: duplicate/missing situation id {qid}')
        seen.add(qid)
        sid = q.get('scenarioId')
        if qid_to_sid.get(qid) != sid:
            raise SystemExit(f'{qid}: scenarioId mismatch draft={sid} summary={qid_to_sid.get(qid)}')
        l3 = canonical_l3[qid]
        for field in REQUIRED_L3:
            q[field] = l3.get(field)

        # Media audit is situation-lane canonical state. It may clear a conservative
        # text-only false positive or validate the exact official figure/page used.
        media = media_overrides.get(qid)
        if media:
            q['requiresMedia'] = bool(media.get('requiresMedia'))
            q['mediaAuditStatus'] = 'verified'
            q['mediaAuditResult'] = media.get('mediaAuditResult')
            q['rightsStatus'] = media.get('rightsStatus')
            q['mediaDetectionReason'] = (
                'false_positive_verified_text_only'
                if not q['requiresMedia']
                else 'official_media_verified'
            )
            q['canonicalMediaAudit'] = {
                k: v for k, v in media.items()
                if k not in {'requiresMedia', 'mediaAuditStatus', 'rightsStatus'}
            }

        quarantine = []
        if qid in expert_pending:
            quarantine.append('expertReview')
        if q.get('requiresMedia') and str(q.get('mediaAuditStatus') or '').lower() not in {'pass', 'passed', 'verified', 'complete', 'completed'}:
            quarantine.append('media')
        if q.get('officialScoringStatus') not in (None, 'normal') or q.get('scoringException'):
            quarantine.append('scoring')
        concern = str(q.get('contentConcernStatus') or 'none').lower()
        if concern not in {'none', 'pass', 'passed', 'resolved', 'complete', 'completed'}:
            quarantine.append('contentConcern')

        q['canonicalSchemaVersion'] = 1
        q['canonicalCategory'] = '状況設定'
        q['canonicalSourceExam'] = exam
        q['canonicalReleaseStatus'] = 'quarantined' if quarantine else 'normal'
        q['canonicalQuarantineTypes'] = list(dict.fromkeys(quarantine))
        q['canonicalScenarioAuditUnit'] = '3-question-scenario'
        canonical.append(q)
        scenario_groups[sid].append(q)

    if len(scenario_groups) != 20:
        raise SystemExit(f'{exam}: expected 20 scenarios, got {len(scenario_groups)}')
    for sid, group in scenario_groups.items():
        indexes = sorted(q.get('scenarioIndex') for q in group)
        totals = {q.get('scenarioTotal') for q in group}
        texts = {q.get('scenario') for q in group}
        if len(group) != 3 or indexes != [0, 1, 2] or totals != {3} or len(texts) != 1:
            raise SystemExit(f'{sid}: invalid canonical scenario structure indexes={indexes} totals={totals} texts={len(texts)}')

    exam_dir = OUT / f'exam-{exam}'
    exam_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        'schemaVersion': 1,
        'qualification': '看護師国家試験',
        'sourceExam': exam,
        'category': '状況設定',
        'questionCount': len(canonical),
        'scenarioCount': len(scenario_groups),
        'questionsPerScenario': 3,
        'questions': canonical,
    }
    (exam_dir / 'situation.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    by_exam[str(exam)] = {
        'questions': len(canonical),
        'scenarios': len(scenario_groups),
        'explained': sum(1 for q in canonical if complete_item(q)),
        'normal': sum(1 for q in canonical if q['canonicalReleaseStatus'] == 'normal'),
        'quarantined': sum(1 for q in canonical if q['canonicalReleaseStatus'] == 'quarantined'),
        'mediaRequired': sum(1 for q in canonical if q.get('requiresMedia')),
        'mediaVerified': sum(1 for q in canonical if q.get('requiresMedia') and str(q.get('mediaAuditStatus') or '').lower() == 'verified'),
    }
    all_questions.extend(canonical)

if len(all_questions) != 180:
    raise SystemExit(f'expected 180 canonical situation questions, got {len(all_questions)}')

round_map = {115: 1, 114: 2, 113: 3}
audit_rows = []
for q in all_questions:
    audit_rows.append({
        'id': q['id'],
        'round': round_map[int(q['sourceExam'])],
        'subject': '状況設定',
        'topic': q.get('subject') or '',
        'question': q.get('question') or '',
        'choices': q.get('choices') or [],
        'answer_type': q.get('answerType'),
        'answer': q.get('answer'),
        'accepted_answers': q.get('officialAcceptedAnswers') or [],
        'scoring_status': q.get('officialScoringStatus', 'normal'),
        'requires_media': bool(q.get('requiresMedia')),
        'source_url': (q.get('sourceRefs') or [''])[0],
        'origin_type': 'licensed_official',
        'rights_basis': q.get('rightsStatus') or '',
        'point': q.get('point'),
        'detail': q.get('detail'),
        'explanation_evidence_refs': q.get('explanationEvidenceRefs') or [],
        'evidence_checked_date': q.get('evidenceCheckedDate'),
        'scenario_id': q.get('scenarioId'),
        'scenario_index': q.get('scenarioIndex'),
        'scenario_total': q.get('scenarioTotal'),
        'canonical_release_status': q.get('canonicalReleaseStatus'),
    })

(OUT / 'situation-canonical-audit-input.json').write_text(json.dumps(audit_rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(OUT / 'situation-canonical-build-report.json').write_text(json.dumps({
    'schemaVersion': 1,
    'totalQuestions': len(all_questions),
    'totalScenarios': len(expected_by_sid),
    'expertPendingQuestionIds': sorted(expert_pending),
    'verifiedMediaQuestionIds': sorted(media_overrides),
    'byExam': by_exam,
    'outputFiles': [f'questions/exam-{exam}/situation.json' for exam in EXAMS],
}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'totalQuestions': len(all_questions), 'totalScenarios': len(expected_by_sid), 'byExam': by_exam}, ensure_ascii=False))
