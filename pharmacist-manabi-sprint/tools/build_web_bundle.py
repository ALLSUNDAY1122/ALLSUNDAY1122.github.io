#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; P=ROOT/'content'/'product'; src=P/'questions.json'; out=P/'questions-web.json'
KEEP=('id','sourceExam','questionNo','subject','domain','question','choices','answer','accepted_answers','scoring_status','sharedStem','memoryPoint','explanation','displayMode','mediaAssets','numberedChoiceCount','dailySprintCanonicalId','attributionDisplay','modificationDisclosureDisplay','correctionStatus','origin_type')
d=json.loads(src.read_text(encoding='utf-8'));qs=[]
for q in d['questions']:
    qs.append({k:q.get(k) for k in KEEP if k in q})
web={'schemaVersion':1,'contentVersion':d.get('contentVersion'),'examSystemVersion':d.get('examSystemVersion'),'questionCount':len(qs),'questions':qs}
out.write_text(json.dumps(web,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
report={'questions':len(qs),'fullBytes':src.stat().st_size,'webBytes':out.stat().st_size,'reductionPercent':round((1-out.stat().st_size/src.stat().st_size)*100,1)}
(P/'web-bundle-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if len(qs)!=1035:raise SystemExit(1)
