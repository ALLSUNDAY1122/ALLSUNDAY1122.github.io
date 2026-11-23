#!/usr/bin/env python3
"""Repair 46 unresolved OCR segmentation failures from independent choice coordinates.
Original official PDF pixels are OCR'ed separately for stem and each choice.
Requires matching labelled choice geometry in PDF and independent pixel OCR,
two OCR page segmentation modes agreeing on each field, strict CMap-only delta,
official answer PDF SHA and no scoring/media/situation exception.
Never promotes a guessed glyph, loses a protected token, or publishes content.
"""
import collections,hashlib,json,pathlib,re,subprocess,sys
import fitz
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from repair_ocr_cmap_96 import (safe_repair, balanced_source_brackets, strip_footer,
                               BAD, MEDIA, compact)
from official_answer_key_audit import parse as official_key
from boundary_context_verify import _region
from bulk_text_helpers import clean_font
BASE=ROOT/"product-content"; AUDIT=ROOT/"audit"
OUT=AUDIT/"runs/ocr-coordinate-46-20261124";OUT.mkdir(parents=True,exist_ok=True)
PDF_DIR=pathlib.Path("/tmp/kangoshi-official")
PROOF=AUDIT/"ocr-coordinate-repair-ledger-20261124.json"
REPAIR=BASE/"ocr-coordinate-repaired-candidates-20261124.json"
BANK=BASE/"verified-additions-20261124.json"
HOLDS=AUDIT/"dual-engine-hold-20261124.json"
PROM=AUDIT/"dual-engine-promotion-ledger-20261124.json"
MANIFEST=BASE/"manifest.json"
SOURCE=AUDIT/"residual-geometric-source-index-20261124.json"
C0=AUDIT/"ocr-cmap-repair-ledger-20261124.json"
ALLOWED=re.compile(r"^\s*([1-4])(?:\s*[.．、)）]|\s+)")
NONCONTENT=re.compile(r"^\s*(?:DKIX-.*|\d+\s*DKIX-.*)$")
def sha(data):return hashlib.sha256(data).hexdigest()
def recognize(png,psm):
    p=subprocess.run(["tesseract",str(png),"stdout","-l","jpn+eng","--psm",str(psm)],
                     capture_output=True,text=True,timeout=65)
    if p.returncode:raise RuntimeError(p.stderr[-260:])
    return p.stdout
def crop_ocr(page,coords,qid,index):
    f=OUT/f"{qid}-field{index}.png"
    page.get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(*coords),alpha=False).save(str(f))
    texts={m:recognize(f,m) for m in (6,3,4,11)}
    return texts,{"png":f.name,"pngSha256":sha(f.read_bytes()),"clip":[round(v,2) for v in coords],
                 "ocrSha256ByPsm":{str(m):sha(t.encode()) for m,t in texts.items()}}
def anchors(page,rect):
    """Independent PDF word geometry; do not infer answer text from PDF CMap."""
    cand=[]
    for x0,y0,x1,y1,t,*_ in page.get_text("words",sort=True):
        if not (rect.y0+11 <= y0 < rect.y1-7 and rect.x0+5 <= x0 < rect.x0+rect.width*.23):
            continue
        val=clean_font(t).strip()
        m=ALLOWED.match(val)
        if m and int(m.group(1)) in (1,2,3,4):
            cand.append((int(m.group(1)),float(x0),float(y0),float(x1),float(y1)))
    out=[]
    for n in (1,2,3,4):
        found=[x for x in cand if x[0]==n]
        if len(found)!=1:return None,"CHOICE_"+str(n)+"_ANCHOR_NOT_UNIQUE"
        out.append(found[0])
    if not all(out[i+1][2]>out[i][2]+7 for i in range(3)):
        return None,"CHOICE_Y_ORDER_INVALID"
    if max(x[1] for x in out)-min(x[1] for x in out)>30:
        return None,"CHOICE_X_COLUMN_AMBIGUOUS"
    if out[0][2]-rect.y0 < 20:return None,"STEM_REGION_TOO_SHORT"
    return out,None
def normalize_ocr_field(text,index,num):
    lines=[z.strip() for z in text.splitlines() if z.strip() and not NONCONTENT.match(z)]
    if not lines:return None,"OCR_EMPTY_FIELD"
    if index==0:
        # Explicit question number must be present at the top of the source crop.
        k=re.match(r"^(?:問\s*)?0*"+str(num)+r"(?=\s|[.．)）]|$)[\s.．)）]*(.*)$",lines[0])
        if not k:return None,"QUESTION_LABEL_NOT_RECOGNIZED"
        lines[0]=k.group(1)
    else:
        k=ALLOWED.match(lines[0])
        if not k or int(k.group(1))!=index:return None,"OPTION_LABEL_NOT_RECOGNIZED"
        lines[0]=lines[0][k.end():].strip()
    result="".join(z for z in lines if z)
    return (strip_footer(result) if index==4 else result),None
def main():
    old=json.loads(BANK.read_text());hold=json.loads(HOLDS.read_text())
    ledger=json.loads(C0.read_text())
    targets={r["id"] for r in ledger["perQuestion"]
             if r.get("reason")=="OCR_FIELD_SEGMENTATION_FAILED" and r.get("status")=="HOLD"}
    existing={q["id"] for q in old["questions"]}
    targets-=existing
    # First run should have 46; retain these IDs in the immutable baseline list
    # and permit incremental reruns after promotions.
    prior=json.loads(PROOF.read_text()) if PROOF.exists() else None
    baseline=set(prior["originalTargetIds"]) if prior else set(targets)
    assert len(baseline)==46,("expected 46 historic OCR segmentation holds",len(baseline))
    assert targets <= baseline and targets <= {x["id"] for x in hold["hold"]}
    indexed={x["id"]:x for x in json.loads(SOURCE.read_text())["items"]}
    exc={x["id"] for x in json.loads((AUDIT/"official-scoring-exceptions-20261124.json").read_text())["exceptions"]}
    drafts={}
    for ex in (111,112):
        for ses in ("AM","PM"):
            rows=json.loads((BASE/f"keyed-candidates/exam{ex}-{ses}-draft.json").read_text())["questions"]
            drafts.update({x["id"]:x for x in rows})
    keys={e:official_key(e) for e in (111,112)}
    docs={};pdfhash={}
    for e in (111,112):
      for s in ("AM","PM"):
        pdf=PDF_DIR/f"{e}-{s}.pdf"
        docs[(e,s)]=fitz.open(pdf);pdfhash[(e,s)]=sha(pdf.read_bytes())
    rows=[];promoted=[];edits=[];reasons=collections.Counter()
    for qid in sorted(targets):
        q=drafts[qid];e=q["sourceExam"];s=q["session"];n=q["questionNo"]
        row={"id":qid,"exam":e,"session":s,"number":n,"status":"HOLD"}
        def deny(reason):
            row["reason"]=reason;reasons[reason]+=1;rows.append(row)
        key,keyhash=keys[e];answer=q.get("answer");k=key.get(qid)
        if (qid in exc or q.get("officialScoringStatus")!="normal" or not k
            or k.get("status")!="KEY_SINGLE" or not isinstance(answer,int)
            or not 0<=answer<4 or k["rawValue"]!=str(answer+1)
            or q.get("officialKeyPdfSha256")!=keyhash):
            deny("OFFICIAL_KEY_OR_SCORING_HOLD");continue
        if n>=91:deny("SCENARIO_COMMON_TEXT_UNVERIFIED");continue
        if MEDIA.search(q.get("question","")):
            deny("MEDIA_FIDELITY_OR_RIGHTS_HOLD");continue
        meta=indexed.get(qid)
        if not meta or meta.get("status")!="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED":
            deny("SOURCE_QUESTION_REGION_UNVERIFIED");continue
        if meta["sourcePdfSha256"]!=pdfhash[(e,s)]:
            deny("ORIGINAL_PDF_SHA_DRIFT");continue
        page=docs[(e,s)][meta["renderedPage"]-1]
        original_region=ROOT/"audit/runs/residual-geometric-images-20261124"/meta["imageFile"]
        if not original_region.exists() or sha(original_region.read_bytes())!=meta["imageSha256"]:
            deny("ORIGINAL_REGION_IMAGE_HASH_DRIFT");continue
        rect=fitz.Rect(*meta["clip"])
        source,geom=_region(page,n,clean_font)
        if not geom or [round(v,2) for v in geom["clip"]] != [round(v,2) for v in rect]:
            deny("GEOMETRY_CLIP_CHANGED");continue
        choice_boxes,err=anchors(page,rect)
        if err:deny(err);continue
        cuts=[rect.y0]+[(choice_boxes[i][2]+choice_boxes[i][4])/2 if False else choice_boxes[i][2]-3 for i in range(4)]+[rect.y1]
        # Exclude printed page-control/footer text geometrically, never by
        # guessing/replacing OCR characters. Footer is below the final choice.
        footer_ys=[float(w[1]) for w in page.get_text("words",sort=True)
          if "DKIX-" in str(w[4]) and w[1]>choice_boxes[3][2]+9
          and w[1]<rect.y1]
        if footer_ys:
            cuts[-1]=min(cuts[-1],min(footer_ys)-4)
            row["footerBoundaryEvidence"]={"y":min(footer_ys),
                  "lastChoiceEndsAt":cuts[-1],"method":"original PDF word-coordinate footer anchor"}
        # Each OCR field owns its printed label and text until the next label.
        if not all(cuts[i+1]-cuts[i]>10 for i in range(5)):
            deny("FIELD_RECTANGLES_TOO_SHORT");continue
        candidate=[];field_evidence=[];error=None
        for i in range(5):
            coords=[rect.x0,max(rect.y0,cuts[i]),rect.x1,min(rect.y1,cuts[i+1])]
            try:texts,proof=crop_ocr(page,coords,qid,i)
            except Exception as exc_:error="OCR_FAILED";row["detail"]=str(exc_)[:140];break
            result={m:normalize_ocr_field(t,i,n) for m,t in texts.items()}
            proof.update({"fieldIndex":i,
               "normalizedByPsm":{str(m):v for m,(v,err) in result.items()},
               "errorsByPsm":{str(m):err for m,(v,err) in result.items() if err}})
            field_evidence.append(proof)
            groups={}
            for mode,(value,err) in result.items():
                if not err and value:groups.setdefault(compact(value),[]).append(mode)
            good=sorted(groups.items(),key=lambda v:(-len(v[1]),v[0]))
            if not good or len(good[0][1])<2:
                error="COORDINATE_FIELD_NO_TWO_OCR_PSM_CONSENSUS";break
            modes=good[0][1]
            proof["agreedPsmModes"]=modes
            candidate.append(result[modes[0]][0])
        row["fieldEvidence"]=field_evidence
        if error:deny(error);continue
        if len(q.get("choices") or [])<4:
            deny("DRAFT_CHOICES_INCOMPLETE");continue
        oldfields=[q.get("question","")]+q["choices"][:4]
        checks=[safe_repair(x,y) for x,y in zip(oldfields,candidate)]
        row["fieldChecks"]=[{"index":i,"pass":ok,"decision":decision,"deltas":deltas}
                            for i,(ok,decision,deltas) in enumerate(checks)]
        if not all(ok for ok,_,_ in checks):
            deny("NOT_CMAP_ONLY_DIFFERENCE");continue
        if not any(decision!="UNCHANGED" for _,decision,_ in checks):
            deny("NO_CHARACTER_REPAIR");continue
        if not all(balanced_source_brackets(x) for x in candidate) or any(ch in BAD for x in candidate for ch in x):
            deny("REPAIRED_GLYPHS_UNSAFE");continue
        if len(q["choices"])>4:
            tail=q["choices"][4:]
            if not all(re.fullmatch(r"(?:\d{1,3}\s*)?DKIX-\d+-(?:前|後)H-\d+",t.strip()) for t in tail):
                deny("UNRESOLVED_EXTRA_OPTION");continue
        before={"question":q["question"],"choices":q["choices"],"sourcePage":q.get("sourcePage")}
        after={"question":candidate[0],"choices":candidate[1:],"sourcePage":meta["renderedPage"]}
        row.update({"status":"PROMOTED_SOURCE_ONLY","before":before,"after":after,
                    "reason":None,"pdfPage":meta["renderedPage"],
                    "originalPdfSha256":pdfhash[(e,s)],"originalImageSha256":meta["imageSha256"],
                    "officialKeyPdfSha256":keyhash,"officialAnswer":answer,
                    "coordinateClip":meta["clip"],"printedOptionAnchors":choice_boxes})
        revised=dict(q)
        revised.update(question=after["question"],choices=after["choices"],sourcePage=after["sourcePage"],
            printedOptionCount=4,sourceAnswerTokens=[str(answer+1)],officialAcceptedAnswers=[answer],
            requiresMedia=False,mediaAuditStatus="not_required",rightsStatus="mhlw-pdl1.0-text",
            publishable=False,releaseEligible=False,canonicalStatus="source_verified_extension",
            reviewStatus="COORDINATE_FIELD_OCR_IMAGE_VERIFIED_EXPLANATION_PENDING",
            category="必修" if n<=25 else "一般",majorSubject=None,point=None,detail=None)
        revised["audit"]={"coordinateFieldOcrPsm6Matched":True,
             "coordinateFieldOcrPsm3Matched":True,"officialKeyMatched":True,
             "explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}
        revised["evidence"]={"sourcePdfPage":meta["renderedPage"],
            "sourcePdfSha256":pdfhash[(e,s)],"sourceImageSha256":meta["imageSha256"],
            "coordinateClip":meta["clip"],"ocrFieldProof":field_evidence,
            "corrections":row["fieldChecks"],
            "auditLedger":"kangoshi-sprint/audit/ocr-coordinate-repair-ledger-20261124.json"}
        promoted.append(revised)
        edits.append({"id":qid,"before":before,"after":after,"officialAnswer":answer,
                      "originalPdfSha256":pdfhash[(e,s)],"originalImageSha256":meta["imageSha256"],
                      "fields":field_evidence,"diffs":row["fieldChecks"]})
        rows.append(row);reasons["PROMOTED_SOURCE_ONLY"]+=1
    promoted_ids={x["id"] for x in promoted}
    assert len(promoted_ids)==len(promoted) and not promoted_ids.intersection(existing)
    assert len(rows)==len(targets)
    pastrows=prior["perQuestion"] if prior else []
    pastrows=[r for r in pastrows if r.get("status")=="PROMOTED_SOURCE_ONLY" and r["id"] not in targets]
    report={"schemaVersion":1,"originalTargetIds":sorted(baseline),
            "processedThisRun":len(targets),"newPromoted":len(promoted),
            "cumulativePromoted":len(pastrows)+len(promoted),
            "remaining":46-len(pastrows)-len(promoted),
            "reasonCounts":dict(reasons),"newIds":sorted(promoted_ids),
            "perQuestion":pastrows+rows,"published":False,
            "policy":"OCR fields separately clipped by PDF option geometry; require exact same field in at least 2 of PSM 6/3/4/11; CMap-only substitution; original PDF and image SHA; single official answer and no media/scenario; source-only."}
    PROOF.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    old_edits=json.loads(REPAIR.read_text()).get("edits",[]) if REPAIR.exists() else []
    edit_ids={v["id"]:v for v in old_edits}
    edit_ids.update({v["id"]:v for v in edits})
    REPAIR.write_text(json.dumps({"schemaVersion":1,"count":len(edit_ids),"edits":list(edit_ids.values())},
          ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    if promoted:
        old["questions"].extend(promoted)
        old["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]))
        old["count"]=len(old["questions"])
        BANK.write_text(json.dumps(old,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
        hold["hold"]=[h for h in hold["hold"] if h["id"] not in promoted_ids]
        hold["count"]=len(hold["hold"])
        HOLDS.write_text(json.dumps(hold,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
        m=json.loads(MANIFEST.read_text())
        m["verifiedExtension"].update(canonicalSourceVerifiedCount=old["count"],
            canonicalSourceVerifiedTotal=720+old["count"],remainingNotVerified=hold["count"],
            runtimeAdditionalCount=0,releaseEligibleAdditionalCount=0,
            latestCoordinateOcrPromotion=len(promoted))
        MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    p=json.loads(PROM.read_text())
    p["newPromoted"]=int(p.get("newPromoted",0))+len(promoted)
    p["newIds"]=list(p.get("newIds",[]))+sorted(promoted_ids)
    p["canonicalVerified"]=len(old["questions"])
    p["coordinateFieldOcrProof"]="kangoshi-sprint/audit/ocr-coordinate-repair-ledger-20261124.json"
    PROM.write_text(json.dumps(p,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    (OUT/"summary.json").write_text(json.dumps({k:v for k,v in report.items() if k!="perQuestion"},ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"scope":46,"checked":len(targets),"newPromoted":len(promoted),
                      "canonicalAfter":720+old["count"],"heldAfter":hold["count"],
                      "reasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__":main()
