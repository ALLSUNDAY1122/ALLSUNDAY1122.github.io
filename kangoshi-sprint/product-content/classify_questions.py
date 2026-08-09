#!/usr/bin/env python3
import json,re
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw'
OUT=ROOT/'classified'
OUT.mkdir(exist_ok=True)

MAJORS={
 '人体の構造と機能','疾病の成り立ちと回復の促進','健康支援と社会保障制度','基礎看護学','地域・在宅看護論',
 '成人看護学','老年看護学','小児看護学','母性看護学','精神看護学','看護の統合と実践'
}

# High-precision stem patterns. These describe what the question is asking,
# so they outrank incidental words found only in distractors.
DIRECT=[
 (r'止血機構|血液凝固|凝固因子', '人体の構造と機能','血液・免疫の機能'),
 (r'痛みの伝導|疼痛の伝導|侵害受容', '人体の構造と機能','神経・感覚器'),
 (r'股関節の運動|関節の運動|関節可動域|筋収縮', '人体の構造と機能','運動器の構造と機能'),
 (r'ホルモンとその働き|ホルモンの作用|内分泌腺', '人体の構造と機能','腎・内分泌の機能'),
 (r'心臓からの血液の拍出|心拍出量|刺激伝導系', '人体の構造と機能','循環・呼吸の機能'),
 (r'2\s*つ以上の核|多核.*細胞', '人体の構造と機能','細胞・組織'),
 (r'尿比重|尿の濃縮|糸球体|ネフロン', '人体の構造と機能','腎・内分泌の機能'),
 (r'胃潰瘍|胆囊炎|胆嚢炎|肝性脳症|痔瘻|上大静脈症候群|下肢静脈瘤', '疾病の成り立ちと回復の促進','病態・症候'),
 (r'肺血栓塞栓症.*確定診断|診断に用いる.*肺血栓', '疾病の成り立ちと回復の促進','検査・診断'),
 (r'電解質異常|創傷の治癒過程|肉芽組織', '疾病の成り立ちと回復の促進','病態生理'),
 (r'ペースメーカー.*検査|検査.*ペースメーカー', '疾病の成り立ちと回復の促進','検査・診断'),
 (r'腰椎穿刺|静脈血採血|採血で針|酸素投与器具|Fowler|ファウラー|腹部の打診|歯周ポケット|ブラッシング|ノーリフトケア', '基礎看護学','基本的看護技術'),
 (r'頭部.*切創.*止血|止血法はどれか|回復体位', '基礎看護学','安全・救急時援助'),
 (r'廃棄物とその処理|医療廃棄物|産業廃棄物', '健康支援と社会保障制度','環境保健'),
 (r'行動変容|自己効力感|セルフエフィカシー|ヘルスビリーフ', '健康支援と社会保障制度','健康行動・健康教育'),
 (r'職業に伴う作業|職業性.*健康障害|作業環境.*健康障害|労働衛生', '健康支援と社会保障制度','産業保健'),
 (r'民生委員|社会福祉協議会|福祉事務所', '健康支援と社会保障制度','保健医療福祉制度'),
 (r'看護サービスの質|ストラクチャー.*評価|看護手順の目的', '看護の統合と実践','看護管理・質保証'),
 (r'リエゾン精神看護|集団精神療法|ヤーロム|Yalom|ラザルス|Lazarus|ストレスコーピング|パニック発作', '精神看護学','精神看護・心理療法'),
 (r'生後\s*\d+.*児|\d+か月の.*児|\d+歳の.*児|小児の入院患者', '小児看護学','成長発達・小児看護'),
 (r'うっ滞性乳腺炎|産褥|褥婦|分娩第|陣痛|胎児心拍|妊娠\s*\d+週', '母性看護学','妊娠・分娩・産褥'),
 (r'在宅療養.*ケアマネジメント|ケアマネジメント.*在宅|訪問看護|退院支援|退院調整', '地域・在宅看護論','在宅療養・地域連携'),
]

RULES=[
 ('母性看護学','妊娠・胎児',['妊婦','妊娠','胎児','妊娠週','胎盤','羊水','子宮底','妊娠高血圧']),
 ('母性看護学','分娩・産褥',['分娩','産婦','産褥','褥婦','陣痛','破水','悪露','授乳','乳腺炎','母乳']),
 ('母性看護学','新生児',['新生児','Apgar','アプガー','出生直後']),
 ('小児看護学','成長発達',['乳児','幼児','学童','小児','生後','成長発達','発達段階','離乳','乳歯']),
 ('小児看護学','小児の健康障害',['川崎病','先天性心疾患','ネフローゼ','RSウイルス','小児がん']),
 ('精神看護学','精神疾患と看護',['統合失調','うつ病','双極','躁状態','幻覚','幻聴','妄想','精神科','パニック','強迫','摂食障害','依存症','PTSD']),
 ('精神看護学','こころの健康',['精神保健','自傷','希死念慮','自殺企図','心理検査','認知行動療法','ストレスコーピング','集団精神療法']),
 ('老年看護学','高齢者の特徴',['高齢者','老年期','加齢','老化','フレイル','サルコペニア','高齢期']),
 ('老年看護学','認知症看護',['認知症','Lewy','レビー小体','BPSD','認知機能','せん妄']),
 ('地域・在宅看護論','在宅療養支援',['在宅療養','訪問看護','在宅看護','在宅酸素','自宅へ退院','自宅で療養','家族介護者']),
 ('地域・在宅看護論','地域包括ケア',['地域包括','地域ケア','退院支援','退院調整','ケアマネジメント','ケアマネジャー','介護支援専門員']),
 ('健康支援と社会保障制度','人口・保健統計',['人口','平均寿命','健康寿命','国民健康・栄養調査','国民生活基礎調査','人口動態','出生率','死亡率','自殺者','有訴者率','受療率']),
 ('健康支援と社会保障制度','社会保障・保険',['社会保障','医療保険','介護保険','国民健康保険','健康保険','年金','保険給付','要介護認定','要支援認定']),
 ('健康支援と社会保障制度','保健医療福祉制度',['保健所','市町村保健センター','地域保健法','医療法','保健師助産師看護師法','児童福祉法','母子保健法','精神保健福祉法','障害者総合支援法','成年後見','生活保護','民生委員']),
 ('健康支援と社会保障制度','公衆衛生・予防',['公衆衛生','疫学','予防接種','一次予防','二次予防','三次予防','健康診査','感染症法','学校保健','産業保健','労働衛生']),
 ('健康支援と社会保障制度','健康行動・健康教育',['行動変容','自己効力感','健康教育','アドヒアランス','セルフケア行動']),
 ('看護の統合と実践','災害・救急',['災害','トリアージ','多数傷病者','避難所','DMAT','災害派遣','救命処置','BLS','一次救命','心肺蘇生']),
 ('看護の統合と実践','医療安全・看護管理',['インシデント','アクシデント','医療安全','リスクマネジメント','看護管理','看護師長','勤務表','看護サービス','ストラクチャー','看護手順']),
 ('看護の統合と実践','倫理・意思決定',['倫理','意思決定','アドバンス・ケア','ACP','尊厳','守秘義務','インフォームド','個人情報','代理意思決定','私らしく死にたい']),
 ('看護の統合と実践','連携・国際看護',['多職種','チーム医療','医療チーム','国際看護','外国人患者','WHO']),
 ('基礎看護学','感染予防',['標準予防策','手指衛生','感染予防','滅菌','消毒','無菌操作','個人防護具','PPE','針刺し']),
 ('基礎看護学','与薬・輸液',['与薬','注射','点滴','輸液','静脈注射','筋肉内注射','皮下注射','内服薬','薬剤投与','輸血']),
 ('基礎看護学','日常生活援助',['清拭','入浴','口腔ケア','洗髪','排泄援助','食事援助','更衣','ベッドメーキング','体位変換','移乗','車椅子','ノーリフト']),
 ('基礎看護学','観察・フィジカルアセスメント',['バイタルサイン','体温測定','脈拍測定','血圧測定','呼吸数','SpO2','意識レベル','打診','聴診','触診']),
 ('基礎看護学','安全・安楽',['褥瘡予防','転倒予防','安楽な体位','回復体位','三角巾','身体拘束','患者確認','Fowler','ファウラー','止血法']),
 ('基礎看護学','検査・処置の援助',['採血','静脈血','腰椎穿刺','採尿','酸素投与器具']),
 ('基礎看護学','コミュニケーション・看護過程',['コミュニケーション','傾聴','看護過程','看護診断','基本的欲求','Maslow','マズロー','看護記録']),
 ('人体の構造と機能','神経・感覚器',['脳神経','神経伝達','痛みの伝導','交感神経','副交感神経','反射','眼球運動','視神経','聴覚','レム睡眠','睡眠']),
 ('人体の構造と機能','循環・血液の機能',['心拍出量','血液の拍出','刺激伝導系','冠動脈','血液循環','止血機構','血液凝固','凝固因子']),
 ('人体の構造と機能','呼吸の機能',['肺胞','換気','酸素解離曲線','呼吸運動','肺活量']),
 ('人体の構造と機能','消化・代謝の機能',['食道の構造','胃の構造','小腸','大腸','肝臓の機能','胆汁','膵液','消化酵素','基礎代謝']),
 ('人体の構造と機能','腎・内分泌の機能',['ネフロン','糸球体','尿生成','尿比重','下垂体','甲状腺ホルモン','副腎','インスリン分泌','ホルモン']),
 ('人体の構造と機能','遺伝・生殖',['染色体','Down','ダウン症候群','遺伝子','減数分裂','月経周期','性周期']),
 ('人体の構造と機能','運動器の構造と機能',['骨格筋','関節','股関節','筋収縮','運動神経','多核']),
 ('疾病の成り立ちと回復の促進','病態生理',['病態','炎症','浮腫','ショック','アシドーシス','アルカローシス','黄疸','病理','電解質異常','創傷の治癒','肉芽']),
 ('疾病の成り立ちと回復の促進','薬理',['薬理','作用機序','副作用','薬物動態','半減期','抗菌薬','抗凝固薬','鎮痛薬','オピオイド','ステロイド薬']),
 ('疾病の成り立ちと回復の促進','検査・診断',['検査値','血液検査','画像検査','内視鏡','生検','診断に用いる','確定診断','MRI','CT検査','ペースメーカー']),
 ('疾病の成り立ちと回復の促進','感染・免疫',['細菌','ウイルス','真菌','感染経路','抗体','免疫','アレルギー','アナフィラキシー','破傷風菌','結核菌']),
 ('疾病の成り立ちと回復の促進','消化器の病態',['胃潰瘍','胆囊炎','胆嚢炎','肝性脳症','痔瘻','肝硬変','肝炎','膵炎','胆石']),
 ('疾病の成り立ちと回復の促進','循環・呼吸の病態',['肺血栓塞栓','上大静脈症候群','下肢静脈瘤','心不全','心筋梗塞','不整脈','呼吸不全']),
]

ADULT_DOMAINS=[
 ('循環器',['心不全','心筋梗塞','狭心症','不整脈','心房細動','高血圧','深部静脈血栓','肺塞栓','下肢静脈瘤','上大静脈症候群']),
 ('呼吸器',['COPD','慢性閉塞性肺疾患','肺炎','気管支喘息','呼吸不全','気胸','肺癌','間質性肺炎','無気肺']),
 ('消化器',['胃癌','食道癌','大腸癌','胃潰瘍','肝硬変','肝炎','胆囊炎','胆嚢炎','肝性脳症','痔瘻','潰瘍性大腸炎','クローン','膵炎']),
 ('内分泌・代謝',['糖尿病','低血糖','高血糖','甲状腺','Basedow','バセドウ']),
 ('腎・泌尿器',['腎不全','慢性腎臓病','CKD','腎盂腎炎','膀胱炎','前立腺','血液透析','腹膜透析']),
 ('脳神経',['脳梗塞','脳出血','くも膜下出血','Parkinson','パーキンソン','てんかん','片麻痺','腓骨神経麻痺']),
 ('運動器',['骨折','骨粗鬆症','変形性関節症','関節リウマチ','人工関節','ギプス','廃用症候群']),
 ('血液・免疫',['白血病','悪性リンパ腫','貧血','血友病','好中球','血小板減少']),
]
CARE_WORDS=('看護','援助','観察','指導','セルフケア','アセスメント','退院','療養','患者への対応','声かけ','ケア','術後','術前','離床','リハビリ','生活上','自己管理')


def compact(text):
    return re.sub(r'\s+',' ',str(text or '')).strip()


def score_rules(stem,scenario,choices):
    scores=Counter(); subject_scores=Counter(); signals={}
    for major,subject,terms in RULES:
        hits=[]; score=0
        for term in terms:
            s=stem.count(term); sc=scenario.count(term); c=choices.count(term)
            if s or sc or c:
                score += s*5 + sc*3 + c
                hits.append(term)
        if score:
            scores[major]+=score
            subject_scores[(major,subject)]+=score
            signals.setdefault(major,[]).extend(hits)
    return scores,subject_scores,signals


def classify(q):
    stem=compact(q.get('question'))
    scenario=compact(q.get('scenario'))
    choices=' '.join(compact(x) for x in (q.get('choices') or []))

    # Direct stem rules are high precision and ignore distractor noise.
    for pattern,major,subject in DIRECT:
        if re.search(pattern,stem,re.I):
            return major,subject,'high',10,[f'direct:{pattern}']

    scores,subject_scores,signals=score_rules(stem,scenario,choices)

    # Adult disease names are routed by question intent. General knowledge about
    # pathology/diagnosis belongs to 疾病の成り立ち; patient-care/situation questions
    # belong to 成人看護学 unless another age/life-stage specialty scores higher.
    combined=f'{stem} {scenario}'
    care_context=any(w in stem for w in CARE_WORDS) or q.get('category')=='状況設定'
    for subject,terms in ADULT_DOMAINS:
        hits=[t for t in terms if t in combined]
        if not hits: continue
        if care_context:
            bonus=4*len([t for t in terms if t in stem])+3*len([t for t in terms if t in scenario])
            scores['成人看護学']+=max(4,bonus)
            subject_scores[('成人看護学',subject)]+=max(4,bonus)
            signals.setdefault('成人看護学',[]).extend(hits)
        else:
            bonus=5*len([t for t in terms if t in stem])+2*len([t for t in terms if t in choices])
            scores['疾病の成り立ちと回復の促進']+=max(4,bonus)
            subject_scores[('疾病の成り立ちと回復の促進','病態・診断')]+=max(4,bonus)
            signals.setdefault('疾病の成り立ちと回復の促進',[]).extend(hits)

    if not scores:
        return None,None,'unclassified',0,[]
    ranked=scores.most_common()
    major,best=ranked[0]; second=ranked[1][1] if len(ranked)>1 else 0
    subj_candidates=[(score,subj) for (m,subj),score in subject_scores.items() if m==major]
    subject=max(subj_candidates)[1] if subj_candidates else None
    margin=best-second
    if best>=10 or (best>=5 and margin>=4): status='high'
    elif best>=5 and margin>=2: status='medium'
    else: status='low'
    return major,subject,status,best,sorted(set(signals.get(major,[])))


report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'semantic-keyword-v2-with-scenario'}
major_counts=Counter()
for set_id in ('set1','set2','set3'):
    src=RAW/f'{set_id}-raw.json'
    data=json.loads(src.read_text(encoding='utf-8'))
    for q in data['questions']:
        major,subject,status,score,signals=classify(q)
        q['majorSubject']=major
        q['subject']=subject
        q['classificationStatus']=status
        q['classificationScore']=score
        q['classificationSignals']=signals
        q['classificationMethod']='semantic-keyword-v2-with-scenario'
        report['total']+=1; report[status]+=1
        if major: major_counts[major]+=1
        if status!='high':
            report['needsReview'].append({
                'id':q['id'],'status':status,'score':score,'question':q['question'][:240],
                'scenario':compact(q.get('scenario'))[:260] if q.get('scenario') else None,
                'candidateMajor':major,'candidateSubject':subject,'signals':signals
            })
    (OUT/f'{set_id}-classified.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(major_counts.items()))
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False))
print(f"needsReview={len(report['needsReview'])}")
