#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from collections import Counter,defaultdict
from difflib import SequenceMatcher
from pathlib import Path

BASE=Path(__file__).resolve().parent
SCOPE='https://www.fsa.go.jp/cpaaob/kouninkaikeishi-shiken/hanir9-a.html'
ENGLISH='https://www.fsa.go.jp/cpaaob/kouninkaikeishi-shiken/r9shiken/r9eigosyutudai.html'
RIGHTS='一次資料の事実・規定・計算原理を参照して独自に作問。公式問題文・第三者解説の転載なし。'
SUBJECTS={'企業法':20,'管理会計論':18,'監査論':20,'財務会計論':35}

def norm(s):
    s=str(s).lower(); s=re.sub(r'\s+','',s); return re.sub(r'[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]','',s)

def expand_specs(path,subject):
    specs=json.loads((BASE/path).read_text(encoding='utf-8')); out=[]
    for x in specs:
        out.append({
            'id':f"CPA-R9-MOCK-{subject}-{x['n']:03d}",'round':3,'round_label':'第3回（令和9年対応・独自模試）',
            'subject':subject,'topic':x['t'],'question':x['q'],'choices':x['c'],'correct_index':x['a'],'explanation':x['e'],
            'primary_basis':x['b'],'source_url':x['u'],'scope_url':SCOPE,'basis_date':'2026-04-01',
            'origin_type':'original_from_primary_source','rights_basis':RIGHTS,'language':x['l'],'points':x['p'],
            'mock_status':'independent_mock_not_official_R9_question'
        })
    return out

def main():
    qs=json.loads((BASE/'questions-company-law.json').read_text(encoding='utf-8'))
    qs+=expand_specs('specs-management.json','管理会計論')
    qs+=expand_specs('specs-audit.json','監査論')
    qs+=expand_specs('specs-financial.json','財務会計論')
    errors=[]; warnings=[]
    required=['id','round','subject','topic','question','choices','correct_index','explanation','primary_basis','source_url','basis_date','origin_type','rights_basis','language','points']
    if len(qs)!=93: errors.append(f'総問題数 {len(qs)}/93')
    counts=Counter(q['subject'] for q in qs)
    for s,n in SUBJECTS.items():
        if counts[s]!=n: errors.append(f'{s} {counts[s]}/{n}')
    if sum(q['points'] for q in qs)!=500: errors.append('総配点が500点でない')
    ids=[q['id'] for q in qs]
    if len(ids)!=len(set(ids)): errors.append('ID重複')
    for q in qs:
        for f in required:
            if q.get(f) in (None,'',[]): errors.append(f"{q.get('id')}: {f}欠損")
        if not isinstance(q['correct_index'],int) or not 0<=q['correct_index']<len(q['choices']): errors.append(f"{q['id']}: 正解index不正")
        if q['basis_date']!='2026-04-01': errors.append(f"{q['id']}: 基準日不正")
        if not q['source_url'].startswith(('https://www.fsa.go.jp/','https://laws.e-gov.go.jp/','https://www.asb-j.jp/')): errors.append(f"{q['id']}: 一次資料ドメイン外")
        if q['origin_type']!='original_from_primary_source': errors.append(f"{q['id']}: origin_type不正")
    textmap=defaultdict(list)
    for q in qs: textmap[norm(q['question'])].append(q['id'])
    for v in textmap.values():
        if len(v)>1: errors.append(f'本文完全一致 {v}')
    for i in range(len(qs)):
        for j in range(i+1,len(qs)):
            ratio=SequenceMatcher(None,norm(qs[i]['question']),norm(qs[j]['question'])).ratio()
            if ratio>=0.90: errors.append(f"高類似 {ratio:.2f}: {qs[i]['id']} <-> {qs[j]['id']}")
    english=[q for q in qs if q['language']=='en']; ep=sum(q['points'] for q in english)
    if ep!=28: errors.append(f'英語配点 {ep}/28')
    if not (0.05<=ep/500<=0.06): errors.append('英語配点比率が5-6%外')
    if set(q['subject'] for q in english)!={'財務会計論','管理会計論','監査論'}: errors.append('英語出題科目不正')
    # 独立計算問題の期待答えを再計算して固定チェック
    calc_expected={
      'CPA-R9-MOCK-管理会計論-005':1,'CPA-R9-MOCK-管理会計論-007':2,'CPA-R9-MOCK-管理会計論-009':2,
      'CPA-R9-MOCK-管理会計論-010':2,'CPA-R9-MOCK-管理会計論-012':1,'CPA-R9-MOCK-管理会計論-013':0,
      'CPA-R9-MOCK-管理会計論-014':0,'CPA-R9-MOCK-管理会計論-015':0,'CPA-R9-MOCK-管理会計論-016':3,
      'CPA-R9-MOCK-管理会計論-017':3,'CPA-R9-MOCK-管理会計論-018':2,'CPA-R9-MOCK-財務会計論-006':1,
      'CPA-R9-MOCK-財務会計論-023':2,'CPA-R9-MOCK-財務会計論-030':2}
    byid={q['id']:q for q in qs}
    for qid,idx in calc_expected.items():
        if byid[qid]['correct_index']!=idx: errors.append(f'{qid}: 計算正解監査FAIL')
    result={
      'audit':'CPA R9 independent mock 93 question audit','status':'PASS' if not errors else 'FAIL','basis_date':'2026-04-01',
      'official_scope_url':SCOPE,'official_english_scope_url':ENGLISH,'counts':dict(counts),'total':len(qs),'points':sum(q['points'] for q in qs),
      'english_question_count':len(english),'english_points':ep,'english_ratio':ep/500,
      'checks':['必須項目','科目別件数','500点','正解index','一次資料URL','2026-04-01基準日','ID重複','本文完全一致','高類似>=0.90','英語3科目5-6%','計算問題固定再計算','権利由来'],
      'errors':errors,'warnings':warnings,
      'notice':'第3回は令和9年公式問題ではない。令和9年第I回の公式出題範囲・英語方針を反映した独自模試で、93問構成は現行R8構成を暫定継承。'
    }
    (BASE/'questions-r9-mock.json').write_text(json.dumps(qs,ensure_ascii=False,indent=2),encoding='utf-8')
    (BASE/'audit-r9-mock.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    topics={s:[{'question_no':int(q['id'].split('-')[-1]),'topic':q['topic'],'language':q['language'],'points':q['points'],'source_url':q['source_url']} for q in qs if q['subject']==s] for s in SUBJECTS}
    (BASE/'topic-map-r9.json').write_text(json.dumps({'status':result['status'],'basis_date':'2026-04-01','subjects':topics},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'status':result['status'],'questions':len(qs),'points':result['points'],'english_points':ep,'errors':len(errors)},ensure_ascii=False))
    if errors:
        for e in errors: print('FAIL:',e)
        sys.exit(1)

if __name__=='__main__': main()
