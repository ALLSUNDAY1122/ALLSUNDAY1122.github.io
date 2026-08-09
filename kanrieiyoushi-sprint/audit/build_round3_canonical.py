#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit"
REGISTRY = AUDIT / "primary-source-registry.json"
OUT = AUDIT / "data/questions.round3.canonical.json"
FILES = [
 ("社会・環境","round3/01-social.json",16),("人体・疾病","round3/02-body-disease.json",26),
 ("食べ物","round3/03-food.json",25),("基礎栄養","round3/04-basic-nutrition.json",14),
 ("応用栄養","round3/05-applied-nutrition.json",16),("栄養教育","round3/06-nutrition-education.json",13),
 ("臨床栄養","round3/07-clinical-nutrition.json",26),("公衆栄養","round3/08-public-nutrition.json",16),
 ("給食経営","round3/09-foodservice-management.json",18),("応用力","round3/10-applied.json",30),
]
RIGHTS="一次資料の論点・事実を基礎に独自作問。既存過去問本文・選択肢・解説の転載・軽微改変なし。"

# 初回600問横断監査で0.90以上になった4問を、異なる評価能力へ再設計。
OVERRIDES={
 "KNR3-024":{
  "question":"16時間の絶食後、脂肪組織から放出された長鎖脂肪酸をエネルギー源として利用する。細胞内で脂肪酸分解が主に進む場所はどれか。",
  "choices":["核","ミトコンドリア","ゴルジ体","リボソーム","中心体"],"correct_index":1,
  "memory_line":"長鎖脂肪酸のβ酸化は主にミトコンドリアで進む。",
  "short_reason":"絶食時の代謝状況から細胞内局在を判断する。",
  "explanation":"絶食時には脂肪酸利用が高まり、長鎖脂肪酸はミトコンドリアへ運ばれてβ酸化を受ける。"
 },
 "KNR3-038":{
  "question":"閉経後女性で骨量低下が進んでいる。骨基質を分解し、骨吸収を直接担う細胞はどれか。",
  "choices":["骨芽細胞","破骨細胞","軟骨細胞","赤血球","線維芽細胞"],"correct_index":1,
  "memory_line":"骨吸収は破骨細胞、骨形成は骨芽細胞。",
  "short_reason":"骨量低下の症例から骨リモデリング担当細胞を判断する。",
  "explanation":"破骨細胞は骨吸収を担い、骨芽細胞は新しい骨基質の形成を担う。"
 },
 "KNR3-077":{
  "question":"極端に野菜・果物が少ない食生活が続き、歯肉出血と創傷治癒遅延がみられた。欠乏が疑われる栄養素はどれか。",
  "choices":["ビタミンA","ビタミンB1","ビタミンC","ビタミンD","ビタミンK"],"correct_index":2,
  "memory_line":"ビタミンC欠乏ではコラーゲン合成障害に関連する症状が起こりうる。",
  "short_reason":"機能の直接暗記ではなく欠乏症状から推定する。",
  "explanation":"ビタミンCはコラーゲン合成に必要で、重度欠乏では歯肉出血や創傷治癒遅延などがみられうる。"
 },
 "KNR3-078":{
  "question":"日照機会が少なく、骨の石灰化障害が疑われる。腸管でのカルシウム吸収低下と関連する欠乏栄養素はどれか。",
  "choices":["ビタミンB2","ビタミンC","ビタミンD","ビタミンE","ビタミンK"],"correct_index":2,
  "memory_line":"ビタミンDは腸管カルシウム吸収と骨代謝に関与する。",
  "short_reason":"病態から欠乏栄養素を推定する。",
  "explanation":"ビタミンD欠乏ではカルシウム吸収が低下し、骨の石灰化障害につながりうる。"
 },
 "KNR3-119":{
  "question":"高血圧で外食の麺類を週5回食べ、毎回スープを飲み干している。最初に提案する減塩行動として実行しやすいものはどれか。",
  "choices":["麺類のスープを残す","漬物を追加する","卓上食塩を増やす","加工肉を追加する","みそ汁を毎食2杯にする"],"correct_index":0,
  "memory_line":"汁を残すことは外食時の具体的な減塩行動になる。",
  "short_reason":"一般論ではなく、実際の食行動から優先介入を選ぶ。",
  "explanation":"麺類の汁には食塩が多く含まれやすいため、スープを残すことは実行しやすい減塩方法の一つである。"
 }
}

def main():
 registry=json.loads(REGISTRY.read_text(encoding="utf-8")); sources=registry["sources"]
 data=[]; seq=1
 for subject,rel,expected in FILES:
  items=json.loads((AUDIT/rel).read_text(encoding="utf-8"))
  if len(items)!=expected: raise SystemExit(f"{subject}: {len(items)}/{expected}")
  for raw in items:
   key=raw.get("source")
   if key not in sources: raise SystemExit(f"KNR3-{seq:03d}: unknown source key {key}")
   src=sources[key]; qid=f"KNR3-{seq:03d}"
   base=dict(raw); base.update(OVERRIDES.get(qid,{}))
   choices=base.get("choices"); answer=base.get("correct_index")
   if not isinstance(choices,list) or len(choices)!=5 or not isinstance(answer,int) or not 0<=answer<5:
    raise SystemExit(f"{qid}: choices/answer invalid")
   q={"id":qid,"round":3,"subject":subject,"topic":base["topic"],"question":base["question"],"choices":choices,"correct_index":answer,
      "memory_line":base.get("memory_line",base["explanation"].split("。")[0]+"。"),"short_reason":base.get("short_reason",base["explanation"]),"explanation":base["explanation"],
      "source_url":src["url"],"source_key":key,"source_authority":src["authority"],"reference_date":"2026-08-09","source_status":"primary_source_reviewed",
      "origin_type":"original_from_primary_source","rights_basis":RIGHTS,"audit_status":"approved"}
   data.append(q); seq+=1
 if len(data)!=200: raise SystemExit(f"round3 count mismatch {len(data)}/200")
 counts=Counter(q["subject"] for q in data); expected_counts={s:n for s,_,n in FILES}
 if dict(counts)!=expected_counts: raise SystemExit(f"distribution mismatch {dict(counts)}")
 OUT.parent.mkdir(parents=True,exist_ok=True); OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
 print(f"built round3 {len(data)} questions -> {OUT}"); print("distribution:",dict(counts)); print(f"similarity overrides={len(OVERRIDES)}")
if __name__=="__main__": main()
