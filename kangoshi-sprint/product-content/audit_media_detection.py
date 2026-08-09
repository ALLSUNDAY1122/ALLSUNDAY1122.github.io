#!/usr/bin/env python3
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
MEDIA_RE=re.compile(r'(?:図|写真|画像|グラフ|心電図|波形|別冊)|(?:表\s*(?:を|に|の))',re.I)
errors=[]; flagged=[]; total=0
for sid in ('set1','set2','set3'):
    data=json.loads((RAW/f'{sid}-raw.json').read_text(encoding='utf-8'))
    for q in data.get('questions',[]):
        total+=1; stem=str(q.get('question') or '')
        cue=bool(MEDIA_RE.search(stem))
        no_text_choices=q.get('answerType') in {'singleChoice','multiChoice'} and len(q.get('choices') or [])==0
        required=bool(q.get('requiresMedia'))
        if cue or no_text_choices:
            flagged.append(q['id'])
            if not required: errors.append(f"{q['id']}: media cue/non-text choices but requiresMedia=false")
            if q.get('mediaAuditStatus')!='pending': errors.append(f"{q['id']}: mediaAuditStatus must be pending")
            if 'media-pending' not in str(q.get('rightsStatus') or ''): errors.append(f"{q['id']}: rightsStatus missing media-pending")
report={'total':total,'flaggedCount':len(flagged),'flaggedIds':flagged,'errors':errors,'pass':not errors}
(RAW/'media-detection-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'total':total,'flaggedCount':len(flagged),'errorCount':len(errors),'pass':not errors},ensure_ascii=False))
if errors:
    print('\n'.join(errors)); sys.exit(1)
