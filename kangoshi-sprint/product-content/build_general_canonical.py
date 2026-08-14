#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
OUT=ROOT/'questions'
WORKSTREAM=ROOT.parent/'workstreams'/'B-general'

EXAMS={115:'set1',114:'set2',113:'set3'}
SPECIAL={
    115: WORKSTREAM/'K115-SPECIAL-AUDIT.json',
    114: WORKSTREAM/'K114-SPECIAL-AUDIT.json',
    113: WORKSTREAM/'K113-SPECIAL-AUDIT.json',
}


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def special_map(path):
    doc=load(path)
    result={}
    quarantine=doc.get('quarantine') or {}
    for group_name,rows in quarantine.items():
        for row in rows or []:
            qid=row.get('id')
            if not qid:
                raise SystemExit(f'{path}: quarantine row without id')
            entry=result.setdefault(qid,{'types':[],'records':[]})
            entry['types'].append(group_name)
            entry['records'].append(row)
    return result


def overlay_special(q,entry):
    q=dict(q)
    types=list(dict.fromkeys(entry.get('types') or []))
    records=entry.get('records') or []

    # Source-data defects cease to be a quarantine reason once the verified
    # normalization overlay has materially repaired the canonical draft.
    source_only=types and set(types)=={'sourceDataDefects'}
    source_resolved=bool(q.get('sourceCorrectionStatus')=='official_pdf_verified')
    active_types=[t for t in types if not (t=='sourceDataDefects' and source_resolved)]

    q['sourceDataDefectResolved']=bool('sourceDataDefects' in types and source_resolved)
    q['canonicalReleaseStatus']='quarantined' if active_types else 'normal'
    q['canonicalQuarantineTypes']=active_types
    q['canonicalAuditSources']=[]

    for row in records:
        if row.get('sourcePdf'):
            q['canonicalAuditSources'].append(row['sourcePdf'])
        for ref in row.get('evidenceRefs') or []:
            q['canonicalAuditSources'].append(ref)

        # Specialist audit content may be the only safe explanation for a
        # quarantined question. Use it when the normal L3 row is absent.
        if not str(q.get('point') or '').strip() and row.get('point'):
            q['point']=row['point']
        if not str(q.get('detail') or '').strip() and row.get('detail'):
            q['detail']=row['detail']
        if not (q.get('explanationEvidenceRefs') or []) and row.get('evidenceRefs'):
            q['explanationEvidenceRefs']=row['evidenceRefs']
        if not q.get('evidenceCheckedDate') and row.get('evidenceCheckedDate'):
            q['evidenceCheckedDate']=row['evidenceCheckedDate']

    q['canonicalAuditSources']=sorted(set(q['canonicalAuditSources']))
    if source_only and source_resolved:
        q['canonicalSourceRepairStatus']='resolved_verified_in_raw_normalization'
    return q


all_questions=[]
summary={}
for exam,set_id in EXAMS.items():
    draft_path=DRAFT/f'{set_id}-draft.json'
    data=load(draft_path)
    specials=special_map(SPECIAL[exam])
    general=[]
    seen=set()
    for original in data.get('questions',[]):
        if original.get('category')!='一般':
            continue
        q=dict(original)
        qid=q.get('id')
        if not qid or qid in seen:
            raise SystemExit(f'{exam}: duplicate/missing general id {qid}')
        seen.add(qid)
        entry=specials.get(qid)
        if entry:
            q=overlay_special(q,entry)
        else:
            q['canonicalReleaseStatus']='normal'
            q['canonicalQuarantineTypes']=[]
            q['canonicalAuditSources']=[]
            q['sourceDataDefectResolved']=False
        q['canonicalSchemaVersion']=1
        q['canonicalCategory']='一般'
        q['canonicalSourceExam']=exam
        general.append(q)

    unknown_special=sorted(set(specials)-{q['id'] for q in general})
    if unknown_special:
        raise SystemExit(f'{exam}: special audit ids not in general draft: {unknown_special}')
    if len(general)!=130:
        raise SystemExit(f'{exam}: expected 130 general questions, got {len(general)}')

    exam_dir=OUT/f'exam-{exam}'
    exam_dir.mkdir(parents=True,exist_ok=True)
    out_path=exam_dir/'general.json'
    payload={
        'schemaVersion':1,
        'qualification':'看護師国家試験',
        'sourceExam':exam,
        'category':'一般',
        'questionCount':len(general),
        'questions':general,
    }
    out_path.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary[str(exam)]={
        'count':len(general),
        'normal':sum(1 for q in general if q['canonicalReleaseStatus']=='normal'),
        'quarantined':sum(1 for q in general if q['canonicalReleaseStatus']=='quarantined'),
        'sourceRepairsResolved':sum(1 for q in general if q.get('sourceDataDefectResolved')),
        'explained':sum(1 for q in general if str(q.get('point') or '').strip() and str(q.get('detail') or '').strip()),
    }
    all_questions.extend(general)

if len(all_questions)!=390:
    raise SystemExit(f'expected 390 general questions, got {len(all_questions)}')

# Adapter for the shared Learning Sprint validator. The shared validator now
# audits the consolidated canonical questions rather than temporary batches.
audit_rows=[]
for q in all_questions:
    exam=int(q.get('sourceExam'))
    round_no={115:1,114:2,113:3}[exam]
    audit_rows.append({
        'id':q['id'],
        'round':round_no,
        'subject':'一般',
        'topic':q.get('subject') or '',
        'question':q.get('question') or '',
        'choices':q.get('choices') or [],
        'answer_type':q.get('answerType'),
        'answer':q.get('answer'),
        'accepted_answers':q.get('officialAcceptedAnswers') or [],
        'scoring_status':q.get('officialScoringStatus','normal'),
        'requires_media':bool(q.get('requiresMedia')),
        'source_url':(q.get('sourceRefs') or [''])[0],
        'origin_type':'licensed_official',
        'rights_basis':q.get('rightsStatus') or '',
        'point':q.get('point'),
        'detail':q.get('detail'),
        'explanation_evidence_refs':q.get('explanationEvidenceRefs') or [],
        'evidence_checked_date':q.get('evidenceCheckedDate'),
        'canonical_release_status':q.get('canonicalReleaseStatus'),
    })

(OUT/'general-canonical-audit-input.json').write_text(json.dumps(audit_rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'general-canonical-build-report.json').write_text(json.dumps({
    'schemaVersion':1,
    'total':len(all_questions),
    'byExam':summary,
    'outputFiles':[f'questions/exam-{exam}/general.json' for exam in EXAMS],
},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'total':len(all_questions),'byExam':summary},ensure_ascii=False))
