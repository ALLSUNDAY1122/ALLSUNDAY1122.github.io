#!/usr/bin/env python3
"""Conservative 2-D table geometry + furigana anchoring from source PDF.

A row passes ONLY if each of 4/5 numbered choices has unique aligned
(正/誤) cell coordinates. Ruby association alone is not sufficient for
publication: the app must render the base+reading accurately.
"""
import argparse,collections,hashlib,json,re
from pathlib import Path
import fitz
from auto_diff_pdf import B,download,norm,source_pages,git_blob_sha

KANJI=re.compile(r"[\u3400-\u9fff々]")
KANA=re.compile(r"^[ぁ-んァ-ンー]{1,12}$")
ONE_DIGIT={"１":1,"２":2,"３":3,"４":4,"５":5,"1":1,"2":2,"3":3,"4":4,"5":5}
def group_rows(words):
    """Group visible word bounding boxes by physical y, never by text order."""
    groups=[]
    for w in sorted(words,key=lambda x:((x[1]+x[3])/2,x[0])):
        cy=(w[1]+w[3])/2
        matched=next((a for a in groups if abs(a["y"]-cy)<=2.8),None)
        if matched is None:
            matched={"y":cy,"words":[]}
            groups.append(matched)
        matched["words"].append(w)
    for g in groups:g["words"].sort(key=lambda w:w[0])
    return sorted(groups,key=lambda g:g["y"])
def first_question_clip(doc,records,q):
    """Approximate question rectangles using printed 問n headers on each page.
    Any ambiguous header detection causes safe HOLD, not guessed location."""
    matches=[]
    for page_index in q["sourcePdfPages"]:
        page=doc[page_index-1]
        headers=[]
        for line in page.get_text("dict")["blocks"]:
            if "lines" not in line:continue
            for ln in line["lines"]:
                text="".join(s.get("text","") for s in ln["spans"]).strip().replace(" ","")
                m=re.fullmatch(r"問([０-９0-9]{1,3})",text)
                if m:headers.append((int(m.group(1).translate(str.maketrans("０１２３４５６７８９","0123456789"))),ln["bbox"]))
        target=[(n,b) for n,b in headers if n==q["questionNo"]]
        if target:
            if len(target)!=1:return None
            y=target[0][1][1]
            succeeding=[b[1] for n,b in headers if b[1]>y+2]
            end=min(succeeding) if succeeding else page.rect.height
            matches.append((page_index-1,fitz.Rect(0,y,page.rect.width,end)))
        elif matches:
            # continuation page, clip to next question header only
            succeeding=[b[1] for n,b in headers]
            end=min(succeeding) if succeeding else page.rect.height
            matches.append((page_index-1,fitz.Rect(0,0,page.rect.width,end)))
    return matches or None
def geometry_table(doc,q,clips):
    choices=q.get("choices")
    if not choices or len(choices) not in (4,5):return {"status":"HOLD","reason":"CHOICES_MISSING"}
    parsed=[re.findall(r"[正誤]",c) for c in choices]
    if any(len(c) not in (3,4) or norm("".join(c))!=norm(x) for c,x in zip(parsed,choices)):
        return {"status":"HOLD","reason":"NOT_PURE_TRUE_FALSE_TABLE"}
    if len({len(c) for c in parsed})!=1:
        return {"status":"HOLD","reason":"INCONSISTENT_NUMBER_OF_COLUMNS"}
    ncol=len(parsed[0])
    candidates=[]
    for page_idx,rect in clips or []:
        page=doc[page_idx]
        for group in group_rows(page.get_text("words",clip=rect,sort=True)):
            tokens=[]
            for w in group["words"]:
                value=w[4].strip()
                if value in ONE_DIGIT or value in ("正","誤"):
                    tokens.append({"text":value,"x":(w[0]+w[2])/2,"y":(w[1]+w[3])/2})
            for index,tok in enumerate(tokens):
                number=ONE_DIGIT.get(tok["text"])
                if number is None or not 1<=number<=len(choices):continue
                cells=tokens[index+1:index+1+ncol]
                if len(cells)!=ncol:continue
                if [c["text"] for c in cells]!=parsed[number-1]:continue
                if not all(c["x"]>tok["x"] for c in cells):continue
                if not all(cells[k+1]["x"]>cells[k]["x"]+2 for k in range(ncol-1)):continue
                if max(abs(c["y"]-tok["y"]) for c in cells)>3.5:continue
                candidates.append({"number":number,"page":page_idx+1,"y":tok["y"],"x":[round(c["x"],2) for c in cells],"cells":[c["text"] for c in cells]})
    layout=[]
    for number in range(1,len(choices)+1):
        matches=[c for c in candidates if c["number"]==number]
        if len(matches)!=1:return {"status":"HOLD","reason":"NONUNIQUE_OR_MISSING_PHYSICAL_ROW","row":number,"count":len(matches)}
        layout.append(matches[0])
    if len({r["page"] for r in layout})!=1:return {"status":"HOLD","reason":"TABLE_SPANS_MULTIPLE_PAGES"}
    if any(layout[i]["y"]>=layout[i+1]["y"]-2 for i in range(len(layout)-1)):
        return {"status":"HOLD","reason":"ROW_VERTICAL_ORDER_MISMATCH"}
    for col in range(ncol):
        xs=[r["x"][col] for r in layout]
        if max(xs)-min(xs)>4:
            return {"status":"HOLD","reason":"COLUMN_ALIGNMENT_MISMATCH","column":col+1,"spread":round(max(xs)-min(xs),2)}
    if any(layout[i]["x"][j]>=layout[i]["x"][j+1] for i in range(len(layout)) for j in range(ncol-1)):
        return {"status":"HOLD","reason":"COLUMN_ORDER_MISMATCH"}
    return {"status":"PASS","method":"PHYSICAL_CELL_XY_AND_TEXT_MATCH","rows":layout,"columns":ncol}
def ruby_associations(doc,q,clips):
    """Detect short kana spans above larger Kanji spans. Do not infer unseen pronunciation."""
    found=[];issues=[]
    for page_idx,rect in clips or []:
        page=doc[page_idx]
        spans=[]
        for block in page.get_text("dict",clip=rect)["blocks"]:
            for line in block.get("lines",[]):
                for span in line.get("spans",[]):
                    t=span.get("text","").strip()
                    if t:spans.append({"text":t,"size":span["size"],"bbox":span["bbox"]})
        candidates=[s for s in spans if KANA.fullmatch(s["text"]) and s["size"]<=11]
        for s in candidates:
            x0,y0,x1,y1=s["bbox"];cx=(x0+x1)/2
            near=[]
            for base in spans:
                if base is s or not KANJI.search(base["text"]) or base["size"]<s["size"]*1.2:continue
                a,b,c,d=base["bbox"]
                vertical=b-y1
                if not -1<=vertical<=21:continue
                if not (a-2<=cx<=c+2):continue
                near.append((abs((a+c)/2-cx)+max(0,vertical)*0.3,base))
            near.sort(key=lambda x:x[0])
            if not near:issues.append({"ruby":s["text"],"page":page_idx+1,"reason":"NO_KANJI_ANCHOR"});continue
            if len(near)>1 and abs(near[1][0]-near[0][0])<3:
                issues.append({"ruby":s["text"],"page":page_idx+1,"reason":"MULTIPLE_KANJI_ANCHORS"});continue
            base=near[0][1]
            found.append({"ruby":s["text"],"baseText":base["text"],"page":page_idx+1,"rubyBBox":list(map(lambda n:round(n,2),s["bbox"])),"baseBBox":list(map(lambda n:round(n,2),base["bbox"]))})
    unique={(r["page"],r["ruby"],tuple(r["rubyBBox"])):r for r in found}
    result=list(unique.values())
    # Automatic source-layout association is not automatic app ruby display certification.
    status="ASSOCIATED_SOURCE_ONLY" if result and not issues else "INCONCLUSIVE"
    return {"status":status,"associations":result,"issues":issues[:15]}
def run(year):
    base=json.loads((B/f"AUTO_DIFF_{year}.json").read_text())
    entries={q["id"]:q for q in base["questions"]}
    source=json.loads((B/"SOURCES_2022_2026.json").read_text())
    urls=next(x for x in source["years"] if x["year"]==year)
    hashes=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    qs=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    pdf={}
    for half,url in [("first_half",urls["question_pdf_first_half"]),("second_half",urls["question_pdf_second_half"])]:
        expected=next(x for x in hashes if x["half"]==half)
        pdf[half]=download(url,B/f".tmp_{year}_{half}.pdf",expected["sha256"])
    output=[];newpass=0;reason_counts=collections.Counter()
    for q in qs:
        prev=entries[q["id"]]
        reasons=list(prev["reasons"])
        result={"id":q["id"],"priorStatus":prev["status"],"originalReasons":reasons,
                "status":"HOLD","reasons":reasons[:],"table":None,"ruby":None}
        if prev["status"]=="AUTO_PASS":
            result["status"]="PREVIOUS_PASS";result["reasons"]=[]
            output.append(result);continue
        hard=[r for r in reasons if r in ("PDF_RAW_DIFF","STEM_DIFF","CHOICE_DIFF","CHOICE_COUNT_DIFF","PDF_OPTION_PARSE",
            "CANDIDATE_OPTIONS_MISSING","OFFICIAL_INVALID_Q90_REVIEW","PAGE_EMBEDDED_IMAGE_REVIEW")]
        if hard:
            result["reasons"]=hard+["OTHER_LAYOUT_FLAGS"] if len(hard)<len(reasons) else hard
            reason_counts.update(result["reasons"]);output.append(result);continue
        half="first_half" if q["questionNo"]<=60 else "second_half"
        doc=pdf[half]
        clips=first_question_clip(doc,None,q)
        if not clips:
            result["reasons"]=["QUESTION_PAGE_HEADER_AMBIGUOUS"];reason_counts.update(result["reasons"]);output.append(result);continue
        table=None
        if "ANSWER_TABLE_REVIEW" in reasons:
            table=geometry_table(doc,q,clips)
            result["table"]=table
            if table["status"]!="PASS":
                result["reasons"]=[r for r in result["reasons"] if r!="ANSWER_TABLE_REVIEW"]
                result["reasons"].append("TABLE_XY_"+table["reason"])
            else:
                result["reasons"].remove("ANSWER_TABLE_REVIEW")
        if "RUBY_POSITION_REVIEW" in reasons:
            ruby=ruby_associations(doc,q,clips);result["ruby"]=ruby
            # Source ruby association can be certified, not UI display alignment.
            result["reasons"].remove("RUBY_POSITION_REVIEW")
            result["reasons"].append("RUBY_RENDER_NOT_CERTIFIED" if ruby["status"]=="ASSOCIATED_SOURCE_ONLY" else "RUBY_XY_ASSOCIATION_INCONCLUSIVE")
        if "FIGURE_OR_FORM_REVIEW" in result["reasons"]:
            # Keyword alone cannot certify no actual figure/vector paths: keep HOLD.
            pass
        if not result["reasons"]:
            result["status"]="GEOMETRY_PASS";newpass+=1
        reason_counts.update(result["reasons"])
        output.append(result)
    for doc in pdf.values():doc.close()
    report={"year":year,"method":"FRESH_SHA_PINNED_PDF_PHYSICAL_WORD_CELL_GEOMETRY",
            "priorAuditCandidateGitBlob":base["candidateGitBlob"],
            "pdfHashes":[e["sha256"] for e in hashes],
            "total":120,"previousAutoPass":base["autoPass"],"newGeometryPass":newpass,
            "remainingHold":120-base["autoPass"]-newpass,
            "reasonCounts":dict(reason_counts),"questions":output,
            "limitations":"Ruby may be associated with PDF Kanji spans but must not auto-publish unless app ruby markup faithfully renders. Vector diagrams are not certified by word geometry."}
    (B/f"GEOMETRY_AUDIT_{year}.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"geometryNewPass":newpass,"hold":report["remainingHold"],"reasons":dict(reason_counts)},ensure_ascii=False))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--year",type=int,required=True,choices=range(2022,2027))
    run(p.parse_args().year)
