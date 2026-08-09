#!/usr/bin/env python3
import json, re, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
expected={'必修':50,'一般':130,'状況設定':60}
errors=[]; summaries=[]; all_stems={}; duplicates=[]
for set_id in ('set1','set2','set3'):
    p=RAW/f'{set_id}-raw.json'
    if not p.exists():
        errors.append(f'{set_id}: raw file missing'); continue
    d=json.loads(p.read_text(encoding='utf-8')); qs=d.get('questions',[])
    if len(qs)!=240: errors.append(f'{set_id}: expected 240 questions, got {len(qs)}')
    ids=set(); cats={k:0 for k in expected}; media=0; empty_stem=0; missing_answers=0
    for q in qs:
        qid=q.get('id')
        if not qid or qid in ids: errors.append(f'{set_id}: duplicate/missing id {qid}')
        ids.add(qid)
        cat=q.get('category');
        if cat in cats: cats[cat]+=1
        else: errors.append(f'{qid}: invalid category {cat}')
        stem=re.sub(r'\s+',' ',str(q.get('question') or '')).strip()
        if not stem: empty_stem+=1; errors.append(f'{qid}: empty question')
        key=stem.casefold()
        if key:
            if key in all_stems: duplicates.append({'stem':stem,'first':all_stems[key],'second':qid})
            else: all_stems[key]=qid
        if q.get('answer') is None: missing_answers+=1; errors.append(f'{qid}: answer missing')
        if not q.get('sourceRefs'): errors.append(f'{qid}: sourceRefs missing')
        if q.get('requiresMedia'): media+=1
        if q.get('reviewStatus')!='official_import_pending_explanation_and_classification': errors.append(f'{qid}: raw review status invalid')
        if q.get('point') is not None or q.get('detail') is not None: errors.append(f'{qid}: raw import must not pretend explanation is reviewed')
    for cat,n in expected.items():
        if cats[cat]!=n: errors.append(f'{set_id}: {cat} expected {n}, got {cats[cat]}')
    summaries.append({'set':set_id,'count':len(qs),'categories':cats,'mediaPending':media,'emptyStem':empty_stem,'missingAnswers':missing_answers})
report={'structuralErrors':errors,'sets':summaries,'exactDuplicateStemsAcrossSets':duplicates,'releaseAllowed':False,'note':'raw取込監査。重複は最終720問化の前に除外・差替え判断する。'}
(RAW/'raw-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print(json.dumps(report,ensure_ascii=False))
