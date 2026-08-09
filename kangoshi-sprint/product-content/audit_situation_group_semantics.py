#!/usr/bin/env python3
import json,re,sys
from collections import Counter,defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'
errors=[]; warnings=[]; groups=defaultdict(list)

for sid in ('set1','set2','set3'):
    data=json.loads((OUT/f'{sid}-classified.json').read_text(encoding='utf-8'))
    for q in data['questions']:
        if q.get('category')!='状況設定': continue
        groups[q['scenarioId']].append(q)
        qid=q['id']; major=q.get('majorSubject'); stem=str(q.get('question') or ''); scenario=str(q.get('scenario') or '')

        # Situation questions should be classified by applied nursing/pathology,
        # not by generic anatomy/physiology simply because a distractor contains a body part.
        if major=='人体の構造と機能':
            errors.append(f'{qid}: situation question classified as 人体の構造と機能')

        # Patient is explicitly a child.
        child_patient=bool(re.search(r'A\s*ちゃん|A\s*君|A\s*くん|\b小児\b|二分脊椎.*[男女]児|自閉スペクトラム症.*[男女]児',scenario,re.I))
        if child_patient and major not in {'小児看護学','健康支援と社会保障制度'}:
            errors.append(f'{qid}: explicit pediatric patient but classified {major}')

        # Maternal/perinatal patient context. Allow a clearly system/legal stem to override.
        maternal=bool(re.search(r'妊娠\s*\d+週|妊婦|産褥|褥婦|分娩|帝王切開.*出生|胎児心拍',scenario,re.I))
        system_stem=bool(re.search(r'法律|制度|保険|給付|届出|支援法',stem,re.I))
        if maternal and not system_stem and major not in {'母性看護学','小児看護学'}:
            errors.append(f'{qid}: maternal/perinatal case but classified {major}')

        # Very-old/end-of-life geriatric case. Ethics/integration is allowed for explicit
        # decision-making questions, but generic adult-disease classification is not.
        geriatric_end=bool(re.search(r'介護老人福祉施設|介護老人保健施設|老衰|102\s*歳|100\s*歳|看取り',scenario,re.I))
        ethics_stem=bool(re.search(r'意思決定|私らしく死|延命|尊厳|家族.*説明|看取り',stem,re.I))
        if geriatric_end:
            allowed={'老年看護学','看護の統合と実践'} if ethics_stem else {'老年看護学'}
            if major not in allowed:
                errors.append(f'{qid}: geriatric/end-of-life case expects {sorted(allowed)}, got {major}')

        # Disaster case should not be reduced to a routine technique unless the stem
        # explicitly asks about a technical procedure independent of disaster response.
        disaster=bool(re.search(r'大地震|震度\s*[5-7]|発災直後|避難所',scenario,re.I))
        regional_stem=bool(re.search(r'訪問看護|在宅|避難行動要支援',stem,re.I))
        if disaster and not regional_stem and major not in {'看護の統合と実践','基礎看護学'}:
            errors.append(f'{qid}: disaster case classified {major}')

for scenario_id,qs in sorted(groups.items()):
    qs=sorted(qs,key=lambda q:q['questionNo'])
    majors=Counter(q['majorSubject'] for q in qs)
    scenario=str(qs[0].get('scenario') or '')
    if len(qs)!=3:
        errors.append(f'{scenario_id}: expected 3 questions, got {len(qs)}')
    if majors.get('人体の構造と機能')==3:
        errors.append(f'{scenario_id}: all three situation questions classified as anatomy/physiology')
    if re.search(r'認知症|Alzheimer|レビー小体',scenario,re.I) and '老年看護学' not in majors:
        warnings.append(f'{scenario_id}: dementia case has no 老年看護学 question: {dict(majors)}')
    if re.search(r'訪問看護|在宅療養|自宅で療養|要介護',scenario,re.I) and '地域・在宅看護論' not in majors:
        warnings.append(f'{scenario_id}: home-care case has no 地域・在宅看護論 question: {dict(majors)}')

report={'groupCount':len(groups),'questionCount':sum(len(v) for v in groups.values()),'errors':errors,'warnings':warnings,'pass':not errors}
(OUT/'situation-semantic-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'groups':len(groups),'questions':report['questionCount'],'errors':len(errors),'warnings':len(warnings),'pass':not errors},ensure_ascii=False))
if errors:
    print('\n'.join(errors[:150])); sys.exit(1)
