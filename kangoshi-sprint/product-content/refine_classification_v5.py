#!/usr/bin/env python3
import json,re
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent; OUT=ROOT/'classified'

RULES=[
 # 人体・発達・生理
 (r'壮年期の身体的変化', '成人看護学','成人期の発達・健康'),
 (r'ABO.*血液型|オモテ検査.*ウラ検査', '人体の構造と機能','血液の機能'),
 (r'上行大動脈から分枝|膵管と合流|大十二指腸乳頭|健康な成人の皮膚|止血後の線維素溶解|線溶', '人体の構造と機能','人体の構造・生理'),
 (r'成長・発達における順序性|第二次性徴.*思春期', '小児看護学','成長発達'),
 # 制度・公衆衛生
 (r'医療提供施設|救急医療に関する|学校感染症.*出席停止|育児・介護休業法|労働安全衛生法|食事摂取基準|鉄摂取推奨量', '健康支援と社会保障制度','保健医療制度・健康政策'),
 (r'障害者総合支援法.*地域移行|精神障害者保健福祉手帳|介護老人保健施設|業務従事者届', '健康支援と社会保障制度','社会保障・福祉制度'),
 (r'国際生活機能分類|ICF', '健康支援と社会保障制度','健康・障害の概念'),
 # 基礎看護
 (r'クリティカルシンキング|看護目標を設定|看護計画', '基礎看護学','看護過程'),
 (r'漸進的筋弛緩法', '基礎看護学','安楽・リラクセーション'),
 (r'超音波検査.*説明|フィジカルアセスメント.*問診|ストレッチャー.*角|褥瘡の好発部位|創傷処置|24\s*時間蓄尿', '基礎看護学','検査・観察・安全援助'),
 (r'医療機関の廃棄物.*バイオハザード', '基礎看護学','感染予防・医療廃棄物'),
 (r'診療情報について|診療情報.*適切', '看護の統合と実践','倫理・情報管理'),
 # 疾病・薬理・検査
 (r'有機リン.*殺虫剤|有機リン.*投与', '疾病の成り立ちと回復の促進','中毒・薬理'),
 (r'肝動脈塞栓術|TAE', '疾病の成り立ちと回復の促進','治療'),
 (r'多発性筋炎|Ménière|メニエール|緑内障.*禁忌|器質的変化.*嚥下障害', '疾病の成り立ちと回復の促進','病態・疾患'),
 (r'術前の休薬|休薬を検討', '疾病の成り立ちと回復の促進','薬理・周術期'),
 (r'異常な呼吸音|低調性連続性副雑音', '疾病の成り立ちと回復の促進','呼吸器の徴候'),
 # 成人看護
 (r'口すぼめ呼吸', '成人看護学','呼吸器看護'),
 (r'眼底光凝固療法|膀胱癌.*緊急|膀胱鏡.*組織検査|痛風の患者|急性髄膜炎患者', '成人看護学','成人の疾患別看護'),
 (r'乳房超音波検査|マンモグラフィ.*成人女性', '成人看護学','がん検診・乳房疾患'),
 # 老年
 (r'老人性皮膚|老人性難聴|presbyacusis|pruritus senilis', '老年看護学','加齢変化と看護'),
 # 小児
 (r'ピアジェ|Piaget|子どもの成長・発達', '小児看護学','成長発達'),
 # 母性
 (r'一般不妊治療|不妊治療|経産道感染|親性について|閉経.*エストロゲン', '母性看護学','性と生殖・女性の健康'),
 # 精神
 (r'バーンアウト|燃え尽き|満足感や達成感が得られず.*うつ', '精神看護学','ストレス・精神保健'),
 # 統合・災害
 (r'Psychological First Aid|サイコロジカルファーストエイド|PFA', '看護の統合と実践','災害看護'),
]

SCENARIO=[
 (r'便潜血.*陽性|結腸切除|大腸', '成人看護学','消化器・周術期'),
 (r'肺気腫|pulmonary emphysema', '成人看護学','呼吸器'),
]

def c(v): return re.sub(r'\s+',' ',str(v or '')).strip()
def high(q,m,s,r): q.update({'majorSubject':m,'subject':s,'classificationStatus':'high','classificationScore':40,'classificationSignals':[r],'classificationMethod':'refinement-v5'})
def refine(q):
 if q.get('classificationStatus')=='high': return
 stem=c(q.get('question')); scen=c(q.get('scenario'))
 for p,m,s in RULES:
  if re.search(p,stem,re.I): high(q,m,s,'v5:'+p); return
 if scen:
  for p,m,s in SCENARIO:
   if re.search(p,scen,re.I): high(q,m,s,'v5-scenario:'+p); return

report={'total':0,'high':0,'medium':0,'low':0,'unclassified':0,'majorCounts':{},'needsReview':[],'method':'refinement-v5'}; counts=Counter()
for sid in ('set1','set2','set3'):
 p=OUT/f'{sid}-classified.json'; d=json.loads(p.read_text(encoding='utf-8'))
 for q in d['questions']:
  refine(q); st=q.get('classificationStatus','unclassified'); report['total']+=1; report[st]+=1
  if q.get('majorSubject'): counts[q['majorSubject']]+=1
  if st!='high': report['needsReview'].append({'id':q['id'],'status':st,'score':q.get('classificationScore',0),'question':c(q.get('question'))[:300],'scenario':c(q.get('scenario'))[:350] if q.get('scenario') else None,'candidateMajor':q.get('majorSubject'),'candidateSubject':q.get('subject'),'signals':q.get('classificationSignals') or []})
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report['majorCounts']=dict(sorted(counts.items())); (OUT/'classification-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='needsReview'},ensure_ascii=False)); print('needsReview='+str(len(report['needsReview'])))
