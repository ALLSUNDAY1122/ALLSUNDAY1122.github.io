#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
STAGES=[
 ('base','classify_questions.py'),
 ('refine-v3','refine_classification.py'),
 ('refine-v4','refine_classification_v4.py'),
 ('refine-v5','refine_classification_v5.py'),
 ('refine-v6','refine_classification_v6.py'),
 ('refine-v7','refine_classification_v7.py'),
 ('refine-v8','refine_classification_v8.py'),
 ('refine-v9','refine_classification_v9.py'),
 ('refine-v10','refine_classification_v10.py'),
 ('situation-specialist-corrections','apply_situation_classification_corrections.py'),
 ('validate','validate_classification.py'),
 ('semantic-audit','audit_classification_semantics.py'),
 ('situation-summary','summarize_situation_groups.py'),
 ('situation-semantic-audit','audit_situation_group_semantics.py'),
 ('warning-resolution','validate_classification_warnings.py'),
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

(ROOT/'classified/classification-run-summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
