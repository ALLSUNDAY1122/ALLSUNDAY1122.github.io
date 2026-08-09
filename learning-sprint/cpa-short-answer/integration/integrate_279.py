#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from collections import Counter
from pathlib import Path

BASE=Path(__file__).resolve().parent
ROOT=BASE.parent
R8=ROOT/'r8-content'/'questions-r8-official.json'
R8_AUDIT=ROOT/'r8-content'/'audit-result.json'
R9=ROOT/'r9-mock'/'questions-r9-mock.json'
OUT=BASE/'questions-all-279.json'
REPORT=BASE/'audit-integration-279.json'

def convert_r8(q):
    r=1 if q['round_key']=='R8-I' else 2
    basis='2025-04-01' if r==1 else '2026-04-01'
    official_choice=q['correct_choice']
    choice_text=q['choices'][q['correct_index']]
    return {
      'id':q['id'],'round':r,'round_label':q['round'],'subject':q['subject'],
      'topic':f"公式問題/{q['subject']}/Q{q['question_no']}",'question':q['question'],'choices':q['choices'],'correct_index':q['correct_index'],
      'explanation':f"公式正解・配点表では選択肢{official_choice}「{choice_text}」が正解。問題本文・回答肢・正解番号・配点は公認会計士・監査審査会の公式PDFから直接取り込み、SHA-256付きで照合済み。",
      'explanation_type':'official_answer_mapping','primary_basis':'公認会計士・監査審査会 公式試験問題・公式正解配点表',
      'source_url':q['source_pdf_url'],'answer_source_url':q['answer_pdf_url'],'scope_url':'https://www.fsa.go.jp/cpaaob/kouninkaikeishi-shiken/r8shiken/hani8-a.html' if r==1 else 'https://www.fsa.go.jp/cpaaob/kouninkaikeishi-shiken/hani8-d.html',
      'basis_date':basis,'origin_type':'licensed_official','rights_basis':q['rights_basis'],'rights_review':q['rights_review'],
      'language':'ja','points':q['points'],'source_pdf_sha256':q['source_pdf_sha256'],'source_segment_sha256':q['source_segment_sha256']
    }

def main():
    r8_a=json.loads(R8_AUDIT.read_text(encoding='utf-8'))
    raw8=json.loads(R8.read_text(encoding='utf-8')); r9=json.loads(R9.read_text(encoding='utf-8'))
    errors=[]
    if r8_a.get('status')!='PASS' or r8_a.get('actual_total')!=186 or r8_a.get('rights_review_pass_count')!=186: errors.append('R8監査証跡がPASS/186でない')
    if len(raw8)!=186: errors.append(f'R8件数 {len(raw8)}/186')
    if len(r9)!=93: errors.append(f'R9独自模試件数 {len(r9)}/93')
    allq=[convert_r8(q) for q in raw8]+r9
    if len(allq)!=279: errors.append(f'統合件数 {len(allq)}/279')
    ids=[q['id'] for q in allq]
    if len(ids)!=len(set(ids)): errors.append('統合ID重複')
    counts=Counter((q['round'],q['subject']) for q in allq)
    expected={'企業法':20,'管理会計論':18,'監査論':20,'財務会計論':35}
    for r in (1,2,3):
        for s,n in expected.items():
            if counts[(r,s)]!=n: errors.append(f'第{r}回/{s}: {counts[(r,s)]}/{n}')
    pts=Counter()
    for q in allq: pts[q['round']]+=q.get('points',0)
    for r in (1,2,3):
        if pts[r]!=500: errors.append(f'第{r}回配点 {pts[r]}/500')
    for q in allq:
        if not q.get('explanation') or not q.get('source_url') or not q.get('basis_date') or not q.get('rights_basis'): errors.append(f"{q['id']}: 統合必須項目欠損")
        if not isinstance(q.get('correct_index'),int) or not 0<=q['correct_index']<len(q.get('choices',[])): errors.append(f"{q['id']}: 正解index不正")
    report={
      'audit':'CPA short-answer 3-round 279-question integration','status':'PASS' if not errors else 'FAIL','total':len(allq),
      'round_counts':{str(r):sum(1 for q in allq if q['round']==r) for r in (1,2,3)},'round_points':{str(r):pts[r] for r in (1,2,3)},
      'round_types':{'1':'R8-I licensed official','2':'R8-II licensed official','3':'R9-I-scope independent mock'},
      'r8_rights_review_pass':r8_a.get('rights_review_pass_count'),'r9_origin':'original_from_primary_source',
      'checks':['279件','3回×4科目件数','各回500点','ID重複','正解index','解説存在','一次/公式出典','基準日','rights_basis','R8監査証跡'],
      'errors':errors,
      'notice':'第1・2回は令和8年公式問題。第3回は令和9年公式問題ではなく、令和9年第I回出題範囲を反映した独自模試。'
    }
    OUT.write_text(json.dumps(allq,ensure_ascii=False,indent=2),encoding='utf-8')
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'status':report['status'],'total':len(allq),'round_points':report['round_points'],'errors':len(errors)},ensure_ascii=False))
    if errors:
        for e in errors: print('FAIL:',e)
        sys.exit(1)
if __name__=='__main__': main()
