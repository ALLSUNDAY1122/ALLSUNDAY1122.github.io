#!/usr/bin/env python3
"""Stratified alternative-extractor cross-check (pdfplumber/pdfminer vs PyMuPDF).
A sampled agreement never certifies all remaining questions.
"""
import argparse,collections,difflib,hashlib,json
from pathlib import Path
import pdfplumber
from auto_diff_pdf import B,download,norm
from geometry_second_gate import first_question_clip

SAMPLE_NOS=[1,3,17,28,45,60,73,90,104,120]
def run(year):
    source=json.loads((B/"SOURCES_2022_2026.json").read_text())
    item=next(x for x in source["years"] if x["year"]==year)
    hashes=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    questions=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    results=[]
    for half,url in [("first_half",item["question_pdf_first_half"]),("second_half",item["question_pdf_second_half"])]:
        expected=next(x for x in hashes if x["half"]==half)
        path=B/f".tmp_{year}_{half}.pdf"
        mupdf=download(url,path,expected["sha256"])
        with pdfplumber.open(path) as alternate:
            for n in SAMPLE_NOS:
                if (n<=60)!=(half=="first_half"):continue
                q=questions[n-1]
                area=first_question_clip(mupdf,None,q)
                if not area:
                    results.append({"id":q["id"],"status":"CANNOT_LOCATE_CLIP","reason":"HEADER_AMBIGUOUS"});continue
                chunks1=[];chunks2=[]
                for pageidx,box in area:
                    mp=mupdf[pageidx]
                    pg=alternate.pages[pageidx]
                    rect=(max(0,box.x0),max(0,box.y0),min(pg.width,box.x1),min(pg.height,box.y1))
                    chunks1.append(mp.get_text("text",clip=box,sort=True))
                    # Independent extractor from PDFMiner; clip to exactly same rectangle
                    txt=pg.crop(rect).extract_text(x_tolerance=2,y_tolerance=3) or ""
                    chunks2.append(txt)
                first=norm("".join(chunks1));second=norm("".join(chunks2))
                a=collections.Counter(first);b=collections.Counter(second)
                common=sum((a&b).values())
                maxchars=max(len(first),len(second),1)
                multiset=round(common/maxchars,4)
                sequence=round(difflib.SequenceMatcher(None,first,second,autojunk=False).ratio(),4)
                exact=first==second
                # Cross-engine differences are evidence; do not manufacture matches
                status="PASS_EXACT" if exact else "PASS_CHARACTER_MULTISET" if multiset>=.99 and sequence>=.90 else "REVIEW_EXTRACTOR_DISAGREEMENT"
                results.append({"id":q["id"],"status":status,"mupdfChars":len(first),"pdfplumberChars":len(second),
                    "characterMultisetAgreement":multiset,"sequenceAgreement":sequence,
                    "mupdfNormalizedSha256":hashlib.sha256(first.encode()).hexdigest(),
                    "pdfplumberNormalizedSha256":hashlib.sha256(second.encode()).hexdigest(),
                    "sourcePdfSha256":expected["sha256"],"sourcePages":[i+1 for i,_ in area]})
        mupdf.close()
    assert len(results)==len(SAMPLE_NOS)
    counts=collections.Counter(row["status"] for row in results)
    out={"year":year,"method":"PDFPLUMBER_PDFMINER_VERSUS_PYMUPDF_SAME_SHA_PINNED_PDF",
         "samples":len(results),"sampleQuestionNumbers":SAMPLE_NOS,
         "summary":dict(counts),"limitations":"10 stratified questions per year only; does not prove independence for all 600. Extractor disagreement requires review.",
         "results":results}
    (B/f"CROSSCHECK_{year}.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"samples":len(results),"results":dict(counts)},ensure_ascii=False))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--year",type=int,required=True,choices=range(2022,2027))
    run(p.parse_args().year)
