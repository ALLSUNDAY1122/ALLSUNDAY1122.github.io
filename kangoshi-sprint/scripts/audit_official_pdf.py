#!/usr/bin/env python3
"""Nursing exam strict PDF text audit. Never interpret a text match as media rights or answer-key clearance."""
import argparse, hashlib, json, pathlib, re, sys, unicodedata

def normalize(value):
    s=unicodedata.normalize("NFKC",str(value))
    return re.sub(r"[\s\u200b\ufeff]+","",s).replace("−","-").replace("‐","-").replace("〜","~").replace("～","~").replace("\x02つ選べ","2つ選べ").replace("઄つ選べ","2つ選べ")

def assess(question,pages):
    stem=normalize(question.get("question") or question.get("stem") or question.get("text") or "")
    options=question.get("choices") or question.get("options") or []
    options=[normalize(x.get("text","") if isinstance(x,dict) else x) for x in options]
    media=bool(question.get("requiresMedia") or any(question.get(k) for k in ("image","images","media","figure","diagram","photo")))
    if media:
        return "HOLD_MEDIA_RIGHTS",[], "Media rights must be verified per item"
    if not stem or not options or any(not x for x in options):
        return "HOLD_INCOMPLETE_DATA",[], "Missing stem or choices"
    if not question.get("sourceAttribution"):
        return "HOLD_MISSING_ATTRIBUTION",[], "Per-question source attribution missing"
    hits=[i+1 for i,p in enumerate(pages) if stem in p]
    if not hits:
        return "HOLD_STEM_MISMATCH",[], "Normalized stem absent from source PDF"
    if not any(all(x in pages[i-1] for x in options) for i in hits):
        return "HOLD_CHOICES_MISMATCH",hits,"Not all choices present on the same source page as stem"
    return "PASS_TEXT_ONLY",hits,"Answer key, scanning, figures, and scoring exceptions not checked"

def run(args):
    import fitz
    source=pathlib.Path(args.pdf)
    if not source.is_file(): raise FileNotFoundError(str(source))
    doc=fitz.open(source)
    pages=[normalize(p.get_text(sort=True)) for p in doc]
    data=json.loads(pathlib.Path(args.questions).read_text(encoding="utf-8"))
    questions=data["questions"] if isinstance(data,dict) else data
    if not isinstance(questions,list): raise ValueError("Expected questions list")
    expected_session=args.session.upper()
    results=[]
    for q in questions:
        if q.get("session","").upper()!=expected_session:continue
        code,hits,detail=assess(q,pages)
        results.append({"id":q.get("id"),"status":code,"pages":hits,"reason":detail})
    kinds=sorted(set(x["status"] for x in results))
    counts={x:sum(q["status"]==x for q in results) for x in kinds}
    output={"exam":args.exam,"session":expected_session,"source":args.source_url,"pdf_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"questionsChecked":len(results),"statusCounts":counts,"sourcePageCount":len(pages),"answerCheck":"NOT_RUN","mediaRightsCheck":"UNVERIFIED","results":results}
    pathlib.Path(args.report).parent.mkdir(parents=True,exist_ok=True)
    pathlib.Path(args.report).write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"exam":args.exam,"session":expected_session,"questionsChecked":len(results),"statusCounts":counts},ensure_ascii=False))
    return 0 if counts.get("PASS_TEXT_ONLY")==120 and len(results)==120 else 1

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    for name in ("questions","pdf","report","session","source-url"):ap.add_argument("--"+name,required=True)
    ap.add_argument("--exam",required=True,type=int)
    args=ap.parse_args()
    if args.session.upper() not in ("AM","PM"): ap.error("session must be AM or PM")
    sys.exit(run(args))
