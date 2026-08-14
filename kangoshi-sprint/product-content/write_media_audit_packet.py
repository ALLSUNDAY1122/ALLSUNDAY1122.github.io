#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
MEDIA_RE=re.compile(r'(?:図|写真|画像|グラフ|心電図|波形|別冊)|(?:表\s*(?:を|に|の))',re.I)
items=[]
for sid in ('set1','set2','set3'):
    doc=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    for q in doc.get('questions') or []:
        stem=str(q.get('question') or '')
        media=bool(q.get('requiresMedia')) or bool(MEDIA_RE.search(stem)) or (q.get('answerType') in {'singleChoice','multiChoice'} and len(q.get('choices') or [])==0)
        if not media: continue
        items.append({
            'id':q.get('id'),'sourceExam':q.get('sourceExam'),'session':q.get('session'),'questionNo':q.get('questionNo'),
            'category':q.get('category'),'question':q.get('question'),'choices':q.get('choices') or [],'answer':q.get('answer'),
            'sourceRequiresMedia':bool(q.get('requiresMedia')),'sourceRefs':q.get('sourceRefs') or [],
            'media':q.get('media'),'mediaRefs':q.get('mediaRefs') or [],'mediaSourceRefs':q.get('mediaSourceRefs') or [],
            'point':q.get('point'),'detail':q.get('detail'),'evidenceRefs':q.get('explanationEvidenceRefs') or [],
            'officialScoringStatus':q.get('officialScoringStatus'),'scoringExceptionStatus':q.get('scoringExceptionStatus')
        })
items.sort(key=lambda r:(-int(r.get('sourceExam') or 0),str(r.get('session')),int(r.get('questionNo') or 0)))
by_exam={str(e):sum(1 for x in items if int(x.get('sourceExam') or 0)==e) for e in (115,114,113)}
out={'schemaVersion':1,'count':len(items),'byExam':by_exam,'items':items}
(DRAFT/'media-audit-packet.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(DRAFT/'media-audit-ids.json').write_text(json.dumps({'schemaVersion':1,'count':len(items),'byExam':by_exam,'ids':[x['id'] for x in items]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'count':len(items),'byExam':by_exam},ensure_ascii=False))
