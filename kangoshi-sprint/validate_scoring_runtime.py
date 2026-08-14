#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
app=(ROOT/'app-v03.js').read_text(encoding='utf-8')
index=(ROOT/'index.html').read_text(encoding='utf-8')
scoring=(ROOT/'scoring-overrides.js').read_text(encoding='utf-8')
expected={
 'K113-AM005':'include_if_correct_exclude_if_wrong','K113-AM023':'include_if_correct_exclude_if_wrong',
 'K113-AM025':'include_if_correct_exclude_if_wrong','K113-PM002':'include_if_correct_exclude_if_wrong',
 'K113-PM011':'include_if_correct_exclude_if_wrong','K113-PM021':'excluded',
 'K115-AM032':'excluded','K115-AM080':'multiple_accepted'
}
errors=[]
for qid,mode in expected.items():
    if qid not in scoring or f"mode:'{mode}'" not in scoring:
        errors.append(f'{qid}: missing mode {mode}')
markers={
 'map':'const SCORING=window.KANGOSHI_SCORING||{};',
 'examPool':'const examNo=[115,114,113][round];',
 'rule':'function scoringRule(q)',
 'excluded':"rule.mode==='excluded'",
 'conditional':"rule.mode==='include_if_correct_exclude_if_wrong'",
 'multiple':"rule.mode==='multiple_accepted'",
 'scoredTotal':'scoredTotal=session.results.filter',
 'neutral':'採点対象外'
}
for name,needle in markers.items():
    if needle not in app: errors.append(f'app marker missing: {name}')
if '<script src="scoring-overrides.js"></script>' not in index: errors.append('index missing scoring-overrides.js')
if scoring.find("'K115-AM080':{mode:'multiple_accepted',acceptedAnswers:[3,4]")<0:
    errors.append('K115-AM080 accepted answers mismatch')
report={'schemaVersion':1,'exceptionCount':len(expected),'expected':expected,'markers':{k:(v in app) for k,v in markers.items()},'pass':not errors,'errors':errors}
(ROOT/'product-content'/'scoring-runtime-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
