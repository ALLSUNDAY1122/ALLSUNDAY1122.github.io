#!/usr/bin/env python3
"""Debug only: locate printed shared-case header for 19 situation questions."""
import json,pathlib,subprocess,re,collections,sys
import fitz
R=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R/"scripts"))
from bulk_text_helpers import clean_font,norm
D=json.loads((R/"product-content/coordinate-reextracted-pending-20261124.json").read_text())
for exam,session in ((112,"AM"),(112,"PM"),(111,"AM"),(111,"PM")):
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
    doc=fitz.open(pdf)
    for q in D["questions"]:
      if q["sourceExam"]!=exam or q["session"]!=session or q["questionNo"]<91:continue
      n=q["questionNo"];first=91+3*((n-91)//3)
      pg=q["sourcePage"]
      hits=[]
      for p in range(max(1,pg-4),min(len(doc),pg+1)+1):
        raw=doc[p-1].get_text("text",sort=False)
        lines=raw.splitlines()
        for i,line in enumerate(lines):
          if "次の文を読み" in line or "次の文章を読み" in line:
            match=re.search(r"(?:次の文を読み|次の文章を読み)\s*(\d+)\s*[〜～~−-]\s*(\d+)",line)
            if match and int(match.group(1))==first:
              alt=subprocess.run(["pdftotext","-f",str(p),"-l",str(p),"-layout","-enc","UTF-8",str(pdf),"-"],capture_output=True,text=True).stdout
              raw_excerpt="\n".join(lines[i:i+9])
              a=alt.splitlines()
              idx=next((k for k,x in enumerate(a) if "次の文を読み" in x and str(first) in x),None)
              pop_excerpt="\n".join(a[idx:idx+9]) if idx is not None else ""
              hits.append({"page":p,"raw":repr(raw_excerpt[:700]),"poppler":repr(pop_excerpt[:700]),
                "anchorFirst":first,"header":line})
      print("SITUATION_DIAG",json.dumps({"id":q["id"],"number":n,"sourcePage":pg,"groupFirst":first,"hits":hits},ensure_ascii=False))
