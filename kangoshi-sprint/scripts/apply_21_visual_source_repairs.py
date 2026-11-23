#!/usr/bin/env python3
"""Apply individually visually confirmed source-PDF corrections for two held nurse questions.

Visual decisions are explicit in a checked-in allowlist. This script does not
infer medical words from OCR. It validates source PDF + original image + four
individually cropped choice images + independent official answer before changing
the source-only bank; records before/after and never enables publishing.
"""
import collections,hashlib,json,pathlib,re,sys
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"scripts"))
from official_answer_key_audit import parse as official_key
from repair_ocr_cmap_96 import compact
BASE=ROOT/"product-content";AUD=ROOT/"audit"
PDF=pathlib.Path("/tmp/kangoshi-official")
INPUT=AUD/"ocr-noncmap-visual-corrections-20261124.json"
PROOF=AUD/"ocr-noncmap-visual-promotion-ledger-20261124.json"
BANK=BASE/"verified-additions-20261124.json"
HOLD=AUD/"dual-engine-hold-20261124.json"
PROM=AUD/"dual-engine-promotion-ledger-20261124.json"
MANIFEST=BASE/"manifest.json"
DIFF=BASE/"ocr-noncmap-visual-repaired-candidates-20261124.json"
INDEX=AUD/"residual-geometric-source-index-20261124.json"
COORD=AUD/"ocr-coordinate-repair-ledger-20261124.json"
def sha(x):return hashlib.sha256(x).hexdigest()
def main():
    planned=json.loads(INPUT.read_text())
    original=json.loads(BANK.read_text());held=json.loads(HOLD.read_text())
    prior=json.loads(PROOF.read_text()) if PROOF.exists() else None
    assert len(planned["items"])==2
    indexed={r["id"]:r for r in json.loads(INDEX.read_text())["items"]}
    individual={r["id"]:r for r in json.loads(COORD.read_text())["perQuestion"]}
    keys={e:official_key(e) for e in (111,112)}
    drafts={}
    for e in (111,112):
      for s in ("AM","PM"):
        rows=json.loads((BASE/f"keyed-candidates/exam{e}-{s}-draft.json").read_text())["questions"]
        drafts.update({r["id"]:r for r in rows})
    already={r["id"] for r in original["questions"]}
    holds={r["id"] for r in held["hold"]}
    new=[];changes=[];evidence=[]
    for v in planned["items"]:
        qid=v["id"];q=drafts[qid];ex=q["sourceExam"];ses=q["session"];n=q["questionNo"]
        if qid in already:continue
        assert qid in holds and (ex,ses,n)==(v["exam"],v["session"],v["number"])
        assert q.get("officialScoringStatus")=="normal"
        key,keyhash=keys[ex];answer=key.get(qid);expected=v["answerZeroBased"]
        assert isinstance(expected,int) and 0<=expected<4
        assert answer is not None and answer["status"]=="KEY_SINGLE" and answer["rawValue"]==str(expected+1)
        assert q["answer"]==expected and q.get("officialKeyPdfSha256")==keyhash
        assert len(v["choices"])==4 and len(q["choices"])==4
        pdf=PDF/f"{ex}-{ses}.pdf";filehash=sha(pdf.read_bytes())
        assert filehash==v["visualSourcePdfSha256"]
        meta=indexed[qid];r=individual[qid]
        assert meta["renderedPage"]==v["pdfPage"]
        assert meta["sourcePdfSha256"]==filehash
        sourceimage=ROOT/"audit/runs/residual-geometric-images-20261124"/meta["imageFile"]
        assert sha(sourceimage.read_bytes())==meta["imageSha256"]
        assert len(r["fieldEvidence"])==5
        # Printed choices are not guessed: confirm every coordinate-cropped
        # image SHA and independent multi-PSM OCR text before permitting edits.
        for i,text in enumerate(v["choices"],1):
            proof=r["fieldEvidence"][i]
            png=ROOT/"audit/runs/ocr-coordinate-46-20261124"/proof["png"]
            assert proof["fieldIndex"]==i
            assert sha(png.read_bytes())==v["optionFieldCropsSha256"][i-1]==proof["pngSha256"]
            modes=proof.get("agreedPsmModes",[])
            assert len(modes)>=2
            assert compact(proof["normalizedByPsm"][str(modes[0])])==compact(text)
            assert compact(q["choices"][i-1])==compact(text)
        # Independently verify unambiguous legible terms on the original PDF;
        # source-page visual approval resolves punctuation and digits that
        # multiple OCR engines misread (see reviewed provenance).
        page=fitz.open(pdf)[v["pdfPage"]-1];pdf_text=page.get_text("text")
        for token in (["一次救命処置","胸骨圧迫","人工呼吸"] if n==24 else ["労働衛生","作業環境管理","作業管理"]):
            assert token in pdf_text,("PDF text anchor absent",qid,token)
        before={"question":q["question"],"choices":q["choices"],"sourcePage":q.get("sourcePage")}
        after={"question":v["question"],"choices":v["choices"],"sourcePage":v["pdfPage"]}
        assert before!=after
        row={"id":qid,"status":"ORIGINAL_PDF_PAGE_VISUALLY_VERIFIED_SOURCE_ONLY",
             "before":before,"after":after,
             "officialAnswerZeroBased":expected,"officialKeyPdfSha256":keyhash,
             "sourcePdfSha256":filehash,"sourceImageSha256":meta["imageSha256"],
             "sourcePdfPage":v["pdfPage"],"coordinateClip":meta["clip"],
             "originalSourceUrl":planned["sourceUrl"],
             "fourOptionCropHashes":v["optionFieldCropsSha256"],
             "visualFindings":v["pageVisualFindings"],
             "reviewScope":"Original source PDF image reviewed; no explanation/runtime or release approval"}
        revised=dict(q)
        revised.update(question=v["question"],choices=v["choices"],sourcePage=v["pdfPage"],
            printedOptionCount=4,officialAcceptedAnswers=[expected],
            sourceAnswerTokens=[str(expected+1)],canonicalStatus="source_verified_extension",
            requiresMedia=False,mediaAuditStatus="not_required",rightsStatus="mhlw-pdl1.0-text",
            reviewStatus="ORIGINAL_PDF_VISUAL_NONCMAP_VERIFIED_EXPLANATION_PENDING",
            publishable=False,releaseEligible=False,
            category="必修" if n<=25 else "一般",majorSubject=None,point=None,detail=None)
        revised["audit"]={"originalPdfPageVisualTextReviewed":True,
            "fourPrintedOptionsCoordinateAndOcrMatched":True,"officialKeyMatched":True,
            "explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}
        revised["evidence"]={"sourcePdfPage":v["pdfPage"],"sourcePdfSha256":filehash,
            "sourceImageSha256":meta["imageSha256"],"coordinateClip":meta["clip"],
            "auditLedger":"kangoshi-sprint/audit/ocr-noncmap-visual-promotion-ledger-20261124.json",
            "before":before,"manualImageFindings":v["pageVisualFindings"]}
        new.append(revised);evidence.append(row);changes.append(row)
    ids={x["id"] for x in new}
    assert len(ids)==len(new) and not ids.intersection(already)
    previous=[x for x in prior["items"] if x["id"] not in ids] if prior else []
    result={"schemaVersion":1,"visualVerifiedScope":2,"newPromoted":len(new),
        "cumulativePromoted":len(previous)+len(new),
        "remainingFrom2":2-len(previous)-len(new),
        "newIds":sorted(ids),"items":previous+evidence,
        "releaseEligible":0}
    PROOF.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    existing_changes=json.loads(DIFF.read_text())["edits"] if DIFF.exists() else []
    prior_by={x["id"]:x for x in existing_changes}
    prior_by.update({x["id"]:x for x in changes})
    DIFF.write_text(json.dumps({"schemaVersion":1,"count":len(prior_by),
        "edits":list(prior_by.values())},ensure_ascii=False,indent=2)+"\n")
    if new:
        original["questions"].extend(new)
        original["questions"].sort(key=lambda x:(-x["sourceExam"],x["session"],x["questionNo"]))
        original["count"]=len(original["questions"])
        BANK.write_text(json.dumps(original,ensure_ascii=False,indent=2)+"\n")
        held["hold"]=[x for x in held["hold"] if x["id"] not in ids]
        held["count"]=len(held["hold"])
        HOLD.write_text(json.dumps(held,ensure_ascii=False,indent=2)+"\n")
        manifest=json.loads(MANIFEST.read_text())
        manifest["verifiedExtension"].update(canonicalSourceVerifiedCount=original["count"],
            canonicalSourceVerifiedTotal=720+original["count"],
            remainingNotVerified=held["count"],runtimeAdditionalCount=0,
            releaseEligibleAdditionalCount=0,latestVisualNonCmapPromotion=len(new))
        MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    promotion=json.loads(PROM.read_text())
    promotion["newPromoted"]=int(promotion.get("newPromoted",0))+len(new)
    promotion["newIds"]=list(promotion.get("newIds",[]))+sorted(ids)
    promotion["canonicalVerified"]=original["count"]
    promotion["nonCmapVisualProof"]="kangoshi-sprint/audit/ocr-noncmap-visual-promotion-ledger-20261124.json"
    PROM.write_text(json.dumps(promotion,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"newVisuallyConfirmed":len(new),"canonical":720+original["count"],
       "remaining":held["count"],"ids":sorted(ids)},ensure_ascii=False))
if __name__=="__main__":main()
