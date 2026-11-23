#!/usr/bin/env python3
"""Conservative bulk verifier: PyMuPDF vs Poppler PDF-to-text plus official answer key.
Never infer glyphs from two parsers sharing the same faulty source CMap.
"""
import json, pathlib, re, subprocess, collections, hashlib, unicodedata, sys
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs/dual-engine-20261124"
OUT.mkdir(parents=True,exist_ok=True)
STAGE=ROOT/"product-content/keyed-candidates"
EXIST=json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())
existing={x["id"] for x in EXIST["questions"]}
KEY=json.loads((ROOT/"audit/official-scoring-exceptions-20261124.json").read_text())
exceptions={x["id"]:x for x in KEY["exceptions"]}
SUSPICIOUS=re.compile(r"[\x00-\x1f\x7f\ufffd઄¹¼ïñèêçâ]|[!?]|(?:[A-Za-z]{1,}V[A-Za-z]{1,})")
MEDIA=re.compile(r"図(?:を|に|中|で|の|表)|画像|写真|別冊|模式図|エックス線写真|心電図を|波形を|グラフ")
FONT_GLYPH_MAP={2:"2",4:"1",5:"3",6:"4",7:"5",8:"9",11:"6",12:"7",31:"（"}
def clean_font(s):
    text=str(s).translate(str.maketrans(FONT_GLYPH_MAP))
    return re.sub(r"（([^（！!\n]{0,90})!",r"（\1）",text)
def norm(s):
    return re.sub(r"\s+","",unicodedata.normalize("NFKC",clean_font(s))).replace("～","~").replace("〜","~").replace("−","-").replace("‐","-")
def fitz_segment(page,n):
    lines=page.get_text("text",sort=False).splitlines(keepends=True)
    start=next((i for i,line in enumerate(lines) if line.strip()==str(n)),None)
    if start is None:return None
    stop=next((i for i in range(start+1,len(lines)) if lines[i].strip()==str(n+1)),len(lines))
    return "".join(lines[start:stop])
def pdftotext(pdf,page):
    r=subprocess.run(["pdftotext","-f",str(page),"-l",str(page),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"],capture_output=True,text=True)
    if r.returncode:raise RuntimeError(f"Poppler failed {pdf.name} page {page}: {r.stderr[-350:]}")
    return r.stdout
sys.path.insert(0,str(ROOT/'scripts'))
from official_answer_key_audit import parse as read_official_key
from boundary_context_verify import verify as verify_boundary
from boundary_context_verify import _region,equivalent_shared_context
from reextract_coordinate_candidates import split_fields,segment_poppler,equivalent_english_gloss_reorder
keys={e:read_official_key(e) for e in (111,112)}
VISUAL={x["id"]:x for x in json.loads((ROOT/"audit/visual-glyph-confirmation-20261124.json").read_text())["items"]}
VISUAL_DIR=ROOT/"audit/runs/context-control-visual-20261124"
SCENARIO_VISUAL={x["id"]:x for x in json.loads((ROOT/"audit/visual-scenario-parentheses-20261124.json").read_text())["items"]}
all_rows=[];approved=[];by_session={}
for exam in (112,111):
  for session in ("AM","PM"):
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
    doc=fitz.open(pdf)
    draft=json.loads((STAGE/f"exam{exam}-{session}-draft.json").read_text())
    page_cache={}
    def cached_pdftotext(path,page):
        if page not in page_cache:page_cache[page]=pdftotext(path,page)
        return page_cache[page]
    rows=[]
    for q in draft["questions"]:
        qid=q["id"];n=q["questionNo"];pg=q.get("sourcePage")
        failures=[]
        if qid in existing:failures.append("ALREADY_VERIFIED_CANONICAL")
        visual=None
        if qid in VISUAL:
            ev=VISUAL[qid]
            img=VISUAL_DIR/f"{qid}-p{ev['page']}.png"
            ix=ev["choiceIndex"]
            if (q.get("sourcePage")==ev["page"] and q.get("questionNo")==ev["number"]
                and q.get("sourceExam")==ev["exam"] and q.get("session")==ev["session"]
                and hashlib.sha256(pdf.read_bytes()).hexdigest()==ev["pdfSha256"]
                and img.is_file() and hashlib.sha256(img.read_bytes()).hexdigest()==ev["pngSha256"]
                and len(q.get("choices") or [])==4
                and q["choices"][ix]==ev["expectedChoice"]
                and q.get("visualGlyphProof",{}).get("pngSha256")==ev["pngSha256"]):
                visual=ev
        scenario_visual=None
        if qid in SCENARIO_VISUAL:
            ev=SCENARIO_VISUAL[qid]
            screenshot=VISUAL_DIR/f"{qid}-p{ev['contextPage']}.png"
            if (ev["exam"]==exam and ev["session"]==session and ev["contextPage"]<=pg
                and hashlib.sha256(pdf.read_bytes()).hexdigest()==ev["sourcePdfSha256"]
                and screenshot.is_file()
                and hashlib.sha256(screenshot.read_bytes()).hexdigest()==ev["contextPngSha256"]):
                scenario_visual=ev
        # Independent scenario context validation happens below.
        if qid in exceptions or q.get("officialScoringStatus")!="normal":failures.append("SCORING_EXCEPTION")
        if not q.get("extractionValid",False):failures.append("ORIGINAL_STRUCTURE_INVALID")
        if len(q.get("choices") or [])!=4:failures.append("CHOICE_COUNT_NOT_FOUR")
        if not isinstance(q.get("answer"),int) or q["answer"] not in range(4) or str(q["answer"]+1)!=(q.get("officialKeyRaw") or "").strip():failures.append("OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX")
        if q.get("answerKeyVerification")!="MATCH_SINGLE_DIGIT_KEY_NOT_VERBATIM_CERTIFIED":failures.append("OFFICIAL_ANSWER_NOT_SINGLE")
        official=keys[exam][0].get(qid)
        if not official or official.get("status")!="KEY_SINGLE" or official.get("rawValue")!=str((q.get("answer") if isinstance(q.get("answer"),int) else -10)+1):failures.append("INDEPENDENT_OFFICIAL_KEY_MISMATCH")
        if q.get("officialKeyPdfSha256")!=keys[exam][1]:failures.append("OFFICIAL_KEY_SOURCE_SHA_DRIFT")
        stem=q.get("question") or ""
        choices=q.get("choices") or []
        short_stem=len(norm(stem))<18  # coordinate uniqueness may certify a short official stem
        if MEDIA.search(stem):failures.append("MEDIA_OR_DIAGRAM_CUE")
        if any(SUSPICIOUS.search(x) or re.search(r"[\u0080-\u009f\u00a1-\u00ff]",x) for x in [stem]+choices):failures.append("SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT")
        if any(re.search(r"DKIX|[前後]H-\\d+|[-−]H[-−]\\d+",x) for x in [stem]+choices):failures.append("PAGE_FOOTER_CONTAMINATION")
        boundary_evidence=None
        scenario_evidence=None
        coordinate_segment=None
        geometric_crosscheck=None
        if isinstance(pg,int) and 1<=pg<=len(doc) and q.get("coordinateReextraction"):
            raw_clip,geom=_region(doc[pg-1],n,clean_font)
            alt_crop=segment_poppler(cached_pdftotext(pdf,pg),n)
            if raw_clip and alt_crop and geom and q["coordinateReextraction"].get("page")==pg:
                py_fields,err1=split_fields(raw_clip,n)
                pop_fields,err2=split_fields(alt_crop,n)
                if not err1 and not err2:
                    left=[py_fields["question"]]+py_fields["choices"]
                    right=[pop_fields["question"]]+pop_fields["choices"]
                    target=[stem]+choices
                    if len(target)==5 and all((equivalent_shared_context(x,y)[0] or equivalent_english_gloss_reorder(x,y)) and (equivalent_shared_context(x,z)[0] or equivalent_english_gloss_reorder(x,z)) for x,y,z in zip(left,right,target)):
                        geometric_crosscheck={"page":pg,"anchor":geom["anchorBox"],"rectangle":geom["clip"],
                            "fields":5,"method":"exact Japanese and Latin token multiset; PyMuPDF clip vs independent Poppler page segmentation",
                            "requiresOfficialAnswer":True}
        if not isinstance(pg,int) or not 1<=pg<=len(doc):
            failures.append("SOURCE_PAGE_INVALID")
        else:
            verified_page, boundary_errors, scenario_evidence, geometry, coordinate_segment=verify_boundary(
                doc,pdf,n,pg,stem,choices,cached_pdftotext,clean_font,norm,
                visually_verified_fields={visual["choiceIndex"]+1} if visual else set(),
                context_glyph_evidence=scenario_visual,
                strict_geometric_fields_verified=bool(geometric_crosscheck))
            if verified_page is not None:
                boundary_evidence={"previousPage":pg,"correctedPage":verified_page,**(geometry or {})}
                pg=verified_page
            failures.extend(boundary_errors)
        if short_stem and coordinate_segment is None:failures.append("TOO_SHORT_FOR_UNIQUE_STEM")
        if isinstance(pg,int) and 1<=pg<=len(doc):
            page=doc[pg-1]
            source_segment=coordinate_segment
            if source_segment is not None:source_segment=clean_font(source_segment)
            if source_segment is None:failures.append("COORDINATE_REGION_UNVERIFIED")
            else:
                if re.search(r"[\x00-\x08\x0b-\x1f\x7f]",source_segment) and not visual:failures.append("C0_SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY")
                if re.search(r"[\ufffd઄¹¼ïñèêçâ\u0080-\u009f\u00a1-\u00ff]",source_segment):failures.append("SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY")
            poppler=cached_pdftotext(pdf,pg)
            wordblob=norm(page.get_text("text",sort=False))
            altblob=norm(poppler)
            for i,text in enumerate([stem]+choices):
                if geometric_crosscheck:continue
                if visual and i==visual["choiceIndex"]+1:continue
                if not text:continue
                if norm(text) not in wordblob:failures.append("PYMUPDF_FIELD_MISMATCH_"+str(i))
                if norm(text) not in altblob:failures.append("POPPLER_FIELD_MISMATCH_"+str(i))
            if source_segment and not geometric_crosscheck and norm(stem) not in norm(source_segment):failures.append("PYMUPDF_WRONG_QUESTION_BOUNDARY")
            media_in_page=bool(page.get_images(full=True))
            if media_in_page:failures.append("PAGE_HAS_RASTER_OR_DIAGRAM_REVIEW")
        else:media_in_page=None
        failures=list(dict.fromkeys(failures))
        status="PASS_DUAL_ENGINE_AND_OFFICIAL_KEY" if not failures else "HOLD"
        row={"id":qid,"exam":exam,"session":session,"number":n,"status":status,"reasons":failures,"sourcePdfPage":pg,"pageHasRaster":media_in_page,
            "officialKeyRaw":q.get("officialKeyRaw"),"answer":q.get("answer"),"coordinateBoundaryEvidence":boundary_evidence,"scenarioContext":scenario_evidence,"visualNumericGlyphEvidence":visual,"visualScenarioGlyphEvidence":scenario_visual,"geometricCrosscheckEvidence":geometric_crosscheck,
            "sourcePdfSha256":hashlib.sha256(pdf.read_bytes()).hexdigest()}
        rows.append(row);all_rows.append(row)
        if status.startswith("PASS"):
            canonical={
              "id":qid,"sourceExam":exam,"session":session,"questionNo":n,
              "question":stem,"choices":choices,"answer":q["answer"],"officialAcceptedAnswers":[q["answer"]],
              "answerType":"singleChoice","sourceAnswerTokens":q["sourceAnswerTokens"],"officialScoringStatus":"normal",
              "scoringException":None,"requiresMedia":False,"mediaAuditStatus":"not_required",
              "rightsStatus":"mhlw-pdl1.0-text","sourceRefs":q["sourceRefs"],"sourceAttribution":q["sourceAttribution"],
              "sourcePage":pg,"scenarioContextEvidence":scenario_evidence,"visualNumericGlyphEvidence":visual,"coordinateBoundaryEvidence":boundary_evidence,"shortStemVerifiedByCoordinates":bool(short_stem and coordinate_segment is not None),"sourcePdfSha256":row["sourcePdfSha256"],"officialKeyPdfSha256":q.get("officialKeyPdfSha256"),
              "reviewStatus":"source_dual_engine_and_official_key_verified","canonicalStatus":"source_verified_extension",
              "publishable":False,"releaseEligible":False,
              "audit":{"questionDualEngineMatched":True,"allChoicesDualEngineMatched":True,"officialKeyMatched":True,
                       "sourceGlyphControlAbsent":True,"mediaNotRequired":True,
                       "explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}}
            approved.append(canonical)
    by_session[f"{exam}-{session}"]={"total":len(rows),"pass":sum(x["status"].startswith("PASS") for x in rows),"hold":sum(x["status"]=="HOLD" for x in rows)}
    (OUT/f"{exam}-{session}-per-question.json").write_text(json.dumps(rows,ensure_ascii=False,indent=2)+"\n")
summary={"engine1":"PyMuPDF geometric word bounding boxes + clipped question rectangle", "engine2":"Poppler pdftotext -layout", "key":"MHLW 2026-11-24 official answer PDF tokens",
 "policy":"Conservative coordinate boundary gate: question number x/y, bounded question rectangle, full stem/four choices in crop and independent Poppler PDF page, official answer source; reject source control glyphs, raster pages, scoring exceptions and unverified scenario context.",
 "total":len(all_rows),"freshPromotable":len(approved),"alreadyCanonical":len(existing),
 "holds":len(all_rows)-len(approved),"bySession":by_session,
 "holdReasons":dict(collections.Counter(reason for row in all_rows for reason in row["reasons"])),
 "promotionMeaning":"Source-verified canonical extension only; explanation independent audit & runtime not completed. Not publishable.",
 "releaseReady":0}
(OUT/"summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
(OUT/"bulk-verified-nonpublishable.json").write_text(json.dumps({"schemaVersion":1,"questions":approved,"count":len(approved)},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"total":summary["total"],"freshPromotable":summary["freshPromotable"],"holds":summary["holds"],"bySession":by_session,"holdReasons":summary["holdReasons"]},ensure_ascii=False))
if len(all_rows)!=480:sys.exit(2)
