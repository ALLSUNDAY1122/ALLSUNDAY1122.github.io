#!/usr/bin/env python3
from __future__ import annotations
import difflib,json,re,sys
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; PRODUCT=ROOT/'content'/'product'; REPORT=PRODUCT/'final-audit-v2.json'
EXPECTED={109:{'必須':90,'理論':105,'実践':150},110:{'必須':90,'理論':105,'実践':150},111:{'必須':90,'理論':105,'実践':150}}
errors=[]
d=json.loads((PRODUCT/'questions.json').read_text(encoding='utf-8')); qs=d['questions']; qby={q['id']:q for q in qs}
if len(qs)!=1035: errors.append(f'total {len(qs)}/1035')
for k,v in Counter(q.get('id') for q in qs).items():
    if not k or v!=1: errors.append(f'id duplicate/missing {k}:{v}')
for exam,expect in EXPECTED.items():
    sub=Counter(q.get('subject') for q in qs if int(q.get('sourceExam',0))==exam)
    if sum(sub.values())!=345: errors.append(f'exam {exam} total {sum(sub.values())}/345')
    for sec,n in expect.items():
        if sub[sec]!=n: errors.append(f'exam {exam}/{sec} {sub[sec]}/{n}')
hashes=defaultdict(list)
for q in qs:
    qid=q['id']; status=q.get('release_status')
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
            if a.get('origin_type')=='licensed_official' and b.get('origin_type')=='licensed_official' and a.get('source_url') and b.get('source_url'):
                rec['classification']='official_exam_similarity'; resolved_high.append(rec)
            else: unresolved_high.append(rec)
if unresolved_high: errors.append(f'unresolved high-similarity pairs: {len(unresolved_high)}')
report={'schemaVersion':2,'questionCount':len(qs),'errors':errors,'blockedCount':sum(1 for q in qs if str(q.get('release_status','')).startswith('blocked')),'explanationCoverage':sum(1 for q in qs if q.get('explanation')),'explanationReviewPending':sum(1 for q in qs if q.get('scoring_status')!='excluded' and q.get('explanationReviewRequired')),'mediaAssetCoverage':sum(1 for q in qs if q.get('mediaAssets')),'rebuiltTextMedia':sum(1 for q in qs if q.get('mediaAuditStatus')=='rebuilt_as_independent_text'),'resolvedExactOfficialRepeats':resolved_exact,'resolvedHighSimilarityOfficialPairs':resolved_high,'unresolvedHighSimilarityPairs':unresolved_high,'generatedSupplementQuestionCount':0,'finalPass':not errors}
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(report,ensure_ascii=False))
if errors: sys.exit(1)
