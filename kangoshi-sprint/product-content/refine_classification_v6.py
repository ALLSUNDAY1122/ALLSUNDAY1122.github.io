#!/usr/bin/env python3
import json,re
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent; OUT=ROOT/'classified'
RULES=[
 # 制度・公衆衛生
 (r'育児.*介護休業法|障害者総合支援法|障害福祉サービス|日常生活自立支援事業|難病.*法律|難病法|医療提供施設|大気汚染物質', '健康支援と社会保障制度','保健医療福祉制度・社会保障'),
 (r'人口動態統計.*悪性新生物|女性の死亡数.*悪性新生物', '健康支援と社会保障制度','人口・保健統計'),
 (r'臓器の移植に関する法律.*脳死|看護師の特定行為', '健康支援と社会保障制度','医療制度・法規'),
 # 小児・母性・老年
 (r'永久歯が生え始め|永久歯.*年齢', '小児看護学','成長発達'),
 (r'二分脊椎|spina bifida', '小児看護学','小児の健康障害'),
 (r'保護者.*子ども.*虐待|子どもへの虐待', '小児看護学','子どもの権利と家族支援'),
 # 基礎看護
 (r'ボディメカニクス|病室の湿度|空気感染.*予防|ポジショニング|転倒・転落.*内的要因|経鼻経管栄養|鼻腔内吸引|シリンジポンプ|改訂水飲みテスト|Holter.*説明|ホルター.*説明|散瞳薬.*眼底検査', '基礎看護学','安全・観察・検査援助'),
 (r'心静止.*投与する薬剤', '基礎看護学','救命処置'),
 (r'指鼻試験', '基礎看護学','フィジカルアセスメント'),
 # 人体
 (r'神経筋接合部|アセチルコリン.*筋細胞|胸管について|左心房と左心室.*弁|心房と心室.*電気的|直腸の構造|短期記憶|脳幹に含まれる|脳死の状態', '人体の構造と機能','神経・循環・消化の構造機能'),
 (r'起床時に最も高く|日内変動.*ホルモン', '人体の構造と機能','内分泌の機能'),
 (r'ケトン体の供給源|エネルギー不足.*ケトン', '人体の構造と機能','代謝の機能'),
 (r'体温のセットポイント|全身のふるえ', '人体の構造と機能','体温調節'),
 # 疾病・薬理
 (r'心室頻拍|ventricular tachycardia|下垂手|尿中ケトン体|末.*性顔面神経麻痺|ドパミン受容体.*遮断|全身放射線照射|肝細胞癌|喀血を症状|重炭酸イオン|Helicobacter|ヘリコバクター|うっ血乳頭|伝音性難聴|梅毒|もやもや病|Sjögren|シェーグレン', '疾病の成り立ちと回復の促進','病態・診断・治療'),
 (r'尿潜血検査.*偽陰性', '疾病の成り立ちと回復の促進','検査・診断'),
 # 成人看護
 (r'骨盤底筋訓練.*尿失禁|インスリン療法|人工肛門周囲|高次脳機能障害.*失行|乳房温存療法|臨死期|開心術後.*心タンポナーデ', '成人看護学','成人の疾患別・周術期看護'),
 # 精神
 (r'フィンク.*危機モデル|Fink.*危機|看護師を愛情深い親|肯定的な感情|精神障害.*リカバリー|共同創造|コプロダクション|退院後生活環境相談員|バーンアウト|燃え尽き', '精神看護学','精神看護・リカバリー'),
 # 看護管理・統合
 (r'病院の看護部.*組織図|プライマリナーシング|ワーク・ライフ・バランス', '看護の統合と実践','看護管理'),
]
SCEN=[
 (r'境界性パーソナリティ|borderline personality|リストカット|神経性過食症|bulimia', '精神看護学','精神疾患と看護'),
 (r'胆石症|cholelithiasis.*胆囊摘出|胆嚢摘出', '成人看護学','消化器・周術期'),
]
def c(v): return re.sub(r'\s+',' ',str(v or '')).strip()
def high(q,m,s,r): q.update({'majorSubject':m,'subject':s,'classificationStatus':'high','classificationScore':50,'classificationSignals':[r],'classificationMethod':'refinement-v6'})
def refine(q):
 if q.get('classificationStatus')=='high': return
 st=c(q.get('question')); sc=c(q.get('scenario'))
 for p,m,s in RULES:
  if re.search(p,st,re.I): high(q,m,s,'v6:'+p); return
 if sc:
  for p,m,s in SCEN:
   if re.search(p,sc,re.I): high(q,m,s,'v6-scenario:'+p); return
report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'refinement-v6'}; cnt=Counter()
for sid in ('set1','set2','set3'):
 p=OUT/f'{sid}-classified.json'; d=json.loads(p.read_text(encoding='utf-8'))
 for q in d['questions']:
  refine(q); s=q.get('classificationStatus','unclassified'); report['total']+=1; report[s]+=1
  if q.get('majorSubject'): cnt[q['majorSubject']]+=1
  if s!='high': report['needsReview'].append({'id':q['id'],'status':s,'score':q.get('classificationScore',0),'question':c(q.get('question'))[:320],'scenario':c(q.get('scenario'))[:380] if q.get('scenario') else None,'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject'),'signals':q.get('classificationSignals') or []})
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(cnt.items())); (OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print('needsReview='+str(len(report['needsReview'])))
