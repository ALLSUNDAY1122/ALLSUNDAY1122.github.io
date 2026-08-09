#!/usr/bin/env python3
import json, re, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
SOURCES=json.loads((ROOT/'official-sources.json').read_text(encoding='utf-8'))
expected={'必修':50,'一般':130,'状況設定':60}
source_by_id={s['id']:s for s in SOURCES['sets']}
errors=[]; summaries=[]; all_stems={}; duplicates=[]
FRONT_MATTER_WORDS=('答案用紙','正解は「','試験問題の数','解答方法について','（例 2 ）','（例 3 ）','（例 4 ）')

for set_id in ('set1','set2','set3'):
    p=RAW/f'{set_id}-raw.json'
    if not p.exists():
        errors.append(f'{set_id}: raw file missing'); continue
    d=json.loads(p.read_text(encoding='utf-8')); qs=d.get('questions',[])
    if int(d.get('schemaVersion') or 0)<3: errors.append(f'{set_id}: schemaVersion expected >=3, got {d.get("schemaVersion")}')
    src=source_by_id[set_id]
    expected_exceptions={(x['session'],int(x['questionNo'])):x for x in src.get('scoringExceptions',[])}
    if len(qs)!=240: errors.append(f'{set_id}: expected 240 questions, got {len(qs)}')
    ids=set(); cats={k:0 for k in expected}; media=0; empty_stem=0; short_stem=0; malformed_stem=0; missing_answers=0; multiple_accepted=0; numeric=0; choice_shape_errors=0
    seen_exceptions=set()
    for q in qs:
        qid=q.get('id')
        if not qid or qid in ids: errors.append(f'{set_id}: duplicate/missing id {qid}')
        ids.add(qid)
        cat=q.get('category')
        if cat in cats: cats[cat]+=1
        else: errors.append(f'{qid}: invalid category {cat}')

        stem=re.sub(r'\s+',' ',str(q.get('question') or '')).strip()
        if not stem:
            empty_stem+=1; errors.append(f'{qid}: empty question')
        elif re.fullmatch(r'[\d\W_]+',stem):
            malformed_stem+=1; errors.append(f'{qid}: digits/symbols-only question: {stem!r}')
        elif len(stem)<6:
            short_stem+=1; errors.append(f'{qid}: question too short: {stem!r}')
        if any(word in stem for word in FRONT_MATTER_WORDS):
            malformed_stem+=1; errors.append(f'{qid}: front-matter contamination detected')

        key=stem.casefold()
        if key:
            if key in all_stems: duplicates.append({'stem':stem,'first':all_stems[key],'second':qid})
            else: all_stems[key]=qid

        session=q.get('session'); qno=int(q.get('questionNo') or 0)
        status=q.get('officialScoringStatus','normal')
        expected_exception=expected_exceptions.get((session,qno))
        if expected_exception:
            seen_exceptions.add((session,qno))
            if status!=expected_exception['mode']:
                errors.append(f"{qid}: scoring exception mismatch {status}/{expected_exception['mode']}")
        elif status!='normal':
            errors.append(f'{qid}: undocumented scoring status {status}')

        answer=q.get('answer')
        if answer is None:
            missing_answers+=1
            if status!='excluded': errors.append(f'{qid}: answer missing but not excluded')
        elif status=='excluded':
            errors.append(f'{qid}: excluded question unexpectedly has answer')

        accepted=q.get('officialAcceptedAnswers')
        if not isinstance(accepted,list): errors.append(f'{qid}: officialAcceptedAnswers missing')
        if status=='multiple_accepted':
            multiple_accepted+=1
            if not isinstance(accepted,list) or len(accepted)<2: errors.append(f'{qid}: multiple accepted answers not preserved')
        if status!='excluded' and (not isinstance(accepted,list) or len(accepted)<1):
            errors.append(f'{qid}: accepted answer missing')

        answer_type=q.get('answerType')
        choices=q.get('choices') or []
        requires_media=bool(q.get('requiresMedia'))
        if requires_media: media+=1
        if answer_type=='numeric':
            numeric+=1
            if not isinstance(answer,int): errors.append(f'{qid}: numeric answer is not integer')
            if choices:
                choice_shape_errors+=1; errors.append(f'{qid}: numeric question unexpectedly has choices')
        elif answer_type=='singleChoice':
            if answer is not None and not isinstance(answer,int): errors.append(f'{qid}: singleChoice answer invalid')
            if not requires_media and len(choices)<2:
                choice_shape_errors+=1; errors.append(f'{qid}: non-media singleChoice has too few choices ({len(choices)})')
        elif answer_type=='multiChoice':
            if not isinstance(answer,list) or len(answer)<2: errors.append(f'{qid}: multiChoice answer invalid')
            if not requires_media and len(choices)<2:
                choice_shape_errors+=1; errors.append(f'{qid}: non-media multiChoice has too few choices ({len(choices)})')
        else:
            errors.append(f'{qid}: invalid answerType {answer_type}')

        if answer_type!='numeric' and choices:
            max_idx=len(choices)-1
            candidates=[]
            if isinstance(answer,int): candidates=[answer]
            elif isinstance(answer,list): candidates=answer
            for a in candidates:
                if not isinstance(a,int) or not (0<=a<=max_idx): errors.append(f'{qid}: answer index out of range {a}/{len(choices)}')

        if not q.get('sourceRefs'): errors.append(f'{qid}: sourceRefs missing')
        if q.get('reviewStatus')!='official_import_pending_explanation_and_classification': errors.append(f'{qid}: raw review status invalid')
        if q.get('point') is not None or q.get('detail') is not None: errors.append(f'{qid}: raw import must not pretend explanation is reviewed')

    for cat,n in expected.items():
        if cats[cat]!=n: errors.append(f'{set_id}: {cat} expected {n}, got {cats[cat]}')
    missing_exception_rows=set(expected_exceptions)-seen_exceptions
    if missing_exception_rows: errors.append(f'{set_id}: scoring exception rows missing {sorted(missing_exception_rows)}')
    summaries.append({
        'set':set_id,'count':len(qs),'categories':cats,'mediaPending':media,'emptyStem':empty_stem,
        'shortStem':short_stem,'malformedStem':malformed_stem,'choiceShapeErrors':choice_shape_errors,
        'missingAnswersAllowedExcluded':missing_answers,'numeric':numeric,'multipleAccepted':multiple_accepted,
        'scoringExceptions':len(seen_exceptions)
    })

report={
    'structuralErrors':errors,
    'sets':summaries,
    'exactDuplicateStemsAcrossSets':duplicates,
    'releaseAllowed':False,
    'note':'raw取込監査。数字だけ・短すぎる設問、前付け混入、選択肢構造不良もFAILにする。採点除外・複数正解は公式例外として保持する。'
}
(RAW/'raw-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print(json.dumps(report,ensure_ascii=False))
