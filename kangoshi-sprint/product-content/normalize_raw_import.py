#!/usr/bin/env python3
import json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
CONTROL=re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f]')
PRINTER=re.compile(r'\s*DKIX[^\n]*(?:\.smd|\.indd)[^\n]*$',re.IGNORECASE)
MEDIA_WORDS=('図を示す','図に示す','写真を示す','別冊','画像を示す','グラフを示す','表を示す')


def clean_text(value):
    text=str(value or '')
    text=CONTROL.sub('',text)
    text=PRINTER.sub('',text)
    return re.sub(r'\s+',' ',text).strip()


summary=[]
for set_id in ('set1','set2','set3'):
    path=RAW/f'{set_id}-raw.json'
    if not path.exists():
        raise SystemExit(f'missing raw file: {path}')
    data=json.loads(path.read_text(encoding='utf-8'))
    inferred_media=0; explicit_media=0; cleaned_fields=0
    for q in data.get('questions',[]):
        old=q.get('question') or ''
        new=clean_text(old)
        if new!=old: cleaned_fields+=1
        q['question']=new
        choices=[]
        for choice in q.get('choices') or []:
            cleaned=clean_text(choice)
            if cleaned!=choice: cleaned_fields+=1
            choices.append(cleaned)
        q['choices']=choices

        explicit=any(word in new for word in MEDIA_WORDS)
        image_choice=(q.get('answerType') in {'singleChoice','multiChoice'} and len(choices)==0)
        if explicit:
            q['requiresMedia']=True
            q['mediaDetectionReason']='explicit_reference_in_stem'
            explicit_media+=1
        elif image_choice:
            q['requiresMedia']=True
            q['mediaDetectionReason']='non_text_choices_inferred'
            q['mediaEvidenceStatus']='visual_verification_required'
            inferred_media+=1
        else:
            q['mediaDetectionReason']='not_detected'

        if q.get('requiresMedia'):
            q['mediaAuditStatus']='pending'
            q['rightsStatus']='mhlw-pdl1.0-text; media-pending'
        else:
            q['mediaAuditStatus']='not_required'
            q['rightsStatus']='mhlw-pdl1.0-text'

    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary.append({'set':set_id,'explicitMedia':explicit_media,'inferredImageChoices':inferred_media,'cleanedFields':cleaned_fields})

out=RAW/'normalization-summary.json'
out.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
