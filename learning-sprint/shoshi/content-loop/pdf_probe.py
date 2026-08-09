#!/usr/bin/env python3
import json,re,requests,pymupdf

PDF_LINKS={
'R5-AM':'https://www.moj.go.jp/content/001400147.pdf','R5-PM':'https://www.moj.go.jp/content/001400148.pdf',
'R6-AM':'https://www.moj.go.jp/content/001422259.pdf','R6-PM':'https://www.moj.go.jp/content/001422260.pdf',
'R7-AM':'https://www.moj.go.jp/content/001444126.pdf','R7-PM':'https://www.moj.go.jp/content/001444127.pdf'}
H={'User-Agent':'Mozilla/5.0'}
patterns=[re.compile(r'第\s*(\d+)\s*問'),re.compile(r'第([０-９0-9]+)問'),re.compile(r'(?m)^\s*(\d{1,2})\s*$')]
for key,url in PDF_LINKS.items():
 r=requests.get(url,headers=H,timeout=30);r.raise_for_status();doc=pymupdf.open(stream=r.content,filetype='pdf')
 rows=[]
 for i,p in enumerate(doc):
  txt=p.get_text('text',sort=True).replace('\x08',' ').replace('\x0c',' ')
  heads=[]
  for rx in patterns[:2]: heads += [m.group(1) for m in rx.finditer(txt)]
  lines=[re.sub(r'\s+',' ',x).strip() for x in txt.splitlines() if x.strip()]
  nums=[m.group(1) for m in patterns[2].finditer(txt)]
  rows.append({'p':i+1,'heads':heads[:5],'standalone_nums':nums[-6:],'first':' | '.join(lines[:3])[:220],'last':' | '.join(lines[-4:])[-260:]})
 print('===',key,'pages',len(doc),'===')
 print(json.dumps(rows,ensure_ascii=False))
