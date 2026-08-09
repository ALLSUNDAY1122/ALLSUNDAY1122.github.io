#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
out=[]
for round_no,set_id in enumerate(('set1','set2','set3'),1):
    p=RAW/f'{set_id}-raw.json'
    if not p.exists():
        raise SystemExit(f'missing raw dataset: {p}')
    d=json.loads(p.read_text(encoding='utf-8'))
    for q in d.get('questions',[]):
        out.append({
            'id':q['id'],
            'round':round_no,
            'subject':q['category'],
            'topic':q.get('subject') or '',
            'question':q['question'],
            'choices':q.get('choices') or [],
            'answer_type':q['answerType'],
            'answer':q.get('answer'),
            'accepted_answers':q.get('officialAcceptedAnswers') or [],
            'scoring_status':q.get('officialScoringStatus','normal'),
            'requires_media':bool(q.get('requiresMedia')),
            'source_url':(q.get('sourceRefs') or [''])[0],
            'origin_type':'licensed_official',
            'rights_basis':q.get('rightsStatus') or '',
            'source_exam':q.get('sourceExam'),
            'source_refs':q.get('sourceRefs') or []
        })

path=RAW/'common-audit-input.json'
path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'wrote {len(out)} questions to {path}')
