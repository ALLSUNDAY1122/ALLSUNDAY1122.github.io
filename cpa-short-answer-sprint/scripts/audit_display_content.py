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
OFFICIAL_EX_RE=re.compile(r'公式正解・配点表では選択肢(\d+)「([^」]*)」が正解。')
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

def sync_official_explanation(q:dict)->None:
    if q.get('origin_type')!='licensed_official' or not isinstance(q.get('explanation'),str): return
    ci=q.get('correct_index')
    choices=q.get('choices') or []
    if not isinstance(ci,int) or not 0<=ci<len(choices): return
    mapping=f'公式正解・配点表では選択肢{ci+1}「{choices[ci]}」が正解。'
    if OFFICIAL_EX_RE.search(q['explanation']):
        q['explanation']=OFFICIAL_EX_RE.sub(mapping,q['explanation'],count=1)
    else:
        q['explanation']=mapping+q['explanation']

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
    table_repairs=[]
    for qid,entry in (corr.get('questions') or {}).items():
        q=corrected_by_id.get(qid)
        if q is None:
            fail(f'補正対象IDが存在しない: {qid}')
            continue
        if entry.get('choices_to') is not None:
            source=entry.get('choices_from')
            target=entry.get('choices_to')
            if q.get('choices') not in (source,target):
                fail(f'{qid}: 表形式補正元不一致: {q.get("choices")!r}')
            elif q.get('choices')==source:
                q['choices']=copy.deepcopy(target)
                table_repairs.append(qid)
                applied.append({'id':qid,'kind':'table_choices','count':len(target)})
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
                applied.append({'id':qid,'kind':'choice','choice':idx+1,'from':rep.get('from'),'to':rep.get('to')})
        sync_official_explanation(q)

    expected_artifacts={(qid,rep['index'],rep['from']) for qid,e in (corr.get('questions') or {}).items() for rep in e.get('choice_replacements') or []}
    actual_artifacts={(qid,idx,text) for qid,idx,text in source_artifacts}
    if actual_artifacts!=expected_artifacts:
        fail(f'PDF由来破損と補正表が不一致: source={sorted(actual_artifacts)} expected={sorted(expected_artifacts)}')

    expected_tables={qid for qid,e in (corr.get('questions') or {}).items() if e.get('choices_to') is not None}
    raw_table_collapses={q['id'] for q in raw if isinstance(q.get('choices'),list) and (any(str(c).strip()=='' for c in q['choices']) or len(set(str(c).strip() for c in q['choices']))<len(q['choices']))}
    if raw_table_collapses!=expected_tables:
        fail(f'表形式崩壊と補正表が不一致: source={sorted(raw_table_collapses)} expected={sorted(expected_tables)}')

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

    # 公式PDFで再確認した重要回帰条件
    fixed_expectations={
      'CPA-R8-I-企業法-020':(5,'ウエ'),
      'CPA-R8-II-企業法-020':(1,'アウ'),
      'CPA-R8-I-財務会計論-019':(1,'ア：〇　イ：×　ウ：〇'),
      'CPA-R8-I-財務会計論-020':(5,'① 622, 300 円／② 623, 252 円'),
      'CPA-R8-II-財務会計論-020':(5,'① 71, 731 千円／② 23, 210 千円')
    }
    for qid,(ci,answer) in fixed_expectations.items():
        q=corrected_by_id.get(qid)
        if not q or q.get('correct_index')!=ci or q.get('choices',[None]*6)[ci]!=answer:
            fail(f'{qid}: 公式PDF/正解表との固定整合に失敗 expected={ci+1}:{answer}')

    summary={
      'status':'PASS' if not errors else 'FAIL',
      'questions':len(raw),
      'source_pdf_artifacts':len(source_artifacts),
      'source_table_collapses':len(raw_table_collapses),
      'applied_repairs':len(applied),
      'structured_questions_auto_spaced':structured,
      'official_answer_mappings_checked':official_checked,
      'choice_count_distribution':dict(sorted(choice_counts.items())),
      'max_choices':max_choices,
      'errors':errors,
      'warnings':warnings,
      'repairs':applied
    }
    out=APP/'audit'/'display-content-audit-result.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    if errors: sys.exit(1)

if __name__=='__main__': main()
