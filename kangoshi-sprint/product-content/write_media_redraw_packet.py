#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
audit=json.loads((ROOT/'media-rights-audit.json').read_text(encoding='utf-8'))
packet=json.loads((DRAFT/'media-audit-packet.json').read_text(encoding='utf-8'))
meta={x['id']:x for x in audit.get('items') or [] if x.get('status')=='needs_redraw'}
rows=[]
for q in packet.get('items') or []:
    if q.get('id') not in meta:continue
    m=meta[q['id']]
    rows.append({
        'id':q.get('id'),'sourceExam':q.get('sourceExam'),'session':q.get('session'),'questionNo':q.get('questionNo'),
        'question':q.get('question'),'choices':q.get('choices') or [],'answer':q.get('answer'),
        'point':q.get('point'),'detail':q.get('detail'),'reason':m.get('reason'),
        'questionPdf':m.get('questionPdf'),'questionPageIndex':m.get('questionPageIndex'),
        'bookletPdf':m.get('bookletPdf'),'bookletNo':m.get('bookletNo'),'bookletPageIndices':m.get('bookletPageIndices')
    })
rows.sort(key=lambda x:(-int(x.get('sourceExam') or 0),str(x.get('session')),int(x.get('questionNo') or 0)))
out={'schemaVersion':1,'count':len(rows),'items':rows}
(ROOT/'media-redraw-packet.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'needsRedraw':len(rows),'ids':[x['id'] for x in rows]},ensure_ascii=False))
