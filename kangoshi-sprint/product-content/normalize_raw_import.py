#!/usr/bin/env python3
import json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
CONTROL=re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f]')
PRINTER=re.compile(r'\s*DKIX[^\n]*(?:\.smd|\.indd)[^\n]*$',re.IGNORECASE)
# Be conservative: false-positive media deferral is safer than explaining a question
# without seeing a required figure. This catches wording variants such as
# "図をAに示す", "心電図を示す", "別冊写真" and similar PDF extraction spacing.
MEDIA_RE=re.compile(r'(?:図|写真|画像|グラフ|心電図|波形|別冊)|(?:表\s*(?:を|に|の))',re.IGNORECASE)
NEXT_SCENARIO=re.compile(r'\s*次の文を読み\s*\d{2,3}\s*[～〜－—―\-]\s*\d{2,3}\s*の問いに答えよ[。．]?\s*.*$',re.DOTALL)


def clean_text(value):
    text=str(value or '')
    text=CONTROL.sub('',text)
    text=PRINTER.sub('',text)
    text=re.sub(r'\s+',' ',text).strip()
    text=NEXT_SCENARIO.sub('',text).strip()
    return text


summary=[]
for set_id in ('set1','set2','set3'):
    path=RAW/f'{set_id}-raw.json'
    if not path.exists():
        raise SystemExit(f'missing raw file: {path}')
    data=json.loads(path.read_text(encoding='utf-8'))
    inferred_media=0; explicit_media=0; cleaned_fields=0; scenario_preambles_removed=0
    for q in data.get('questions',[]):
        old=q.get('question') or ''
        new=clean_text(old)
        if new!=old:
            cleaned_fields+=1
            if '次の文を読み' in old: scenario_preambles_removed+=1
        q['question']=new
        choices=[]
        for choice in q.get('choices') or []:
            cleaned=clean_text(choice)
            if cleaned!=choice:
                cleaned_fields+=1
                if '次の文を読み' in str(choice): scenario_preambles_removed+=1
            choices.append(cleaned)
        q['choices']=choices

        explicit=bool(MEDIA_RE.search(new))
        image_choice=(q.get('answerType') in {'singleChoice','multiChoice'} and len(choices)==0)
        if explicit:
            q['requiresMedia']=True
            q['mediaDetectionReason']='media_reference_in_stem_conservative'
            explicit_media+=1
        elif image_choice:
            q['requiresMedia']=True
            q['mediaDetectionReason']='non_text_choices_inferred'
            q['mediaEvidenceStatus']='visual_verification_required'
            inferred_media+=1
        else:
            q['requiresMedia']=False
            q['mediaDetectionReason']='not_detected'
            q.pop('mediaEvidenceStatus',None)

        if q.get('requiresMedia'):
            q['mediaAuditStatus']='pending'
            q['rightsStatus']='mhlw-pdl1.0-text; media-pending'
        else:
            q['mediaAuditStatus']='not_required'
            q['rightsStatus']='mhlw-pdl1.0-text'

    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary.append({
        'set':set_id,
        'explicitMedia':explicit_media,
        'inferredImageChoices':inferred_media,
        'cleanedFields':cleaned_fields,
        'scenarioPreamblesRemoved':scenario_preambles_removed
    })

out=RAW/'normalization-summary.json'
out.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
