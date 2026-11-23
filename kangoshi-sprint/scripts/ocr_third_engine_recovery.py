#!/usr/bin/env python3
"""Conservative third-engine OCR source check for unresolved nurse questions.

OCR text comes from rendered source pixels (Tesseract Japanese + English).
Requires complete question and four/five choices in printed order, an exact
field-level match to PyMuPDF OR Poppler, official one-choice PDF answer, and
independent scoring/media/scenario gates. OCR output alone is never a release.
"""
import collections, hashlib, json, pathlib, re, subprocess, sys, unicodedata
import fitz

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from boundary_context_verify import _region
from bulk_text_helpers import clean_font, suspicious
from reextract_coordinate_candidates import segment_poppler, split_fields
from official_answer_key_audit import parse as parse_official

OUT=ROOT/"audit/runs/ocr-third-engine-20261124"
OUT.mkdir(parents=True,exist_ok=True)
STAGE=ROOT/"product-content/keyed-candidates"
EXT=ROOT/"product-content/verified-additions-20261124.json"
MANIFEST=ROOT/"product-content/manifest.json"
HOLD=ROOT/"audit/dual-engine-hold-20261124.json"
LEDGER=ROOT/"audit/dual-engine-promotion-ledger-20261124.json"
INDEX=ROOT/"audit/residual-geometric-source-index-20261124.json"
RUN_IMAGES=ROOT/"audit/runs/residual-geometric-images-20261124"
PDF_DIR=pathlib.Path("/tmp/kangoshi-official")

def norm(x):
    # No semantic substitutions: exact Japanese characters, digits, and Latin
    # content; ignore whitespace, compatibility width, and OCR-safe typography.
    v=unicodedata.normalize("NFKC",str(x))
    v=re.sub(r"\\s+","",v)
    return v.replace("〜","~").replace("～","~").replace("−","-").replace("‐","-")

def official_valid(q, key, sha, exception_ids):
    a=q.get("answer")
    return (q["id"] not in exception_ids and q.get("officialScoringStatus")=="normal"
            and isinstance(a,int) and 0<=a< len(q.get("choices") or [])
            and key.get("status")=="KEY_SINGLE"
            and key.get("rawValue")==str(a+1)
            and q.get("officialKeyPdfSha256")==sha
            and q.get("officialKeyRaw","").strip()==str(a+1))

def get_ocr(png):
    p=subprocess.run(["tesseract",str(png),"stdout","-l","jpn+eng","--psm","6"],
       capture_output=True,text=True,timeout=65)
    if p.returncode:raise RuntimeError(p.stderr[-250:])
    return p.stdout

def validate_ocr(ocr, number, fields):
    if len(fields) not in (5,6):return False,"FIELD_COUNT"
    # OCR must independently identify the full stem and every answer option.
    # Check content in order, not just an unordered bag of matching tokens.
    cleaned=norm(ocr)
    stem=norm(fields[0])
    if len(stem)<18 or len(cleaned)<sum(len(norm(s)) for s in fields)*0.90:
        return False,"OCR_TOO_SHORT"
    offset=0
    for i,val in enumerate(fields):
        tok=norm(val)
        if not tok:return False,"EMPTY_FIELD"
        start=cleaned.find(tok,offset)
        if start<0:return False,"OCR_FIELD_"+str(i)+"_NOT_EXACT"
        offset=start+len(tok)
    # Each selected extraction is itself independently segmented by printed
    # choice labels; OCR content must agree with all five/six fields exactly.
    # OCR may contain extra text: that is retained as audit evidence, not cleared.
    return True,"PASS_EXACT_ORDERED_FULL_FIELDS"

def engine_fields(page,pdf,pg,n,engine):
    if engine=="PyMuPDF":
        raw,geo=_region(page,n,clean_font)
        if not geo:return None,None,"NO_UNIQUE_GEOMETRIC_ANCHOR"
    else:
        cmd=["pdftotext","-f",str(pg),"-l",str(pg),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=25)
        if r.returncode:return None,None,"POPPLER_ERROR"
        raw=segment_poppler(r.stdout,n)
        geo=None
        if raw is None:return None,None,"POPPLER_AMBIGUOUS_ANCHOR"
    parsed,reason=split_fields(raw,n) if raw is not None else (None,"NO_TEXT")
    if reason:return None,geo,reason
    if any(suspicious(v) for v in [parsed["question"]]+parsed["choices"]):
        return None,geo,"SOURCE_TEXT_UNSAFE"
    return parsed,geo,None

def main():
    prior=json.loads(EXT.read_text())
    holds=json.loads(HOLD.read_text())
    index=json.loads(INDEX.read_text())
    original=json.loads(LEDGER.read_text())
    media_regex=re.compile("図(?:を|に|中|で|の|表)|画像|写真|別冊|模式図|エックス線写真|心電図を|波形を|グラフ")
    exceptions={x["id"] for x in json.loads((ROOT/"audit/official-scoring-exceptions-20261124.json").read_text())["exceptions"]}
    assert len(holds["hold"])+len(prior["questions"])==480
    indexed={x["id"]:x for x in index["items"]}
    staged={}
    for exam in (112,111):
        for sess in ("AM","PM"):
            bank=json.loads((STAGE/f"exam{exam}-{sess}-draft.json").read_text())
            staged.update({q["id"]:q for q in bank["questions"]})
    assert len(staged)==480
    verified={x["id"] for x in prior["questions"]}
    keys={e:parse_official(e) for e in (111,112)}
    pdfs={(e,s):PDF_DIR/f"{e}-{s}.pdf" for e in (111,112) for s in ("AM","PM")}
    docs={k:fitz.open(p) for k,p in pdfs.items()}
    pdfhash={k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in pdfs.items()}
    rows=[]; new=[]; reason_counts=collections.Counter()
    for h in holds["hold"]:
        qid=h["id"];q=staged[qid];e=q["sourceExam"];s=q["session"];n=q["questionNo"]
        record={"id":qid,"exam":e,"session":s,"number":n,"status":"HOLD",
                "previousReasons":h["reasons"],"ocrMethod":"Tesseract jpn+eng PSM6 from rendered source PDF pixels",
                "enginesCompared":["PyMuPDF","Poppler"],"reasons":[]}
        fail=record["reasons"]
        def save():
            reason_counts.update(fail)
            rows.append(record)
        if qid in verified:fail.append("ALREADY_CANONICAL");save();continue
        key,sha=keys[e]
        if not official_valid(q,key.get(qid,{}),sha,exceptions):
            fail.append("OFFICIAL_KEY_OR_SCORING_NOT_CLEAR");save();continue
        if media_regex.search(q.get("question","")) or any("MEDIA" in v or "DIAGRAM" in v for v in h["reasons"]):
            fail.append("MEDIA_RIGHTS_OR_DIAGRAM_GATE");save();continue
        if n>=91:
            fail.append("SCENARIO_CONTEXT_REQUIRES_SEPARATE_OCR_PROOF");save();continue
        imgmeta=indexed.get(qid)
        if not imgmeta or imgmeta.get("status")!="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED":
            fail.append("SOURCE_REGION_NOT_UNIQUE");save();continue
        pg=imgmeta["renderedPage"];pdf=pdfs[(e,s)];doc=docs[(e,s)]
        img=RUN_IMAGES/imgmeta["imageFile"]
        if not img.is_file() or hashlib.sha256(img.read_bytes()).hexdigest()!=imgmeta["imageSha256"] or imgmeta.get("sourcePdfSha256")!=pdfhash[(e,s)]:
            fail.append("ORIGINAL_IMAGE_SHA_MISMATCH");save();continue
        record.update(sourcePdfPage=pg,sourcePdfSha256=pdfhash[(e,s)],
                      sourceImageSha256=imgmeta["imageSha256"],sourceImage=img.name,
                      coordinateClip=imgmeta["clip"])
        try:ocr=get_ocr(img)
        except Exception as exc:fail.append("OCR_EXECUTION_FAILED");record["diagnostic"]=str(exc)[:180];save();continue
        record["ocrTextSha256"]=hashlib.sha256(ocr.encode()).hexdigest()
        (OUT/f"{qid}-ocr.txt").write_text(ocr,encoding="utf8")
        good=[]
        for engine in ("PyMuPDF","Poppler"):
            extracted,geo,err=engine_fields(doc[pg-1],pdf,pg,n,engine)
            if err:
                record[engine+"Check"]=err;continue
            fields=[extracted["question"]]+extracted["choices"]
            if len(extracted["choices"])!=len(q.get("choices") or []):
                record[engine+"Check"]="OPTION_COUNT_DIFFER";continue
            ok,reason=validate_ocr(ocr,n,fields)
            record[engine+"Check"]=reason
            if ok:good.append((engine,extracted))
        if not good:fail.append("NO_EXACT_OCR_AND_ENGINE_FULL_FIELD_MATCH");save();continue
        # To avoid repairing unrelated metadata from noisy OCR, require at least
        # one engine's OCR-confirmed text to equal the staged answer's full fields
        # OR replace the staged text exactly with the independent extracted text.
        engine,parsed=good[0]
        text=[parsed["question"]]+parsed["choices"]
        if any(suspicious(v) for v in text):
            fail.append("UNSAFE_SOURCE_GLYPH");save();continue
        if not (len(parsed["choices"]) in (4,5) and 0<=q["answer"]<len(parsed["choices"])):
            fail.append("ANSWER_OUT_OF_RANGE");save();continue
        original_text={"question":q.get("question"),"choices":q.get("choices")}
        record.update(status="PASS_OCR_PLUS_"+engine,matchedEngine=engine,allFieldsMatched=len(text),
                      candidateTextChanged=original_text!={"question":parsed["question"],"choices":parsed["choices"]})
        row=dict(q)
        row.update(question=parsed["question"],choices=parsed["choices"],sourcePage=pg,
                   publishable=False,releaseEligible=False,requiresMedia=False,mediaAuditStatus="not_required",
                   rightsStatus="mhlw-pdl1.0-text",officialAcceptedAnswers=[q["answer"]],
                   answerType="singleChoice",scoringException=None,canonicalStatus="source_verified_extension",
                   reviewStatus="OCR_AND_INDEPENDENT_PDF_ENGINE_SOURCE_KEY_VERIFIED_EXPLANATION_PENDING",
                   majorSubject=None,point=None,detail=None)
        row["audit"]={"questionOcrAndPdfEngineMatched":True,"allChoicesOcrAndPdfEngineMatched":True,
                      "officialKeyMatched":True,"explanationIndependentlyReviewed":False,
                      "runtimeIntegrationChecked":False}
        row["evidence"]={"method":"OCR source pixels + "+engine+" + independent official PDF answer",
                         "sourcePdfPage":pg,"sourcePdfSha256":pdfhash[(e,s)],
                         "sourceImageSha256":imgmeta["imageSha256"],
                         "sourceOcrSha256":record["ocrTextSha256"],
                         "coordinateClip":imgmeta["clip"],
                         "auditLedger":"kangoshi-sprint/audit/ocr-third-engine-results-20261124.json",
                         "originalText":original_text}
        row["printedOptionCount"]=len(parsed["choices"])
        row["category"]="必修" if n<=25 else "一般"
        new.append(row);save()
    assert len(rows)==len(holds["hold"])
    new_ids={q["id"] for q in new}
    assert len(new_ids)==len(new) and not verified.intersection(new_ids)
    residual=[h for h in holds["hold"] if h["id"] not in new_ids]
    counts={"attempted":len(rows),"newPromoted":len(new),"canonicalAfter":720+len(prior["questions"])+len(new),
            "remainingHeld":len(residual),"holdReasons":dict(reason_counts)}
    ledger={"schemaVersion":1,"counts":counts,"newIds":sorted(new_ids),
            "policy":"Source-only; OCR pixel exact full-field alignment to one PDF engine and official answer key; no scoring exceptions/media/scenarios. No release.",
            "eachItem":rows}
    (ROOT/"audit/ocr-third-engine-results-20261124.json").write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+"\n")
    (OUT/"summary.json").write_text(json.dumps(counts,ensure_ascii=False,indent=2)+"\n")
    if new:
        prior["questions"].extend(new)
        prior["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]))
        prior["count"]=len(prior["questions"])
        EXT.write_text(json.dumps(prior,ensure_ascii=False,indent=2)+"\n")
        holds["hold"]=residual;holds["count"]=len(residual)
        HOLD.write_text(json.dumps(holds,ensure_ascii=False,indent=2)+"\n")
        m=json.loads(MANIFEST.read_text());m["verifiedExtension"].update(
            canonicalSourceVerifiedCount=prior["count"],canonicalSourceVerifiedTotal=720+prior["count"],
            remainingNotVerified=len(residual),runtimeAdditionalCount=0,releaseEligibleAdditionalCount=0,
            lastOcrPromotionCount=len(new))
        MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n")
    # Keep latest promotion ledger additive so the status writer can synchronize.
    original["newPromoted"]=int(original.get("newPromoted",0))+len(new)
    original["newIds"]=list(original.get("newIds",[]))+sorted(new_ids)
    original["canonicalVerified"]=len(prior["questions"])
    original["ocrThirdEngineEvidence"]="kangoshi-sprint/audit/ocr-third-engine-results-20261124.json"
    LEDGER.write_text(json.dumps(original,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(counts,ensure_ascii=False))
if __name__=="__main__":
    main()
