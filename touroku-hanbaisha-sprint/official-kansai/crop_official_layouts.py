#!/usr/bin/env python3
"""Stage source-PDF region images for unresolved layout questions, not automatic publication.

Verifies official PDF SHA256; clips by the strict printed question boundary.
Crops include text/graphics, never generated approximations. Paths and hashes are
auditable. Rights and mobile visual approval are NOT inferred.
"""
import argparse,hashlib,json,collections
from pathlib import Path
import fitz
from auto_diff_pdf import B,download
from geometry_second_gate import first_question_clip

DEST=B/"layout-crops"
def run(year):
    master=json.loads((B/"SPECIAL_LAYOUT_REVIEW_QUEUE_20261124.json").read_text())
    records=[r for r in master["records"] if r["year"]==year]
    source=next(r for r in json.loads((B/"SOURCES_2022_2026.json").read_text())["years"] if r["year"]==year)
    hashes=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    candidate=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    docs={}
    for half,url in (("first_half",source["question_pdf_first_half"]),("second_half",source["question_pdf_second_half"])):
        docs[half]=download(url,B/f".tmp_{year}_{half}.pdf",next(z["sha256"] for z in hashes if z["half"]==half))
    approved=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())["approvedIds"]
    known=set(approved);output=[];categories=collections.Counter()
    for record in records:
        q=candidate[record["number"]-1]
        if q["id"]!=record["id"]:raise RuntimeError("source candidate mismatch")
        half="first_half" if q["questionNo"]<=60 else "second_half"
        d=docs[half];sha=next(z["sha256"] for z in hashes if z["half"]==half)
        clips=first_question_clip(d,None,q)
        out={"id":q["id"],"year":year,"category":record["category"],
             "alreadyApproved":q["id"] in known,"sourcePdfUrl":record["sourcePdfUrl"],
             "sourcePdfSha256":sha,"attribution":q["attributionDisplay"],
             "reuseLicense":"関西広域連合サイト利用ルール・政府標準利用規約2.0準拠（第三者権利は別途確認）",
             "rights":"REVIEW_THIRD_PARTY_COMPONENTS",
             "displayQA":"PENDING",
             "publishable":False,"assets":[]}
        if not clips:
            out.update(status="HOLD",reason="QUESTION_BOUNDARY_NOT_UNIQUE")
            categories[out["reason"]]+=1;output.append(out);continue
        if len(clips)>2:
            out.update(status="HOLD",reason="QUESTION_SPANS_TOO_MANY_PAGES")
            categories[out["reason"]]+=1;output.append(out);continue
        for seq,(pageidx,rect) in enumerate(clips,1):
            if rect.width<=80 or rect.height<=30 or rect.height>d[pageidx].rect.height:
                out.update(status="HOLD",reason="INVALID_CROP_RECT")
                break
            pix=d[pageidx].get_pixmap(matrix=fitz.Matrix(1.8,1.8),clip=rect,alpha=False)
            raw=pix.tobytes("png")
            if len(raw)>2_000_000 or pix.width>1600 or pix.height>2400:
                out.update(status="HOLD",reason="IMAGE_SIZE_LIMIT")
                break
            path=DEST/f"{q['id']}-p{pageidx+1}-{seq}.png"
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(raw)
            out["assets"].append({"relativePath":str(path.relative_to(B)),
                "webPath":"official-kansai/"+str(path.relative_to(B)),
                "page":pageidx+1,
                "sourceCropBBox":[round(v,2) for v in rect],
                "dpi":129.6,"width":pix.width,"height":pix.height,
                "bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()})
        if "status" not in out:
            out.update(status="CROP_STAGED_PENDING_RIGHTS_AND_VISUAL_QA",reason="LICENSE_AND_DISPLAY_NOT_CLEARED")
        categories[out["reason"]]+=1
        output.append(out)
    for doc in docs.values():doc.close()
    results={"year":year,"requested":len(records),"staged":sum(r["status"]=="CROP_STAGED_PENDING_RIGHTS_AND_VISUAL_QA" for r in output),
        "unresolved":sum(r["status"]!="CROP_STAGED_PENDING_RIGHTS_AND_VISUAL_QA" for r in output),
        "alreadyApproved":sum(r["alreadyApproved"] for r in output),
        "reasonCounts":dict(categories),"records":output,
        "policy":"Never auto-publish PNG crops without resolving embedded third-party rights and verifying mobile appearance. Original source PDF images must be used without re-illustration."}
    (B/f"LAYOUT_CROPS_{year}.json").write_text(json.dumps(results,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"requested":len(records),"staged":results["staged"],"alreadyApproved":results["alreadyApproved"],"reasons":dict(categories)},ensure_ascii=False))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--year",type=int,required=True,choices=range(2022,2027))
    run(p.parse_args().year)
