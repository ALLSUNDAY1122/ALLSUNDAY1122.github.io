#!/usr/bin/env python3
import json,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
QROOT=ROOT/'questions'
EXAMS={115:'set1',114:'set2',113:'set3'}
errors=[]
summary={}
all_ids=[]
URL=re.compile(r'^https://',re.I)


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

for exam,set_id in EXAMS.items():
    raw=load(RAW/f'{set_id}-raw.json')
    raw_map={q['id']:q for q in raw.get('questions',[]) if q.get('category')=='一般'}
    can=load(QROOT/f'exam-{exam}'/'general.json')
    qs=can.get('questions') or []
    if len(raw_map)!=130: errors.append(f'{exam}: raw general {len(raw_map)}/130')
    if len(qs)!=130: errors.append(f'{exam}: canonical general {len(qs)}/130')
    counts={'total':len(qs),'normal':0,'quarantined':0,'sourceRepairResolved':0,'missingExplanation':0,'missingEvidence':0,'missingDate':0,'rightsMissing':0,'answerMismatch':0,'scoringMismatch':0}
    for q in qs:
        qid=q.get('id'); all_ids.append(qid)
        r=raw_map.get(qid)
        if not r:
            errors.append(f'{exam}:{qid}: missing in raw'); continue
        if q.get('answer')!=r.get('answer') or q.get('officialAcceptedAnswers')!=r.get('officialAcceptedAnswers'):
            counts['answerMismatch']+=1; errors.append(f'{qid}: official answer changed')
        if q.get('officialScoringStatus')!=r.get('officialScoringStatus'):
            counts['scoringMismatch']+=1; errors.append(f'{qid}: official scoring changed')
        if q.get('question')!=r.get('question') or (q.get('choices') or [])!=(r.get('choices') or []):
            errors.append(f'{qid}: canonical stem/choices diverge from normalized raw')
        status=q.get('canonicalReleaseStatus')
        if status=='normal': counts['normal']+=1
        elif status=='quarantined': counts['quarantined']+=1
        else: errors.append(f'{qid}: canonicalReleaseStatus invalid {status}')
        if q.get('sourceDataDefectResolved'): counts['sourceRepairResolved']+=1
        if len(str(q.get('point') or '').strip())<8 or len(str(q.get('detail') or '').strip())<20:
            counts['missingExplanation']+=1
        refs=q.get('explanationEvidenceRefs') or []
        if not refs or not all(URL.match(str(x)) for x in refs): counts['missingEvidence']+=1
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',str(q.get('evidenceCheckedDate') or '')): counts['missingDate']+=1
        if not str(q.get('rightsStatus') or '').strip(): counts['rightsMissing']+=1
    summary[str(exam)]=counts

if len(all_ids)!=390: errors.append(f'total ids {len(all_ids)}/390')
if len(set(all_ids))!=len(all_ids): errors.append('duplicate canonical ids')

# Final canonical content gate: even quarantined items remain canonical records and
# must carry an explanation/evidence audit. Quarantine only blocks product release.
for exam,counts in summary.items():
    for key in ('missingExplanation','missingEvidence','missingDate','rightsMissing','answerMismatch','scoringMismatch'):
        if counts[key]: errors.append(f'{exam}: {key}={counts[key]}')

report={
    'schemaVersion':1,
    'scope':'general-390-canonical',
    'counts':summary,
    'total':len(all_ids),
    'duplicateIds':len(all_ids)-len(set(all_ids)),
    'errorCount':len(errors),
    'errors':errors,
    'pass':not errors,
    'releaseAllowed':False,
    'note':'Canonical content PASS does not release quarantined media/content/scoring items; rights and expert gates remain separate.'
}
(QROOT/'general-canonical-integrity-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(0 if not errors else 1)
