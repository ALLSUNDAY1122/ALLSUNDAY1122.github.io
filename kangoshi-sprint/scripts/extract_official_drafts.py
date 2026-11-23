#!/usr/bin/env python3
"""Generate evidence-backed DRAFT records for 112/111; never publish raw guesses."""
import json,re,sys,pathlib,hashlib,unicodedata
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
def lines(pdf):
    doc=fitz.open(pdf)
    for pi,p in enumerate(doc):
        for line in p.get_text("text",sort=True).splitlines():
            s=line.strip()
            if s:yield pi+1,s
def parse(pdf,exam,session):
    # The official PDF has sample questions 201-204 on pages 1-3;
    # actual examination starts at question 1 on subsequent pages.
    rows=list(lines(pdf));start=next((i for i,(pg,line) in enumerate(rows) if pg>=5 and re.match(r"^1\s+[^0-9.]",line)),None)
    if start is None: return {"exam":exam,"session":session,"status":"NO_QUESTION_1_DETECTED","questions":[]}
    chunks=[];num=None;content=[];page=None
    for pg,line in rows[start:]:
        # parse only valid numbered question headers in ascending sequence
        m=re.match(r"^(\d{1,3})[ \t　]+([^\s].*)$",line)
        n=int(m.group(1)) if m else None
        if n is not None and 1<=n<=120 and (num is None and n==1 or num is not None and n==num+1):
            if num is not None:chunks.append((num,page,content))
            num=n;page=pg;content=[m.group(2)]
            if n==120:continue
        elif num is not None:content.append(line)
    if num is not None:chunks.append((num,page,content))
    out=[];failure=[]
    for n,page,body in chunks:
        groups=[];current=None
        for s in body:
            m=re.match(r"^([1-5])[\.．。．\s]+(.+)$",s)
            if m:
                if current:groups.append(current)
                current={"index":int(m.group(1)),"parts":[m.group(2)]}
            elif current:current["parts"].append(s)
        if current:groups.append(current)
        choice_numbers=[g["index"] for g in groups]
        clean=[{"number":g["index"],"text":" ".join(g["parts"])} for g in groups]
        valid=len(clean)>=2 and choice_numbers==list(range(1,len(clean)+1)) and len(clean)<=5 and n<=120
        q={"id":f"K{exam}-{session}{n:03d}","sourceExam":exam,"session":session,"questionNo":n,
            "question":" ".join(body[:next((i for i,s in enumerate(body) if re.match(r"^[1-5][\.．。．\s]+",s)),len(body))]),
            "choices":[v["text"] for v in clean],"answer":None,"sourcePage":page,
            "sourceRefs":[],"sourceAttribution":f"出典：厚生労働省『第{exam}回看護師国家試験』を学習用データとして加工",
            "requiresMedia":None,"rightsStatus":"not_audited","reviewStatus":"HOLD_OFFICIAL_KEY_AND_LAYOUT",
            "extractionValid":valid}
        if not valid:failure.append(n)
        out.append(q)
    complete=len(out)==120 and [q["questionNo"] for q in out]==list(range(1,121)) and not failure
    return {"exam":exam,"session":session,"status":"STAGING_ONLY" if complete else "HOLD_EXTRACTION_INCOMPLETE",
            "detected":len(out),"invalidQuestionNumbers":failure,"questions":out,
            "note":"No key parsing, media rights, scenario grouping or visual verification; never include in release bank"}
def main():
    base=ROOT/"audit/runs";base.mkdir(parents=True,exist_ok=True)
    summary={}
    sources={e["exam"]:e for e in json.loads((ROOT/"audit/official-source-manifest-20261124.json").read_text())["sources"]}
    for exam in (112,111):
        for session in ("AM","PM"):
            pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
            if not pdf.exists():
                summary[f"{exam}-{session}"]={"status":"PDF_MISSING"};continue
            data=parse(pdf,exam,session)
            data["pdfSha256"]=hashlib.sha256(pdf.read_bytes()).hexdigest()
            for q in data["questions"]:
                q["sourceRefs"]=[sources[exam]["morningPdf" if session=="AM" else "afternoonPdf"],sources[exam]["answerPdf"]]
                q["textFidelity"]="UNVERIFIED_PDF_GLYPH_MAPPING"
                q["answerSourceChecked"]=False
                q["requiresMedia"]=None
                q["reviewStatus"]="HOLD_OFFICIAL_KEY_AND_TEXT_FIDELITY"
            (base/f"exam{exam}-{session}-draft.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
            summary[f"{exam}-{session}"]={"status":data["status"],"detected":data.get("detected",0),"invalid":data.get("invalidQuestionNumbers",[])}
    (base/"new-draft-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))
if __name__=="__main__":main()
