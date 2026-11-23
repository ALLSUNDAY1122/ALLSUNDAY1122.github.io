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
from boundary_context_verify import _region
from official_answer_key_audit import parse as parse_key
from bulk_text_helpers import clean_font, norm, suspicious

def crop_poppler(pdf,pg,rect):
    # Poppler's -x/-y/-W/-H use 72-dpi output image coordinates; PDF is 72pt.
    x0,y0,x1,y1=rect
    cmd=["pdftotext","-f",str(pg),"-l",str(pg),"-r","72",
         "-x",str(max(0,int(x0))),"-y",str(max(0,int(y0))),
         "-W",str(max(1,int(x1-x0)+2)),"-H",str(max(1,int(y1-y0)+2)),
         "-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"]
    p=subprocess.run(cmd,capture_output=True,text=True,timeout=30)
    if p.returncode: raise RuntimeError("Poppler crop: "+p.stderr[-180:])
    return p.stdout

def split_fields(raw,n):
    lines=[line.strip() for line in clean_font(raw).splitlines() if line.strip()]
    if not lines: return None,"EMPTY_CROP"
    # A question anchor may occupy a standalone line or start the stem line.
    first=re.compile(r"^(?:問\s*)?0*"+str(n)+r"(?:[\s.．。]|$)")
    while lines and not first.match(lines[0]):
        lines.pop(0)
    if not lines:return None,"NUMBER_ANCHOR_NOT_IN_CROP"
    lines[0]=first.sub("",lines[0],count=1).strip()
    if not lines[0]:lines.pop(0)
    fields=[];stem=[];current=None
    # Choice labels must appear in order at line start; no missing or fifth choice.
    ch=re.compile(r"^([1-5])[.．、)）]\s*(.*)$")
    for line in lines:
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
        for q in bank["questions"]:
          if q["id"] in skip:continue
          summary["checked"]+=1
          n=int(q["questionNo"]);hint=q.get("sourcePage")
          pages=range(max(1,hint-3),min(len(doc),hint+3)+1) if isinstance(hint,int) else range(1,len(doc)+1)
          candidates=[]
          for pg in pages:
            a,geo=_region(doc[pg-1],n,clean_font)
            if a is None:continue
            # Reject ambiguous coordinate extraction, including one page's two anchors.
            b=crop_poppler(pdf,pg,geo["clip"])
            pa,err1=split_fields(a,n)
            pb,err2=split_fields(b,n)
            if err1 or err2:continue
            if norm(pa["question"])!=norm(pb["question"]):continue
            if any(norm(x)!=norm(y) for x,y in zip(pa["choices"],pb["choices"])):continue
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
            result.append({"id":q["id"],"status":"HOLD","reasons":reason})
            continue
          summary["sourceReextractPass"]+=1
          previous={"question":q.get("question"),"choices":q.get("choices"),"sourcePage":q.get("sourcePage"),"extractionValid":q.get("extractionValid")}
          changed=norm(previous["question"])!=norm(pa["question"]) or [norm(x) for x in previous["choices"] or []]!=[norm(x) for x in pa["choices"]] or previous["sourcePage"]!=pg
          q.update(question=pa["question"],choices=pa["choices"],sourcePage=pg,extractionValid=True)
          q["coordinateReextraction"]={"page":pg,"anchorBox":geo["anchorBox"],"clip":geo["clip"],"source":"PyMuPDF+Poppler cropped text", "sourcePdfSha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),"previousCandidateChanged":changed}
          if changed:
            summary["updated"]+=1
            repairs.append({"id":q["id"],"before":previous,"after":{"question":q["question"],"choices":q["choices"],"sourcePage":pg},"bbox":geo["clip"]})
          result.append({"id":q["id"],"status":"DUAL_ENGINE_REEXTRACTED","changed":changed,"sourcePage":pg})
        path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    report={"summary":summary,"reasons":dict(reasons),"questions":result,"repairs":repairs,
            "note":"Staged candidates only; official key/exception verified at reextract and again in bulk. No release authorization."}
    (OUT/"coordinate-reextraction-evidence.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"coordinateReextraction":summary,"holdReasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__":main()
