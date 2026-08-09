#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
STAGES=[
 ('base','classify_questions.py'),
 ('refine-v3','refine_classification.py'),
 ('refine-v4','refine_classification_v4.py'),
 ('refine-v5','refine_classification_v5.py'),
]
results=[]
for name,file in STAGES:
    p=subprocess.run([sys.executable,str(ROOT/file)],capture_output=True,text=True)
    print(f'=== {name} ===')
    print(p.stdout,end='')
    if p.stderr: print(p.stderr,file=sys.stderr,end='')
    results.append({'stage':name,'file':file,'exit':p.returncode})
    if p.returncode:
        (ROOT/'classified/classification-run-summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        sys.exit(p.returncode)

p=subprocess.run([sys.executable,str(ROOT/'validate_classification.py')],capture_output=True,text=True)
print('=== validate ==='); print(p.stdout,end='')
if p.stderr: print(p.stderr,file=sys.stderr,end='')
results.append({'stage':'validate','file':'validate_classification.py','exit':p.returncode})
(ROOT/'classified/classification-run-summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sys.exit(p.returncode)
