#!/usr/bin/env python3
"""Repair source CMap omissions in 96 held records using image-pinned OCR evidence.

Never correct unanchored ordinary Japanese glyphs from OCR. A repair requires:
- verified 2x official source image + PDF hash,
- 2 OCR renderings agree on each whole text field,
- only known CMap/control gaps or terminal page footer changed,
- all protected source numbers, negations and Latin words retained,
- answer key independently re-read and no scoring exception/media/scenario,
- original/repair text + hashes stored before source-only promotion.
Unresolved cases are saved as detailed holds; publication always blocked.
"""
import collections,difflib,hashlib,json,pathlib,re,subprocess,sys,unicodedata
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from official_answer_key_audit import parse as official_key
from boundary_context_verify import _region
from bulk_text_helpers import clean_font
from ocr_third_engine_recovery import norm
BASE=ROOT/"product-content"
AUDIT=ROOT/"audit"
DOCS=pathlib.Path("/tmp/kangoshi-official")
IMG=ROOT/"audit/runs/residual-geometric-images-20261124"
OUT=ROOT/"audit/runs/ocr-cmap-repair-20261124"
OUT.mkdir(parents=True,exist_ok=True)
REPAIRED=BASE/"ocr-repaired-candidates-20261124.json"
PROOF=AUDIT/"ocr-cmap-repair-ledger-20261124.json"
EXIST=BASE/"verified-additions-20261124.json"
HOLD=AUDIT/"dual-engine-hold-20261124.json"
PROM=AUDIT/"dual-engine-promotion-ledger-20261124.json"
MANIFEST=BASE/"manifest.json"
SOURCE=AUDIT/"residual-geometric-source-index-20261124.json"
DEEP=AUDIT/"ocr-category-deep-review-20261124.json"
BAD=set("!ïñèêçâ¹¼઄\u008d\u008f\u000e\u000f\u001f\ufffd")
BAD.update(chr(i) for i in range(0,32) if i not in (9,10,13))
FOOTER=re.compile(r"\s*(?:\d{1,3}\s+)?DKIX-\d+-(?:前|後)H-\d+\s*$")
MEDIA=re.compile("図(?:を|に|中|で|の|表)|画像|写真|別冊|模式図|エックス線写真|心電図を|波形を|グラフ")
PROTECTED=re.compile(r"\d+(?:\.\d+)?|[A-Za-z]{2,}|ない|なし|以外|除く|未|無|非|不可")
CHOICE=re.compile(r"^\s*([1-5])[.．、)）\s]\s*(.*)$")
HEADING=re.compile(r"^\s*(?:問\s*)?(\d{1,3})\s*(.*)$")

def compact(t):
    s=unicodedata.normalize("NFKC",str(t))
    s=re.sub(r"\s+","",s)
    return s.replace("～","~").replace("〜","~").replace("−","-").replace("‐","-")
def strip_footer(t):
    return FOOTER.sub("",str(t)).rstrip()
def ocr(png,psm):
    cmd=["tesseract",str(png),"stdout","-l","jpn+eng","--psm",str(psm)]
    p=subprocess.run(cmd,capture_output=True,text=True,timeout=65)
    if p.returncode:raise RuntimeError(p.stderr[-250:])
    return p.stdout
def parse_ocr(text,number):
    lines=[x.strip() for x in text.splitlines() if x.strip()]
    if not lines:return None,"NO_OCR_TEXT"
    start=None
    for i,line in enumerate(lines):
        m=HEADING.match(line)
        if m and int(m.group(1))==number:
            start=i;lines[i]=m.group(2);break
    if start is None:return None,"OCR_QUESTION_NUMBER_NOT_FOUND"
    lines=lines[start:]
    options=[];stem=[];current=None
    for line in lines:
        m=CHOICE.match(line)
        if m:
            k=int(m.group(1))
            if k!=len(options)+1:return None,"OCR_CHOICES_NON_SEQUENTIAL"
            options.append(m.group(2));current=k
        elif current is None:stem.append(line)
        else:options[-1]+=line
    if len(options) not in (4,5) or not stem or any(not c for c in options):
        return None,"OCR_UNABLE_TO_SEGMENT_ALL_CHOICES"
    options[-1]=strip_footer(options[-1])
    return [ "".join(stem)]+options,None
def safe_repair(old,new):
    old=compact(strip_footer(old));new=compact(strip_footer(new))
    if not old or not new:return False,"EMPTY_FIELD",[]
    if old==new:return True,"UNCHANGED",[]
    sm=difflib.SequenceMatcher(None,old,new,autojunk=False)
    diffs=[]
    for tag,i,j,k,l in sm.get_opcodes():
        if tag=="equal":continue
        before=old[i:j];after=new[k:l]
        # No ungrounded OCR substitutions of real clinical text; only clear
        # existing CMap placeholders and the printed characters replacing them.
        if not before or not all(ch in BAD for ch in before):
            return False,"DIFFERENCE_NOT_EXCLUSIVELY_CMAP_GLYPHS",diffs
        if not after or len(after)>max(5,4*len(before)):
            return False,"OCR_REPLACEMENT_NOT_LOCAL",diffs
        if any(x in BAD for x in after):return False,"REPLACEMENT_UNSAFE",diffs
        if i<2 or j>len(old)-2:return False,"INSUFFICIENT_BILATERAL_CONTEXT",diffs
        diffs.append({"at":i,"before":before,"after":after,
            "leftAnchor":old[max(0,i-5):i],"rightAnchor":old[j:j+5]})
    if not diffs:return False,"NO_CMAP_DELTA",[]
    if len(diffs)>4:return False,"TOO_MANY_UNTRUSTED_CMAP_GAPS",diffs
    # All protected existing tokens outside placeholders must survive intact.
    old_safe="".join(" " if x in BAD else x for x in old)
    originals=PROTECTED.findall(old_safe)
    afters=PROTECTED.findall(new)
    cursor=0
    for t in originals:
        try:idx=afters.index(t,cursor)
        except ValueError:return False,"PROTECTED_NUMBER_NEGATION_OR_MEDICAL_TOKEN_CHANGED",diffs
        cursor=idx+1
    return True,"CMAP_ONLY_ANCHORED_GAP",diffs
def main():
    original=json.loads(EXIST.read_text())
    holds=json.loads(HOLD.read_text())
    deep=json.loads(DEEP.read_text())
    indexed={x["id"]:x for x in json.loads(SOURCE.read_text())["items"]}
    excluded={x["id"] for x in json.loads((AUDIT/"official-scoring-exceptions-20261124.json").read_text())["exceptions"]}
    target={r["id"] for r in deep["records"] if r["category"]=="NO_EXACT_OCR_AND_ENGINE_FULL_FIELD_MATCH"}
    assert len(target)==96,("Expected original 96",len(target))
    draft={}
    for ex in (111,112):
      for ses in ("AM","PM"):
        p=BASE/f"keyed-candidates/exam{ex}-{ses}-draft.json"
        data=json.loads(p.read_text())
        draft.update({q["id"]:q for q in data["questions"]})
    keymaps={ex:official_key(ex) for ex in (111,112)}
    pdfs={(ex,ses):DOCS/f"{ex}-{ses}.pdf" for ex in (111,112) for ses in ("AM","PM")}
    filesha={k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in pdfs.items()}
    result=[];promoted=[];candidate_edits=[];stats=collections.Counter()
    canonical_ids={q["id"] for q in original["questions"]}
    active_ids={q["id"] for q in holds["hold"]}
    assert target<=active_ids
    for qid in sorted(target):
        q=draft[qid];ex=q["sourceExam"];ses=q["session"];n=q["questionNo"]
        row={"id":qid,"status":"HOLD","reason":None,"sourceExam":ex,"session":ses,"number":n}
        def deny(reason):
            row["reason"]=reason;stats[reason]+=1;result.append(row)
        if qid in canonical_ids:deny("ALREADY_CANONICAL");continue
        key,keysha=keymaps[ex];entry=key.get(qid);answer=q.get("answer")
        if (qid in excluded or q.get("officialScoringStatus")!="normal"
            or not entry or entry.get("status")!="KEY_SINGLE"
            or not isinstance(answer,int) or not 0<=answer<4
            or str(answer+1)!=entry.get("rawValue")
            or q.get("officialKeyPdfSha256")!=keysha):
            deny("OFFICIAL_KEY_OR_SCORING_EXCEPTION");continue
        if n>=91:deny("SCENARIO_PASSAGE_UNVERIFIED");continue
        if MEDIA.search(q.get("question","")):deny("MEDIA_REQUIRES_SEPARATE_GATE");continue
        meta=indexed.get(qid)
        if not meta or meta.get("status")!="UNIQUE_QUESTION_NUMBER_ANCHOR_NOT_TEXT_CERTIFIED":
            deny("NO_UNIQUE_IMAGE_GEOMETRY");continue
        pdf=pdfs[(ex,ses)]
        if meta.get("sourcePdfSha256")!=filesha[(ex,ses)]:
            deny("PDF_SHA_MISMATCH");continue
        image=IMG/meta["imageFile"]
        if not image.exists() or hashlib.sha256(image.read_bytes()).hexdigest()!=meta["imageSha256"]:
            deny("SOURCE_IMAGE_SHA_MISMATCH");continue
        row["sourcePdfSha256"]=filesha[(ex,ses)]
        row["sourceImageSha256"]=meta["imageSha256"]
        row["sourcePage"]=meta["renderedPage"]
        row["coordinateClip"]=meta["clip"]
        try:
            a=ocr(image,6)
            b=ocr(image,3)
        except Exception as exc:
            deny("OCR_ERROR");row["detail"]=str(exc)[:100];continue
        row["ocrPsm6Sha256"]=hashlib.sha256(a.encode()).hexdigest()
        row["ocrPsm3Sha256"]=hashlib.sha256(b.encode()).hexdigest()
        (OUT/f"{qid}-psm6.txt").write_text(a,encoding="utf8")
        (OUT/f"{qid}-psm3.txt").write_text(b,encoding="utf8")
        fields_a,err_a=parse_ocr(a,n)
        fields_b,err_b=parse_ocr(b,n)
        if err_a or err_b:
            row["ocrSegmentation"]={"psm6":err_a,"psm3":err_b}
            deny("OCR_FIELD_SEGMENTATION_FAILED");continue
        if len(fields_a)!=len(fields_b) or any(compact(x)!=compact(y) for x,y in zip(fields_a,fields_b)):
            row["ocrSegmentation"]={"psm6Count":len(fields_a),"psm3Count":len(fields_b)}
            deny("INDEPENDENT_OCR_RENDERINGS_FIELD_DISAGREE");continue
        if len(fields_a)!=5 or len(q.get("choices") or [])<4:
            deny("PRINTED_CHOICES_NOT_FOUR");continue
        originals=[q.get("question","")]+q["choices"][:4]
        if len(q["choices"])>4:
            extras=q["choices"][4:]
            if not all(re.fullmatch(r"(?:\d{1,3}\s*)?DKIX-\d+-(?:前|後)H-\d+",x.strip()) for x in extras):
                deny("EXTRA_OPTION_UNRESOLVED");continue
        comparisons=[safe_repair(o,v) for o,v in zip(originals,fields_a)]
        row["fieldChecks"]=[{"index":i,"pass":ok,"reason":why,"deltas":d} for i,(ok,why,d) in enumerate(comparisons)]
        if not all(z[0] for z in comparisons):
            deny("OCR_CMAP_ONLY_FULL_FIELD_GATE_FAILED");continue
        new_text={"question":fields_a[0],"choices":fields_a[1:]}
        if any(ch in BAD for f in [new_text["question"]]+new_text["choices"] for ch in f):
            deny("UNRESOLVED_OCR_BAD_GLYPH");continue
        # Full exact OCR fields from two renderings must be identical and
        # original unaffected glyphs must be identical; this avoids replacing
        # medicinal terminology on one noisy OCR pass.
        before={"question":q["question"],"choices":q["choices"],"sourcePage":q.get("sourcePage")}
        after={**new_text,"sourcePage":meta["renderedPage"]}
        if before==after:
            deny("NO_ACTUAL_EDIT");continue
        row.update(status="REPAIRED_SOURCE_ONLY",reason=None,before=before,after=after)
        candidate_edits.append({"id":qid,"before":before,"after":after,
              "sourcePdfSha256":row["sourcePdfSha256"],"sourceImageSha256":row["sourceImageSha256"],
              "ocrPsm6Sha256":row["ocrPsm6Sha256"],"ocrPsm3Sha256":row["ocrPsm3Sha256"],
              "fieldChecks":row["fieldChecks"]})
        revised=dict(q)
        revised.update(question=new_text["question"],choices=new_text["choices"],
            sourcePage=meta["renderedPage"],printedOptionCount=4,
            sourceAnswerTokens=[str(answer+1)],officialAcceptedAnswers=[answer],
            requiresMedia=False,mediaAuditStatus="not_required",
            rightsStatus="mhlw-pdl1.0-text",publishable=False,releaseEligible=False,
            canonicalStatus="source_verified_extension",
            reviewStatus="OCR_IMAGE_PINNED_CMAP_ONLY_REPAIRED_EXPLANATION_PENDING",
            category="必修" if n<=25 else "一般",majorSubject=None,point=None,detail=None)
        revised["audit"]={"sourceImageOcrPsm6Matched":True,"sourceImageOcrPsm3Matched":True,
            "allChoicesImageOcrMatched":True,"officialKeyMatched":True,
            "explanationIndependentlyReviewed":False,"runtimeIntegrationChecked":False}
        revised["evidence"]={"sourcePdfPage":meta["renderedPage"],
            "sourcePdfSha256":row["sourcePdfSha256"],"sourceImageSha256":row["sourceImageSha256"],
            "ocrPsm6Sha256":row["ocrPsm6Sha256"],"ocrPsm3Sha256":row["ocrPsm3Sha256"],
            "coordinateClip":meta["clip"],"corrections":row["fieldChecks"],
            "auditLedger":"kangoshi-sprint/audit/ocr-cmap-repair-ledger-20261124.json"}
        promoted.append(revised)
        result.append(row);stats["REPAIRED_SOURCE_ONLY"]+=1
    ids={q["id"] for q in promoted}
    assert len(ids)==len(promoted) and not (ids&canonical_ids)
    assert len(result)==96
    report={"schemaVersion":1,"scope":96,"repairedCount":len(promoted),
            "promotedSourceOnlyCount":len(promoted),"remainingFrom96":96-len(promoted),
            "reasonCounts":dict(stats),"editedIds":sorted(ids),"perQuestion":result,
            "validation":"Two image OCR PSM renderings full five fields; CMap-only original gap modifications; original PDF/image hashes; single official answer; no media/scenarios; not a product release."}
    PROOF.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    REPAIRED.write_text(json.dumps({"schemaVersion":1,"count":len(candidate_edits),
        "edits":candidate_edits},ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    if promoted:
        original["questions"].extend(promoted)
        original["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]))
        original["count"]=len(original["questions"])
        EXIST.write_text(json.dumps(original,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
        holds["hold"]=[h for h in holds["hold"] if h["id"] not in ids]
        holds["count"]=len(holds["hold"])
        HOLD.write_text(json.dumps(holds,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
        m=json.loads(MANIFEST.read_text())
        m["verifiedExtension"].update(canonicalSourceVerifiedCount=original["count"],
            canonicalSourceVerifiedTotal=720+original["count"],
            remainingNotVerified=holds["count"],lastOcrCmapRepairedCount=len(promoted))
        MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    p=json.loads(PROM.read_text())
    p["newPromoted"]=int(p.get("newPromoted",0))+len(promoted)
    p["newIds"]=list(p.get("newIds",[]))+sorted(ids)
    p["canonicalVerified"]=len(original["questions"])
    p["ocrCmapRepairProof"]="kangoshi-sprint/audit/ocr-cmap-repair-ledger-20261124.json"
    PROM.write_text(json.dumps(p,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    print(json.dumps({"sourceCanonical":720+len(original["questions"]),
        "newlyRepairedAndPromoted":len(promoted),"holds":len(holds["hold"]),
        "repairReasons":dict(stats)},ensure_ascii=False))
if __name__=="__main__":main()
