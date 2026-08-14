#!/usr/bin/env python3
import json,re,sys
from collections import Counter,defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

STEM_EXPECT=[
 (r'妊娠|妊婦|分娩|産褥|褥婦|胎児|不妊治療|子宮復古|経産道感染', {'母性看護学'}, 'maternal-explicit'),
 (r'永久歯|乳児|幼児|学童|小児|二分脊椎|ディストラクション|アタッチメント', {'小児看護学'}, 'pediatric-explicit'),
 (r'統合失調|神経性過食|境界性パーソナリティ|精神障害.*リカバリー|共同創造|コプロダクション|セルフヘルプグループ|社会生活技能訓練', {'精神看護学'}, 'mental-explicit'),
 (r'訪問看護|在宅療養|看護小規模多機能', {'地域・在宅看護論'}, 'community-explicit'),
 (r'障害者総合支援法|介護保険法|育児.*介護休業法|労働安全衛生法|人口動態統計|患者調査|医療法|人材確保の促進', {'健康支援と社会保障制度'}, 'system-explicit'),
 (r'災害|サイコロジカルファーストエイド|Psychological First Aid', {'看護の統合と実践'}, 'disaster-explicit'),
 (r'プライマリナーシング|看護部.*組織図|看護サービスの質|看護師長', {'看護の統合と実践'}, 'management-explicit'),
 (r'膀胱留置カテーテル|口腔内吸引|鼻腔内吸引|経鼻経管栄養|ボディメカニクス|病室の湿度|ストレッチャー|褥瘡の好発部位', {'基礎看護学'}, 'basic-skill-explicit'),
 (r'脊髄神経|心房と左心室の間.*弁|上行大動脈から分枝|胸管について|直腸の構造|味蕾|Corti|短期記憶', {'人体の構造と機能'}, 'anatomy-explicit'),
 (r'梅毒|肺結核|ヘリコバクター|重症筋無力症|メニエール|多発性筋炎|大動脈弁狭窄症|もやもや病|シェーグレン', {'疾病の成り立ちと回復の促進'}, 'disease-explicit'),
]
SCEN_EXPECT=[
 (r'妊娠|妊婦|分娩|産褥|胎児|新生児', {'母性看護学'}, 'maternal-scenario'),
 (r'A\s*ちゃん|A\s*君|A\s*くん|乳児|幼児|学童|小児|二分脊椎', {'小児看護学'}, 'pediatric-scenario'),
 (r'統合失調|神経性過食|境界性パーソナリティ|うつ病|双極|精神科', {'精神看護学'}, 'mental-scenario'),
 (r'震度\s*[5-7]|大地震|発災直後', {'看護の統合と実践'}, 'disaster-scenario'),
]
COMMUNITY_STEM=re.compile(r'訪問看護|在宅療養|在宅で|自宅.*療養|福祉避難所|ハザードマップ',re.I)

errors=[]; warnings=[]; total=0; majors=Counter(); per_set={}; scenario_groups=defaultdict(list)
for sid in ('set1','set2','set3'):
    p=OUT/f'{sid}-classified.json'
    if not p.exists():
        errors.append(f'{sid}: classified file missing'); continue
    data=json.loads(p.read_text(encoding='utf-8')); qs=data.get('questions',[])
    set_counts=Counter()
    for q in qs:
        total+=1; qid=q.get('id','?'); major=q.get('majorSubject'); stem=str(q.get('question') or ''); scen=str(q.get('scenario') or '')
        category=q.get('category')
        specialist=q.get('classificationSpecialistCorrection') if category=='状況設定' else None
        majors[major]+=1; set_counts[major]+=1

        stem_matches=[]
        for pattern,allowed,label in STEM_EXPECT:
            if category=='状況設定' and label in {'basic-skill-explicit','community-explicit'}:
                if re.search(pattern,stem,re.I):
                    warnings.append(f'{qid}: contextual stem domain {label}; assigned {major}')
                continue
            if category=='状況設定' and label=='disaster-explicit' and COMMUNITY_STEM.search(stem):
                if re.search(pattern,stem,re.I):
                    warnings.append(f'{qid}: home-care disaster preparedness; assigned {major} allowed as 地域・在宅看護論 or 看護の統合と実践')
                continue
            if re.search(pattern,stem,re.I):
                stem_matches.append((allowed,label))

        if stem_matches:
            union=set().union(*(x[0] for x in stem_matches))
            labels=[x[1] for x in stem_matches]
            if major not in union:
                if specialist:
                    warnings.append(f'{qid}: specialist situation correction overrides local stem domains {labels}; assigned {major}')
                else:
                    errors.append(f'{qid}: stem semantic domains {labels} allow {sorted(union)}, got {major}')
            if len(union)>1:
                warnings.append(f'{qid}: multi-domain stem {labels}; assigned {major} requires contextual review')

        if category=='状況設定' and scen:
            for pattern,allowed,label in SCEN_EXPECT:
                if re.search(pattern,scen,re.I) and major not in allowed:
                    stem_union=set().union(*(x[0] for x in stem_matches)) if stem_matches else set()
                    if major not in stem_union:
                        if specialist:
                            warnings.append(f'{qid}: specialist situation correction overrides scenario keyword domain {label}; assigned {major}')
                        else:
                            errors.append(f'{qid}: {label} expects {sorted(allowed)}, got {major}')
            if q.get('scenarioId'):
                scenario_groups[q['scenarioId']].append((qid,major,q.get('subject')))

    per_set[sid]=dict(set_counts)
    missing=[m for m in ['人体の構造と機能','疾病の成り立ちと回復の促進','健康支援と社会保障制度','基礎看護学','地域・在宅看護論','成人看護学','老年看護学','小児看護学','母性看護学','精神看護学','看護の統合と実践'] if set_counts[m]==0]
    if missing: warnings.append(f'{sid}: no questions classified to {missing}')

split_groups=[]
for scenario_id,rows in sorted(scenario_groups.items()):
    group_majors=Counter(r[1] for r in rows)
    if len(group_majors)>1:
        split_groups.append({'scenarioId':scenario_id,'majors':dict(group_majors),'questions':rows})
        if len(group_majors)>=3:
            errors.append(f'{scenario_id}: situation group split across 3 majors {dict(group_majors)}')
        else:
            warnings.append(f'{scenario_id}: situation group split {dict(group_majors)}; contextual review required')

report={
 'total':total,'majorCounts':dict(majors),'perSetMajorCounts':per_set,
 'strongSemanticErrors':errors,'splitScenarioGroups':split_groups,'warnings':warnings,
 'pass':not errors,
 'note':'独立ルールによる分類整合監査。状況設定では在宅・一般技術語を主分類の強制根拠にせず、在宅利用者の災害準備は地域・在宅看護論または災害看護を許容する。多領域設問は警告、単一の強い意味領域との矛盾はFAIL。ただし症例単位専門監査で理由・変更前後・scenarioIdを明示したclassificationSpecialistCorrectionは局所キーワードより優先し、矛盾を警告として残す。専門家監査の代替ではない。'
}
(OUT/'semantic-consistency-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'total':total,'errorCount':len(errors),'splitScenarioGroups':len(split_groups),'warningCount':len(warnings),'pass':not errors},ensure_ascii=False))
if errors:
    print('\n'.join(errors[:100])); sys.exit(1)
