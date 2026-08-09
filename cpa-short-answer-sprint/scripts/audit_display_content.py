#!/usr/bin/env python3
from __future__ import annotations
import copy
import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
APP=ROOT/'cpa-short-answer-sprint'
DATA=ROOT/'learning-sprint/cpa-short-answer/integration/questions-all-279.json'
CORRECTIONS=APP/'data-display-corrections-v1.json'

ITEM_RE=re.compile(r'([アイウエオカキクケコ])．')
PDF_ARTIFACT_RE=re.compile(r'M\d+[―—−-]\d+(?:M\d+[―—−-]\d+)+')
CONTROL_RE=re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f]')
OFFICIAL_EX_RE=re.compile(r'選択肢(\d+)「([^」]*)」が正解')
ORDER='アイウエオカキクケコ'
errors=[]
warnings=[]

def fail(msg): errors.append(msg)
def warn(msg): warnings.append(msg)

def is_structured_question(text:str)->bool:
    labels=ITEM_RE.findall(text or '')
    if len(labels)<2 or labels[0]!='ア': return False
    pos=[ORDER.find(x) for x in labels]
    return all(x>=0 for x in pos) and all(pos[i]>pos[i-1] for i in range(1,len(pos)))

def format_question(text:str)->str:
    if not is_structured_question(text): return text
    return ITEM_RE.sub(r'\n\n\1．',text).lstrip('\n').strip()

def main():
    raw=json.loads(DATA.read_text(encoding='utf-8'))
    corr=json.loads(CORRECTIONS.read_text(encoding='utf-8'))
    if len(raw)!=279: fail(f'総問題数 {len(raw)}/279')
    by_id={q.get('id'):q for q in raw}
    if len(by_id)!=len(raw): fail('ID重複あり')

    source_artifacts=[]
    for q in raw:
        for i,c in enumerate(q.get('choices') or []):
            if PDF_ARTIFACT_RE.search(str(c)):
                source_artifacts.append((q.get('id'),i,str(c)))

    corrected=copy.deepcopy(raw)
    corrected_by_id={q['id']:q for q in corrected}
    applied=[]
    for qid,entry in (corr.get('questions') or {}).items():
        q=corrected_by_id.get(qid)
        if q is None:
            fail(f'補正対象IDが存在しない: {qid}')
            continue
        for rep in entry.get('choice_replacements') or []:
            idx=rep.get('index')
            if not isinstance(idx,int) or not 0<=idx<len(q.get('choices') or []):
                fail(f'{qid}: 補正index不正 {idx}')
                continue
            actual=q['choices'][idx]
            if actual not in (rep.get('from'),rep.get('to')):
                fail(f'{qid}: 補正元不一致 choice {idx+1}: {actual!r}')
                continue
            if actual==rep.get('from'):
                q['choices'][idx]=rep.get('to')
                if isinstance(q.get('explanation'),str):
                    q['explanation']=q['explanation'].replace(rep.get('from'),rep.get('to'))
                applied.append((qid,idx,rep.get('from'),rep.get('to')))

    expected={(qid,rep['index'],rep['from']) for qid,e in (corr.get('questions') or {}).items() for rep in e.get('choice_replacements') or []}
    actual={(qid,idx,text) for qid,idx,text in source_artifacts}
    if actual!=expected:
        fail(f'PDF由来破損と補正表が不一致: source={sorted(actual)} expected={sorted(expected)}')

    structured=0
    max_choices=0
    choice_counts={}
    official_checked=0
    for q in corrected:
        qid=q.get('id','?')
        text=str(q.get('question') or '')
        choices=q.get('choices')
        if not text.strip(): fail(f'{qid}: 問題本文が空')
        if CONTROL_RE.search(text): fail(f'{qid}: 問題本文に制御文字')
        if PDF_ARTIFACT_RE.search(text): fail(f'{qid}: 問題本文にPDFフッタ断片')
        if not isinstance(choices,list):
            fail(f'{qid}: choicesが配列でない')
            continue
        max_choices=max(max_choices,len(choices));choice_counts[len(choices)]=choice_counts.get(len(choices),0)+1
        if not 2<=len(choices)<=8: fail(f'{qid}: 選択肢数異常 {len(choices)}')
        cleaned=[str(c).strip() for c in choices]
        if any(not c for c in cleaned): fail(f'{qid}: 空の選択肢')
        if len(set(cleaned))!=len(cleaned): fail(f'{qid}: 選択肢重複 {cleaned}')
        for i,c in enumerate(cleaned):
            if CONTROL_RE.search(c): fail(f'{qid}: 選択肢{i+1}に制御文字')
            if PDF_ARTIFACT_RE.search(c): fail(f'{qid}: 選択肢{i+1}にPDFフッタ断片 {c!r}')
        ci=q.get('correct_index')
        if not isinstance(ci,int) or not 0<=ci<len(choices): fail(f'{qid}: correct_index不正 {ci}')
        if q.get('origin_type')=='licensed_official':
            official_checked+=1
            ex=str(q.get('explanation') or '')
            m=OFFICIAL_EX_RE.search(ex)
            if not m:
                fail(f'{qid}: 公式正解マッピング文を解析できない')
            elif isinstance(ci,int) and 0<=ci<len(choices):
                if int(m.group(1))-1!=ci: fail(f'{qid}: 解説の正解番号とcorrect_index不一致')
                if m.group(2)!=choices[ci]: fail(f'{qid}: 解説の正解肢本文とchoices不一致: {m.group(2)!r} != {choices[ci]!r}')
            if PDF_ARTIFACT_RE.search(ex): fail(f'{qid}: 解説にPDFフッタ断片')
        if is_structured_question(text):
            structured+=1
            formatted=format_question(text)
            if '\n\nア．' not in formatted or '\n\nイ．' not in formatted:
                fail(f'{qid}: ア・イ等の設問分割に失敗')

    # ユーザー報告の2問を個別に固定確認
    r1=corrected_by_id.get('CPA-R8-I-企業法-020')
    r2=corrected_by_id.get('CPA-R8-II-企業法-020')
    if not r1 or r1.get('choices',[None]*6)[5]!='ウエ' or r1.get('correct_index')!=5:
        fail('R8-I企業法Q20: 選択肢6「ウエ」/正解6の整合に失敗')
    if not r2 or r2.get('choices',[None]*6)[5]!='ウエ' or r2.get('correct_index')!=1 or r2.get('choices',[None,None])[1]!='アウ':
        fail('R8-II企業法Q20: 選択肢6「ウエ」/正解2「アウ」の整合に失敗')

    summary={
      'status':'PASS' if not errors else 'FAIL',
      'questions':len(raw),
      'source_pdf_artifacts':len(source_artifacts),
      'applied_repairs':len(applied),
      'structured_questions_auto_spaced':structured,
      'official_answer_mappings_checked':official_checked,
      'choice_count_distribution':dict(sorted(choice_counts.items())),
      'max_choices':max_choices,
      'errors':errors,
      'warnings':warnings,
      'repairs':[{'id':q,'choice':i+1,'from':f,'to':t} for q,i,f,t in applied]
    }
    out=APP/'audit'/'display-content-audit-result.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    if errors: sys.exit(1)

if __name__=='__main__': main()
