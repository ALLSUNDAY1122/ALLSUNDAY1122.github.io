#!/usr/bin/env python3
import json,re
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

# Strong stem rules derived from FAILs. These match the subject being tested,
# not incidental distractors.
STEM_RULES=[
 (r'居宅サービス計画|ケアプラン', '健康支援と社会保障制度','介護保険制度'),
 (r'深部静脈血栓症.*危険因子', '疾病の成り立ちと回復の促進','循環器の病態'),
 (r'包帯法|包帯.*固定', '基礎看護学','安全・安楽'),
 (r'法律とその内容|最も新しく制定された法律', '健康支援と社会保障制度','保健医療福祉制度'),
 (r'高齢の親の介護.*家族の発達課題', '老年看護学','高齢者と家族'),
 (r'看護職員の交代勤務|看護職員.*勤務', '看護の統合と実践','看護管理'),
 (r'外国籍.*お祈り|外国籍.*宗教|宗教的', '看護の統合と実践','倫理・国際看護'),
 (r'^体液について|体液の分布|細胞外液|細胞内液', '人体の構造と機能','体液・恒常性'),
 (r'バソプレシン', '人体の構造と機能','腎・内分泌の機能'),
 (r'腰部脊柱管狭窄症|間欠性跛行', '疾病の成り立ちと回復の促進','運動器の病態'),
 (r'子宮頸癌.*異常に増殖|癌で異常に増殖', '疾病の成り立ちと回復の促進','腫瘍・病理'),
 (r'食物アレルギー.*[男女]児|A\s*ちゃん.*アレルギー', '小児看護学','小児の健康障害'),
 (r'エネルギー代謝|異化|同化', '人体の構造と機能','代謝の機能'),
 (r'発症にダニ|ダニが関与', '疾病の成り立ちと回復の促進','アレルギー・感染'),
 (r'貼付剤|薬剤の形状|剤形', '疾病の成り立ちと回復の促進','薬理'),
 (r'老視|老眼', '人体の構造と機能','感覚器'),
 (r'胎生週.*胚|胚子.*分化|胚葉', '人体の構造と機能','発生・生殖'),
 (r'重症筋無力症', '疾病の成り立ちと回復の促進','神経・筋疾患'),
 (r'患者調査|入院医療で正しい', '健康支援と社会保障制度','保健統計'),
 (r'患者の個別性|個別性を理解', '基礎看護学','看護の基本概念'),
 (r'客観的情報の記録|主観的情報|SOAP', '基礎看護学','看護記録'),
 (r'リラクセーション.*腹式呼吸|腹式呼吸の方法', '基礎看護学','安楽・リラクセーション'),
 (r'CO2\s*ナルコーシス|高濃度の酸素吸入', '疾病の成り立ちと回復の促進','呼吸器の病態'),
 (r'新鮮凍結血漿', '基礎看護学','輸血・輸液'),
 (r'介護保険制度のケアマネジメント', '健康支援と社会保障制度','介護保険制度'),
 (r'急性期の患者に起きる生体反応', '疾病の成り立ちと回復の促進','侵襲・生体反応'),
 (r'セルフヘルプグループ', '精神看護学','地域精神保健'),
 (r'悪液質', '疾病の成り立ちと回復の促進','がんの病態'),
 (r'がん患者の家族.*社会的苦痛|社会的苦痛', '成人看護学','がん看護'),
 (r'膵頭十二指腸切除術|ドレーンを留置する場所', '成人看護学','周術期・消化器'),
 (r'自己血糖測定', '成人看護学','糖尿病看護'),
 (r'骨髄検査|骨髄穿刺', '基礎看護学','検査・処置の援助'),
 (r'脊髄造影', '基礎看護学','検査・処置の援助'),
 (r'看護小規模多機能|通い.*訪問.*泊まり', '地域・在宅看護論','地域密着型サービス'),
 (r'ポリファーマシー', '老年看護学','高齢者の薬物療法'),
 (r'介護医療院', '健康支援と社会保障制度','介護保険制度'),
 (r'夜尿症|nocturnal enuresis', '小児看護学','小児の健康障害'),
 (r'セクシュアリティ', '母性看護学','性と生殖の健康'),
 (r'プレコンセプションケア|ノンストレステスト|NST|子宮復古不全', '母性看護学','妊娠・分娩・産褥'),
 (r'知的障害|社会生活技能訓練|SST', '精神看護学','精神障害とリハビリテーション'),
 (r'門脈系の血管|門脈系', '人体の構造と機能','循環・消化器の構造'),
 (r'大動脈弁狭窄症', '疾病の成り立ちと回復の促進','循環器の病態'),
 (r'内臓脂肪.*推定|腹囲.*内臓脂肪', '健康支援と社会保障制度','生活習慣病予防'),
 (r'体格指数|BMI.*求め', '健康支援と社会保障制度','健康評価'),
]

STEM_SPECIALTY=[
 (r'訪問看護|在宅療養|地域連携|退院支援|退院調整', '地域・在宅看護論','在宅療養・地域連携'),
 (r'妊婦|妊娠|分娩|産褥|褥婦|胎児|新生児|授乳|乳腺炎', '母性看護学','母性看護'),
 (r'乳児|幼児|学童|A\s*ちゃん|[男女]児|小児', '小児看護学','小児看護'),
 (r'統合失調|うつ病|双極|パニック|精神科|幻聴|妄想|リエゾン精神', '精神看護学','精神看護'),
 (r'認知症|レビー小体|BPSD', '老年看護学','認知症看護'),
]

SCENARIO_SPECIALTY=[
 (r'妊婦|妊娠|分娩|産褥|褥婦|胎児|新生児', '母性看護学','母性看護'),
 (r'\d+\s*歳[^。]{0,20}(男児|女児)|乳児|幼児|学童|小児', '小児看護学','小児看護'),
 (r'統合失調|うつ病|双極|パニック障害|精神科|幻聴|妄想|アルコール依存', '精神看護学','精神看護'),
 (r'認知症|レビー小体|Alzheimer|アルツハイマー', '老年看護学','認知症看護'),
]

ADULT_SCENARIO=[
 ('循環器',r'心筋梗塞|心不全|狭心症|心房細動|CABG|冠動脈|大動脈'),
 ('呼吸器',r'COPD|肺炎|肺癌|呼吸不全|気胸|喘息'),
 ('消化器',r'食道癌|胃癌|大腸癌|肝硬変|膵癌|胆道癌|潰瘍性大腸炎'),
 ('内分泌・代謝',r'糖尿病|低血糖|高血糖'),
 ('腎・泌尿器',r'腎不全|慢性腎臓病|血液透析|腹膜透析|膀胱癌|回腸導管|泌尿器科'),
 ('脳神経',r'脳出血|脳梗塞|くも膜下出血|Parkinson|パーキンソン'),
 ('運動器',r'骨折|人工関節|脊柱管狭窄|関節リウマチ'),
 ('がん看護',r'癌|がん|化学療法|放射線治療|緩和ケア'),
]


def compact(v): return re.sub(r'\s+',' ',str(v or '')).strip()


def assign(q,major,subject,reason):
    q['majorSubject']=major; q['subject']=subject
    q['classificationStatus']='high'; q['classificationScore']=20
    q['classificationSignals']=[reason]; q['classificationMethod']='semantic-refinement-v3'


def refine(q):
    stem=compact(q.get('question')); scenario=compact(q.get('scenario'))
    for pattern,major,subject in STEM_RULES:
        if re.search(pattern,stem,re.I):
            assign(q,major,subject,f'stem-rule:{pattern}'); return
    for pattern,major,subject in STEM_SPECIALTY:
        if re.search(pattern,stem,re.I):
            assign(q,major,subject,f'stem-specialty:{pattern}'); return

    if q.get('category')=='状況設定' and scenario:
        # Domain-specific life-stage specialties outrank generic adult disease context.
        for pattern,major,subject in SCENARIO_SPECIALTY:
            if re.search(pattern,scenario,re.I):
                assign(q,major,subject,f'scenario-specialty:{pattern}'); return
        # If the question itself asks about community/home care, keep it in regional nursing.
        if re.search(r'訪問看護|在宅|自宅退院|地域連携|退院支援|介護サービス',stem,re.I):
            assign(q,'地域・在宅看護論','在宅療養・地域連携','situation-regional-focus'); return
        # Otherwise use the clinical specialty of the scenario; this prevents
        # distractor words such as 輸液/採血 from pulling CABG or cancer cases into 基礎看護.
        for subject,pattern in ADULT_SCENARIO:
            if re.search(pattern,scenario,re.I):
                assign(q,'成人看護学',subject,f'scenario-adult:{pattern}'); return
        # Clearly home-based scenarios without a named disease remain regional.
        if re.search(r'訪問看護|訪問介護|在宅療養|自宅で療養|要介護',scenario,re.I):
            assign(q,'地域・在宅看護論','在宅療養支援','scenario-homecare'); return

    # Promote a unique score-4+ candidate. Scores at this level originate from
    # a stem hit or a clinical scenario signal, not a single distractor hit.
    if q.get('classificationStatus') in {'low','medium'} and int(q.get('classificationScore') or 0)>=4 and q.get('majorSubject') and q.get('subject'):
        q['classificationStatus']='high'
        q['classificationMethod']='semantic-refinement-v3-promoted'
        q['classificationSignals']=(q.get('classificationSignals') or [])+['unique-score>=4']


report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'semantic-refinement-v3'}
counts=Counter()
for set_id in ('set1','set2','set3'):
    path=OUT/f'{set_id}-classified.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    for q in data['questions']:
        refine(q)
        status=q.get('classificationStatus','unclassified')
        report['total']+=1; report[status]+=1
        if q.get('majorSubject'): counts[q['majorSubject']]+=1
        if status!='high':
            report['needsReview'].append({
                'id':q['id'],'status':status,'score':q.get('classificationScore',0),
                'question':compact(q.get('question'))[:260],
                'scenario':compact(q.get('scenario'))[:300] if q.get('scenario') else None,
                'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject'),
                'signals':q.get('classificationSignals') or []
            })
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(counts.items()))
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False))
print(f"needsReview={len(report['needsReview'])}")
