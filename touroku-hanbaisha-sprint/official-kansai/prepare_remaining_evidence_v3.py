#!/usr/bin/env python3
"""Prepare remaining registration-exam source evidence. Zero automatic promotions.
Reproducible on GitHub Actions; pinned official PDF SHA-256 and original question boundary.
"""
import collections,hashlib,json,html
from pathlib import Path
from PIL import Image, ImageDraw
from playwright.sync_api import sync_playwright
import fitz
from auto_diff_pdf import B,download
from geometry_second_gate import first_question_clip
from ruby_font_cluster_recovery import rawglyphs,clusters
from rebuild_ruby_comparison_120 import guess_mapping,make_preview,make_sheet,font_check

IOS=B.parents[1]/"touroku-hanbaisha-ios"
ST=json.loads((IOS/"release-status.json").read_text())
cat=ST["unapproved_id_reconciliation_20261124"]["categories"]
ruby45=cat["ruby_not_in_v2_review_45"]
tables=cat["table_layout_hold_4"]
manual=cat["manual_or_cross_engine_holds_4"]
invalid=cat["official_invalid_2023_q90"]
assert (len(ruby45),len(tables),len(manual),len(invalid))==(45,4,4,1)
assert len(set(ruby45+tables+manual+invalid))==54
source={x["year"]:x for x in json.loads((B/"SOURCES_2022_2026.json").read_text())["years"]}
candidates={y:json.loads((B/f"QUESTIONS_{y}_APP_CANDIDATE.json").read_text())["questions"] for y in source}
geo={y:json.loads((B/f"GEOMETRY_AUDIT_{y}.json").read_text())["questions"] for y in source}
shas={y:json.loads((B/f"PDF_SHA256_{y}.json").read_text()) for y in source}
docs={}
for y in source:
    docs[y]={}
    for half,key in (("first_half","question_pdf_first_half"),("second_half","question_pdf_second_half")):
        expected=next(v["sha256"] for v in shas[y] if v["half"]==half)
        docs[y][half]=download(source[y][key],B/f".tmp_recovery_{y}_{half}.pdf",expected)
outdir=B/"ruby-font-review"
outdir.mkdir(exist_ok=True)
crops=B/"layout-crops"
crops.mkdir(exist_ok=True)
records=[]
def row_for(id):
    y=int(id[5:9]);n=int(id[-3:]);q=candidates[y][n-1]
    assert q["id"]==id
    half="first_half" if n<=60 else "second_half"
    doc=docs[y][half]
    sha=next(v["sha256"] for v in shas[y] if v["half"]==half)
    return y,n,q,doc,sha,first_question_clip(doc,None,q)
for id in ruby45:
    y,n,q,doc,sha,clips=row_for(id)
    row={"id":id,"category":"RUBY_COMPARISON_NEW","sourcePdfSha256":sha,"sourceUrl":q["sourceUrl"],
         "sourcePages":q["sourcePdfPages"],"status":"HOLD_PENDING_DIRECT_VISUAL_REVIEW",
         "promoted":False,"issues":[]}
    if not clips:
        row["issues"].append("QUESTION_CROP_NOT_UNIQUE")
        records.append(row);continue
    # Source region is the actual PDF image, not a reconstructed guess.
    pix_parts=[]
    for page,rect in clips:
        pix=doc[page].get_pixmap(matrix=fitz.Matrix(1.6,1.6),clip=rect,alpha=False)
        pix_parts.append(Image.frombytes("RGB",(pix.width,pix.height),pix.samples))
    sourceImage=Image.new("RGB",(max(x.width for x in pix_parts),sum(x.height for x in pix_parts)+12*(len(pix_parts)-1)),"white")
    yy=0
    for image in pix_parts:sourceImage.paste(image,(0,yy));yy+=image.height+12
    sourceFile=outdir/f"{id}-source-v3.png"
    sourceImage.save(sourceFile)
    row["sourceImage"]=str(sourceFile.relative_to(B))
    groups=clusters(rawglyphs(doc,clips))
    mapping=[];issues=[]
    for group in groups:
        result,why=guess_mapping(q,group,geo[y][n-1],rawglyphs(doc,clips))
        if result:mapping.append(result)
        else:issues.append(why)
    # A candidate is not proof: compare image explicitly before making any PASS.
    preview,parts,count=make_preview({"id":id},q,mapping,issues)
    candidate=outdir/f"{id}-candidate-v3.html"
    candidate.write_text(preview)
    row["comparisonHtml"]=str(candidate.relative_to(B))
    row["rubyDomExpected"]=count
    row["rubyMappings"]=mapping
    row["sourceRubyGroups"]=len(groups)
    row["issues"]=sorted(set(issues))
    records.append(row)
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel="chrome",headless=True)
    page=browser.new_page(viewport={"width":375,"height":850},device_scale_factor=1)
    for row in records:
        if row["category"]!="RUBY_COMPARISON_NEW" or "comparisonHtml" not in row:continue
        page.goto((B/row["comparisonHtml"]).resolve().as_uri())
        page.evaluate("document.fonts.ready")
        proof=font_check(page)
        assert proof["fontJP"] and proof["domRuby"]==row["rubyDomExpected"]==proof["domRt"]
        out=outdir/f"{row['id']}-candidate-375-v3.png"
        page.screenshot(path=str(out),full_page=True)
        row["candidateScreenshot"]=str(out.relative_to(B))
        row["fontValidated"]=True
    browser.close()
# Four ingredient/combination tables, and four exception/manual audit records:
for id in tables+manual:
    y,n,q,doc,sha,clips=row_for(id)
    category="TABLE_SOURCE_IMAGE" if id in tables else "EXCEPTION_MANUAL_REAUDIT"
    r={"id":id,"category":category,"sourcePdfSha256":sha,"sourceUrl":q["sourceUrl"],
       "sourcePages":q["sourcePdfPages"],"answerIndex":q["answerNumberOfficial"],
       "status":"HOLD_PENDING_INDEPENDENT_PDF_SCOPE_RIGHTS_VISUAL_QA",
       "promoted":False,"assets":[]}
    if not clips:r["status"]="HOLD_QUESTION_REGION_NOT_UNIQUE"
    else:
        for ix,(page,rect) in enumerate(clips,1):
            pix=doc[page].get_pixmap(matrix=fitz.Matrix(2,2),clip=rect,alpha=False)
            data=pix.tobytes("png")
            file=crops/f"{id}-recovery-p{page+1}-{ix}.png"
            file.write_bytes(data)
            r["assets"].append({"path":str(file.relative_to(B)),"page":page+1,
                  "bbox":[round(v,3) for v in rect],"sha256":hashlib.sha256(data).hexdigest(),
                  "width":pix.width,"height":pix.height})
    records.append(r)
for docpair in docs.values():
    for doc in docpair.values():doc.close()
assert len(records)==53
manifest={"schema":"touhan-unapproved-evidence-v3","source":"OFFICIAL_KANSAI_SHA_PINNED",
  "rubyNewComparisons":45,"tableCrops":4,"manualExceptionCrops":4,
  "visualPass":0,"newlyPromoted":0,"invalid2023Q90Excluded":invalid,
  "classification":"NO_AUTOMATIC_PROMOTION; human direct comparison and rights checks still required",
  "records":records}
(B/"REMAINING_EVIDENCE_V3_20261124.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"rubyNewComparisons":45,"tableCrops":4,"manualAuditCrops":4,
"sourceImages":sum(bool(r.get("sourceImage")) for r in records),
"tableAssets":sum(len(r.get("assets",[])) for r in records if r["category"]=="TABLE_SOURCE_IMAGE"),
"promoted":0},ensure_ascii=False))
