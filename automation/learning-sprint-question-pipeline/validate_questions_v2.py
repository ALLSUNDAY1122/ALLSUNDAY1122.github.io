#!/usr/bin/env python3
"""Learning Sprint v2 structural validator: subject allowlists without fabricated official per-subject counts."""
import argparse,json,re,sys
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path
def norm(s): return re.sub(r'[\s\W_]+','',str(s).lower(),flags=re.UNICODE)
def main():
 p=argparse.ArgumentParser(); p.add_argument('--config',required=True); p.add_argument('files',nargs='+'); a=p.parse_args(); c=json.loads(Path(a.config).read_text(encoding='utf-8')); qs=[]
 for f in a.files: qs.extend(json.loads(Path(f).read_text(encoding='utf-8')))
 errs=[]; rounds=c['rounds']; qpr=c['questions_per_round']; subjects=set(c['subjects']); practical=set(c['practical_allowed_subjects'])
 if len(qs)!=len(rounds)*qpr: errs.append(f'total expected={len(rounds)*qpr} actual={len(qs)}')
 ids=[q.get('id') for q in qs]
 if len(set(ids))!=len(ids): errs.append('duplicate ids')
 for r in rounds:
  rr=[q for q in qs if q.get('round')==r]
  if len(rr)!=qpr: errs.append(f'{r}: expected {qpr}, got {len(rr)}')
  for sess,n in c['sessions_per_round'].items():
   got=sum(q.get('session')==sess for q in rr)
   if got!=n: errs.append(f'{r}/{sess}: expected {n}, got {got}')
  tc=Counter(q.get('question_type') for q in rr)
  for typ,n in c['question_type_counts'].items():
   if tc[typ]!=n: errs.append(f'{r}/{typ}: expected {n}, got {tc[typ]}')
 required=['id','round','session','slot','question_type','subject','topic','text','choices','answer','accepted_answers','explanation','source','source_url','answer_source_url','baseline_date','origin_type','rights_basis','rights_url','source_checked_at']
 for q in qs:
  for f in required:
   if q.get(f) in (None,'',[]): errs.append(f'{q.get("id")}: missing {f}')
  if q.get('subject') not in subjects: errs.append(f'{q.get("id")}: invalid subject')
  if q.get('question_type')=='practical' and q.get('subject') not in practical: errs.append(f'{q.get("id")}: invalid practical subject')
  if len(q.get('choices') or [])!=5: errs.append(f'{q.get("id")}: choices != 5')
  if q.get('third_party_media') or q.get('media_dependency'): errs.append(f'{q.get("id")}: unresolved media')
 for i,q in enumerate(qs):
  x=norm(q.get('text',''))
  for p0 in qs[:i]:
   y=norm(p0.get('text',''))
   if x==y: errs.append(f'exact duplicate: {p0["id"]}/{q["id"]}'); continue
   if min(len(x),len(y))/max(len(x),len(y))<0.72: continue
   if SequenceMatcher(None,x,y).ratio()>=c.get('similarity_threshold',0.90): errs.append(f'high similarity: {p0["id"]}/{q["id"]}')
 print(json.dumps({'status':'PASS' if not errs else 'FAIL','questions':len(qs),'errors':errs[:100],'error_count':len(errs)},ensure_ascii=False,indent=2))
 if errs: sys.exit(1)
if __name__=='__main__': main()
