#!/usr/bin/env python3
"""Independent remaining source-hold triage: official keys/exceptions, OCR character diffs, scenario passages.
An evidence report, not a substitute for final source/rights gating.
"""
import collections, difflib, hashlib, json, pathlib, re, subprocess, sys, unicodedata
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from official_answer_key_audit import parse as official_key
from boundary_context_verify import context_for_group, equivalent_shared_context, _region
from bulk_text_helpers import clean_font, suspicious
from reextract_coordinate_candidates import split_fields, segment_poppler
from ocr_third_engine_recovery import get_ocr, norm
OUT=ROOT/"audit/runs/ocr-category-20261124"
OUT.mkdir(parents=True,exist_ok=True)
PREV=json.loads((ROOT/"audit/ocr-third-engine-results-20261124.json").read_text())
SOURCE=json.loads((ROOT/"audit/dual-engine-hold-20261124.json").read_text())
INDEX=json.loads((ROOT/"audit/residual-geometric-source-index-20261124.json").read_text())
EXCEPTIONS=json.loads((ROOT/"audit/official-scoring-exceptions-20261124.json").read_text())["exceptions"]
EXC={x["id"]:x for x in EXCEPTIONS}
PREV_BY={x["id"]:x for x in PREV["eachItem"]}
IMAGES={x["id"]:x for x in INDEX["items"]}
STAGED={}
for ex in (111,112):
 for session in ("AM","PM"):
  data=json.loads((ROOT/f"product-content/keyed-candidates/exam{ex}-{session}-draft.json").read_text())
  STAGED.update({q["id"]:q for q in data["questions"]})
KEYS={ex:official_key(ex) for ex in (111,112)}
PDFS={(ex,s):pathlib.Path(f"/tmp/kangoshi-official/{ex}-{s}.pdf") for ex in (111,112) for s in ("AM","PM")}
DOCS={k:fitz.open(p) for k,p in PDFS.items()}
SHA={k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in PDFS.items()}
PROTECTED=re.compile(r"\\d+(?:[.,．]\\d+)?%?|(?:ない|なし|以外|除く|不可|未|無|非)|[A-Za-z]{2,}")
def extracted(page,pdf,pg,n,engine):
 if engine=="PyMuPDF":
  raw,_=_region(page,n,clean_font)
 else:
  p=subprocess.run(["pdftotext","-f",str(pg),"-l",str(pg),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"],capture_output=True,text=True,timeout=30)
  raw=segment_poppler(p.stdout,n) if p.returncode==0 else None
 if not raw:return None,"MISSING_NUMBERED_REGION"
 parsed,err=split_fields(raw,n)
 return parsed,err
def diff_summary(a,b):
 a=norm(a);b=norm(b)
 sm=difflib.SequenceMatcher(None,a,b,autojunk=False)
 chunks=[{"op":op,"source":a[i:j][:90],"ocr":b[k:l][:90],"sourceStart":i,"ocrStart":k}
  for op,i,j,k,l in sm.get_opcodes() if op!="equal"]
 protected_a=PROTECTED.findall(a);protected_b=PROTECTED.findall(b)
 return {"sourceCharacters":len(a),"ocrCharacters":len(b),"similarity":round(sm.ratio(),5),
         "editCount":sum(max(len(v["source"]),len(v["ocr"])) for v in chunks),
         "protectedTokensEqual":protected_a==protected_b,
         "protectedSource":protected_a[:60],"protectedOcr":protected_b[:60],
         "edits":chunks[:35],"editsTruncated":len(chunks)>35}
def ocr_image(qid,meta):
 f=ROOT/"audit/runs/residual-geometric-images-20261124"/meta["imageFile"]
 if not f.is_file() or hashlib.sha256(f.read_bytes()).hexdigest()!=meta["imageSha256"]:
  return None,"IMAGE_MISSING_OR_HASH_DRIFT"
 try:return get_ocr(f),None
 except Exception as e:return None,str(e)[:160]
def page_poppler(pdf,pg):
 r=subprocess.run(["pdftotext","-f",str(pg),"-l",str(pg),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"],capture_output=True,text=True,timeout=30)
 return r.stdout if r.returncode==0 else ""
rows=[];categories=collections.Counter();keys_out=collections.Counter()
for held in SOURCE["hold"]:
 qid=held["id"];q=STAGED[qid];e=q["sourceExam"];session=q["session"];n=q["questionNo"]
 prev=PREV_BY[qid];category=prev["reasons"][0] if prev["reasons"] else "UNKNOWN"
 categories[category]+=1
 key,sha=KEYS[e];answer=key.get(qid);exc=EXC.get(qid)
 official={"pdfSha256":sha,"officialRaw":answer.get("rawValue") if answer else None,
  "officialStatus":answer.get("status") if answer else "MISSING",
  "draftRaw":q.get("officialKeyRaw"),"draftAnswer":q.get("answer"),
  "draftShaMatches":q.get("officialKeyPdfSha256")==sha,
  "exception":{k:exc.get(k) for k in ("mode","url","reason")} if exc else None}
 if exc:official["decision"]="EXCEPTION_HANDLING_REQUIRED_"+exc["mode"]
 elif not answer or answer["status"]!="KEY_SINGLE":official["decision"]="NOT_SINGLE_OFFICIAL_KEY"
 elif not isinstance(q.get("answer"),int) or answer["rawValue"]!=str(q["answer"]+1) or q.get("officialKeyPdfSha256")!=sha:
  official["decision"]="OFFICIAL_KEY_OR_STAGED_MISMATCH"
 else:official["decision"]="NORMAL_KEY_CONFIRMED"
 keys_out[official["decision"]]+=1
 row={"id":qid,"exam":e,"session":session,"number":n,"category":category,
      "previousReasons":held["reasons"],"official":official,"sourceStatus":"HOLD"}
 if category=="OFFICIAL_KEY_OR_SCORING_NOT_CLEAR":
  row["categoryDecision"]="SCORING_CONFIRMED_NOT_SOURCE_CERTIFIED"
 elif category=="NO_EXACT_OCR_AND_ENGINE_FULL_FIELD_MATCH":
  meta=IMAGES.get(qid)
  if not meta or meta.get("status")!="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED":
   row["categoryDecision"]="NO_UNIQUE_SOURCE_REGION"
  elif meta["sourcePdfSha256"]!=SHA[(e,session)]:
   row["categoryDecision"]="PDF_HASH_DRIFT"
  else:
   ocr,error=ocr_image(qid,meta)
   if error:row["categoryDecision"]="OCR_UNAVAILABLE";row["error"]=error
   else:
    pg=meta["renderedPage"];doc=DOCS[(e,session)];pdf=PDFS[(e,session)]
    checks={}
    for engine in ("PyMuPDF","Poppler"):
     parsed,reason=extracted(doc[pg-1],pdf,pg,n,engine)
     if reason:checks[engine]={"failure":reason};continue
     fields=[parsed["question"]]+parsed["choices"]
     checks[engine]={"printedOptions":len(parsed["choices"]),
         "fieldDiffs":[diff_summary(s,ocr) for s in fields],
         "ocrFullTextHash":hashlib.sha256(ocr.encode()).hexdigest(),
         "sourceFieldsHash":hashlib.sha256(json.dumps(fields,ensure_ascii=False).encode()).hexdigest(),
         "sourceSuspicious":any(suspicious(x) for x in fields)}
    row["ocrTextEvidence"]=checks
    row["sourceImageSha256"]=meta["imageSha256"]
    row["categoryDecision"]="CHARACTER_DIFF_SAVED_HOLD_FOR_UNPROVEN_FIELD_BOUNDARIES"
 elif category=="SCENARIO_CONTEXT_REQUIRES_SEPARATE_OCR_PROOF":
  meta=IMAGES.get(qid);pg=meta.get("renderedPage") if meta else None
  context_rows=[];context_found=False
  if pg and meta.get("sourcePdfSha256")==SHA[(e,session)]:
   doc=DOCS[(e,session)];pdf=PDFS[(e,session)]
   for cp in range(max(1,pg-3),pg+1):
    raw=doc[cp-1].get_text("text",sort=False)
    info=context_for_group(clean_font(raw),n)
    if info is None:continue
    context_found=True
    pi=context_for_group(clean_font(page_poppler(pdf,cp)),n)
    clip=doc[cp-1].rect
    png=OUT/f"{qid}-shared-passage-p{cp}.png"
    doc[cp-1].get_pixmap(matrix=fitz.Matrix(2.5,2.5),clip=clip,alpha=False).save(str(png))
    ocr,err=ocr_image(qid,{"imageFile":"not-applicable","imageSha256":""}) if False else (None,None)
    try:ocr=get_ocr(png)
    except Exception as e:err=str(e)[:180]
    extracted_context=info["passage"]
    equal_pdf=equivalent_shared_context(info["passage"],pi["passage"])[0] if pi else False
    context_rows.append({"page":cp,"sourceImageSha256":hashlib.sha256(png.read_bytes()).hexdigest(),
      "pdfSourceSha256":SHA[(e,session)],"groupStart":info["first"],"groupEnd":info["last"],
      "twoPdfEnginesAgree":equal_pdf,"sourceContextLength":len(norm(extracted_context)),
      "ocrContextDiff":diff_summary(extracted_context,ocr) if ocr else None,
      "ocrError":err,"ocrExactContextSubstring":norm(extracted_context) in norm(ocr) if ocr else False})
  row["scenarioEvidence"]=context_rows
  row["categoryDecision"]="SCENARIO_IMAGE_AND_TEXT_CHECKED_SOURCE_HOLD" if context_found else "SHARED_PASSAGE_NOT_LOCATED"
 else:row["categoryDecision"]="MEDIA_REQUIRES_SEPARATE_RIGHTS_AND_FIDELITY"
 rows.append(row)
assert len(rows)==len(SOURCE["hold"]) and len(rows)+len(json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())["questions"])==480
result={"schemaVersion":1,"examScope":[111,112],"checked":len(rows),
 "categories":dict(categories),"officialDecisions":dict(keys_out),
 "promotionAllowedFromThisLedger":False,"newlyPromoted":0,"records":rows,
 "note":"OCR text and source-page graphics are independent image evidence, but diffs alone do not prove all fields; exception keys do not clear source, diagram or app gates."}
dest=ROOT/"audit/ocr-category-deep-review-20261124.json"
dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
(OUT/"summary.json").write_text(json.dumps({k:v for k,v in result.items() if k!="records"},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"checked":len(rows),"categories":dict(categories),"official":dict(keys_out),"newlyPromoted":0},ensure_ascii=False))
