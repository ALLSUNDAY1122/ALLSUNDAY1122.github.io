#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/"audit"
DATA=AUDIT/"data/questions.round1-2-3.canonical.json"
REGISTRY=AUDIT/"primary-source-registry.json"

BANNED_PHRASES=["過去問より引用","過去問題より引用","原文転載","転載問題","市販問題集より","過去問を改変"]
ALLOWED_ORIGINS={"original_from_primary_source","licensed_official","public_domain_or_law"}

# 数式問題の期待値を、IDではなく論点＋答え文字列で検査する。
CALC_EXPECTED={
 "疫学計算：罹患率と有病率":"2％",
 "疫学計算：相対危険と寄与危険":"2",
 "症例対照研究：オッズ比計算":"4",
 "スクリーニング：感度・特異度計算":"90％",
 "食品成分表：可食部換算":"200",
 "食品成分表：調理損失を含む栄養計算":"24mg",
 "エネルギー換算：栄養成分表示":"165kcal",
 "スポーツ：発汗量から水分補給":"1.3L",
 "身体活動：メッツ・時の実践計算":"10",
 "損益分岐：売価変更の影響":"5,000食",
 "発注：廃棄率を含む計算":"100kg",
 "計算：BMIと減量目標":"84.1kg",
 "計算：標準体重と必要エネルギー":"56.3kg",
 "計算：たんぱく質量g/kg":"72g",
 "計算：脂質エネルギー比":"22.5％",
 "計算：食塩相当量":"2.54g",
 "計算：non-HDL-C":"160mg/dL",
 "計算：メッツ・時":"10",
 "計算：食材発注量":"50kg",
 "計算：廃棄率・歩留まり":"85％",
 "計算：損益分岐点":"3,000食"
}

def fail(errors,msg): errors.append(msg)

def main():
 data=json.loads(DATA.read_text(encoding="utf-8"))
 registry=json.loads(REGISTRY.read_text(encoding="utf-8"))
 allowed=set(registry["allowedHosts"])
 errors=[]; warnings=[]
 if len(data)!=600: fail(errors,f"総問題数 {len(data)}/600")
 for q in data:
  qid=q.get("id","?"); choices=q.get("choices",[]); idx=q.get("correct_index")
  if not isinstance(choices,list) or len(choices)!=5: fail(errors,f"{qid}: 選択肢数 {len(choices) if isinstance(choices,list) else 'invalid'}/5")
  elif len(set(str(x) for x in choices))!=5: fail(errors,f"{qid}: 選択肢重複")
  if not isinstance(idx,int) or not 0<=idx<len(choices): fail(errors,f"{qid}: correct_index不正")
  if not str(q.get("explanation","")).strip(): fail(errors,f"{qid}: 解説欠損")
  url=q.get("source_url",""); host=urlparse(url).hostname or ""
  if not url.startswith("https://"): fail(errors,f"{qid}: HTTPSでない根拠URL {url}")
  if host not in allowed: fail(errors,f"{qid}: 許可外ソース {host}")
  if not str(q.get("reference_date","")).strip(): fail(errors,f"{qid}: 基準日欠損")
  if q.get("origin_type") not in ALLOWED_ORIGINS: fail(errors,f"{qid}: 作問由来未承認 {q.get('origin_type')}")
  rights=str(q.get("rights_basis", ""))
  if not rights.strip(): fail(errors,f"{qid}: 権利根拠欠損")
  if q.get("origin_type")=="original_from_primary_source" and not any(x in rights for x in ("独自作成","独自作問")):
   fail(errors,f"{qid}: 独自作問の権利根拠が不明")
  if q.get("audit_status")!="approved": fail(errors,f"{qid}: audit_status={q.get('audit_status')}")
  combined=" ".join(str(q.get(k,"")) for k in ("question","explanation","rights_basis"))
  for phrase in BANNED_PHRASES:
   if phrase in combined: fail(errors,f"{qid}: 転載依拠を示す文言 {phrase}")
  # 公開過去問の番号表現を持ち込まない。
  if re.search(r"第\s*\d+\s*回.*問\s*\d+",q.get("question","")): fail(errors,f"{qid}: 実試験番号らしき表現")
  topic=q.get("topic")
  if q.get("round")==3 and topic in CALC_EXPECTED and isinstance(idx,int) and 0<=idx<len(choices):
   expected=CALC_EXPECTED[topic]
   answer=str(choices[idx])
   if answer!=expected: fail(errors,f"{qid}: 計算監査 {topic}: answer={answer} expected={expected}")
 # ラウンドごとの正答位置が極端に偏っていないかは警告のみ。
 for rnd in (1,2,3):
  part=[q for q in data if q.get("round")==rnd]
  counts=[sum(1 for q in part if q.get("correct_index")==i) for i in range(5)]
  if min(counts)<10: warnings.append(f"第{rnd}回: 正答位置の偏り要確認 {counts}")
 print("=== 管理栄養士 600問 内容・権利ポリシー監査 ===")
 print(f"問題数: {len(data)}/600")
 if warnings:
  print("WARNINGS")
  for w in warnings: print("-",w)
 if errors:
  print("FAIL")
  for e in errors: print("-",e)
  return 1
 print("PASS: URL/一次資料ホスト/正答index/選択肢/解説/基準日/作問由来/権利根拠/転載依拠文言/主要計算を監査")
 print("NOTE: 本監査は開発上の内部品質監査であり、法律意見または医療ガイドライン全文の専門家査読を代替しない。")
 return 0
if __name__=="__main__": sys.exit(main())
