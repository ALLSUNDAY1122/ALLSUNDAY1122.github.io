#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
errors=[]
def err(s): errors.append(s)
index=(ROOT/'index.html').read_text(encoding='utf-8')
for needed in ('product-loader-v06.js','product-v06.css'):
    if needed not in index: err('index missing '+needed)
for old in ('./questions.js','./preflight-v05.js','./app.js'):
    if old in index: err('index still loads old '+old)
audit=json.loads((ROOT/'content/product/final-audit-v2.json').read_text(encoding='utf-8'))
if audit.get('finalPass') is not True: err('final product audit is not PASS')
if audit.get('questionCount')!=1035: err('audit questionCount != 1035')
if audit.get('blockedCount')!=0: err('blocked questions remain')
if audit.get('explanationCoverage')!=1035: err('explanation coverage incomplete')
if audit.get('unresolvedHighSimilarityPairs'): err('unresolved high similarity remains')
product=json.loads((ROOT/'content/product/questions.json').read_text(encoding='utf-8'))
qs=product.get('questions',[])
if len(qs)!=1035: err(f'product count {len(qs)}/1035')
active=[q for q in qs if q.get('scoring_status')!='excluded']; excluded=[q for q in qs if q.get('scoring_status')=='excluded']
if len(excluded)!=4: err(f'excluded count {len(excluded)}/4')
flex=[q for q in qs if q.get('scoring_status')=='multiple_accepted']
if len(flex)!=3: err(f'flexible answer count {len(flex)}/3')
media=[q for q in qs if q.get('displayMode')=='officialQuestionImage']; rebuilt=[q for q in qs if q.get('mediaAuditStatus')=='rebuilt_as_independent_text']
if len(media)!=154: err(f'media image count {len(media)}/154')
if len(rebuilt)!=4: err(f'rebuilt text media count {len(rebuilt)}/4')
for q in media:
    for rel in q.get('mediaAssets',[]):
        p=ROOT/rel
        if not p.exists() or p.stat().st_size<1000: err(f'media asset missing/short {q.get("id")}:{rel}')
for q in active:
    if not q.get('explanation') or not q.get('memoryPoint'): err('missing learning content '+q.get('id','?'))
    if q.get('release_status','').startswith('blocked'): err('blocked active '+q.get('id','?'))
    if q.get('displayMode')=='textChoices':
        c=q.get('choices') or []
        if not 2<=len(c)<=6: err('choice count '+q.get('id','?'))
for q in flex:
    acc=q.get('accepted_answers') or []
    if len(acc)!=3 or any(len(x)!=2 for x in acc): err('flexible rule malformed '+q.get('id','?'))
# Verify exact three official flexible rule IDs.
if {q['id'] for q in flex}!={'P111-287','P110-331','P109-305'}: err('flexible rule IDs mismatch')
report={'pass':not errors,'errors':errors,'total':len(qs),'active':len(active),'excluded':len(excluded),'flexible':len(flex),'media':len(media),'rebuiltMedia':len(rebuilt)}
(ROOT/'content/product/web-static-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
if errors: sys.exit(1)
