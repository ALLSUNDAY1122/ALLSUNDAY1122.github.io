#!/usr/bin/env python3
import json, shutil
from pathlib import Path

IOS=Path(__file__).resolve().parents[1]
APP=IOS.parent
ROOT=APP/'product-content'
DRAFT=ROOT/'enriched-draft'
OUT=IOS/'GeneratedResources'
MEDIA_OUT=OUT/'Media'

if OUT.exists():
    shutil.rmtree(OUT)
MEDIA_OUT.mkdir(parents=True,exist_ok=True)

scoring=json.loads((ROOT/'scoring-runtime-audit.json').read_text(encoding='utf-8'))
if scoring.get('pass') is not True:
    raise SystemExit('scoring runtime audit must PASS')
scoring_modes=scoring.get('expected') or {}
questions=[]
media_count=0

for sid in ('set1','set2','set3'):
    doc=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    rows=doc.get('questions') or []
    if len(rows)!=240:
        raise SystemExit(f'{sid}: expected 240, got {len(rows)}')
    for q in rows:
        at=q.get('answerType') or 'singleChoice'
        answer=q.get('answer')
        accepted=[]
        numeric=None
        if at=='numeric':
            try: numeric=float(answer)
            except Exception: raise SystemExit(f"{q['id']}: invalid numeric answer {answer!r}")
        elif at=='multiChoice':
            vals=answer if isinstance(answer,list) else [answer]
            accepted=[sorted(int(v) for v in vals)]
        else:
            accepted=[[int(answer)]]
        if scoring_modes.get(q['id'])=='multiple_accepted':
            vals=q.get('officialAcceptedAnswers') or []
            if len(vals)<2: raise SystemExit(f"{q['id']}: multiple accepted choices missing")
            accepted=[[int(v)] for v in vals]
        assets=q.get('mediaAssets') or []
        native_assets=[]
        for rel in assets:
            src=APP/rel
            if not src.exists(): raise SystemExit(f"{q['id']}: missing media {rel}")
            dest=MEDIA_OUT/src.name
            if dest.exists() and dest.read_bytes()!=src.read_bytes():
                raise SystemExit(f'media filename collision: {src.name}')
            shutil.copy2(src,dest)
            native_assets.append(f'Media/{src.name}')
        if q.get('mediaReleaseStatus')=='resolved': media_count+=1
        questions.append({
            'id':q['id'],'sourceExam':int(q['sourceExam']),'session':q.get('session') or '',
            'questionNo':int(q.get('questionNo') or 0),'category':q.get('category') or '',
            'majorSubject':q.get('majorSubject') or 'その他・横断','subject':q.get('subject') or '',
            'answerType':at,'selectCount':q.get('selectCount'),
            'question':q.get('question') or '','choices':q.get('choices') or [],
            'acceptedChoiceSets':accepted,'numericAnswer':numeric,
            'tolerance':float(q.get('tolerance') or 0),'unit':q.get('unit') or '',
            'point':q.get('point') or '','detail':q.get('detail') or '',
            'scenario':q.get('scenario') or '', 'scenarioId':q.get('scenarioId') or '',
            'scenarioIndex':int(q.get('scenarioIndex') or 0),'scenarioTotal':int(q.get('scenarioTotal') or 0),
            'scoringMode':scoring_modes.get(q['id'],'normal'),
            'mediaAssets':native_assets,'mediaAttribution':q.get('mediaAttribution') or ''
        })

if len(questions)!=720 or len({q['id'] for q in questions})!=720:
    raise SystemExit('native content must contain 720 unique questions')
by_exam={e:[q for q in questions if q['sourceExam']==e] for e in (115,114,113)}
for exam,rows in by_exam.items():
    comp={c:sum(q['category']==c for q in rows) for c in ('必修','一般','状況設定')}
    if (len(rows),comp)!=(240,{'必修':50,'一般':130,'状況設定':60}):
        raise SystemExit(f'exam {exam}: composition mismatch {len(rows)} {comp}')
if media_count!=38:
    raise SystemExit(f'expected 38 media questions, got {media_count}')

free_ids=[]
for category in ('必修','一般','状況設定'):
    # Canonical deterministic sample: earliest 8 questions across the newest exam.
    free_ids += [q['id'] for q in questions if q['sourceExam']==115 and q['category']==category][:8]

payload={
    'schemaVersion':1,'qualification':'看護師国家試験','contentVersion':'kangoshi-2026-08-canonical-720',
    'totalQuestions':720,'exams':[115,114,113],'freeSampleQuestionIds':free_ids,
    'questions':questions
}
(OUT/'questions.generated.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
audit={
    'schemaVersion':1,'questions':len(questions),'uniqueIds':len({q['id'] for q in questions}),
    'byExam':{str(e):len(rows) for e,rows in by_exam.items()},'mediaQuestions':media_count,
    'copiedMediaAssets':len(list(MEDIA_OUT.iterdir())),'freeSampleQuestions':len(free_ids),
    'scoringExceptions':len(scoring_modes),'pass':True
}
(OUT/'native-content-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False))
