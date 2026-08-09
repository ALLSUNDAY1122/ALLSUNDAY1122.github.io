#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/"audit"
R1=AUDIT/"data/questions.round1.canonical.json"
R2=AUDIT/"data/questions.round2.canonical.json"
R3=AUDIT/"data/questions.round3.canonical.json"
OUT=AUDIT/"data/questions.round1-2-3.canonical.json"

def rebalance_answer_positions(round_data):
 out=[]
 for pos,q in enumerate(round_data):
  q=dict(q); choices=list(q["choices"]); old=q["correct_index"]
  correct=choices[old]
  distractors=[c for i,c in enumerate(choices) if i!=old]
  target=pos % 5
  new_choices=distractors[:]
  new_choices.insert(target,correct)
  q["choices"]=new_choices; q["correct_index"]=target
  q["choice_order_policy"]="balanced_0_to_4_cycle"
  out.append(q)
 return out

def main():
 subprocess.check_call([sys.executable,str(AUDIT/"build_round2_canonical.py")])
 subprocess.check_call([sys.executable,str(AUDIT/"build_round3_canonical.py")])
 if not R1.exists(): subprocess.check_call([sys.executable,str(AUDIT/"build_round1_canonical.py")])
 rounds=[json.loads(p.read_text(encoding="utf-8")) for p in (R1,R2,R3)]
 if [len(x) for x in rounds] != [200,200,200]: raise SystemExit(f"round size mismatch {[len(x) for x in rounds]}")
 rounds=[rebalance_answer_positions(x) for x in rounds]
 data=rounds[0]+rounds[1]+rounds[2]
 ids=[q["id"] for q in data]
 if len(ids)!=len(set(ids)): raise SystemExit("cross-round duplicate IDs")
 OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
 print(f"built {len(data)} questions -> {OUT}")
 for i,r in enumerate(rounds,1):
  print(f"round{i} answer positions:",[sum(1 for q in r if q['correct_index']==x) for x in range(5)])
if __name__=="__main__": main()
