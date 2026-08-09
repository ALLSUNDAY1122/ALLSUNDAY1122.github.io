#!/usr/bin/env python3
import glob,json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
BATCH=ROOT/'explanation-batches'
REQUIRED=ROOT/'required-150'
SITUATION_AUDIT=ROOT/'situation-audit'
BATCH.mkdir(exist_ok=True)

sets={}
index={}
for sid in ('set1','set2','set3'):
    p=DRAFT/f'{sid}-draft.json'
    data=json.loads(p.read_text(encoding='utf-8'))
    sets[sid]=(p,data)
    for q in data.get('questions',[]):
        if q['id'] in index:
            raise SystemExit(f'duplicate draft id: {q["id"]}')
        index[q['id']]=q

errors=[]
text_corrections_applied=[]
special_quarantine_ids=set()
situation_expert_ids=set()

def valid_row(row, source_name):
    qid=row.get('id')
    q=index.get(qid)
    if not q:
        errors.append(f'{source_name}: unknown id {qid}')
        return None
    point=str(row.get('point') or '').strip()
    detail=str(row.get('detail') or '').strip()
    refs=row.get('explanationEvidenceRefs') or []
    checked=str(row.get('evidenceCheckedDate') or '').strip()
    if len(point)<8 or len(detail)<20 or not refs or not checked:
        errors.append(f'{source_name}: incomplete explanation row {qid}')
        return None
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',checked):
        errors.append(f'{source_name}: invalid evidenceCheckedDate {qid}: {checked}')
        return None
    if not all(str(ref).startswith('https://') for ref in refs):
        errors.append(f'{source_name}: non-https explanation evidence {qid}')
        return None
    return q

# Apply verified required-question text overlays before explanation enrichment.
correction_path=REQUIRED/'text-corrections.json'
if correction_path.exists():
    doc=json.loads(correction_path.read_text(encoding='utf-8'))
    source_refs=doc.get('sourceRefs') or []
    checked=doc.get('checkedDate')
    seen_corrections=set()
    for row in doc.get('corrections',[]):
        qid=row.get('id')
        if qid in seen_corrections:
            errors.append(f'{correction_path.name}: duplicate correction id {qid}')
            continue
        seen_corrections.add(qid)
        q=index.get(qid)
        if not q:
            errors.append(f'{correction_path.name}: unknown id {qid}')
            continue
        if q.get('category')!='必修':
            errors.append(f'{correction_path.name}: correction out of required scope {qid}')
            continue
        if 'question' in row:
            q['question']=row['question']
        if 'choices' in row:
            q['choices']=row['choices']
        q['textCorrectionStatus']='official_overlay_verified'
        q['textCorrectionEvidenceRefs']=source_refs
        q['textCorrectionCheckedDate']=checked
        text_corrections_applied.append(qid)

files=sorted(glob.glob(str(BATCH/'*.json')))
applied=[]
seen_qids={}
seen_batch_ids={}
for filename in files:
    name=Path(filename).name
    batch=json.loads(Path(filename).read_text(encoding='utf-8'))
    batch_id=str(batch.get('batchId') or '').strip()
    if not batch_id:
        errors.append(f'{name}: batchId missing')
    elif batch_id in seen_batch_ids:
        errors.append(f'{name}: duplicate batchId {batch_id} also in {seen_batch_ids[batch_id]}')
    else:
        seen_batch_ids[batch_id]=name
    items=batch.get('items')
    if not isinstance(items,list) or not items:
        errors.append(f'{name}: items missing/empty')
        continue
    for row in items:
        qid=row.get('id')
        if qid in seen_qids:
            errors.append(f'{name}: duplicate question id {qid} also in {seen_qids[qid]}')
            continue
        q=valid_row(row,name)
        if not q:
            continue
        seen_qids[qid]=name
        q['point']=str(row.get('point') or '').strip()
        q['detail']=str(row.get('detail') or '').strip()
        q['explanationEvidenceRefs']=row.get('explanationEvidenceRefs') or []
        q['evidenceCheckedDate']=str(row.get('evidenceCheckedDate') or '').strip()
        q['explanationStatus']='ai_explained'
        if q.get('dynamicEvidenceRequired'):
            q['dynamicEvidenceStatus']=row.get('dynamicEvidenceStatus','pending')
        applied.append(qid)

# Specialist explanations are complete L3 content, but remain quarantined from release.
special_explanation_path=REQUIRED/'special-case-explanations.json'
special_applied=[]
if special_explanation_path.exists():
    doc=json.loads(special_explanation_path.read_text(encoding='utf-8'))
    items=doc.get('items')
    if not isinstance(items,list):
        errors.append(f'{special_explanation_path.name}: items missing')
    else:
        for row in items:
            qid=row.get('id')
            if qid in seen_qids:
                errors.append(f'{special_explanation_path.name}: duplicate question id {qid} also in {seen_qids[qid]}')
                continue
            q=valid_row(row,special_explanation_path.name)
            if not q:
                continue
            seen_qids[qid]=special_explanation_path.name
            q['point']=str(row.get('point') or '').strip()
            q['detail']=str(row.get('detail') or '').strip()
            q['explanationEvidenceRefs']=row.get('explanationEvidenceRefs') or []
            q['evidenceCheckedDate']=str(row.get('evidenceCheckedDate') or '').strip()
            q['explanationStatus']='ai_explained'
            q['specialistExplanationStatus']=row.get('status','quarantined')
            if q.get('dynamicEvidenceRequired'):
                q['dynamicEvidenceStatus']=row.get('dynamicEvidenceStatus','pending')
            applied.append(qid)
            special_applied.append(qid)

# Propagate required-question specialist quarantine metadata without changing official scoring data.
special_case_path=REQUIRED/'special-cases.json'
if special_case_path.exists():
    doc=json.loads(special_case_path.read_text(encoding='utf-8'))
    quarantine={}
    for kind in ('mediaDependent','scoringSpecial','expertReview'):
        for row in doc.get(kind,[]) or []:
            qid=row.get('id')
            q=index.get(qid)
            if not q:
                errors.append(f'{special_case_path.name}: unknown {kind} id {qid}')
                continue
            quarantine.setdefault(qid,[]).append({
                'kind':kind,
                'status':row.get('status'),
                'reason':row.get('reason') or row.get('issue') or row.get('note')
            })
            if kind=='expertReview':
                q['expertReviewStatus']='required'
    for qid,reasons in quarantine.items():
        q=index[qid]
        q['specialistQuarantineStatus']='quarantined'
        q['specialistQuarantineReasons']=reasons
        special_quarantine_ids.add(qid)

# Situation specialist queue is coordinator-owned release metadata. It must not
# alter the official answer or scoring fields; it only holds the question until
# expert review is complete.
situation_expert_path=SITUATION_AUDIT/'expert-review-queue.json'
if situation_expert_path.exists():
    doc=json.loads(situation_expert_path.read_text(encoding='utf-8'))
    items=doc.get('items') or []
    if not isinstance(items,list):
        errors.append(f'{situation_expert_path.name}: items invalid')
    else:
        seen_situation=set()
        for row in items:
            qid=row.get('questionId') or row.get('id')
            if qid in seen_situation:
                errors.append(f'{situation_expert_path.name}: duplicate question id {qid}')
                continue
            seen_situation.add(qid)
            q=index.get(qid)
            if not q:
                errors.append(f'{situation_expert_path.name}: unknown id {qid}')
                continue
            if q.get('category')!='状況設定':
                errors.append(f'{situation_expert_path.name}: out-of-scope id {qid}')
                continue
            q['expertReviewStatus']='required'
            q['specialistQuarantineStatus']='quarantined'
            reasons=list(q.get('specialistQuarantineReasons') or [])
            reasons.append({
                'kind':'situationExpertReview',
                'status':row.get('status','expert_review_required'),
                'reason':row.get('issue'),
                'scenarioId':row.get('scenarioId'),
                'priority':row.get('priority')
            })
            q['specialistQuarantineReasons']=reasons
            special_quarantine_ids.add(qid)
            situation_expert_ids.add(qid)

if errors:
    print('\n'.join(errors))
    raise SystemExit(1)

for p,data in sets.values():
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

report={
    'batchFiles':len(files),
    'batchIds':sorted(seen_batch_ids),
    'specialExplanationFile':special_explanation_path.name if special_explanation_path.exists() else None,
    'specialExplanationItems':len(special_applied),
    'textCorrectionsApplied':len(text_corrections_applied),
    'specialistQuarantineCount':len(special_quarantine_ids),
    'situationExpertReviewCount':len(situation_expert_ids),
    'appliedCount':len(applied),
    'uniqueAppliedCount':len(set(applied)),
    'duplicateQuestionIds':0,
    'duplicateBatchIds':0,
    'appliedIds':applied
}
(DRAFT/'batch-apply-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({
    'batchFiles':report['batchFiles'],
    'specialExplanationItems':report['specialExplanationItems'],
    'textCorrectionsApplied':report['textCorrectionsApplied'],
    'specialistQuarantineCount':report['specialistQuarantineCount'],
    'situationExpertReviewCount':report['situationExpertReviewCount'],
    'appliedCount':report['appliedCount'],
    'uniqueAppliedCount':report['uniqueAppliedCount']
},ensure_ascii=False))
