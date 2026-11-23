#!/usr/bin/env python3
"""Fail-closed PDF-text verification gate for nursing exam question exports.
Usage: python3 audit_official_pdf.py --questions questions.json --pdf official.pdf --report report.json
Requires: pip install pymupdf
"""
import argparse, json, re, hashlib, pathlib, sys
def norm(s):
    return re.sub(r"\s+", "", str(s)).replace("−","-").replace("－","-")
def main():
    p=argparse.ArgumentParser();p.add_argument("--questions",required=True);p.add_argument("--pdf",required=True);p.add_argument("--report",required=True);a=p.parse_args()
    import fitz
    pdf=pathlib.Path(a.pdf); doc=fitz.open(pdf); pages=[norm(x.get_text(sort=True)) for x in doc]
    data=json.loads(pathlib.Path(a.questions).read_text(encoding="utf-8"))
    if isinstance(data,dict): data=data.get("questions",[])
    if not isinstance(data,list): raise ValueError("questions must be list")
    results=[]
    for q in data:
        ident=q.get("id","UNKNOWN"); fields=[q.get("question") or q.get("stem") or q.get("text") or ""]
        opts=q.get("options") or q.get("choices") or []
        fields += [x.get("text","") if isinstance(x,dict) else str(x) for x in opts]
        fields=[norm(x) for x in fields]
        hits=[i+1 for i,page in enumerate(pages) if fields[0] and fields[0] in page]
        match=bool(hits) and all(any(f in pages[i-1] for i in hits) for f in fields if f)
        flags=[k for k in ("image","images","media","figure","diagram","photo") if q.get(k)]
        status="HOLD_MEDIA_RIGHTS" if flags else ("PASS_TEXT" if match and all(fields) else "HOLD_TEXT_MISMATCH")
        results.append({"id":ident,"status":status,"pdf_pages":hits,"media_flags":flags})
    output={"pdf_sha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),"questions":len(results),"pass_text":sum(x["status"]=="PASS_TEXT" for x in results),"hold":sum(x["status"]!="PASS_TEXT" for x in results),"results":results,"note":"Text extraction is a primary gate, not proof of image rights, correct answer keys, ruby, layout or legal accuracy."}
    pathlib.Path(a.report).write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in output.items() if k!="results"},ensure_ascii=False))
    return 0 if output["hold"]==0 else 1
if __name__=="__main__": sys.exit(main())
