#!/usr/bin/env python3
import argparse, json, re, sys, unicodedata
from collections import Counter
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urljoin
import requests
from bs4 import BeautifulSoup
from pypdf import PdfReader
INDEX_URL='https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/topics_150873_139_140.html'; RIGHTS_URL='https://www.mhlw.go.jp/chosakuken/'; R59_CORRECTION='https://www.mhlw.go.jp/general/sikaku/successlist/2024/siken08_09-2/about.html'; CHECKED_AT='2026-08-19'; TARGET_GENERAL=480; TARGET_PRACTICAL=120
SUBJECTS=['解剖学','生理学','運動学','病理学概論','臨床心理学','リハビリテーション医学','臨床医学大要','作業療法']; PRACTICAL_SUBJECTS=['運動学','臨床心理学','リハビリテーション医学','臨床医学大要','作業療法']
EXAM_DATES={45:'2010-02-28',46:'2011-02-27',47:'2012-02-26',48:'2013-02-24',49:'2014-02-23',50:'2015-03-01',51:'2016-02-28',52:'2017-02-26',53:'2018-02-25',54:'2019-02-24',55:'2020-02-23',56:'2021-02-21',57:'2022-02-20',58:'2023-02-19',59:'2024-02-18',60:'2025-02-24'}
MEDIA_TERMS=['別冊','図に示','図のよう','図を示','図から','画像','写真','MRI','ＣＴ画像','CT画像','エックス線写真','X線写真','超音波画像','心電図を示','波形を示','グラフに示','表に示','模式図','イラストを示']
RULES=[('作業療法',['作業療法','COPM','AMPS','MOHO','作業遂行','自助具','福祉用具','就労支援','復職','家事訓練','手工芸','余暇活動','生活行為']),('運動学',['関節可動域','ROM','筋力','MMT','歩行','姿勢','重心','運動学','筋収縮','関節運動','Brunnstrom','上肢機能','巧緻']),('臨床心理学',['心理','認知行動','防衛機制','投影法','知能検査','記憶検査','BADS','BIT','CAT','RBMT','精神療法','集団療法']),('リハビリテーション医学',['リハビリテーション','FIM','ICF','ADL','義肢','装具','車椅子','地域包括','介護保険','退院支援','自立支援']),('解剖学',['解剖','骨','筋','神経','靱帯','腱','関節','脳神経','脊髄神経','血管','動脈','静脈']),('生理学',['生理','呼吸','心拍','心拍数','血圧','代謝','ホルモン','電解質','酸素','換気','腎機能','神経伝導']),('病理学概論',['病理','炎症','腫瘍','癌','がん','感染','壊死','浮腫','免疫','アレルギー','変性']),('臨床医学大要',['疾患','症候','診断','治療','薬物','骨折','脳梗塞','脳出血','心不全','糖尿病','Parkinson','パーキンソン','統合失調症','うつ病','認知症'])]
@dataclass
class Source: exam:int; page_url:str; am_url:str; pm_url:str; answer_url:str
def norm(s): return unicodedata.normalize('NFKC',s or '').replace('\u3000',' ').strip()
def get(url,binary=False):
 r=requests.get(url,timeout=90,headers={'User-Agent':'LS16-question-bank-audit/1.0'}); r.raise_for_status(); return r.content if binary else r.text
def discover_exam_pages(min_exam=45,max_exam=60):
 soup=BeautifulSoup(get(INDEX_URL),'html.parser'); found={}
 for a in soup.find_all('a',href=True):
  t=norm(a.get_text(' ',strip=True)); m=re.search(r'第\s*(\d+)\s*回',t)
  if m and '作業療法士国家試験' in t and '問題' in t and '正答' in t and min_exam<=int(m.group(1))<=max_exam: found[int(m.group(1))]=urljoin(INDEX_URL,a['href'])
 return found
def pdf_links_from_page(page_url):
 soup=BeautifulSoup(get(page_url),'html.parser'); header=next((h for h in soup.find_all(['h2','h3']) if '作業療法士国家試験問題' in norm(h.get_text(' ',strip=True))),None)
 if not header: raise RuntimeError(f'OT section not found: {page_url}')
 links=[]; node=header
 while True:
  node=node.find_next()
  if node is None: break
  if node.name in ('h2','h3') and node is not header: break
  if node.name=='a' and node.get('href','').lower().endswith('.pdf'): links.append(urljoin(page_url,node['href']))
 if len(links)<5: raise RuntimeError(f'not enough OT PDF links ({len(links)}): {page_url}')
 return links[0],links[2],links[4]
def corrected_r59_answer():
 soup=BeautifulSoup(get(R59_CORRECTION),'html.parser')
 for a in soup.find_all('a',href=True):
  parent=norm(a.parent.get_text(' ',strip=True) if a.parent else a.get_text(' ',strip=True))
  if '第59回作業療法士国家試験正答' in parent: return urljoin(R59_CORRECTION,a['href'])
 raise RuntimeError('corrected R59 OT answer link not found')
def build_sources():
 pages=discover_exam_pages(); out=[]; fix=None
 for n in range(60,44,-1):
  if n not in pages: continue
  am,pm,ans=pdf_links_from_page(pages[n])
  if n==59: fix=fix or corrected_r59_answer(); ans=fix
  out.append(Source(n,pages[n],am,pm,ans))
 return out
def pdf_text(url,tmpdir):
 path=tmpdir/(re.sub(r'[^A-Za-z0-9._-]+','_',url.split('/')[-1]) or 'doc.pdf'); path.write_bytes(get(url,binary=True)); return '\n'.join((p.extract_text() or '') for p in PdfReader(str(path)).pages)
def answer_map(text):
 text=norm(text); ms=list(re.finditer(r'([AB])(\d{3})',text)); out={}
 for i,m in enumerate(ms):
  seg=text[m.end():(ms[i+1].start() if i+1<len(ms) else len(text))]; vals=[]
  for token in re.findall(r'(?<!\d)([1-5]{1,2})(?!\d)',seg):
   digs=[int(x) for x in token]
   if len(set(digs))==len(digs) and all(1<=x<=5 for x in digs) and digs not in vals: vals.append(digs)
  out[m.group(1)+m.group(2)]=vals
 return out
def clean_line(line): return re.sub(r'\s*DKIX[^\s]*.*$','',norm(line)).strip()
def find_q_starts(lines):
 starts={}; expected=1
 for idx,line in enumerate(lines):
  s=clean_line(line); m=re.match(r'^(\d{1,3})\s+(.+)$',s)
  if not m or int(m.group(1))!=expected: continue
  rest=m.group(2).strip()
  if rest.startswith(('．','.')) or len(rest)<3 or re.match(r'^(答案|問題番号|問№|正答)',rest) or sum(1 for c in rest if '\u3040'<=c<='\u30ff' or '\u4e00'<=c<='\u9fff')<1: continue
  starts[expected]=idx; expected+=1
  if expected==101: break
 return starts
def shared_contexts(lines,starts):
 contexts={}
 for idx,line in enumerate(lines):
  s=clean_line(line)
  if '次の文により' not in s or '問いに答えよ' not in s: continue
  nums=[int(x) for x in re.findall(r'\d{1,3}',s) if 1<=int(x)<=100]
  if len(nums)<2: continue
  targets=list(range(min(nums[0],nums[1]),max(nums[0],nums[1])+1)); first=targets[0]
  if first not in starts or idx>=starts[first]: continue
  ctx=' '.join(clean_line(lines[j]) for j in range(idx,starts[first]) if clean_line(lines[j]))
  for q in targets: contexts[q]=ctx
 return contexts
def trim_tail(s): return norm(re.sub(r'\s+\d+\s*$','',re.split(r'次の文により\s*[、,]?',s,maxsplit=1)[0]))
def split_choices(block):
 marks=[(int(m.group(1)),m.start(),m.end()) for m in re.finditer(r'(?<!\d)([1-5])\s*[．.]\s*',block)]; seq=None
 for i in range(len(marks)-4):
  if [marks[i+j][0] for j in range(5)]==[1,2,3,4,5]: seq=marks[i:i+5]
 if not seq: return None,[]
 stem=trim_tail(block[:seq[0][1]]); choices=[trim_tail(block[en:(seq[j+1][1] if j<4 else len(block))]) for j,(_,st,en) in enumerate(seq)]; return stem,choices
def extract_questions(text,session):
 lines=text.splitlines(); starts=find_q_starts(lines)
 if len(starts)!=100: raise RuntimeError(f'{session}: detected {len(starts)} question starts, expected 100; last={max(starts) if starts else None}')
 contexts=shared_contexts(lines,starts); out=[]
 for n in range(1,101):
  block=' '.join(clean_line(x) for x in lines[starts[n]:starts.get(n+1,len(lines))] if clean_line(x)); block=re.sub(r'^\s*'+str(n)+r'\s+','',block,count=1); stem,choices=split_choices(block)
  if stem and n in contexts: stem=norm(contexts[n]+' '+stem)
  out.append({'slot':n,'session':session,'text':stem or norm(block),'choices':choices})
 return out
def media_dependent(q):
 s=norm(q['text']+' '+' '.join(q.get('choices') or []))
 if len(q.get('choices') or [])!=5: return True,'malformed_choices'
 if any(term in s for term in MEDIA_TERMS): return True,'media_reference'
 if any(any(x in c for x in '①②③④⑤') for c in q['choices']): return True,'symbolic_media_choices'
 if min(len(norm(c)) for c in q['choices'])<1: return True,'empty_choice'
 return False,''
def classify(text,qtype):
 s=norm(text)
 for subject,words in RULES:
  if qtype=='practical' and subject not in PRACTICAL_SUBJECTS: continue
  if any(w in s for w in words): return subject
 return '作業療法' if qtype=='practical' else '臨床医学大要'
def topic_for(text,subject):
 m=re.search(r'([A-Za-zＡ-Ｚａ-ｚ0-9一-龥ぁ-んァ-ヶ]{2,18})(?:は|で|について|を)',norm(text)); return m.group(1)[:18] if m else subject+'・公式過去問'
def normalized_text(s): return re.sub(r'[\s\W_]+','',norm(s).lower(),flags=re.UNICODE)
def is_near_duplicate(text,accepted,threshold=0.90):
 a=normalized_text(text)
 if not a: return True,None,1.0
 for q in accepted:
  b=q['_norm']
  if a==b: return True,q['source_id'],1.0
  if min(len(a),len(b))/max(len(a),len(b))<0.72: continue
  r=SequenceMatcher(None,a,b).ratio()
  if r>=threshold: return True,q['source_id'],r
 return False,None,0.0
def explanation(q,sets):
 rendered=[]
 for aset in sets: rendered.append('・'.join(f'{i}「{q["choices"][i-1]}」' for i in aset if 1<=i<=len(q['choices'])))
 return f'厚生労働省の当該回公式正答値表では、正答は {" / ".join(rendered)} と公表されている。設問条件と正答選択肢を対応させて確認する。'
def process_source(src,tmpdir):
 amap=answer_map(pdf_text(src.answer_url,tmpdir)); allq=[]; stats=Counter()
 for session,url,prefix in [('am',src.am_url,'A'),('pm',src.pm_url,'B')]:
  for q in extract_questions(pdf_text(url,tmpdir),session):
   qtype='practical' if q['slot']<=20 else 'general'; accepted=amap.get(f'{prefix}{q["slot"]:03d}',[])
   if not accepted: stats['answer_blank_or_excluded']+=1; continue
   dep,reason=media_dependent(q)
   if dep: stats[reason]+=1; continue
   if not q['text'] or len(q['text'])<12: stats['short_text']+=1; continue
   subject=classify(q['text']+' '+' '.join(q['choices']),qtype); sid=f'OT-{src.exam}-{prefix}-{q["slot"]:03d}'
   allq.append({'source_id':sid,'reference_exam_round':src.exam,'source_session':session,'source_slot':q['slot'],'question_type':qtype,'subject':subject,'topic':topic_for(q['text'],subject),'text':q['text'],'choices':q['choices'],'answer_type':'multiChoice' if any(len(x)>1 for x in accepted) else 'singleChoice','accepted_answers':accepted,'answer':accepted[0],'scoring_status':'normal_or_final_accepted','explanation':explanation(q,accepted),'explanation_scope':'official_answer_verification','source':f'厚生労働省 第{src.exam}回作業療法士国家試験 {"午前" if session=="am" else "午後"} 問題','source_url':url,'source_page_url':src.page_url,'answer_source_url':src.answer_url,'baseline_date':EXAM_DATES.get(src.exam,f'{1965+src.exam}-01-01'),'source_checked_at':CHECKED_AT,'origin_type':'licensed_official','rights_status':'mhlw-pdl1-reviewed-text-only','rights_basis':'厚生労働省利用規約（PDL1.0準拠）。出典・加工表示を行い、図版・写真・別冊等の媒体依存問題は除外。','rights_url':RIGHTS_URL,'third_party_media':False,'media_dependency':False,'classification_basis':'app-internal keyword classification; not an official MHLW per-item subject label'}); stats['eligible']+=1
 return allq,stats
def choose_bank(pool):
 accepted=[]; stats=Counter(); bytype={'general':[],'practical':[]}
 for q in pool:
  dup,_,_=is_near_duplicate(q['text'],accepted)
  if dup: stats['duplicate_or_high_similarity']+=1; continue
  q['_norm']=normalized_text(q['text']); accepted.append(q); bytype[q['question_type']].append(q)
 if len(bytype['general'])<TARGET_GENERAL or len(bytype['practical'])<TARGET_PRACTICAL: raise RuntimeError(f'insufficient unique eligible pool: general={len(bytype["general"])} practical={len(bytype["practical"])}')
 gi=iter(bytype['general'][:TARGET_GENERAL]); pi=iter(bytype['practical'][:TARGET_PRACTICAL]); rounds=[]
 for r in range(1,4):
  items=[]
  for sess in ('am','pm'):
   for slot in range(1,101):
    q=next(pi) if slot<=20 else next(gi); q={k:v for k,v in q.items() if not k.startswith('_')}; q['id']=f'OT-R{r}-{sess.upper()}-{slot:03d}'; q['round']=f'R{r}'; q['session']=sess; q['slot']=slot; items.append(q)
  rounds.append(items)
 return rounds,stats
def audit(rounds):
 qs=[q for rd in rounds for q in rd]; errors=[]
 if len(qs)!=600: errors.append(f'total={len(qs)}')
 if len(set(q['id'] for q in qs))!=len(qs): errors.append('duplicate_ids')
 for r in ('R1','R2','R3'):
  rr=[q for q in qs if q['round']==r]
  if len(rr)!=200: errors.append(f'{r}_total={len(rr)}')
  for s in ('am','pm'):
   if sum(q['session']==s for q in rr)!=100: errors.append(f'{r}_{s}_count')
  ct=Counter(q['question_type'] for q in rr)
  if ct['practical']!=40 or ct['general']!=160: errors.append(f'{r}_type={dict(ct)}')
 for q in qs:
  if q['subject'] not in SUBJECTS or (q['question_type']=='practical' and q['subject'] not in PRACTICAL_SUBJECTS): errors.append(f'bad_subject:{q["id"]}')
  for f in ('topic','text','choices','answer','explanation','source_url','answer_source_url','baseline_date','rights_basis','rights_url'):
   if not q.get(f): errors.append(f'missing_{f}:{q["id"]}')
  if len(q.get('choices') or [])!=5 or q.get('third_party_media') or q.get('media_dependency'): errors.append(f'structure_or_media:{q["id"]}')
 exact={}; near=[]
 for i,q in enumerate(qs):
  a=normalized_text(q['text'])
  if a in exact: errors.append(f'exact:{exact[a]}:{q["id"]}')
  exact[a]=q['id']
  for p in qs[:i]:
   b=normalized_text(p['text'])
   if min(len(a),len(b))/max(len(a),len(b))<0.72: continue
   ratio=SequenceMatcher(None,a,b).ratio()
   if ratio>=0.90: near.append((p['id'],q['id'],round(ratio,4)))
 if near: errors.append(f'near_similarity={len(near)} first={near[:5]}')
 return errors,Counter(q['subject'] for q in qs),Counter(q['reference_exam_round'] for q in qs)
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--out',default='sagyo-ryohoshi-sprint/data'); ap.add_argument('--audit-out',default='sagyo-ryohoshi-sprint/audit/bank-audit.json'); ap.add_argument('--tmp',default='.tmp-ls16'); args=ap.parse_args(); out=Path(args.out); out.mkdir(parents=True,exist_ok=True); tmp=Path(args.tmp); tmp.mkdir(parents=True,exist_ok=True)
 pool=[]; source_stats={}
 for src in build_sources():
  try: qs,st=process_source(src,tmp)
  except Exception as e: print(f'SOURCE_FAIL R{src.exam}: {e}',file=sys.stderr); continue
  pool.extend(qs); source_stats[str(src.exam)]=dict(st); g=sum(q['question_type']=='general' for q in pool); p=sum(q['question_type']=='practical' for q in pool); print(f'SOURCE_OK R{src.exam} eligible={len(qs)} pooled general={g} practical={p}')
  if g>=TARGET_GENERAL+100 and p>=TARGET_PRACTICAL+45: break
 rounds,dedupe_stats=choose_bank(pool); errors,subjects,source_counts=audit(rounds)
 for i,rd in enumerate(rounds,1): (out/f'questions-r{i}.json').write_text(json.dumps(rd,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 report={'task':'LS16-004','checked_at':CHECKED_AT,'status':'PASS' if not errors else 'FAIL','total':sum(map(len,rounds)),'rounds':[len(x) for x in rounds],'type_counts':dict(Counter(q['question_type'] for rd in rounds for q in rd)),'subject_counts':dict(subjects),'source_exam_counts':dict(sorted(source_counts.items(),reverse=True)),'source_stats':source_stats,'dedupe_stats':dict(dedupe_stats),'errors':errors,'rights_gate':'PASS_TEXT_ONLY','rights_url':RIGHTS_URL,'r59_answer_basis':R59_CORRECTION,'notes':['subject is internal learning classification, not an official per-item MHLW label','media/figure/appendix dependent questions are excluded','R59 uses the corrected final MHLW answer publication']}
 Path(args.audit_out).parent.mkdir(parents=True,exist_ok=True); Path(args.audit_out).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(report,ensure_ascii=False,indent=2)); raise SystemExit(1 if errors else 0)
if __name__=='__main__': main()
