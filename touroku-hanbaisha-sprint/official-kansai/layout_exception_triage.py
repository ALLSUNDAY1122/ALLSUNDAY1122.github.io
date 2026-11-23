#!/usr/bin/env python3
"""Re-evaluate only spurious figure-keyword/ordinary-prose choice table holds.
Genuine drawings, graphical tables and uncertain PDF page clips stay HOLD.
"""
import argparse,collections,json,re
from auto_diff_pdf import B,download,norm
from geometry_second_gate import first_question_clip
EXPLICIT=re.compile(r"次の表|下表|次の図|下図|図表|別図|模式図|構造式|化学構造|グラフ|一覧表|添付文書|成分の一覧")
TF=re.compile(r"^[正誤]+$")
def run(year):
    geo=json.loads((B/f"GEOMETRY_AUDIT_{year}.json").read_text())
    base=json.loads((B/f"AUTO_DIFF_{year}.json").read_text())
    qdata=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    source=json.loads((B/"SOURCES_2022_2026.json").read_text())
    meta=next(x for x in source["years"] if x["year"]==year)
    hashes=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    docs={}
    for half,url in (("first_half",meta["question_pdf_first_half"]),("second_half",meta["question_pdf_second_half"])):
        docs[half]=download(url,B/f".tmp_{year}_{half}.pdf",next(x["sha256"] for x in hashes if x["half"]==half))
    records=[];reason_counts=collections.Counter();passes=0;target_count=0
    for q,g,a in zip(qdata,geo["questions"],base["questions"]):
        if q["id"]!=g["id"] or g["id"]!=a["id"]:raise RuntimeError("index mismatch")
        reasons=list(g["reasons"])
        result={"id":q["id"],"status":"NOT_TARGET","reasons":[]}
        if "FIGURE_OR_FORM_REVIEW" not in reasons and "TABLE_XY_NOT_PURE_TRUE_FALSE_TABLE" not in reasons:
            records.append(result);continue
        target_count+=1
        fail=[]
        if a["candidateNormalizedSha256"]!=a["sourceNormalizedSha256"]:fail.append("PDF_CONTENT_DIFF")
        if any(r in reasons for r in ("RUBY_RENDER_NOT_CERTIFIED","RUBY_XY_ASSOCIATION_INCONCLUSIVE","OFFICIAL_INVALID_Q90_REVIEW","CHOICE_DIFF","OTHER_LAYOUT_FLAGS")):fail.append("OTHER_UNRESOLVED_REASON")
        choices=q.get("choices")
        if not choices or not all(choices):fail.append("OPTION_STRUCTURALLY_MISSING")
        tf=bool(choices) and all(TF.fullmatch(norm(choice)) and len(norm(choice)) in (3,4) for choice in choices)
        if "TABLE_XY_NOT_PURE_TRUE_FALSE_TABLE" in reasons and tf:fail.append("TRUE_FALSE_TABLE_NOT_XY_CERTIFIED")
        full=q.get("question","")
        if "FIGURE_OR_FORM_REVIEW" in reasons and EXPLICIT.search(full):fail.append("EXPLICIT_FIGURE_OR_LIST")
        if "FIGURE_OR_FORM_REVIEW" in reasons:
            # The old detector accidentally flagged common verbs such as 図る/図られる.
            # Refuse clearance unless all 図 tokens are the benign lexical usage.
            for m in re.finditer(r"図",full):
                suffix=full[m.end():m.end()+1]
                if suffix not in ("る","ら","り","っ"):fail.append("FIGURE_KEYWORD_NOT_BENIGN");break
            if not ("図" in full):fail.append("FIGURE_TRIGGER_OUTSIDE_STEM")
        doc=docs["first_half" if q["questionNo"]<=60 else "second_half"]
        clips=first_question_clip(doc,None,q)
        if not clips:fail.append("PDF_CLIP_NOT_UNIQUE")
        elif "FIGURE_OR_FORM_REVIEW" in reasons:
            # Reject embedded artwork and vector drawings local to the question,
            # rather than assuming PDF contains text only.
            for i,rect in clips:
                page=doc[i]
                if page.get_images(full=True):
                    fail.append("PDF_PAGE_IMAGE_PRESENT");break
                drawings=page.get_drawings()
                if any(fitz_rect_intersects(rect,el.get("rect")) for el in drawings if el.get("rect")):
                    fail.append("VECTOR_GRAPHICS_NEAR_QUESTION");break
        if "FIGURE_OR_FORM_REVIEW" in reasons and "ANSWER_TABLE_REVIEW" in a["reasons"]:
            table=g.get("table") or {}
            if table.get("status")!="PASS":fail.append("ANSWER_TABLE_XY_UNVERIFIED")
        if "TABLE_XY_NOT_PURE_TRUE_FALSE_TABLE" in reasons and not tf and not a["reasons"]==["ANSWER_TABLE_REVIEW"]:
            fail.append("ORIGINAL_HOLD_REASON_NOT_ISOLATED")
        if fail:result.update(status="HOLD",reasons=sorted(set(fail)))
        else:
            result.update(status="LAYOUT_FALSE_POSITIVE_PASS",reasons=[],
                method="EXPLICIT_SOURCE_NO_GRAPHICS_AND_NORMALIZED_PDF_MATCH",
                subtype="BENIGN_FIGURE_VERB" if "FIGURE_OR_FORM_REVIEW" in reasons else "ORDINARY_PROSE_OPTIONS",
                note="No diagram in question region; not a substitute for review of genuine diagram questions")
            passes+=1
        reason_counts.update(result["reasons"])
        records.append(result)
    for d in docs.values():d.close()
    output={"year":year,"total":120,"targets":target_count,"cleared":passes,
      "held":target_count-passes,"reasonCounts":dict(reason_counts),
      "candidateGitBlob":base["candidateGitBlob"],"records":records,
      "policy":"Genuine table, ruby or diagram never marked PASS unless proven; lexical false positives can clear only with source text and geometry proofs."}
    (B/f"LAYOUT_TRIAGE_{year}.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"targets":target_count,"newPass":passes,"held":target_count-passes,"reasonCounts":dict(reason_counts)},ensure_ascii=False))
def fitz_rect_intersects(a,b):
    intersection=a & b
    return a.intersects(b) and intersection.width*intersection.height>8
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--year",type=int,required=True,choices=range(2022,2027))
    run(ap.parse_args().year)
