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
converted_svg=0

for sid in ('set1','set2','set3'):
    doc=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    rows=doc.get('questions') or []
    if len(rows)!=240:
        raise SystemExit(f'{sid}: expected 240, got {len(rows)}')
    for q in rows:
        at=q.get('answerType') or 'singleChoice'
        answer=q.get('answer')
        mode=scoring_modes.get(q['id'],'normal')
        accepted=[]
        numeric=None
        if mode=='excluded':
            # Officially excluded items intentionally have no app-created answer.
            accepted=[]
        elif at=='numeric':
            try: numeric=float(answer)
            except Exception: raise SystemExit(f"{q['id']}: invalid numeric answer {answer!r}")
        elif at=='multiChoice':
            vals=answer if isinstance(answer,list) else [answer]
            accepted=[sorted(int(v) for v in vals)]
        else:
            accepted=[[int(answer)]]
        if mode=='multiple_accepted':
            vals=q.get('officialAcceptedAnswers') or []
            if len(vals)<2: raise SystemExit(f"{q['id']}: multiple accepted choices missing")
            accepted=[[int(v)] for v in vals]
        assets=q.get('mediaAssets') or []
        native_assets=[]
        for rel in assets:
            src=APP/rel
            if not src.exists(): raise SystemExit(f"{q['id']}: missing media {rel}")
            if src.suffix.lower()=='.svg':
                try:
                    import cairosvg
                except ImportError as exc:
                    raise SystemExit('CairoSVG is required to rasterize original redraw SVGs') from exc
                dest=MEDIA_OUT/f'{src.stem}.png'
                cairosvg.svg2png(url=str(src),write_to=str(dest),output_width=1200)
                converted_svg+=1
            else:
                dest=MEDIA_OUT/src.name
                if dest.exists() and dest.read_bytes()!=src.read_bytes():
                    raise SystemExit(f'media filename collision: {src.name}')
                shutil.copy2(src,dest)
            native_assets.append(f'Media/{dest.name}')
        if q.get('mediaReleaseStatus')=='resolved': media_count+=1
        choices=q.get('choices') or []
        if not choices and at!='numeric':
            # Official image-only choice rows are represented by numbered panels
            # in the audited redraw; expose the corresponding 1–4 tap targets.
            choices=['①','②','③','④']
        questions.append({
            'id':q['id'],'sourceExam':int(q['sourceExam']),'session':q.get('session') or '',
            'questionNo':int(q.get('questionNo') or 0),'category':q.get('category') or '',
            'majorSubject':q.get('majorSubject') or 'その他・横断','subject':q.get('subject') or '',
            'answerType':at,'selectCount':q.get('selectCount'),
            'question':q.get('question') or '','choices':choices,
            'acceptedChoiceSets':accepted,'numericAnswer':numeric,
            'tolerance':float(q.get('tolerance') or 0),'unit':q.get('unit') or '',
            'point':q.get('point') or '','detail':q.get('detail') or '',
            'scenario':q.get('scenario') or '', 'scenarioId':q.get('scenarioId') or '',
            'scenarioIndex':int(q.get('scenarioIndex') or 0),'scenarioTotal':int(q.get('scenarioTotal') or 0),
            'scoringMode':mode,
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
if converted_svg!=23:
    raise SystemExit(f'expected 23 SVG redraw conversions, got {converted_svg}')
if sum(1 for q in questions if q['scoringMode']=='excluded' and not q['acceptedChoiceSets'])!=2:
    raise SystemExit('expected exactly 2 officially excluded questions with no accepted answer')

free_ids=[]
for category in ('必修','一般','状況設定'):
    free_ids += [q['id'] for q in questions if q['sourceExam']==115 and q['category']==category][:8]

payload={
    'schemaVersion':1,'qualification':'看護師国家試験','contentVersion':'kangoshi-2026-08-canonical-720',
    'totalQuestions':720,'exams':[115,114,113],'freeSampleQuestionIds':free_ids,
    'questions':questions
}
(OUT/'questions.generated.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
audit={
    'schemaVersion':3,'questions':len(questions),'uniqueIds':len({q['id'] for q in questions}),
    'byExam':{str(e):len(rows) for e,rows in by_exam.items()},'mediaQuestions':media_count,
    'copiedMediaAssets':len(list(MEDIA_OUT.iterdir())),'svgRedrawsRasterized':converted_svg,
    'freeSampleQuestions':len(free_ids),'scoringExceptions':len(scoring_modes),
    'officialExcludedWithoutAcceptedAnswer':2,'pass':True
}
(OUT/'native-content-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False))
