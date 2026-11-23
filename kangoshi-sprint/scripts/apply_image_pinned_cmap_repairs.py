#!/usr/bin/env python3
"""Use visually inspected exact source-PDF image hashes to repair narrow PDF CMap defects.

This is NOT blanket OCR or a relaxed verification. Image proof allows ONLY the
specified Poppler-missing printed numeric substring or paired glyphs. All
other Japanese/Latin text must match between two independent extraction engines.
The official single-key and scoring gates are applied here and again in bulk.
"""
import json,pathlib,hashlib,sys,collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from reextract_coordinate_candidates import split_fields,segment_poppler,poppler_page,equivalent_english_gloss_reorder
from boundary_context_verify import _region,equivalent_shared_context
from bulk_text_helpers import clean_font,norm,suspicious
from official_answer_key_audit import parse as official_keys
MANIFEST=ROOT/"audit/image-pinned-cmap-repairs-20261124.json"
IMAGES=ROOT/"audit/runs/residual-geometric-images-20261124"
manifest=json.loads(MANIFEST.read_text())
BY={x["id"]:x for x in manifest["items"]}
assert len(BY)==len(manifest["items"])==7

def extract_and_match(doc,pdf,n,page,entry,pop_raw=None):
    region,geometry=_region(doc[page-1],n,clean_font)
    if not region or not geometry:return None,"NO_UNIQUE_GEOMETRIC_QUESTION_ANCHOR"
    if pop_raw is None:pop_raw=poppler_page(pdf,page)
    pop_region=segment_poppler(pop_raw,n)
    if pop_region is None:return None,"NO_UNIQUE_POPPLER_QUESTION_ANCHOR"
    parens=bool(entry.get("allowedPairedGlyphs"))
    p,err1=split_fields(region,n,visually_verified_parentheses=parens)
    b,err2=split_fields(pop_region,n,visually_verified_parentheses=parens)
    if err1 or err2:return None,"SPLIT_"+str(err1)+"_"+str(err2)
    py=[p["question"]]+p["choices"]
    po=[b["question"]]+b["choices"]
    if len(py)!=len(po) or len(py) not in (5,6):return None,"WRONG_CHOICES_COUNT"
    exceptions=collections.defaultdict(list)
    for e in entry["allowedSourceNumeralOmissions"]:
        i=e["field"]
        if i<0 or i>=len(py) or not e["source"].strip() or e["source"]==e["poppler"]:
            return None,"INVALID_NUMERIC_EXCEPTION"
        exceptions[i].append(e)
    checks=[]
    for i,(source,alternative) in enumerate(zip(py,po)):
        expected=source
        if i in exceptions:
            for exception in exceptions[i]:
                original=exception["source"];alternate=exception["poppler"]
                if expected.count(original)!=1:return None,"REPAIRED_NUMERIC_TOKEN_NOT_UNIQUE_"+str(i)
                expected=expected.replace(original,alternate,1)
        exact=equivalent_shared_context(expected,alternative)[0] or equivalent_english_gloss_reorder(expected,alternative)
        if not exact:return None,"UNAUTHORIZED_PDF_ENGINE_DIFFERENCE_FIELD_"+str(i)
        if suspicious(source):return None,"UNRESOLVED_PDF_SOURCE_GLYPH_FIELD_"+str(i)
        checks.append({"field":i,"twoEngineAgreement":True,"visuallyPinnedOmissions":exceptions[i]})
    return {"question":p["question"],"choices":p["choices"],"geometry":geometry,
            "checks":checks,"popplerFieldCount":len(po),"sourceFieldCount":len(py)},None

def validate_image(pdf,entry):
    if hashlib.sha256(pdf.read_bytes()).hexdigest()!=entry["sourcePdfSha256"]:
        return "SOURCE_PDF_SHA_DRIFT"
    image=IMAGES/f"{entry['id']}-source-region.png"
    if not image.is_file() or hashlib.sha256(image.read_bytes()).hexdigest()!=entry["sourcePngSha256"]:
        return "SOURCE_IMAGE_SHA_DRIFT"
    return None

def main():
    result=[];fixed=[]
    for ex in (112,111):
        keys,keysha=official_keys(ex)
        for session in ("AM","PM"):
            path=ROOT/"product-content/keyed-candidates"/f"exam{ex}-{session}-draft.json"
            data=json.loads(path.read_text())
            pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf"
            doc=fitz.open(pdf)
            for q in data["questions"]:
                entry=BY.get(q["id"])
                if entry is None:continue
                n=q["questionNo"];page=entry["page"]
                failures=[]
                if (ex,session,n)!=(entry["exam"],entry["session"],entry["number"]):
                    failures.append("QUESTION_SOURCE_ID_MISMATCH")
                imgerr=validate_image(pdf,entry)
                if imgerr:failures.append(imgerr)
                official=keys.get(q["id"])
                if (not official or official.get("status")!="KEY_SINGLE" or
                    not isinstance(q.get("answer"),int) or official.get("rawValue")!=str(q["answer"]+1) or
                    q.get("officialKeyRaw")!=str(q["answer"]+1) or q.get("officialKeyPdfSha256")!=keysha):
                    failures.append("INDEPENDENT_OFFICIAL_KEY_OR_SHA_MISMATCH")
                if q.get("officialScoringStatus")!="normal":
                    failures.append("OFFICIAL_SCORING_EXCEPTION")
                info=None
                if not failures:
                    info,reason=extract_and_match(doc,pdf,n,page,entry)
                    if reason:failures.append(reason)
                if failures:
                    result.append({"id":q["id"],"status":"HOLD","reasons":failures})
                    continue
                before={key:q.get(key) for key in ("question","choices","sourcePage","extractionValid")}
                q.update(question=info["question"],choices=info["choices"],sourcePage=page,extractionValid=True)
                q["imagePinnedCmapRepair"]={"evidence":"kangoshi-sprint/audit/image-pinned-cmap-repairs-20261124.json",
                    "pdfSha256":entry["sourcePdfSha256"],"pngSha256":entry["sourcePngSha256"],
                    "page":page,"anchorBox":info["geometry"]["anchorBox"],
                    "fiveFieldProof":info["checks"],"manualImageReviewed":True,
                    "candidateOnly":True,"original":before}
                result.append({"id":q["id"],"status":"CANDIDATE_REPAIRED_NOT_CANONICAL",
                    "sourcePage":page,"printedChoices":len(info["choices"]),"original":before,
                    "replacement":{"question":q["question"],"choices":q["choices"]},
                    "fieldComparison":info["checks"],"pdfSha256":entry["sourcePdfSha256"],
                    "pngSha256":entry["sourcePngSha256"]})
                fixed.append(q["id"])
            path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    ledger={"schemaVersion":1,"source":"original rendered PDF + PyMuPDF geometric clip + Poppler -layout + official answer",
        "checked":len(BY),"repairedCandidate":len(fixed),"repairedIds":fixed,"rows":result,
        "releasePermission":False,"note":"No candidate elevated until independent bulk verifier reruns same tests."}
    out=ROOT/"audit/image-pinned-cmap-repair-results-20261124.json"
    out.write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"checked":len(BY),"repairedCandidate":len(fixed),"repairedIds":fixed,
        "holds":[x for x in result if x["status"]=="HOLD"]},ensure_ascii=False))
if __name__=="__main__":main()
