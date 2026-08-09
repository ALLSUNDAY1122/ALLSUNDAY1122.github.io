#!/usr/bin/env python3
"""Create conservative explanations anchored only to the official correct choices.

This is the no-model fallback. It never invents numerical/calculation reasoning.
Those questions are emitted to a manual-reason queue. Existing manual/model-reviewed
overlays always take precedence.
"""
from __future__ import annotations

import csv
import glob
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "content" / "review"
REVIEWED = ROOT / "content" / "reviewed"
OUT = REVIEWED / "official-anchor"
OUT.mkdir(parents=True, exist_ok=True)
MANUAL = REVIEW / "manual-reason-queue.tsv"


def existing_ids():
    ids=set()
    for p in glob.glob(str(REVIEWED/"**"/"*.json"), recursive=True):
        if "/official-anchor/" in p:
            continue
        try: d=json.loads(Path(p).read_text(encoding="utf-8"))
        except Exception: continue
        items=d if isinstance(d,list) else d.get("items",[]) if isinstance(d,dict) else []
        for x in items:
            if isinstance(x,dict) and x.get("id"): ids.add(x["id"])
    return ids


def correct_choice_texts(row):
    choices=json.loads(row["choices_json"])
    ans=json.loads(row["answer_json"])
    accepted=json.loads(row["accepted_answers_json"])
    if row["scoring_status"]=="excluded": return [], "解なし"
    if row["scoring_status"]=="multiple_accepted":
        pool=sorted({i for combo in accepted for i in combo})
        return [choices[i] for i in pool if 0<=i<len(choices)], "・".join(str(i+1) for i in pool)+"から任意2つ"
    inds=ans if isinstance(ans,list) else [ans]
    return [choices[i] for i in inds if isinstance(i,int) and 0<=i<len(choices)], "・".join(str(i+1) for i in inds if isinstance(i,int))


def weak_reason(texts,row):
    joined=" ".join(texts).strip()
    if row["scoring_status"]=="excluded": return False
    if not joined: return True
    if re.fullmatch(r"[\d\s.,%％±+\-−×÷/()（）μmMgLmolEq<>＝=^²³⁻⁺℃°・]+",joined): return True
    q=row["question"]
    calculation_terms=("最も近い値","何倍","何回目","含量","濃度はどれ","投与量","クリアランス","半減期","求めよ","算出","計算")
    if any(k in q for k in calculation_terms) and len(joined)<45:
        return True
    return False


def clip(s,n=180):
    s=re.sub(r"\s+"," ",s).strip()
    return s if len(s)<=n else s[:n-1]+"…"


def ask_clause(q):
    q=clip(q,260)
    sentences=[x.strip() for x in re.split(r"(?<=[。？！?])",q) if x.strip()]
    if not sentences: return q
    return clip(sentences[-1],140)


def main():
    existing=existing_ids()
    manual=[]; generated=[]
    for exam in (111,110,109):
        source=REVIEW/f"text-{exam}.tsv"
        if not source.exists(): continue
        batch=[]
        with source.open(encoding="utf-8",newline="") as f:
            for row in csv.DictReader(f,delimiter="\t"):
                if row["id"] in existing: continue
                texts,label=correct_choice_texts(row)
                if weak_reason(texts,row):
                    manual.append(row); continue
                if row["scoring_status"]=="excluded":
                    memory="公式正答は『解なし』。通常の得点問題として扱わない。"
                    explanation="厚生労働省の公式正答表で解なしとされているため、通常の採点対象から除外する。訂正情報がある場合は訂正版を参照し、独立した修正版問題を作る場合は別ID・別来歴で管理する。"
                else:
                    facts="／".join(clip(x,140) for x in texts)
                    clause=ask_clause(row["question"])
                    memory=f"{clip(clause,80)} → {clip(facts,100)}"
                    explanation=(
                        f"厚生労働省の公式正答は{label}。設問は「{clause}」を判断する問題で、選択対象となるのは「{clip(facts,260)}」。"
                        f"{row['domain']}では、この設問条件と正答肢の対応を区別できることが要点になる。"
                    )
                batch.append({
                    "id":row["id"],"memoryPoint":memory,"explanation":explanation,
                    "reviewRequired":False,"generator":"official-question-and-correct-choice-anchor",
                    "generationStatus":"pending_final_semantic_audit"
                })
        if batch:
            (OUT/f"official-anchor-{exam}.json").write_text(json.dumps(batch,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
            generated.extend(x["id"] for x in batch)
    if manual:
        fields=manual[0].keys()
        with MANUAL.open("w",encoding="utf-8",newline="") as f:
            w=csv.DictWriter(f,fieldnames=fields,delimiter="\t",lineterminator="\n"); w.writeheader(); w.writerows(manual)
    elif MANUAL.exists(): MANUAL.unlink()
    report={"existingHighQuality":len(existing),"officialAnchorGenerated":len(generated),"manualReasonQueue":len(manual),"textTotal":len(existing)+len(generated)+len(manual)}
    (REVIEW/"fallback-summary.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False))

if __name__=="__main__": main()
