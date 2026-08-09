#!/usr/bin/env python3
import json,re
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'classified'

RULES=[
 # 人体の構造と機能
 (r'摂食中枢|満腹中枢|脊髄神経|頸神経|感覚性言語中枢|運動性言語中枢|Corti|コルチ|味覚|味蕾|神経線維.*髄|小脳の機能|声帯.*神経|反回神経', '人体の構造と機能','神経・感覚器'),
 (r'結晶性知能|流動性知能', '老年看護学','老年期の心理・認知'),
 (r'乏尿の説明|尿量.*乏尿', '人体の構造と機能','腎・体液調節'),
 (r'乳房について正しい|乳房の構造', '人体の構造と機能','生殖器の構造'),
 (r'門脈系|門脈の', '人体の構造と機能','循環・消化器の構造'),
 (r'体格指数|BMI.*求め', '健康支援と社会保障制度','健康評価'),
 # 基礎看護学
 (r'面接技法.*閉じた質問|closed question|開いた質問', '基礎看護学','コミュニケーション'),
 (r'Cheyne.?Stokes|チェーン.?ストークス|呼吸のパターン', '基礎看護学','観察・バイタルサイン'),
 (r'口腔内吸引|気管内吸引|吸引で正しい', '基礎看護学','呼吸を整える援助'),
 (r'舌根の沈下|気道確保.*体位', '基礎看護学','安全・救急時援助'),
 (r'徒手筋力テスト|MMT', '基礎看護学','フィジカルアセスメント'),
 (r'全身性けいれん発作|けいれん発作.*優先', '基礎看護学','安全・救急時援助'),
 (r'坐薬の挿入|坐薬.*挿入方法', '基礎看護学','与薬'),
 (r'直流除細動器|除細動器', '基礎看護学','救命処置'),
 (r'病室.*照度|読書.*照度', '基礎看護学','療養環境'),
 (r'膀胱留置カテーテル|導尿', '基礎看護学','排泄援助'),
 (r'排痰を促す|体位ドレナージ|排痰法', '基礎看護学','呼吸を整える援助'),
 (r'鼻中隔.*出血|鼻出血.*対応', '基礎看護学','安全・救急時援助'),
 (r'痛みの程度を数値|NRS|VAS|疼痛.*スケール', '基礎看護学','疼痛アセスメント'),
 (r'客観的情報|主観的情報|看護記録', '基礎看護学','看護記録'),
 (r'リラクセーション|腹式呼吸', '基礎看護学','安楽・リラクセーション'),
 (r'個別性を理解|患者の個別性', '基礎看護学','看護の基本概念'),
 # 疾病の成り立ちと回復
 (r'土壌中に分布.*感染|破傷風菌', '疾病の成り立ちと回復の促進','感染・免疫'),
 (r'重症筋無力症|尋常性乾癬|大動脈解離|転移性脳腫瘍|肺結核|大動脈弁狭窄症', '疾病の成り立ちと回復の促進','病態・疾患'),
 (r'エックス線を用いて行う検査|X線を用いて|画像検査', '疾病の成り立ちと回復の促進','検査・診断'),
 (r'減感作療法', '疾病の成り立ちと回復の促進','治療・免疫'),
 (r'高濃度の酸素.*CO2|CO2.*ナルコーシス', '疾病の成り立ちと回復の促進','呼吸器の病態'),
 (r'急性期.*生体反応', '疾病の成り立ちと回復の促進','侵襲と生体反応'),
 # 成人看護学
 (r'肝切除術後|膵頭十二指腸切除術|喉頭摘出|気管孔造設|尿管結石|マンモグラフィ.*説明|自己血糖測定', '成人看護学','成人の治療・療養支援'),
 (r'がん患者の家族|社会的苦痛|悪液質.*患者', '成人看護学','がん看護'),
 # 小児看護学
 (r'アタッチメント|Bowlby|ボウルビ|子ども.*ディストラクション|夜尿症|男児|女児', '小児看護学','成長発達・小児看護'),
 # 母性看護学
 (r'育児時間|習慣流産|自然流産|プレコンセプション|セクシュアリティ|NST|ノンストレステスト|子宮復古不全', '母性看護学','性と生殖・周産期'),
 # 精神看護学
 (r'セルフヘルプグループ|知的障害|社会生活技能訓練|SST', '精神看護学','精神保健・リハビリテーション'),
 # 健康支援と社会保障制度
 (r'児童虐待.*通告|児童虐待防止法|自殺対策基本法|看護師等の人材確保|都道府県ナースセンター|介護医療院', '健康支援と社会保障制度','保健医療福祉制度・法規'),
 (r'患者調査|患者調査における|介護保険法|特定疾病|地域包括支援センター', '健康支援と社会保障制度','保健統計・社会保障'),
 (r'通い.*訪問.*泊まり|看護小規模多機能', '地域・在宅看護論','地域密着型サービス'),
 # 看護の統合と実践
 (r'自己決定する権利|十分な説明.*自己決定|望ましい治療.*納得|共同意思決定|shared decision', '看護の統合と実践','倫理・意思決定'),
 (r'親族と名乗る者.*電話|患者情報.*電話', '看護の統合と実践','倫理・個人情報'),
 (r'交代勤務|看護職員.*勤務|看護サービスの質|看護手順', '看護の統合と実践','看護管理'),
 (r'外国籍.*お祈り|外国籍.*宗教', '看護の統合と実践','倫理・国際看護'),
 (r'発災直後|避難者|自家用車に泊まり|大地震|リーダー看護師が指揮', '看護の統合と実践','災害看護'),
]

SCENARIO_RULES=[
 (r'神経性過食症|bulimia nervosa|神経性やせ症|摂食障害', '精神看護学','精神疾患と看護'),
 (r'震度\s*[5-7]|大地震|発災直後|災害', '看護の統合と実践','災害看護'),
 (r'心筋梗塞.*CABG|冠動脈バイパス', '成人看護学','循環器・周術期'),
 (r'膀胱全摘|回腸導管|芳香族アミン.*尿', '成人看護学','腎・泌尿器'),
]


def compact(v): return re.sub(r'\s+',' ',str(v or '')).strip()

def set_high(q,major,subject,reason):
    q['majorSubject']=major; q['subject']=subject; q['classificationStatus']='high'; q['classificationScore']=30
    q['classificationSignals']=[reason]; q['classificationMethod']='refinement-v4'


def refine(q):
    if q.get('classificationStatus')=='high': return
    stem=compact(q.get('question')); scenario=compact(q.get('scenario'))
    for pattern,major,subject in RULES:
        if re.search(pattern,stem,re.I): set_high(q,major,subject,f'v4:{pattern}'); return
    if scenario:
        for pattern,major,subject in SCENARIO_RULES:
            if re.search(pattern,scenario,re.I): set_high(q,major,subject,f'v4-scenario:{pattern}'); return
    # Existing low candidates with two or more independent signals are safe to promote.
    signals=q.get('classificationSignals') or []
    if q.get('classificationStatus')=='low' and len(signals)>=2 and q.get('majorSubject') and q.get('subject'):
        set_high(q,q['majorSubject'],q['subject'],'v4:multiple-signals')

report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'refinement-v4'}
counts=Counter()
for set_id in ('set1','set2','set3'):
    p=OUT/f'{set_id}-classified.json'; data=json.loads(p.read_text(encoding='utf-8'))
    for q in data['questions']:
        refine(q); status=q.get('classificationStatus','unclassified'); report['total']+=1; report[status]+=1
        if q.get('majorSubject'): counts[q['majorSubject']]+=1
        if status!='high': report['needsReview'].append({'id':q['id'],'status':status,'score':q.get('classificationScore',0),'question':compact(q.get('question'))[:280],'scenario':compact(q.get('scenario'))[:320] if q.get('scenario') else None,'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject'),'signals':q.get('classificationSignals') or []})
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(counts.items()))
(OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print(f"needsReview={len(report['needsReview'])}")
