#!/usr/bin/env python3
"""Source-only recovery for 23 original-PDF nurse question OCR disagreements (21 text, 2 image holds).

The manually transcribed text is in the checked-in 23-question visual register,
which was inspected against each source PDF raster independently of Tesseract.
Every case additionally requires the original PDF/image SHA, unique question
anchor, four individual coordinate OCR image hashes, official answer PDF,
scoring-exception exclusion, and individual before/after trace. Question 75 in exam 112 morning has FIVE printed options, not four. Publication blocked.
"""
import difflib, hashlib, json, pathlib, re, sys
import fitz

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from official_answer_key_audit import parse as official_key
from repair_ocr_cmap_96 import compact
BASE=ROOT/"product-content"
AUD=ROOT/"audit"
PDF=pathlib.Path("/tmp/kangoshi-official")
INPUT=AUD/"ocr-psm-disagreement-23-original-page-transcriptions-20261124.json"
PROOF=AUD/"ocr-psm-disagreement-23-promotion-ledger-20261124.json"
DIFF=BASE/"ocr-psm-disagreement-23-before-after-20261124.json"
BANK=BASE/"verified-additions-20261124.json"
HOLDS=AUD/"dual-engine-hold-20261124.json"
PROM=AUD/"dual-engine-promotion-ledger-20261124.json"
MANIFEST=BASE/"manifest.json"
INDEX=AUD/"residual-geometric-source-index-20261124.json"
COORD=AUD/"ocr-coordinate-repair-ledger-20261124.json"
OUT=AUD/"runs/ocr-psm-disagreement-23-20261124"
OUT.mkdir(parents=True,exist_ok=True)

def digest(data):
    return hashlib.sha256(data).hexdigest()
def mutations(a,b):
    old=compact(a)
    new=compact(b)
    return [{"operation":t,"old":old[i:j],"new":new[k:l],"oldAt":i,"newAt":k}
        for t,i,j,k,l in difflib.SequenceMatcher(None,old,new,autojunk=False).get_opcodes()
        if t!="equal"]
def main():
    plan=json.loads(INPUT.read_text(encoding="utf8"))
    assert len(plan["items"])==23
    ids=[x["id"] for x in plan["items"]]
    assert len(ids)==len(set(ids))
    bank=json.loads(BANK.read_text(encoding="utf8"))
    holds=json.loads(HOLDS.read_text(encoding="utf8"))
    seen={x["id"] for x in bank["questions"]}
    active={x["id"] for x in holds["hold"]}
    expected=set(ids)
    assert not expected-seen-active, "Expected source questions no longer held or canonical"
    prev=json.loads(PROOF.read_text(encoding="utf8")) if PROOF.exists() else None
    done={x["id"]:x for x in prev["cases"] if x["status"]=="PASS_SOURCE_ONLY"} if prev else {}
    index={x["id"]:x for x in json.loads(INDEX.read_text())["items"]}
    coordinates={x["id"]:x for x in json.loads(COORD.read_text())["perQuestion"]}
    exceptions={x["id"] for x in json.loads((AUD/"official-scoring-exceptions-20261124.json").read_text())["exceptions"]}
    drafts={}
    for exam in (111,112):
      for session in ("AM","PM"):
        f=BASE/f"keyed-candidates/exam{exam}-{session}-draft.json"
        drafts.update({x["id"]:x for x in json.loads(f.read_text())["questions"]})
    keys={exam:official_key(exam) for exam in (111,112)}
    documents={}
    pdfhash={}
    for exam in (111,112):
      for session in ("AM","PM"):
        name=PDF/f"{exam}-{session}.pdf"
        documents[(exam,session)]=fitz.open(name)
        pdfhash[(exam,session)]=digest(name.read_bytes())
    results=[];new=[];edits=[]
    media_held=[]
    for item in plan["items"]:
        qid=item["id"]
        if item["status"]=="HOLD_MEDIA_PENDING_FIDELITY_AND_RIGHTS":
            assert qid in active and qid not in seen, "Media case unexpectedly verified "+qid
            media_held.append({"id":qid,"status":"HOLD_MEDIA_PENDING_FIDELITY_AND_RIGHTS",
                "sourcePdfPage":item["pdfPage"],"reason":item["holdReason"],
                "originalSourceUrl":item["originalSourceUrl"]})
            continue
        if qid in seen:
            if qid not in done:
                raise ValueError(f"Already canonical but not in previous 19-case audit: {qid}")
            results.append(done[qid]);continue
        if qid not in active:raise ValueError("Not held "+qid)
        q=drafts[qid];exam=q["sourceExam"];session=q["session"];num=q["questionNo"]
        if (exam,session,num)!=(item["exam"],item["session"],item["number"]):
            raise ValueError("Source question identity does not match "+qid)
        if qid in exceptions or q.get("officialScoringStatus")!="normal":
            raise ValueError("Official scoring exception needs separate treatment "+qid)
        answers,keysha=keys[exam];official=answers.get(qid);expected_answer=q.get("answer")
        if (not official or official["status"]!="KEY_SINGLE"
            or official.get("rawValue")!=str(expected_answer+1)
            or q.get("officialKeyPdfSha256")!=keysha
            or q.get("answer")!=expected_answer):
            raise ValueError("Official answer source mismatch "+qid)
        choices=item["choices"]
        required=5 if qid=="K112-AM075" else 4
        if len(choices)!=required:
            raise ValueError("Wrong printed option count "+qid)
        if len(set(choices))!=len(choices):
            raise ValueError("Duplicate printed options "+qid)
        if not item["question"] or any(not x for x in choices):
            raise ValueError("Empty original-page transcription "+qid)
        geometry=index[qid]
        if geometry["status"]!="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED":
            raise ValueError("Not unique source page number "+qid)
        if geometry["renderedPage"]!=item["pdfPage"]:
            raise ValueError("Page mismatch "+qid)
        if geometry["sourcePdfSha256"]!=pdfhash[(exam,session)]:
            raise ValueError("Official question PDF hash drift "+qid)
        image=ROOT/"audit/runs/residual-geometric-images-20261124"/geometry["imageFile"]
        if not image.is_file() or digest(image.read_bytes())!=geometry["imageSha256"]:
            raise ValueError("Original source screenshot SHA mismatch "+qid)
        page=documents[(exam,session)][item["pdfPage"]-1]
        rect=fitz.Rect(*geometry["clip"])
        if not (0<=rect.x0<rect.x1<=page.rect.width+.1
             and 0<=rect.y0<rect.y1<=page.rect.height+.1):
            raise ValueError("Original PDF crop bounds "+qid)
        question_number=page.get_text("words")
        anchors=[w for w in question_number if re.fullmatch(r"0*"+str(num),w[4])
                 and rect.y0-5 <= w[1] <= rect.y0+15
                 and rect.x0 <= w[0] <= rect.x0+rect.width*.25]
        if len(anchors)!=1:
            raise ValueError(f"Question number source anchor not unique {qid}: {len(anchors)}")
        prior=coordinates[qid]
        if prior.get("status")!="HOLD" or prior.get("reason")!="COORDINATE_FIELD_NO_TWO_OCR_PSM_CONSENSUS":
            raise ValueError("19-case source classification changed "+qid)
        clips=prior.get("fieldEvidence",[])
        if not clips or any(y.get("fieldIndex")!=i for i,y in enumerate(clips)):
            raise ValueError("Individual OCR source clips not unique "+qid)
        # A 23-case failure can occur on the stem, so the historic loop did not
        # finish rendering all choice crops. Render/pin the 4 or 5 choice
        # rectangles separately in this recovery run, rather than fabricating
        # evidence from incomplete prior OCR outputs.
        # Re-render each printed choice from original PDF page position, then
        # OCR using independent recognition modes. The original printed text
        # was read separately from the authoritative PDF screenshot.
        from repair_ocr_coordinate_46 import recognize
        words=page.get_text("words",sort=True)
        region=fitz.Rect(*geometry["clip"])
        choices_geom={}
        for w in words:
            x0,y0,x1,y1,t,*_=w
            if not (region.y0<=y0<region.y1 and region.x0+5<=x0<region.x0+150):continue
            m=re.match(r"^([1-5])[.．、)）]$",t.strip())
            if m:
                choices_geom.setdefault(int(m.group(1)),[]).append((y0,x0))
        clipped=[]
        for idx in range(1,required+1):
            locations=choices_geom.get(idx,[])
            if len(locations)!=1:raise ValueError(f"Option {idx} not unique in source geometry for {qid}: {locations}")
            y=locations[0][0]-4
            following=[positions[0][0]-4 for j,positions in choices_geom.items() if j==idx+1]
            yend=following[0] if following else region.y1
            if yend-y<=9:raise ValueError("Invalid option crop height "+qid)
            r=fitz.Rect(region.x0,y,region.x1,yend)
            f=OUT/f"{qid}-choice{idx}.png"
            page.get_pixmap(matrix=fitz.Matrix(3,3),clip=r,alpha=False).save(str(f))
            readings={str(psm):recognize(f,psm) for psm in (3,6)}
            clipped.append({"index":idx,"sourceCrop":f.name,"sourceCropSha256":digest(f.read_bytes()),
                "clip":[round(z,2) for z in r],"ocrReadingsByPsm":readings,
                "referenceTranscription":choices[idx-1],
                "ocrAgreementRequiredForPromotion":False,
                "authority":"original PDF page image visual review (not OCR majority vote)"})
        # For 5-choice source, the first four prior OCR choice regions were
        # generated by a four-option parser and cannot prove the fifth.
        # Record the source's true fifth option in a separate full-region PNG.
        special_fifth=None
        if required==5:
            extra=OUT/f"{qid}-five-option-original-region.png"
            page.get_pixmap(matrix=fitz.Matrix(3,3),clip=rect,alpha=False).save(str(extra))
            special_fifth={"sourceRegion":extra.name,"imageSha256":digest(extra.read_bytes()),
                "printedOptionCount":5,"printedFifthOption":choices[4],
                "sourceImageMethod":"original PDF full-question raster"}
        before={"question":q.get("question"),"choices":q.get("choices"),"sourcePage":q.get("sourcePage")}
        after={"question":item["question"],"choices":choices,"sourcePage":item["pdfPage"]}
        if before==after:raise ValueError("No actual source repair "+qid)
        case={"id":qid,"status":"PASS_SOURCE_ONLY","sourceExam":exam,"session":session,
              "questionNumber":num,"originalPdfPage":item["pdfPage"],
              "questionPdfSha256":pdfhash[(exam,session)],
              "originalSourceImageSha256":geometry["imageSha256"],
              "originalRegionClip":geometry["clip"],"printedOptionCount":required,
              "officialAnswerZeroBased":expected_answer,"officialAnswerPdfSha256":keysha,
              "before":before,"after":after,"printedEnglishGlossSeparate":item["englishGloss"],
              "textDeltas":[{"field":"question","edits":mutations(before["question"],after["question"])}]
                +[{"field":f"choice{i+1}","edits":mutations(a,b)}
                    for i,(a,b) in enumerate(zip(before["choices"],after["choices"]))],
              "sourceFieldImageProof":clipped,"extraFifthChoiceImageProof":special_fifth,
              "reviewEvidence":{"status":item["status"],"officialPdf":item["originalSourceUrl"],"reviewedOn":"2026-11-24"},"editorialStatus":"source-only; explanation/runtime/rights release pending"}
        revised=dict(q)
        revised.update(question=item["question"],choices=choices,sourcePage=item["pdfPage"],
            printedOptionCount=required,officialAcceptedAnswers=[expected_answer],
            answerType="singleChoice",sourceAnswerTokens=[str(expected_answer+1)],
            requiresMedia=False,mediaAuditStatus="not_required",rightsStatus="mhlw-pdl1.0-text",
            canonicalStatus="source_verified_extension",
            reviewStatus="VISUAL_ORIGINAL_PDF_19_QUESTION_SOURCE_ONLY_EXPLANATION_PENDING",
            publishable=False,releaseEligible=False,
            category="必修" if num<=25 else "一般",majorSubject=None,point=None,detail=None)
        revised["sourceEnglishGloss"]=item["englishGloss"]
        revised["audit"]={"sourcePageVisualReviewed":True,
            "allPrintedChoicesVisualReviewed":True,
            "originalChoiceCropHashesPinned":True,
            "officialKeyMatched":True,"explanationIndependentlyReviewed":False,
            "runtimeIntegrationChecked":False}
        revised["evidence"]={"sourcePdfPage":item["pdfPage"],
            "sourcePdfSha256":pdfhash[(exam,session)],
            "sourceImageSha256":geometry["imageSha256"],
            "coordinateClip":geometry["clip"],
            "auditLedger":"kangoshi-sprint/audit/ocr-psm-disagreement-23-promotion-ledger-20261124.json"}
        results.append(case);new.append(revised);edits.append(case)
    new_ids={x["id"] for x in new}
    assert len(new_ids)==len(new) and not seen&new_ids
    all_pass={x["id"]:x for x in results}
    assert set(all_pass)==expected-{x["id"] for x in media_held}
    assert len(all_pass)+len(media_held)==23
    proof={"schemaVersion":1,"sourceReviewScope":23,"newPromoted":len(new),
        "cumulativePromoted":len(all_pass),"remainingFrom23":23-len(all_pass),
        "mediaHoldCount":len(media_held),"mediaHeld":media_held,
        "newIds":sorted(new_ids),"cases":[all_pass[i] for i in sorted(all_pass)],
        "policy":"Original source PDF pixel visualization and individual OCR evidence + exact official key; source only and NOT app release"}
    PROOF.write_text(json.dumps(proof,ensure_ascii=False,indent=2)+"\n")
    previous=json.loads(DIFF.read_text())["edits"] if DIFF.exists() else []
    editmap={x["id"]:x for x in previous}
    editmap.update({x["id"]:x for x in edits})
    DIFF.write_text(json.dumps({"schemaVersion":1,"count":len(editmap),
         "edits":list(editmap.values())},ensure_ascii=False,indent=2)+"\n")
    if new:
        bank["questions"].extend(new)
        bank["questions"].sort(key=lambda x:(-x["sourceExam"],x["session"],x["questionNo"]))
        bank["count"]=len(bank["questions"])
        BANK.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
        holds["hold"]=[x for x in holds["hold"] if x["id"] not in new_ids]
        holds["count"]=len(holds["hold"])
        HOLDS.write_text(json.dumps(holds,ensure_ascii=False,indent=2)+"\n")
        m=json.loads(MANIFEST.read_text())
        m["verifiedExtension"].update(canonicalSourceVerifiedCount=bank["count"],
            canonicalSourceVerifiedTotal=720+bank["count"],remainingNotVerified=holds["count"],
            runtimeAdditionalCount=0,releaseEligibleAdditionalCount=0,
            latest23PsmDisagreementPromotion=len(new))
        MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n")
    p=json.loads(PROM.read_text())
    p["newPromoted"]=int(p.get("newPromoted",0))+len(new)
    p["newIds"]=list(p.get("newIds",[]))+sorted(new_ids)
    p["canonicalVerified"]=bank["count"]
    p["psm23SourceImageEvidence"]="kangoshi-sprint/audit/ocr-psm-disagreement-23-promotion-ledger-20261124.json"
    PROM.write_text(json.dumps(p,ensure_ascii=False,indent=2)+"\n")
    (OUT/"summary.json").write_text(json.dumps({"scope":23,"newPromoted":len(new),
        "canonical":720+bank["count"],"remaining":holds["count"],"fifthChoiceSource":"K112-AM075"},
        ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"scope":23,"newPromoted":len(new),
       "canonical":720+bank["count"],"remaining":holds["count"],"newIds":sorted(new_ids)},
       ensure_ascii=False))
if __name__=="__main__":main()
