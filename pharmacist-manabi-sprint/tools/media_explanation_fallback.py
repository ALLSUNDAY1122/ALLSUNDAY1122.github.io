#!/usr/bin/env python3
from __future__ import annotations

import csv,glob,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; REVIEW=ROOT/'content'/'review'; REVIEWED=ROOT/'content'/'reviewed'; OUT=REVIEWED/'media-anchor'; OUT.mkdir(parents=True,exist_ok=True)

RULES=[
 ('アレニウス','Arrheniusプロットはln k対1/Tが直線となり、傾きは−Ea/R。温度上昇で速度定数は大きくなる。'),
 ('真度','真度が高いとは中心が真値に近く、精度が高いとは分布のばらつきが小さい。'),
 ('ベシル酸','ベシル酸はベンゼンスルホン酸（C6H5SO3H）。塩基性薬物の塩形成に用いられる。'),
 ('一酸化窒素','NOは総価電子数が奇数で不対電子を1個持つラジカル分子。'),
 ('芳香族性','芳香族性は環状・平面・共役系で4n+2個のπ電子を持つかを確認する。'),
 ('前立腺','前立腺は膀胱の直下にあり、尿道の起始部を取り囲む。'),
 ('ウェルニッケ','ウェルニッケ脳症はチアミン（ビタミンB1）欠乏が代表原因。'),
 ('粉末 X 線','非晶質は長距離秩序がないため、粉末X線回折で鋭い回折ピークではなく幅広いハローを示す。'),
 ('Fick','Fickの法則では透過速度は面積・拡散係数・分配係数・濃度差に比例し、膜厚に反比例する。'),
 ('P︲糖タンパク質','P-糖タンパク質は小腸上皮の管腔側膜などに局在し、基質を細胞内から管腔側へ排出する。'),
 ('P‑糖タンパク質','P-糖タンパク質はATP依存性排出トランスポーターで、組織移行や吸収を制限する。'),
 ('非劣性','非劣性は効果差の信頼区間下限があらかじめ定めた非劣性マージン−Δを上回るかで判断する。'),
 ('チログロブリン','甲状腺ホルモン合成では、チログロブリンのチロシン残基がコロイド側でヨウ素化される。'),
 ('コラーゲン','コラーゲン三重らせんはGly-X-Y反復とヒドロキシプロリンが安定化に重要。'),
 ('ELISA','サンドイッチELISAは異なるエピトープを認識する捕捉抗体と検出抗体を用い、検量線範囲外は希釈して再測定する。'),
 ('細胞周期','G2/M期はDNA複製後なのでG1期の約2倍のDNA量を持つ。'),
 ('凍結乾燥','凍結乾燥の一次乾燥は固体の氷を減圧下で液体を経ずに水蒸気へ昇華させる。'),
 ('NMR','1H NMRでは化学シフト、積分値、スピン結合による分裂から水素の環境と隣接関係を判断する。'),
 ('非晶質','非晶質は結晶格子を持たず、回折ではブロードなパターンを示す。'),
 ('ロータリー打錠','ロータリー打錠では充填→重量調節→予備/本圧縮→排出の順に工程を読む。'),
 ('水蒸気吸着','水蒸気吸着等温線では相対湿度に対する質量変化から非晶質量や水和転移を判断する。'),
 ('DNA の塩基配列','塩基変異はセンス鎖をmRNAのコドンへ置き換え、コドン表でアミノ酸変化を追う。'),
 ('状態図','相図では圧力と温度に対する固体・液体・気体の領域と、昇華・融解・蒸発の境界を読む。'),
 ('標準曲線','検量線は測定範囲内で試料応答を濃度へ換算し、範囲外の試料は適切に希釈して再測定する。'),
 ('95％信頼区間','効果量の信頼区間が無効果値をまたぐかで統計学的有意性を判断する。'),
 ('構造式','構造式問題は官能基・環構造・立体配置・電荷を順に照合して正答構造を特定する。'),
]

def existing_ids():
 ids=set()
 for p in glob.glob(str(REVIEWED/'**'/'*.json'),recursive=True):
  if '/media-anchor/' in p:continue
  try:d=json.loads(Path(p).read_text(encoding='utf-8'))
  except Exception:continue
  items=d if isinstance(d,list) else d.get('items',[]) if isinstance(d,dict) else []
  for x in items:
   if isinstance(x,dict) and x.get('id'):ids.add(x['id'])
 return ids

def answer_label(row):
 a=json.loads(row['answer_json']); acc=json.loads(row['accepted_answers_json'])
 if row['scoring_status']=='excluded':return '解なし'
 if row['scoring_status']=='multiple_accepted':
  pool=sorted({i for combo in acc for i in combo});return '・'.join(str(i+1) for i in pool)+'から任意2つ'
 inds=a if isinstance(a,list) else [a];return '・'.join(str(i+1) for i in inds)

def correct_text(row):
 try:c=json.loads(row['choices_json']);a=json.loads(row['answer_json']);acc=json.loads(row['accepted_answers_json'])
 except Exception:return []
 if row['scoring_status']=='excluded':return []
 if row['scoring_status']=='multiple_accepted':inds=sorted({i for combo in acc for i in combo})
 else:inds=a if isinstance(a,list) else [a]
 return [c[i] for i in inds if isinstance(i,int) and 0<=i<len(c) and c[i].strip()]

def hint(q):
 for key,val in RULES:
  if key in q:return val
 return '図表・構造式・装置図では、設問で指定された特徴を順に照合し、正答肢の位置・構造・変化を対応させて判断する。'

def main():
 ex=existing_ids();total=0
 for exam in (111,110,109):
  rows=[]
  with (REVIEW/f'media-{exam}.tsv').open(encoding='utf-8',newline='') as f:
   for r in csv.DictReader(f,delimiter='\t'):
    if r['id'] in ex:continue
    lab=answer_label(r);texts=correct_text(r);h=hint(r['question'])
    if r['scoring_status']=='excluded':
     mem='公式正答は「解なし」。通常採点から除外する。';exp='厚生労働省公式正答で解なしとされるため、通常の得点問題として扱わない。訂正情報がある場合は訂正版を併記する。'
    elif texts:
     facts='／'.join(re.sub(r'\s+',' ',x).strip() for x in texts)
     mem=(h+' 正答肢：'+facts)[:220]
     exp=f'厚生労働省の公式正答は{lab}。{h} この問題で正答となる記述は「{facts}」。画像と正答肢を対応させて確認する。'
    else:
     mem=(h+f' 公式正答は選択肢{lab}。')[:220]
     exp=f'厚生労働省の公式正答は選択肢{lab}。{h} 元の図・構造式・グラフを出典表示付き画像で確認し、選択肢{lab}が該当する特徴を視覚的に対応づける。'
    rows.append({'id':r['id'],'memoryPoint':mem,'explanation':exp,'reviewRequired':False,'generator':'official-media-answer-anchor','generationStatus':'pending_final_semantic_audit'})
  if rows:
   (OUT/f'media-anchor-{exam}.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');total+=len(rows)
 report={'existingReviewedMediaOrReplacement':len(ex),'mediaAnchorGenerated':total}
 (REVIEW/'media-explanation-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
