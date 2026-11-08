#!/usr/bin/env python3
from __future__ import annotations
import difflib,hashlib,json,re,sys
from datetime import date
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; PRODUCT=ROOT/'content'/'product'; REPORT=PRODUCT/'final-audit-v2.json'
EXPECTED={109:{'必須':90,'理論':105,'実践':150},110:{'必須':90,'理論':105,'実践':150},111:{'必須':90,'理論':105,'実践':150}}
EXPECTED_EXAMS=set(EXPECTED)
OFFICIAL_ORIGIN='licensed_official'
MHLW_PREFIX='https://www.mhlw.go.jp/'
ANSWER_LEAK_MARKERS=('公式正答は','正答は選択肢','答えは選択肢','正解は選択肢')
AUDIT_DIMENSIONS=('transcription','grading','media','explanation','temporalLegal','rights')
COVERAGE_FILE='content/reviewed/independent-audit-coverage-v1.json'
PAYLOAD_ALGORITHM='question-json-and-media-sha256-v1'


def independent_audit_coverage(root, questions):
    """Validate recorded independent decisions, never infer review from assignments.

    Payload v1 = SHA256(UTF8 JSON of {question: full emitted question object,
    mediaAssetSha256: {relative media path: SHA256(actual bytes)}}), with sorted
    keys, ensure_ascii=False, separators=(',', ':'). All evidence stays in root.
    This validates evidence bindings, not the medical/legal truth of decisions.
    """
    root=root.resolve(); issues=Counter(); samples=defaultdict(list)
    def issue(reason, qid=''):
        issues[reason]+=1
        if qid and len(samples[reason])<5: samples[reason].append(qid)
    def read_json(path):
        try: return json.loads(path.read_text(encoding='utf-8'))
        except (OSError, ValueError): return None
    def valid_date(value):
        try: return isinstance(value,str) and bool(re.fullmatch(r'\d{4}-\d{2}-\d{2}',value)) and date.fromisoformat(value)<=date.today()
        except ValueError: return False
    def local_file(value):
        if not isinstance(value,str) or not value or '\\' in value: return None
        path=(root/value).resolve()
        if Path(value).is_absolute() or not path.is_relative_to(root) or not path.is_file(): return None
        return path
    def evidence_valid(refs):
        if not isinstance(refs,list) or not refs: return False
        for ref in refs:
            if not isinstance(ref,dict): return False
            path=local_file(ref.get('path'))
            if not path or not valid_date(ref.get('checkedAt')) or not str(ref.get('locator') or '').strip(): return False
            if hashlib.sha256(path.read_bytes()).hexdigest()!=ref.get('sha256'): return False
        return True
    def payload_hash(q):
        media={}
        for asset in q.get('mediaAssets') or []:
            path=local_file(asset)
            if not path: return None
            media[asset]=hashlib.sha256(path.read_bytes()).hexdigest()
        payload={'question':q,'mediaAssetSha256':media}
        return hashlib.sha256(json.dumps(payload,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8')).hexdigest()

    source=read_json(root/'content/source-manifest.json')
    complete=isinstance(source,dict) and isinstance(source.get('audit'),dict) and source['audit'].get('fullProblemAuditComplete') is True
    if not complete: issue('source manifest fullProblemAuditComplete is not true')
    ledger=read_json(root/COVERAGE_FILE)
    if not isinstance(ledger,dict):
        issue('coverage ledger missing or invalid')
        ledger={}
    if ledger.get('schemaVersion')!=1 or ledger.get('payloadHashAlgorithm')!=PAYLOAD_ALGORITHM:
        issue('coverage ledger schema/hash algorithm invalid')
    if not re.fullmatch(r'[0-9a-f]{40}',str(ledger.get('sourceCommit',''))): issue('coverage source commit invalid')
    expected={q['id']:q for q in questions}; batches={}; assigned=[]
    assignments=ledger.get('batchAssignments',[])
    if not isinstance(assignments,list): assignments=[]
    for batch in assignments:
        if not isinstance(batch,dict): issue('batch assignment invalid'); continue
        bid=batch.get('id'); ids=batch.get('questionIds',[])
        if not isinstance(bid,str) or bid in batches or not isinstance(ids,list) or len(ids)!=115 or batch.get('count')!=115 or not all(isinstance(i,str) for i in ids) or not re.fullmatch(r'[0-9a-f]{64}',str(batch.get('sourcePayloadSha256',''))):
            issue('batch assignment invalid'); continue
        batches[bid]=batch; assigned.extend(ids)
    if len(batches)!=9 or Counter(assigned)!=Counter(expected.keys()): issue('batch assignments do not cover all 1035 IDs exactly once')
    records=ledger.get('records',[])
    if not isinstance(records,list): issue('coverage records invalid'); records=[]
    counts=Counter(r.get('id') for r in records if isinstance(r,dict) and isinstance(r.get('id'),str))
    duplicates={qid for qid,count in counts.items() if count>1}
    if duplicates: issue('duplicate coverage IDs',','.join(sorted(duplicates)[:5]))
    verified=set()
    for record in records:
        if not isinstance(record,dict) or not isinstance(record.get('id'),str): issue('coverage record invalid'); continue
        qid=record['id']; q=expected.get(qid)
        if q is None: issue('unexpected coverage ID',qid); continue
        if qid in duplicates: continue
        before=sum(issues.values())
        batch=batches.get(record.get('batchId')) if isinstance(record.get('batchId'),str) else None
        if not batch or qid not in batch['questionIds'] or record.get('sourcePayloadSha256')!=batch['sourcePayloadSha256']: issue('record source assignment mismatch',qid)
        text=re.sub(r'\s+',' ',str(q.get('question') or '')).strip().casefold()+'\n'+'\n'.join(re.sub(r'\s+',' ',str(c or '')).strip().casefold() for c in q.get('choices',[]))
        canonical=hashlib.sha256(text.encode('utf-8')).hexdigest()[:20]
        if record.get('canonicalContentHash')!=q.get('canonicalContentHash') or q.get('canonicalContentHash')!=canonical: issue('stale canonical content hash',qid)
        current_payload=payload_hash(q)
        if current_payload is None or record.get('payloadSha256')!=current_payload: issue('stale payload or media hash',qid)
        reviewer=record.get('reviewer') or {}; authors=record.get('contentAuthorIds') or []
        if not isinstance(reviewer,dict): reviewer={}
        rid=reviewer.get('id')
        if not isinstance(authors,list): authors=[]
        if not isinstance(rid,str) or not rid.strip() or reviewer.get('independent') is not True or not str(reviewer.get('independenceBasis') or '').strip() or not isinstance(authors,list) or not authors or not all(isinstance(a,str) and a.strip() for a in authors) or rid in authors:
            issue('independent reviewer evidence missing',qid)
        reviewed=record.get('reviewedAt')
        if not valid_date(reviewed): issue('review date missing or invalid',qid)
        dims=record.get('dimensions') or {}
        if not isinstance(dims,dict): dims={}
        for dim in AUDIT_DIMENSIONS:
            result=dims.get(dim) or {}
            if not isinstance(result,dict): result={}
            if result.get('status') not in ('PASS','NOT_APPLICABLE') or not evidence_valid(result.get('evidence')) or (result.get('status')=='NOT_APPLICABLE' and not str(result.get('justification') or '').strip()):
                issue('dimension '+dim+' incomplete',qid)
        verification=record.get('verification') or {}
        if not isinstance(verification,dict): verification={}
        verifier=verification.get('verifiedBy'); checked=verification.get('verifiedAt')
        if record.get('overallStatus')!='PASS' or verification.get('status')!='VERIFIED' or not isinstance(verifier,str) or not verifier.strip() or not valid_date(checked) or (valid_date(reviewed) and valid_date(checked) and checked<reviewed) or not evidence_valid(verification.get('evidence')):
            issue('overall PASS evidence not verified',qid)
        if sum(issues.values())==before: verified.add(qid)
    missing=set(expected)-set(counts)
    if missing: issue('missing per-ID independent audit records',','.join(sorted(missing)[:5]))
    if len(verified)!=1035: issue(f'verified independent coverage {len(verified)}/1035')
    summary={'requiredCount':1035,'recordCount':len(records),'verifiedPassCount':len(verified),'missingCount':len(missing),'duplicateIdCount':len(duplicates),'manifestComplete':complete,'allCovered':len(verified)==1035 and not issues,'issues':dict(issues),'samples':dict(samples)}
    return summary,[f'independent audit: {reason} ({count})' for reason,count in issues.items()]


errors=[]
d=json.loads((PRODUCT/'questions.json').read_text(encoding='utf-8')); qs=d['questions']; qby={q['id']:q for q in qs}
coverage,coverage_errors=independent_audit_coverage(ROOT,qs)
errors.extend(coverage_errors)
if len(qs)!=1035: errors.append(f'total {len(qs)}/1035')
for k,v in Counter(q.get('id') for q in qs).items():
    if not k or v!=1: errors.append(f'id duplicate/missing {k}:{v}')
for exam,expect in EXPECTED.items():
    sub=Counter(q.get('subject') for q in qs if int(q.get('sourceExam',0))==exam)
    if sum(sub.values())!=345: errors.append(f'exam {exam} total {sum(sub.values())}/345')
    for sec,n in expect.items():
        if sub[sec]!=n: errors.append(f'exam {exam}/{sec} {sub[sec]}/{n}')

unexpected_exam=[]; non_official=[]; non_mhlw=[]; answer_leak=[]
hashes=defaultdict(list)
for q in qs:
    qid=q['id']; status=q.get('release_status')
    try: exam=int(q.get('sourceExam',0))
    except (TypeError,ValueError): exam=0
    if exam not in EXPECTED_EXAMS:
        unexpected_exam.append(qid); errors.append(f'{qid}: unexpected sourceExam {q.get("sourceExam")}')
    if q.get('origin_type')!=OFFICIAL_ORIGIN:
        non_official.append(qid); errors.append(f'{qid}: non-official origin {q.get("origin_type")}')
    source_url=str(q.get('source_url') or '')
    answer_source_url=str(q.get('answer_source_url') or '')
    if not source_url.startswith(MHLW_PREFIX) or not answer_source_url.startswith(MHLW_PREFIX):
        non_mhlw.append(qid); errors.append(f'{qid}: source is not MHLW official URL')
    qtext=str(q.get('question') or '')
    if any(marker in qtext for marker in ANSWER_LEAK_MARKERS):
        answer_leak.append(qid); errors.append(f'{qid}: answer-leak marker in question text')
    if str(status).startswith('blocked'): errors.append(f'{qid}: {status}')
    if q.get('scoring_status')!='excluded':
        if not q.get('memoryPoint'): errors.append(f'{qid}: memoryPoint missing')
        if not q.get('explanation'): errors.append(f'{qid}: explanation missing')
        if q.get('explanationReviewRequired'): errors.append(f'{qid}: explanation still requires review')
        if not q.get('explanationProvenance'): errors.append(f'{qid}: explanation provenance missing')
    for f in ('source_url','answer_source_url','effective_date','rights_basis','attributionDisplay','modificationDisclosureDisplay'):
        if not q.get(f): errors.append(f'{qid}: {f} missing')
    if q.get('displayMode')=='textChoices':
        c=q.get('choices') or []
        if not 2<=len(c)<=6: errors.append(f'{qid}: text choice count {len(c)}')
        if q.get('scoring_status')=='normal':
            a=q.get('answer'); inds=a if isinstance(a,list) else [a]
            if any(not isinstance(i,int) or i<0 or i>=len(c) for i in inds): errors.append(f'{qid}: answer index out of choices')
        if q.get('scoring_status')=='multiple_accepted' and not (q.get('accepted_answers') or []): errors.append(f'{qid}: flexible accepted answers missing')
    elif q.get('displayMode')=='officialQuestionImage':
        if not (q.get('mediaAssets') or []): errors.append(f'{qid}: media assets missing')
        if not q.get('mediaAttribution') or q.get('mediaLicense')!='PDL1.0': errors.append(f'{qid}: media rights metadata missing')
        if not 2<=int(q.get('numberedChoiceCount',0))<=6: errors.append(f'{qid}: numberedChoiceCount invalid')
    elif q.get('displayMode')=='thirdPartyRebuildRequired': errors.append(f'{qid}: unresolved third-party asset')
    else: errors.append(f'{qid}: displayMode invalid {q.get("displayMode")}')
    hashes[q.get('canonicalContentHash')].append(q)
resolved_exact=[]
for h,items in hashes.items():
    if h and len(items)>1:
        root=items[0]['id']
        for q in items[1:]:
            if q.get('historicalRepeatOf')!=root or q.get('dailySprintCanonicalId')!=root: errors.append(f'{q["id"]}: exact duplicate not documented against {root}')
            else: resolved_exact.append({'canonical':root,'repeat':q['id']})
def norm(s): return re.sub(r'[\s\W_]+','',str(s or '')).casefold()
by_domain=defaultdict(list)
for q in qs:
    if q.get('scoring_status')!='excluded': by_domain[(q.get('subject'),q.get('domain'))].append((q['id'],norm(q.get('question'))))
resolved_high=[]; unresolved_high=[]
for arr in by_domain.values():
    for i in range(len(arr)):
        ai,at=arr[i]
        if len(at)<25: continue
        for j in range(i+1,len(arr)):
            bi,bt=arr[j]
            if len(bt)<25 or min(len(at),len(bt))/max(len(at),len(bt))<0.78: continue
            sim=difflib.SequenceMatcher(None,at,bt,autojunk=True).ratio()
            if sim<0.94: continue
            rec={'a':ai,'b':bi,'similarity':round(sim,4)}; a=qby[ai]; b=qby[bi]
            if a.get('origin_type')==OFFICIAL_ORIGIN and b.get('origin_type')==OFFICIAL_ORIGIN and a.get('source_url') and b.get('source_url'):
                rec['classification']='official_exam_similarity'; resolved_high.append(rec)
            else: unresolved_high.append(rec)
if unresolved_high: errors.append(f'unresolved high-similarity pairs: {len(unresolved_high)}')
section_counts={str(exam):dict(Counter(q.get('subject') for q in qs if int(q.get('sourceExam',0))==exam)) for exam in sorted(EXPECTED_EXAMS)}
generated_supplements=[q['id'] for q in qs if q.get('origin_type')!=OFFICIAL_ORIGIN or int(q.get('sourceExam',0) or 0) not in EXPECTED_EXAMS]
report={'schemaVersion':4,'independentAuditCoverage':coverage,'questionCount':len(qs),'errors':errors,'blockedCount':sum(1 for q in qs if str(q.get('release_status','')).startswith('blocked')),'explanationCoverage':sum(1 for q in qs if q.get('explanation')),'explanationReviewPending':sum(1 for q in qs if q.get('scoring_status')!='excluded' and q.get('explanationReviewRequired')),'mediaAssetCoverage':sum(1 for q in qs if q.get('mediaAssets')),'rebuiltTextMedia':sum(1 for q in qs if q.get('mediaAuditStatus')=='rebuilt_as_independent_text'),'resolvedExactOfficialRepeats':resolved_exact,'resolvedHighSimilarityOfficialPairs':resolved_high,'unresolvedHighSimilarityPairs':unresolved_high,'difficultyIntegrity':{'policy':'official_exam_only','sourceExams':sorted(EXPECTED_EXAMS),'officialQuestionCount':sum(1 for q in qs if q.get('origin_type')==OFFICIAL_ORIGIN and int(q.get('sourceExam',0) or 0) in EXPECTED_EXAMS),'generatedSupplementQuestionCount':len(generated_supplements),'generatedSupplementQuestionIds':generated_supplements,'unexpectedExamQuestionIds':unexpected_exam,'nonOfficialQuestionIds':non_official,'nonMhlwSourceQuestionIds':non_mhlw,'answerLeakQuestionIds':answer_leak,'sectionCounts':section_counts},'generatedSupplementQuestionCount':len(generated_supplements),'finalPass':not errors}
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(report,ensure_ascii=False))
if errors: sys.exit(1)
