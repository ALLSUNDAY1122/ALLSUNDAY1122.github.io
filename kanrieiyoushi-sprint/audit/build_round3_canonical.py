#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit"
REGISTRY = AUDIT / "primary-source-registry.json"
OUT = AUDIT / "data/questions.round3.canonical.json"
FILES = [
 ("社会・環境","round3/01-social.json",16),
 ("人体・疾病","round3/02-body-disease.json",26),
 ("食べ物","round3/03-food.json",25),
 ("基礎栄養","round3/04-basic-nutrition.json",14),
 ("応用栄養","round3/05-applied-nutrition.json",16),
 ("栄養教育","round3/06-nutrition-education.json",13),
 ("臨床栄養","round3/07-clinical-nutrition.json",26),
 ("公衆栄養","round3/08-public-nutrition.json",16),
 ("給食経営","round3/09-foodservice-management.json",18),
 ("応用力","round3/10-applied.json",30),
]
RIGHTS="一次資料の論点・事実を基礎に独自作問。既存過去問本文・選択肢・解説の転載・軽微改変なし。"

def main():
 registry=json.loads(REGISTRY.read_text(encoding="utf-8"))
 sources=registry["sources"]
 data=[]; seq=1
 for subject,rel,expected in FILES:
  items=json.loads((AUDIT/rel).read_text(encoding="utf-8"))
  if len(items)!=expected: raise SystemExit(f"{subject}: {len(items)}/{expected}")
  for raw in items:
   key=raw.get("source")
   if key not in sources: raise SystemExit(f"KNR3-{seq:03d}: unknown source key {key}")
   src=sources[key]
   choices=raw.get("choices")
   answer=raw.get("correct_index")
   if not isinstance(choices,list) or len(choices)!=5 or not isinstance(answer,int) or not 0<=answer<5:
    raise SystemExit(f"KNR3-{seq:03d}: choices/answer invalid")
   q={
    "id":f"KNR3-{seq:03d}","round":3,"subject":subject,"topic":raw["topic"],
    "question":raw["question"],"choices":choices,"correct_index":answer,
    "memory_line":raw.get("memory_line",raw["explanation"].split("。")[0]+"。"),
    "short_reason":raw.get("short_reason",raw["explanation"]),"explanation":raw["explanation"],
    "source_url":src["url"],"source_key":key,"source_authority":src["authority"],
    "reference_date":"2026-08-09","source_status":"primary_source_reviewed",
    "origin_type":"original_from_primary_source","rights_basis":RIGHTS,"audit_status":"approved"
   }
   data.append(q); seq+=1
 if len(data)!=200: raise SystemExit(f"round3 count mismatch {len(data)}/200")
 counts=Counter(q["subject"] for q in data)
 expected_counts={s:n for s,_,n in FILES}
 if dict(counts)!=expected_counts: raise SystemExit(f"distribution mismatch {dict(counts)}")
 OUT.parent.mkdir(parents=True,exist_ok=True)
 OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
 print(f"built round3 {len(data)} questions -> {OUT}")
 print("distribution:",dict(counts))
if __name__=="__main__": main()
