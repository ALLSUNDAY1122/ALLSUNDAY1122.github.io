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

# (major, small subject, keywords). Stem matches are weighted more heavily than distractor matches.
RULES=[
 ('母性看護学','妊娠・胎児',['妊婦','妊娠','胎児','妊娠週','妊娠期','胎盤','羊水','子宮底']),
 ('母性看護学','分娩・産褥',['分娩','産婦','産褥','陣痛','破水','悪露','授乳','乳房','母乳']),
 ('母性看護学','新生児',['新生児','Apgar','アプガー','出生直後']),
 ('小児看護学','成長発達',['乳児','幼児','学童','小児','成長発達','発達段階','離乳','永久歯','乳歯']),
 ('小児看護学','小児の健康障害',['川崎病','先天性心疾患','ネフローゼ症候群の小児','小児がん','RSウイルス']),
 ('精神看護学','精神疾患と看護',['統合失調','うつ病','双極','躁状態','幻覚','幻聴','妄想','精神科','パニック障害','強迫','摂食障害','依存症']),
 ('精神看護学','こころの健康',['精神保健','自傷','希死念慮','自殺企図','心理検査','認知行動療法']),
 ('老年看護学','高齢者の特徴',['高齢者','老年期','加齢','老化','フレイル','サルコペニア','高齢期']),
 ('老年看護学','認知症看護',['認知症','せん妄','BPSD','認知機能']),
 ('地域・在宅看護論','在宅療養支援',['在宅療養','訪問看護','在宅看護','在宅酸素','居宅','自宅で療養','家族介護者']),
 ('地域・在宅看護論','地域包括ケア',['地域包括','地域ケア','退院支援','退院調整','ケアマネジャー','介護支援専門員']),
 ('健康支援と社会保障制度','人口・保健統計',['人口','平均寿命','健康寿命','国民健康・栄養調査','国民生活基礎調査','人口動態','出生率','死亡率','自殺者','有訴者率','受療率']),
 ('健康支援と社会保障制度','社会保障・保険',['社会保障','医療保険','介護保険','国民健康保険','健康保険','年金','保険給付','要介護認定','要支援認定']),
 ('健康支援と社会保障制度','保健医療福祉制度',['保健所','市町村保健センター','地域保健法','医療法','保健師助産師看護師法','児童福祉法','母子保健法','精神保健福祉法','障害者総合支援法','成年後見制度','生活保護','法律','法に基づ']),
 ('健康支援と社会保障制度','公衆衛生・予防',['公衆衛生','疫学','予防接種','一次予防','二次予防','三次予防','特定健康診査','健康診査','感染症法','学校保健']),
 ('看護の統合と実践','災害・救急',['災害','トリアージ','多数傷病者','避難所','DMAT','災害派遣','救命処置','BLS','一次救命','心肺蘇生']),
 ('看護の統合と実践','医療安全・看護管理',['インシデント','アクシデント','医療安全','リスクマネジメント','看護管理','看護師長','勤務表','ヒヤリ','事故防止']),
 ('看護の統合と実践','倫理・意思決定',['倫理','意思決定','アドバンス・ケア','ACP','尊厳','守秘義務','インフォームド','個人情報','代理意思決定']),
 ('看護の統合と実践','連携・国際看護',['多職種','チーム医療','医療チーム','国際看護','外国人患者','WHO']),
 ('基礎看護学','感染予防',['標準予防策','手指衛生','感染予防','滅菌','消毒','無菌操作','個人防護具','PPE','針刺し']),
 ('基礎看護学','与薬・輸液',['与薬','注射','点滴','輸液','静脈注射','筋肉内注射','皮下注射','内服薬','薬剤投与','輸血']),
 ('基礎看護学','日常生活援助',['清拭','入浴','口腔ケア','洗髪','排泄援助','食事援助','更衣','ベッドメーキング','体位変換','移乗','車椅子']),
 ('基礎看護学','観察・バイタルサイン',['バイタルサイン','体温測定','脈拍測定','血圧測定','呼吸数','SpO2','意識レベル','観察項目']),
 ('基礎看護学','安全・安楽',['褥瘡予防','転倒予防','安楽な体位','回復体位','三角巾','身体拘束','患者確認']),
 ('基礎看護学','コミュニケーション・看護過程',['コミュニケーション','傾聴','看護過程','看護診断','基本的欲求','Maslow','マズロー','看護記録']),
 ('人体の構造と機能','神経・感覚器',['脳神経','神経伝達','交感神経','副交感神経','反射','眼球運動','視神経','聴覚','感覚器','レム睡眠','睡眠']),
 ('人体の構造と機能','循環・呼吸の機能',['心拍出量','刺激伝導系','冠動脈','肺胞','換気','酸素解離曲線','胎児循環','血液循環']),
 ('人体の構造と機能','消化・代謝の機能',['食道の構造','胃の構造','小腸','大腸','肝臓の機能','胆汁','膵液','消化酵素','基礎代謝']),
 ('人体の構造と機能','腎・内分泌の機能',['ネフロン','糸球体','尿生成','下垂体','甲状腺ホルモン','副腎','インスリン分泌','ホルモンの作用']),
 ('人体の構造と機能','遺伝・生殖',['染色体','Down','ダウン症候群','遺伝子','減数分裂','月経周期','性周期']),
 ('人体の構造と機能','運動器の構造と機能',['骨格筋','関節の構造','骨の構造','筋収縮','運動神経']),
 ('疾病の成り立ちと回復の促進','病態生理',['病態','炎症','浮腫の機序','ショックの機序','アシドーシス','アルカローシス','黄疸','病理']),
 ('疾病の成り立ちと回復の促進','薬理',['薬理','作用機序','副作用','薬物動態','半減期','抗菌薬','抗凝固薬','鎮痛薬','オピオイド','ステロイド薬']),
 ('疾病の成り立ちと回復の促進','検査・治療',['検査値','血液検査','画像検査','内視鏡検査','生検','放射線治療','化学療法','透析','検査の目的']),
 ('疾病の成り立ちと回復の促進','感染・免疫',['細菌','ウイルス','真菌','感染経路','抗体','免疫','アレルギー','アナフィラキシー','破傷風菌','結核菌']),
 ('成人看護学','循環器',['心不全','心筋梗塞','狭心症','不整脈','心房細動','心室頻拍','高血圧','動脈硬化','深部静脈血栓','肺塞栓']),
 ('成人看護学','呼吸器',['COPD','慢性閉塞性肺疾患','肺炎','気管支喘息','呼吸不全','気胸','肺癌','間質性肺炎','無気肺','酸素療法']),
 ('成人看護学','消化器',['肝硬変','肝炎','胃癌','大腸癌','消化性潰瘍','潰瘍性大腸炎','Crohn','クローン','胆石','膵炎','閉塞性黄疸']),
 ('成人看護学','内分泌・代謝',['糖尿病','低血糖','高血糖','甲状腺','Basedow','バセドウ','副腎皮質','メタボリック']),
 ('成人看護学','腎・泌尿器',['腎不全','慢性腎臓病','CKD','腎盂腎炎','膀胱炎','前立腺肥大','尿路','血液透析']),
 ('成人看護学','脳神経',['脳梗塞','脳出血','くも膜下出血','Parkinson','パーキンソン','てんかん','髄膜炎','片麻痺']),
 ('成人看護学','運動器',['骨折','骨粗鬆症','変形性関節症','関節リウマチ','人工関節','牽引','ギプス']),
 ('成人看護学','血液・免疫',['白血病','悪性リンパ腫','貧血','血友病','好中球','血小板減少']),
 ('成人看護学','周術期',['手術前','術前','手術後','術後','周術期','全身麻酔','創部','ドレーン']),
 ('成人看護学','がん看護',['がん患者','癌患者','抗がん薬','化学療法中','緩和ケア','終末期','疼痛コントロール'])
]


def compact(text):
    return re.sub(r'\s+',' ',str(text or '')).strip()


def classify(q):
    stem=compact(q.get('question'))
    choices=' '.join(compact(x) for x in (q.get('choices') or []))
    scores=Counter(); subject_scores=Counter(); signals={}
    for major,subject,terms in RULES:
        hits=[]; score=0
        for term in terms:
            s=stem.count(term); c=choices.count(term)
            if s or c:
                score += s*4 + c
                hits.append(term)
        if score:
            scores[major]+=score
            subject_scores[(major,subject)]+=score
            signals.setdefault(major,[]).extend(hits)
    if not scores:
        return None,None,'unclassified',0,[]
    ranked=scores.most_common()
    major,best=ranked[0]; second=ranked[1][1] if len(ranked)>1 else 0
    subj_candidates=[(score,subj) for (m,subj),score in subject_scores.items() if m==major]
    subj=max(subj_candidates)[1] if subj_candidates else None
    margin=best-second
    if best>=8 or (best>=4 and margin>=3): status='high'
    elif best>=4 and margin>=1: status='medium'
    else: status='low'
    return major,subj,status,best,sorted(set(signals.get(major,[])))


report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[]}
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
        q['classificationMethod']='keyword-v1'
        report['total']+=1; report[status]+=1
        if major: major_counts[major]+=1
        if status!='high':
            report['needsReview'].append({'id':q['id'],'status':status,'score':score,'question':q['question'][:220],'candidateMajor':major,'candidateSubject':subject,'signals':signals})
    (OUT/f'{set_id}-classified.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(major_counts.items()))
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False))
print(f"needsReview={len(report['needsReview'])}")
