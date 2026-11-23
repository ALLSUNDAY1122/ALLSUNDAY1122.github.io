#!/usr/bin/env python3
"""Conservative 21-case image-grounded OCR-error diagnosis and source repair.

For each mismatch, re-render each original choice rectangle and collect four
independent OCR configurations. Distinguish suspected OCR character substitution
from CMap damage using original text and PDF extraction on same source page.
Only source-certify if all fields pass a full-content verification gate;
otherwise quarantine the candidate with before/after/difference evidence.
"""
import collections,difflib,hashlib,json,pathlib,re,subprocess,sys
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from repair_ocr_cmap_96 import (safe_repair,balanced_source_brackets,BAD,MEDIA,compact,strip_footer)
from repair_ocr_coordinate_46 import (normalize_ocr_field,recognize,sha)
from official_answer_key_audit import parse as official_key
from ocr_third_engine_recovery import engine_fields
from bulk_text_helpers import suspicious
BASE=ROOT/"product-content";AUD=ROOT/"audit";PDF_DIR=pathlib.Path("/tmp/kangoshi-official")
OUT=AUD/"runs/ocr-noncmap-21-20261124";OUT.mkdir(parents=True,exist_ok=True)
SOURCE=AUD/"ocr-coordinate-repair-ledger-20261124.json"
RESULT=AUD/"ocr-noncmap-repair-ledger-20261124.json"
CHANGE=BASE/"ocr-noncmap-repaired-candidates-20261124.json"
BANK=BASE/"verified-additions-20261124.json"
HOLDS=AUD/"dual-engine-hold-20261124.json"
PROM=AUD/"dual-engine-promotion-ledger-20261124.json"
MANIFEST=BASE/"manifest.json"
INDEX=AUD/"residual-geometric-source-index-20261124.json"
PROTECTED=re.compile(r"\d+(?:[.．]\d+)?|[A-Za-z]{2,}|ない|なし|未|非|無|除く|以外|不可")
def source_token(text):
    return PROTECTED.findall(compact(text))
def diff_rows(original,visual):
    a,b=compact(strip_footer(original)),compact(strip_footer(visual))
    entries=[]
    for code,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
        if code=="equal":continue
        before,after=a[i:j],b[k:l]
        entries.append({"kind":code,"old":before,"ocr":after,"at":i,
           "left":a[max(0,i-6):i],"right":a[j:j+6],
           "classification":("PDF_CMAP_CONTROL" if before and all(c in BAD for c in before)
               else "OCR_OR_SOURCE_CHARACTER_UNRESOLVED"),
           "mayChangeWithoutImageSignoff":False})
    return entries
def fields_ocr(page,crops,qid,number):
    results=[];proposal=[]
    for f in crops:
        i=f["fieldIndex"];clip=f["clip"]
        name=OUT/f"{qid}-field{i}.png"
        page.get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(*clip),alpha=False).save(str(name))
        print_hash=sha(name.read_bytes())
        if print_hash!=f["pngSha256"]:
            raise ValueError(f"ORIGINAL_COORDINATE_CROP_HASH_CHANGED {qid} {i}")
        values={m:normalize_ocr_field(recognize(name,m),i,number) for m in (6,3,4,11)}
        groups={}
        for m,(v,err) in values.items():
            if v is not None and err is None:
                groups.setdefault(compact(v),[]).append(m)
        agreed=sorted(groups.items(),key=lambda t:(-len(t[1]),t[0]))
        choice=agreed[0][0] if agreed and len(agreed[0][1])>=2 else None
        display=values[agreed[0][1][0]][0] if choice is not None else None
        results.append({"fieldIndex":i,"clip":clip,"sourceImageSha256":print_hash,
          "ocrByPsm":{str(m):{"value":v,"error":err} for m,(v,err) in values.items()},
          "consensusModes":agreed[0][1] if choice else [],
          "consensusNormalized":choice})
        proposal.append(display)
    return results,proposal
def main():
    baseline=json.loads(SOURCE.read_text())
    target=[x for x in baseline["perQuestion"] if x.get("reason")=="NOT_CMAP_ONLY_DIFFERENCE" and x.get("status")=="HOLD"]
    existing_bank=json.loads(BANK.read_text());held=json.loads(HOLDS.read_text())
    seen={x["id"] for x in existing_bank["questions"]}
    historic=json.loads(RESULT.read_text()) if RESULT.exists() else None
    original_ids=set(historic["originalTargetIds"]) if historic else {x["id"] for x in target}
    assert len(original_ids)==21,("expected 21 source-record OCR anomalies",len(original_ids))
    target=[x for x in target if x["id"] not in seen]
    assert set(x["id"] for x in target)<=original_ids
    live={x["id"] for x in held["hold"]}
    assert set(x["id"] for x in target)<=live
    drafts={}
    for e in (111,112):
        for s in ("AM","PM"):
            drafts.update({x["id"]:x for x in json.loads((BASE/f"keyed-candidates/exam{e}-{s}-draft.json").read_text())["questions"]})
    exc={x["id"] for x in json.loads((AUD/"official-scoring-exceptions-20261124.json").read_text())["exceptions"]}
    official={e:official_key(e) for e in (111,112)}
    image_index={x["id"]:x for x in json.loads(INDEX.read_text())["items"]}
    docs={(e,s):fitz.open(PDF_DIR/f"{e}-{s}.pdf") for e in (111,112) for s in ("AM","PM")}
    hashes={(e,s):sha((PDF_DIR/f"{e}-{s}.pdf").read_bytes()) for e in (111,112) for s in ("AM","PM")}
    rows=[];promotions=[];edits=[];reasons=collections.Counter()
    for prior in target:
        qid=prior["id"];q=drafts[qid];e=q["sourceExam"];s=q["session"];n=q["questionNo"]
        row={"id":qid,"exam":e,"session":s,"number":n,"status":"HOLD",
          "originalClassification":"NOT_CMAP_ONLY_DIFFERENCE"}
        def hold(reason):
            row["reason"]=reason;rows.append(row);reasons[reason]+=1
        key,keyhash=official[e];answer=q.get("answer");entry=key.get(qid)
        if (qid in exc or q.get("officialScoringStatus")!="normal" or not entry
          or entry.get("status")!="KEY_SINGLE" or not isinstance(answer,int)
          or not 0<=answer<4 or entry.get("rawValue")!=str(answer+1)
          or q.get("officialKeyPdfSha256")!=keyhash):
            hold("OFFICIAL_KEY_OR_SCORING_EXCEPTION");continue
        if n>=91:hold("SITUATION_CONTEXT_NOT_VERIFIED");continue
        if MEDIA.search(q.get("question","")):hold("SOURCE_MEDIA_REQUIRES_RIGHTS");continue
        m=image_index.get(qid)
        if not m or m.get("sourcePdfSha256")!=hashes[(e,s)]:
            hold("SOURCE_PDF_OR_REGION_HASH_MISMATCH");continue
        if m["renderedPage"]!=prior.get("sourcePage",m["renderedPage"]):
            hold("SOURCE_PDF_PAGE_CHANGED");continue
        pdf=PDF_DIR/f"{e}-{s}.pdf";page=docs[(e,s)][m["renderedPage"]-1]
        row["sourcePdfSha256"]=hashes[(e,s)];row["sourcePdfPage"]=m["renderedPage"]
        row["sourceImageSha256"]=m.get("imageSha256")
        crops=prior.get("fieldEvidence",[])
        if len(crops)!=5 or any("clip" not in r or "pngSha256" not in r for r in crops):
            hold("INDIVIDUAL_SOURCE_FIELD_IMAGES_NOT_COMPLETE");continue
        try:evidence,proposal=fields_ocr(page,crops,qid,n)
        except Exception as ex:
            row["diagnostic"]=str(ex)[:160];hold("SOURCE_IMAGE_REVERIFY_FAILED");continue
        row["fieldEvidence"]=evidence
        originals=[q.get("question","")]+(q.get("choices") or [])[:4]
        row["originalText"]={"question":q.get("question"),"choices":q.get("choices")}
        if len(originals)!=5:
            hold("ORIGINAL_FIELD_COUNT_NOT_FIVE");continue
        if any(p is None for p in proposal):
            hold("OCR_CONSENSUS_NOT_REPRODUCED");continue
        row["ocrText"]={"question":proposal[0],"choices":proposal[1:]}
        row["characterDiffs"]=[{"field":i,"edits":diff_rows(a,b)}
            for i,(a,b) in enumerate(zip(originals,proposal))]
        row["protectedTokens"]=[{"field":i,"original":source_token(x),"ocr":source_token(y)}
            for i,(x,y) in enumerate(zip(originals,proposal))]
        # Re-extract all fields from *both* independent PDF engines. If either
        # has untrusted controls/missing content, the case must stay held.
        compare={}
        for mode in ("PyMuPDF","Poppler"):
            parsed,_,error=engine_fields(page,pdf,m["renderedPage"],n,mode)
            compare[mode]={"error":error,"fields":[parsed["question"]]+parsed["choices"] if parsed else None}
        row["engineEvidence"]=compare
        if any(compare[m]["error"] for m in compare):
            hold("ONE_OR_BOTH_PDF_ENGINE_FIELDS_UNVERIFIED");continue
        a,b=compare["PyMuPDF"]["fields"],compare["Poppler"]["fields"]
        if len(a)!=5 or len(b)!=5 or any(compact(x)!=compact(y) for x,y in zip(a,b)):
            hold("TWO_PDF_ENGINES_DO_NOT_AGREE_FULL_FIELDS");continue
        # Trusted PDF text and staged content must agree on every normal
        # (non-CMap) character; OCR often repeatedly misreads Japanese words.
        checked=[];corrections=[]
        for i,(old,ocr_txt,ref) in enumerate(zip(originals,proposal,a)):
            if compact(ref)!=compact(ocr_txt):
                # If PDF/staged agree but OCR disagrees, preserve source.
                if compact(ref)==compact(strip_footer(old)):
                    checked.append(ref);continue
                hold("OCR_DISAGREES_WITH_PDF_REFERENCE");break
            ok,kind,deltas=safe_repair(old,ref)
            if not ok:
                hold("SOURCE_TO_OCR_CHANGE_NOT_CMAP_ONLY");break
            checked.append(ref)
            if kind!="UNCHANGED":
                corrections.append({"field":i,"kind":kind,"deltas":deltas})
        if row["status"]=="HOLD" and "reason" in row:continue
        if len(checked)!=5 or not corrections:
            hold("NO_VERIFIED_SOURCE_CORRECTION");continue
        if any(suspicious(x) for x in checked) or not all(balanced_source_brackets(x) for x in checked):
            hold("UNSAFE_OR_UNBALANCED_CORRECTED_GLYPHS");continue
        if any(source_token(old)!=source_token(new) for old,new in zip(originals,checked)):
            hold("NUMERIC_NEGATION_OR_LATIN_TOKEN_CHANGED");continue
        # Preserve printed option identity even when prior draft contained a
        # page footer as a fifth spurious option.
        extras=q["choices"][4:]
        if extras and not all(re.fullmatch(r"(?:\d{1,3}\s*)?DKIX-\d+-(?:前|後)H-\d+",t.strip()) for t in extras):
            hold("EXTRA_DRAFT_CHOICE_UNVERIFIED");continue
        before={"question":q["question"],"choices":q["choices"],"sourcePage":q.get("sourcePage")}
        after={"question":checked[0],"choices":checked[1:],"sourcePage":m["renderedPage"]}
        row.update(status="PROMOTED_SOURCE_ONLY",reason=None,before=before,after=after,
                   correctionEvidence=corrections,officialAnswer=answer,
                   officialKeyPdfSha256=keyhash,coordinateClip=m["clip"])
        revised=dict(q)
        revised.update(question=after["question"],choices=after["choices"],sourcePage=after["sourcePage"],
          printedOptionCount=4,sourceAnswerTokens=[str(answer+1)],
          officialAcceptedAnswers=[answer],requiresMedia=False,mediaAuditStatus="not_required",
          rightsStatus="mhlw-pdl1.0-text",publishable=False,releaseEligible=False,
          canonicalStatus="source_verified_extension",
          reviewStatus="OCR_NON_CMAP_21_SOURCE_AND_DUAL_ENGINE_VERIFIED_EXPLANATION_PENDING",
          category="必修" if n<=25 else "一般",majorSubject=None,point=None,detail=None)
        revised["audit"]={"twoPdfEnginesAllFieldsAgree":True,"ocrImageFieldsReviewed":True,
          "officialKeyMatched":True,"explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}
        revised["evidence"]={"sourcePdfPage":m["renderedPage"],"sourcePdfSha256":hashes[(e,s)],
          "sourceImageSha256":m["imageSha256"],"coordinateClip":m["clip"],
          "corrections":corrections,"auditLedger":"kangoshi-sprint/audit/ocr-noncmap-repair-ledger-20261124.json"}
        promotions.append(revised)
        edits.append({"id":qid,"before":before,"after":after,"corrections":corrections,
            "officialKeyPdfSha256":keyhash,"sourcePdfSha256":hashes[(e,s)]})
        rows.append(row);reasons["PROMOTED_SOURCE_ONLY"]+=1
    ids={x["id"] for x in promotions}
    assert len(ids)==len(promotions) and not ids&seen
    past=[x for x in historic["perQuestion"] if x["status"]=="PROMOTED_SOURCE_ONLY"] if historic else []
    past=[x for x in past if x["id"] not in ids]
    report={"schemaVersion":1,"originalTargetIds":sorted(original_ids),
      "checkedThisRun":len(target),"newlyPromoted":len(promotions),
      "cumulativePromoted":len(past)+len(promotions),
      "remaining":21-len(past)-len(promotions),
      "reasonCounts":dict(reasons),"newIds":sorted(ids),"perQuestion":past+rows,
      "safety":"Only original PDF+image SHA and exact two-engine all-field pass with protected semantic tokens; ambiguous OCR glyphs stay held; no release."}
    RESULT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    old_edits=json.loads(CHANGE.read_text()).get("edits",[]) if CHANGE.exists() else []
    all_edits={e["id"]:e for e in old_edits}
    all_edits.update({e["id"]:e for e in edits})
    CHANGE.write_text(json.dumps({"schemaVersion":1,"count":len(all_edits),"edits":list(all_edits.values())},
      ensure_ascii=False,indent=2)+"\n")
    if promotions:
        existing_bank["questions"].extend(promotions)
        existing_bank["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]))
        existing_bank["count"]=len(existing_bank["questions"])
        BANK.write_text(json.dumps(existing_bank,ensure_ascii=False,indent=2)+"\n")
        held["hold"]=[x for x in held["hold"] if x["id"] not in ids]
        held["count"]=len(held["hold"])
        HOLDS.write_text(json.dumps(held,ensure_ascii=False,indent=2)+"\n")
        m=json.loads(MANIFEST.read_text())
        m["verifiedExtension"].update(canonicalSourceVerifiedCount=existing_bank["count"],
          canonicalSourceVerifiedTotal=720+existing_bank["count"],remainingNotVerified=held["count"],
          runtimeAdditionalCount=0,releaseEligibleAdditionalCount=0,
          latestNonCmap21Promotion=len(promotions))
        MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n")
    ledger=json.loads(PROM.read_text())
    ledger["newPromoted"]=int(ledger.get("newPromoted",0))+len(promotions)
    ledger["newIds"]=list(ledger.get("newIds",[]))+sorted(ids)
    ledger["canonicalVerified"]=len(existing_bank["questions"])
    ledger["nonCmap21Proof"]="kangoshi-sprint/audit/ocr-noncmap-repair-ledger-20261124.json"
    PROM.write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+"\n")
    (OUT/"summary.json").write_text(json.dumps({"checked":len(target),"promoted":len(promotions),
       "canonical":720+existing_bank["count"],"remaining":held["count"],"reasonCounts":dict(reasons)},ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"checked":len(target),"promoted":len(promotions),
      "canonical":720+existing_bank["count"],"remaining":held["count"],
      "reasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__":main()
