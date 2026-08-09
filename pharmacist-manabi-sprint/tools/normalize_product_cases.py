#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,os,re
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; P=ROOT/'content'/'product'/'questions.json'
def clean(s):return re.sub(r'\s+',' ',str(s or '')).strip()
def common_prefix(a,b):return os.path.commonprefix([a,b])
def hashq(q):
 s=clean(q.get('question')).casefold()+'\n'+'\n'.join(clean(x).casefold() for x in q.get('choices',[]));return hashlib.sha256(s.encode()).hexdigest()[:20]
def split_at_sentence(prefix):
 marks=[prefix.rfind(x) for x in ('。','！','？','：',':')];i=max(marks)
 if i>=80:return prefix[:i+1].strip()
 return ''
def main():
 d=json.loads(P.read_text(encoding='utf-8'));qs=d['questions'];groups=defaultdict(list)
 for q in qs:
  if q.get('caseGroupId'):groups[q['caseGroupId']].append(q)
 extracted=[]
 for gid,items in groups.items():
  if len(items)!=2:continue
  a,b=items; pa=clean(a.get('question'));pb=clean(b.get('question'));pref=common_prefix(pa,pb)
  stem=split_at_sentence(pref)
  if len(stem)<80:continue
  qa=pa[len(stem):].strip();qb=pb[len(stem):].strip()
  if len(qa)<8 or len(qb)<8:continue
  a['sharedStem']=stem;b['sharedStem']=stem;a['question']=qa;b['question']=qb;extracted.append({'caseGroupId':gid,'questions':[a['id'],b['id']],'stemLength':len(stem)})
 # Rebuild canonical exact-repeat markers after normalization.
 roots={}
 for q in qs:
  h=hashq(q);q['canonicalContentHash']=h
  if h in roots:q['historicalRepeatOf']=roots[h];q['dailySprintCanonicalId']=roots[h]
  else:roots[h]=q['id'];q['historicalRepeatOf']=None;q['dailySprintCanonicalId']=q['id']
 d['questions']=qs;P.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 report={'caseGroupCandidates':len(groups),'sharedStemExtracted':len(extracted),'examples':extracted[:20]}
 (ROOT/'content'/'product'/'case-normalization.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
