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
CORRECTIONS_PATH=ROOT/'source-data-corrections.json'


def clean_text(value):
    text=str(value or '')
    text=CONTROL.sub('',text)
    text=PRINTER.sub('',text)
    text=re.sub(r'\s+',' ',text).strip()
    text=NEXT_SCENARIO.sub('',text).strip()
    return text


def load_corrections():
    if not CORRECTIONS_PATH.exists():
        return {}
    doc=json.loads(CORRECTIONS_PATH.read_text(encoding='utf-8'))
    rows=doc.get('corrections') or []
    out={}
    for row in rows:
        qid=row.get('id')
        if not qid:
            raise SystemExit('source-data-corrections: id missing')
        if qid in out:
            raise SystemExit(f'source-data-corrections: duplicate id {qid}')
        out[qid]=row
    return out


def apply_verified_correction(q,set_id,row):
    qid=q.get('id')
    if row.get('setId')!=set_id:
        raise SystemExit(f'{qid}: correction set mismatch {row.get("setId")}/{set_id}')
    if row.get('category') and q.get('category')!=row.get('category'):
        raise SystemExit(f'{qid}: correction category mismatch {q.get("category")}/{row.get("category")}')
    expected=row.get('expectedOfficialAcceptedAnswers')
    if expected is not None and q.get('officialAcceptedAnswers')!=expected:
        raise SystemExit(f'{qid}: officialAcceptedAnswers changed; refusing correction')

    if 'question' in row:
        q['question']=clean_text(row['question'])
    if 'choices' in row:
        q['choices']=[clean_text(x) for x in row['choices']]
    patches=row.get('choicePatches') or {}
    if patches:
        choices=list(q.get('choices') or [])
        for raw_idx,value in patches.items():
            idx=int(raw_idx)
            if idx<0 or idx>=len(choices):
                raise SystemExit(f'{qid}: choice patch index out of range {idx}/{len(choices)}')
            choices[idx]=clean_text(value)
        q['choices']=choices

    q['sourceCorrectionStatus']='official_pdf_verified'
    q['sourceCorrectionCheckedDate']=json.loads(CORRECTIONS_PATH.read_text(encoding='utf-8')).get('checkedDate')
    q['sourceCorrectionRef']=row.get('sourceRef')
    return q


corrections=load_corrections()
applied_corrections=[]
summary=[]
for set_id in ('set1','set2','set3'):
    path=RAW/f'{set_id}-raw.json'
    if not path.exists():
        raise SystemExit(f'missing raw file: {path}')
    data=json.loads(path.read_text(encoding='utf-8'))
    inferred_media=0; explicit_media=0; cleaned_fields=0; scenario_preambles_removed=0; corrected=0
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

        correction=corrections.get(q.get('id'))
        if correction:
            apply_verified_correction(q,set_id,correction)
            corrected+=1
            applied_corrections.append(q['id'])

        new=q.get('question') or ''
        choices=q.get('choices') or []
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
        'scenarioPreamblesRemoved':scenario_preambles_removed,
        'verifiedSourceCorrectionsApplied':corrected
    })

if set(applied_corrections)!=set(corrections):
    missing=sorted(set(corrections)-set(applied_corrections))
    unexpected=sorted(set(applied_corrections)-set(corrections))
    raise SystemExit(f'source correction application mismatch missing={missing} unexpected={unexpected}')

out=RAW/'normalization-summary.json'
out.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'sets':summary,'sourceCorrectionsApplied':sorted(applied_corrections)},ensure_ascii=False))
