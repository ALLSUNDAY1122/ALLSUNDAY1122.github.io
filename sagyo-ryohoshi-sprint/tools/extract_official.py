#!/usr/bin/env python3
import json,re,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'audit'/'raw-official.json'
TMP=Path('/tmp/ls16-official'); TMP.mkdir(exist_ok=True)
SOURCES={
  1:{'exam_round':60,'am':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09a_01.pdf','pm':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09b_01.pdf','answer':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09seitou.pdf'},
  2:{'exam_round':59,'am':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp240424-09a_01.pdf','pm':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp240424-09b_01.pdf','answer':'https://www.mhlw.go.jp/general/sikaku/successlist/2024/siken08_09-2/dl/OT_seitou.pdf'},
  3:{'exam_round':58,'am':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp230524-09a_01.pdf','pm':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp230524-09b_01.pdf','answer':'https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp230524-09seitou.pdf'}
}

def download(url,name):
    p=TMP/name
    req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 LS16 audit'})
    with urllib.request.urlopen(req,timeout=60) as r: p.write_bytes(r.read())
    return p

def text(pdf):
    out=pdf.with_suffix('.txt')
    subprocess.run(['pdftotext','-layout','-nopgbrk',str(pdf),str(out)],check=True)
    return out.read_text(encoding='utf-8',errors='replace')

def parse_answers(t):
    ans={}
    for m in re.finditer(r'\b(AM|PM)\s*0*(\d{1,3})\s+((?:[1-5](?:\s+[1-5]){0,2})?)(?=\s+(?:AM|PM)\s*\d|\s*$)',t,re.M):
        sess='am' if m.group(1)=='AM' else 'pm'; n=int(m.group(2)); ans[(sess,n)]=m.group(3).strip()
    for m in re.finditer(r'\b([AB])\s*0*(\d{1,3})\s+([1-5]{1,2}|)(?=\s+[AB]\s*\d|\s*$)',t,re.M):
        sess='am' if m.group(1)=='A' else 'pm'; n=int(m.group(2)); ans.setdefault((sess,n),m.group(3).strip())
    toks=t.replace('\u3000',' ').split()
    for i,x in enumerate(toks):
        m=re.fullmatch(r'(AM|PM)(\d{1,3})',x,re.I) or re.fullmatch(r'([AB])(\d{3})',x,re.I)
        if not m: continue
        tag=m.group(1).upper(); sess='am' if tag in ('AM','A') else 'pm'; n=int(m.group(2)); vals=[]; j=i+1
        while j<len(toks) and len(vals)<3 and re.fullmatch(r'[1-5]{1,2}',toks[j]): vals.append(toks[j]); j+=1
        if (sess,n) not in ans: ans[(sess,n)]=' '.join(vals)
    return ans

def parse_questions(t):
    lines=[x.rstrip() for x in t.replace('\u3000',' ').splitlines()]
    starts=[]; expected=1
    for i,line in enumerate(lines):
        m=re.match(r'^\s*(\d{1,3})\s+(.+\S)\s*$',line)
        if m and int(m.group(1))==expected:
            starts.append((expected,i)); expected+=1
            if expected==101: break
    if len(starts)!=100:
        starts=[]; expected=1
        for i,line in enumerate(lines):
            m=re.match(r'^\s*(\d{1,3})\s*$',line)
            if m and int(m.group(1))==expected:
                starts.append((expected,i)); expected+=1
                if expected==101: break
    out=[]
    for k,(n,s) in enumerate(starts):
        e=starts[k+1][1] if k+1<len(starts) else len(lines)
        block=[x.strip() for x in lines[s:e] if x.strip()]
        if block: block[0]=re.sub(r'^\s*'+str(n)+r'\s*','',block[0],count=1).strip()
        block=[x for x in block if not re.match(r'^[-―ー\s]*\d+[-―ー\s]*$',x) and '作業療法士国家試験' not in x]
        candidates=[]
        for a in range(len(block)):
            if re.match(r'^1\s+\S',block[a]):
                pos=[]; cur=a; ok=True
                for digit in range(1,6):
                    found=None
                    for z in range(cur,min(len(block),cur+20)):
                        if re.match(r'^'+str(digit)+r'\s+\S',block[z]): found=z; break
                    if found is None: ok=False; break
                    pos.append(found); cur=found+1
                if ok: candidates.append(pos)
        pos=candidates[-1] if candidates else []
        if pos:
            stem=' '.join(block[:pos[0]]).strip(); choices=[]
            for ci,p in enumerate(pos):
                q=pos[ci+1] if ci+1<5 else len(block)
                ch=re.sub(r'^[1-5]\s+','',block[p],count=1)
                cont=[x for x in block[p+1:q] if not re.match(r'^\d{1,3}\s*$',x)]
                choices.append(' '.join([ch]+cont).strip())
        else: stem=' '.join(block).strip(); choices=[]
        marker=bool(re.search(r'別冊|図(?:に|を|で)|画像|写真|MRI|CT|エックス線|X線|グラフ|模式図|標本',stem)) or len(choices)!=5
        out.append({'number':n,'question':stem,'choices':choices,'requires_media':marker,'raw_block':'\n'.join(block)})
    return out

def decode(raw):
    raw=(raw or '').strip()
    if not raw: return {'scoring_status':'excluded','answer_type':'singleChoice','answer':None,'accepted_answers':None}
    groups=raw.split()
    if len(groups)>1:
        sets=[]
        for g in groups: sets.append([int(c)-1 for c in g])
        primary=sets[0]
        return {'scoring_status':'multiple_accepted','answer_type':'multiChoice' if len(primary)>1 else 'singleChoice','answer':primary if len(primary)>1 else primary[0],'accepted_answers':sets}
    arr=[int(c)-1 for c in groups[0]]
    return {'scoring_status':'normal','answer_type':'multiChoice' if len(arr)>1 else 'singleChoice','answer':arr if len(arr)>1 else arr[0],'accepted_answers':None}

def main():
    rows=[]; report=[]
    for r,cfg in SOURCES.items():
        ap=download(cfg['answer'],f'r{r}-ans.pdf'); amap=parse_answers(text(ap)); report.append({'round':r,'exam_round':cfg['exam_round'],'answers':len(amap)})
        for sess in ('am','pm'):
            qp=download(cfg[sess],f'r{r}-{sess}.pdf'); qs=parse_questions(text(qp))
            report[-1][sess+'_questions']=len(qs); report[-1][sess+'_media']=sum(x['requires_media'] for x in qs)
            for q in qs:
                d=decode(amap.get((sess,q['number'])))
                rows.append({'id':f"OT-R{r}-{sess.upper()}-{q['number']:03d}",'round':r,'reference_exam_round':cfg['exam_round'],'session':sess,'slot':q['number'],'question':q['question'],'choices':q['choices'],'requires_media':q['requires_media'],'official_answer_raw':amap.get((sess,q['number'],''),),**d,'question_source_url':cfg[sess],'answer_source_url':cfg['answer'],'raw_block':q['raw_block']})
    OUT.parent.mkdir(parents=True,exist_ok=True); OUT.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2)); print('TOTAL',len(rows),'MEDIA',sum(x['requires_media'] for x in rows)); print('EMPTY_CHOICES',sum(len(x['choices'])!=5 for x in rows),'EXCLUDED',sum(x['scoring_status']=='excluded' for x in rows))
    for x in rows[:3]+rows[97:100]: print(x['id'],x['question'][:80],x['choices'][:2],x['official_answer_raw'])
if __name__=='__main__': main()
