#!/usr/bin/env python3
"""Reconstruct candidate stems and options from PDF geometric question regions.

A candidate changes ONLY when PyMuPDF and Poppler independently reproduce the
same stem and all four choices inside the same unambiguous coordinate crop.
Save original/repaired differences and rejected reasons as an audit artifact.
Never infer CMap glyphs; do not grant rights, scoring exceptions, or publication.
"""
import json, pathlib, re, subprocess, hashlib, unicodedata, collections, sys
import fitz

ROOT=pathlib.Path(__file__).resolve().parents[1]
STAGE=ROOT/"product-content/keyed-candidates"
OUT=ROOT/"audit/runs/dual-engine-20261124"
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/"scripts"))
from boundary_context_verify import _region,equivalent_shared_context
from official_answer_key_audit import parse as parse_key
from bulk_text_helpers import clean_font, norm, suspicious

def poppler_page(pdf,pg):
    cmd=["pdftotext","-f",str(pg),"-l",str(pg),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"]
    p=subprocess.run(cmd,capture_output=True,text=True,timeout=30)
    if p.returncode: raise RuntimeError("Poppler page: "+p.stderr[-180:])
    return p.stdout

def segment_poppler(text,n):
    # Unlike PDF image coordinates, Poppler's -x/-y crop on some source files
    # omitted the final choice; independently segment full page by heading numbers.
    lines=text.splitlines()
    heading=re.compile(r"^\s*(?:問\s*)?0*"+str(n)+r"(?=\s|$)")
    next_heading=re.compile(r"^\s*(?:問\s*)?0*"+str(n+1)+r"(?=\s|$)")
    starts=[i for i,x in enumerate(lines) if heading.match(x)]
    if len(starts)!=1:return None
    i=starts[0]
    stop=next((k for k in range(i+1,len(lines)) if next_heading.match(lines[k])),len(lines))
    return "\n".join(lines[i:stop])

def split_fields(raw,n):
    lines=[line.strip() for line in clean_font(raw).splitlines() if line.strip()]
    if not lines: return None,"EMPTY_CROP"
    # A question anchor may occupy a standalone line or start the stem line.
    first=re.compile(r"^(?:問\s*)?0*"+str(n)+r"(?=\s|$)")
    while lines and not first.match(lines[0]):
        lines.pop(0)
    if not lines:return None,"NUMBER_ANCHOR_NOT_IN_CROP"
    lines[0]=first.sub("",lines[0],count=1).strip()
    if not lines[0]:lines.pop(0)
    fields=[];stem=[];current=None
    # Choice labels must appear in order at line start; no missing or fifth choice.
    ch=re.compile(r"^([1-5])[.．、)）]\s*(.*)$")
    for line in lines:
        if current==4 and (line.startswith("DKIX-") or re.fullmatch(r"\d{1,3}",line)):
            break
        m=ch.match(line)
        if m:
            label=int(m.group(1))
            if label==5:return None,"FIFTH_CHOICE_PRESENT"
            if label!=len(fields)+1:return None,"CHOICE_ORDER_AMBIGUOUS"
            fields.append(m.group(2));current=label
        elif current is None:stem.append(line)
        else:fields[-1]+=line
    if len(fields)!=4 or any(not s for s in fields) or not stem:
        return None,"INCOMPLETE_STEM_OR_FOUR_CHOICES"
    # Prevent printed footer/reference and suspicious extracted characters from release.
    result={"question":"".join(stem),"choices":fields}
    if any(suspicious(x) for x in [result["question"]]+fields):
        return None,"UNRESOLVED_SOURCE_GLYPH_OR_FOOTER"
    return result,None

def equivalent_english_gloss_reorder(a,b):
    """Conservative fallback for inline English ruby/annotations with punctuation.

    Japanese, digits, brackets, all other punctuation must be exact after
    whitespace removal. ASCII periods and commas may shift position ONLY if
    their counts and the English word multiset are unchanged.
    """
    a=clean_font(a);b=clean_font(b)
    english_a=sorted(re.findall(r"[A-Za-z]+",a))
    english_b=sorted(re.findall(r"[A-Za-z]+",b))
    if not english_a or english_a!=english_b:return False
    if (a.count(".")!=b.count(".") or a.count(",")!=b.count(",")):
        return False
    stripped=lambda t:re.sub(r"\\s+","",re.sub(r"[A-Za-z.,]","",unicodedata.normalize("NFKC",t)))
    return bool(stripped(a)) and stripped(a)==stripped(b)

def main():
    verified=json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())
    skip={q["id"] for q in verified["questions"]}
    result=[];repairs=[];reasons=collections.Counter()
    summary={"checked":0,"previousVerified":len(skip),"sourceReextractPass":0,"updated":0,"notUpdated":0}
    for ex in (112,111):
      keys,keysha=parse_key(ex)
      for session in ("AM","PM"):
        path=STAGE/f"exam{ex}-{session}-draft.json"
        bank=json.loads(path.read_text())
        doc=fitz.open(pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf")
        pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf"
        poppler_cache={}
        for q in bank["questions"]:
          if q["id"] in skip:continue
          summary["checked"]+=1
          n=int(q["questionNo"]);hint=q.get("sourcePage")
          pages=range(max(1,hint-3),min(len(doc),hint+3)+1) if isinstance(hint,int) else range(1,len(doc)+1)
          candidates=[]
          diagnostics=[]
          for pg in pages:
            a,geo=_region(doc[pg-1],n,clean_font)
            if a is None:continue
            # Reject ambiguous coordinate extraction, including one page's two anchors.
            if pg not in poppler_cache:poppler_cache[pg]=poppler_page(pdf,pg)
            b=segment_poppler(poppler_cache[pg],n)
            if b is None:continue
            pa,err1=split_fields(a,n)
            pb,err2=split_fields(b,n)
            if err1 or err2:
                diagnostics.append({"pg":pg,"pymupdfError":err1,"popplerError":err2,"pymupdfSample":a[:320],"popplerSample":b[:320],"clip":geo["clip"]})
                continue
            exact_stem=norm(pa["question"])==norm(pb["question"])
            meaningful_stem,_=equivalent_shared_context(pa["question"],pb["question"])
            if not exact_stem and not meaningful_stem and not equivalent_english_gloss_reorder(pa["question"],pb["question"]):
                diagnostics.append({"pg":pg,"reason":"STEM_DIFFER","pymupdf":pa["question"][:220],"poppler":pb["question"][:220]})
                continue
            choice_checks=[equivalent_shared_context(x,y)[0] or equivalent_english_gloss_reorder(x,y) for x,y in zip(pa["choices"],pb["choices"])]
            if not all(choice_checks):
                diagnostics.append({"pg":pg,"reason":"CHOICE_DIFFER","pymupdf":pa["choices"],"poppler":pb["choices"]})
                continue
            candidates.append((pg,geo,pa,pb))
          reason=[]
          if len(candidates)!=1:reason.append("NO_UNIQUE_DUAL_ENGINE_COORDINATE_REEXTRACTION")
          if len(candidates)==1:
            pg,geo,pa,pb=candidates[0]
            official=keys.get(q["id"])
            if (not official or official.get("status")!="KEY_SINGLE"
                or official.get("rawValue")!=str((q.get("answer") if isinstance(q.get("answer"),int) else -10)+1)
                or q.get("officialKeyPdfSha256")!=keysha):
                reason.append("OFFICIAL_KEY_OR_SHA_NOT_MATCHED")
            if q.get("officialScoringStatus")!="normal":reason.append("SCORING_EXCEPTION")
            if re.search(r"図|画像|写真|別冊|心電図|グラフ|波形",pa["question"]):
                reason.append("SOURCE_MEDIA_CUE")
            if n>=91:
                # Scenario context retains separate independent gate in bulk verifier.
                pass
          if reason:
            reasons.update(reason);summary["notUpdated"]+=1
            result.append({"id":q["id"],"status":"HOLD","reasons":reason,"diagnostics":diagnostics[:2]})
            continue
          summary["sourceReextractPass"]+=1
          previous={"question":q.get("question"),"choices":q.get("choices"),"sourcePage":q.get("sourcePage"),"extractionValid":q.get("extractionValid")}
          changed=norm(previous["question"])!=norm(pb["question"]) or [norm(x) for x in previous["choices"] or []]!=[norm(x) for x in pb["choices"]] or previous["sourcePage"]!=pg
          q.update(question=pb["question"],choices=pb["choices"],sourcePage=pg,extractionValid=True)
          q["coordinateReextraction"]={"page":pg,"anchorBox":geo["anchorBox"],"clip":geo["clip"],"source":"PyMuPDF+Poppler cropped text", "sourcePdfSha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),"previousCandidateChanged":changed,"independentFieldEquality":"EXACT_JAPANESE_AND_LATIN_TOKEN_MULTISET_PLUS_FOUR_FIELD_ORDER"}
          if changed:
            summary["updated"]+=1
            repairs.append({"id":q["id"],"before":previous,"after":{"question":q["question"],"choices":q["choices"],"sourcePage":pg},"bbox":geo["clip"]})
          result.append({"id":q["id"],"status":"DUAL_ENGINE_REEXTRACTED","changed":changed,"sourcePage":pg})
        path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    report={"summary":summary,"reasons":dict(reasons),"questions":result,"repairs":repairs,
            "note":"Staged candidates only; official key/exception verified at reextract and again in bulk. No release authorization."}
    (OUT/"coordinate-reextraction-evidence.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    samples=[x for x in result if x.get("diagnostics")][:6]
    print("REEXTRACT_DIAGNOSTICS",json.dumps(samples,ensure_ascii=False)[:11000])
    print(json.dumps({"coordinateReextraction":summary,"holdReasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__":main()
