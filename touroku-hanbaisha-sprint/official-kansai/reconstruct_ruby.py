#!/usr/bin/env python3
"""Only certify one-to-one PDF glyph / detached reading / application ruby alignment.
Uncertain locations, repeated ideographs, alternate line breaks or other holds stay HOLD.
"""
import argparse,collections,hashlib,json,re,unicodedata
from pathlib import Path
from auto_diff_pdf import B,download,norm
from geometry_second_gate import first_question_clip

KANJI=re.compile(r"^[\u3400-\u9fff々]$")
ISOLATED=lambda s:re.compile(r"(?m)^[ \t]*"+re.escape(s)+r"[ \t]*$")
def chars_from_pdf(doc,clips):
    found=[]
    for pageidx,rect in clips:
        for block in doc[pageidx].get_text("rawdict",clip=rect)["blocks"]:
            for line in block.get("lines",[]):
                for span in line.get("spans",[]):
                    for char in span.get("chars",[]):
                        val=char.get("c","")
                        if val and KANJI.fullmatch(val):
                            found.append({"char":val,"bbox":char["bbox"],"page":pageidx+1})
    return found
def pdf_exact_glyph(ruby,chars):
    """Require a single near glyph horizontally and below reading; no line-wide guessed base."""
    rx0,ry0,rx1,ry1=ruby["rubyBBox"]
    cx=(rx0+rx1)/2
    choices=[]
    for glyph in chars:
        if glyph["page"]!=ruby["page"]:continue
        x0,y0,x1,y1=glyph["bbox"]
        dy=y0-ry1
        gx=(x0+x1)/2
        if not -1.5<=dy<=22:continue
        if abs(gx-cx)>max(4.1,(x1-x0)*0.55):continue
        choices.append((abs(gx-cx)+abs(dy-4)*0.12,glyph))
    choices.sort(key=lambda x:x[0])
    if len(choices)!=1:return None,"GLYPH_AMBIGUOUS" if choices else "NO_GLYPH_UNDER_RUBY"
    glyph=choices[0][1]
    if glyph["char"] not in ruby["baseText"]:return None,"PDF_SPAN_GLYPH_MISMATCH"
    return glyph,None
def place_one(text,kanji,reading):
    # Do not transform arbitrary kana inside words; isolated reading line only.
    lines=list(ISOLATED(reading).finditer(text))
    if len(lines)!=1:return None,"DETACHED_RUBY_LINE_NOT_UNIQUE"
    if text.count(kanji)!=1:return None,"KANJI_OCCURRENCE_NOT_UNIQUE"
    start,end=lines[0].span()
    stripped=text[:start]+text[end:]
    offset=stripped.find(kanji)
    if offset<0:return None,"GLYPH_MISSING_AFTER_STRIPPING"
    if norm(stripped) != norm(text[:start]+text[end:]):raise RuntimeError("invariant")
    return {"clean":stripped,"offset":offset},None
def reconstruct(question,geometry):
    fields=[question["question"]]+question["choices"]
    if not all(isinstance(s,str) for s in fields):return None,["UNPARSED_CANDIDATE"]
    association=geometry.get("ruby") or {}
    if association.get("status")!="ASSOCIATED_SOURCE_ONLY":
        return None,["RUBY_SOURCE_ASSOCIATION_INCONCLUSIVE"]
    return fields,None
def run(year):
    base=json.loads((B/f"GEOMETRY_AUDIT_{year}.json").read_text())
    prior=json.loads((B/f"AUTO_DIFF_{year}.json").read_text())
    candidate_file=B/f"QUESTIONS_{year}_APP_CANDIDATE.json"
    data=json.loads(candidate_file.read_text())["questions"]
    source=json.loads((B/"SOURCES_2022_2026.json").read_text())
    metadata=next(x for x in source["years"] if x["year"]==year)
    sha=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    docs={}
    for half,url in (("first_half",metadata["question_pdf_first_half"]),("second_half",metadata["question_pdf_second_half"])):
        docs[half]=download(url,B/f".tmp_{year}_{half}.pdf",next(x["sha256"] for x in sha if x["half"]==half))
    records=[];counts=collections.Counter()
    for q,old in zip(data,base["questions"]):
        if q["id"]!=old["id"]:raise RuntimeError("out-of-order IDs")
        result={"id":q["id"],"year":year,"status":"NOT_RUBY_TARGET","reasons":[],"placements":[]}
        if "RUBY_RENDER_NOT_CERTIFIED" not in old["reasons"]:
            records.append(result);continue
        # All other geometric holds must also be resolved before ruby promotion.
        blockers=[r for r in old["reasons"] if r!="RUBY_RENDER_NOT_CERTIFIED"]
        if blockers:
            result.update(status="HOLD",reasons=blockers+["OTHER_LAYOUT_HOLD"])
            counts.update(result["reasons"]);records.append(result);continue
        half="first_half" if q["questionNo"]<=60 else "second_half"
        doc=docs[half];clips=first_question_clip(doc,None,q)
        if not clips:
            result.update(status="HOLD",reasons=["SOURCE_QUESTION_CLIP_AMBIGUOUS"])
            counts.update(result["reasons"]);records.append(result);continue
        chars=chars_from_pdf(doc,clips)
        ruby=old.get("ruby") or {}
        assocs=ruby.get("associations",[])
        if not assocs or ruby.get("issues"):
            result.update(status="HOLD",reasons=["SOURCE_RUBY_ASSOCIATIONS_INCOMPLETE"])
            counts.update(result["reasons"]);records.append(result);continue
        fields=[q["question"]]+q["choices"]
        if not all(isinstance(s,str) for s in fields):
            result.update(status="HOLD",reasons=["CANDIDATE_FIELD_UNPARSED"])
            counts.update(result["reasons"]);records.append(result);continue
        placements=[];errors=[]
        for a in assocs:
            glyph,error=pdf_exact_glyph(a,chars)
            if error:
                errors.append(error);continue
            kanji=glyph["char"];reading=a["ruby"]
            matches=[]
            for index,text in enumerate(fields):
                placement,reason=place_one(text,kanji,reading)
                if placement:matches.append((index,placement))
            if len(matches)!=1:
                errors.append("FIELD_ANCHOR_NOT_UNIQUE")
                continue
            index,placement=matches[0]
            placements.append({"fieldIndex":index,"kanji":kanji,"reading":reading,
                "pdfPage":glyph["page"],"rubyBBox":a["rubyBBox"],
                "glyphBBox":[round(x,2) for x in glyph["bbox"]],
                "sourceText":a["baseText"]})
        if len(placements)!=len(assocs) or len({p["fieldIndex"] for p in placements})!=len(placements):
            errors.append("MULTIPLE_RUBIES_SAME_FIELD_REQUIRES_ORDERING")
        if not errors:
            enriched=[]
            for i,original in enumerate(fields):
                placements_this=[p for p in placements if p["fieldIndex"]==i]
                if not placements_this:
                    enriched.append([{"text":original}]);continue
                p=placements_this[0];strip,reason=place_one(original,p["kanji"],p["reading"])
                if reason:errors.append(reason);break
                cleaned=strip["clean"];idx=strip["offset"]
                if cleaned.count(p["kanji"])!=1:errors.append("GLYPH_DUPLICATE_AFTER_CLEAN");break
                parts=[{"text":cleaned[:idx]},{"rubyBase":p["kanji"],"rubyText":p["reading"],
                       "sourcePage":p["pdfPage"]},{"text":cleaned[idx+len(p["kanji"]):]}]
                if "".join(v.get("text",v.get("rubyBase","")) for v in parts)!=cleaned:
                    errors.append("RICH_PARTS_DO_NOT_RECONSTRUCT");break
                enriched.append(parts)
            if not errors:
                result.update(status="RUBY_PASS",reasons=[],placements=placements,
                              questionParts=enriched[0],choicesParts=enriched[1:],
                              proof="one-to-one matching PDF char bbox and unique candidate standalone reading -> DOM ruby")
        if errors:
            result.update(status="HOLD",reasons=sorted(set(errors)),placements=placements)
            counts.update(result["reasons"])
        records.append(result)
    for doc in docs.values():doc.close()
    passed=sum(x["status"]=="RUBY_PASS" for x in records)
    output={"year":year,"total":120,
            "target":sum("RUBY_RENDER_NOT_CERTIFIED" in x["reasons"] for x in base["questions"]),
            "rubyPass":passed,"rubyHold":sum(x["status"]=="HOLD" for x in records),
            "reasonCounts":dict(counts),
            "candidateGitBlob":prior["candidateGitBlob"],"geoEvidence":f"GEOMETRY_AUDIT_{year}.json",
            "records":records,
            "restriction":"Only unique glyph bbox and one isolated kana line in one app field pass. Other layout issues cannot be overridden."}
    (B/f"RUBY_RECON_{year}.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"targets":output["target"],"PASS":passed,"HOLD":output["rubyHold"],"reasons":dict(counts)},ensure_ascii=False))
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--year",type=int,choices=range(2022,2027),required=True)
    run(parser.parse_args().year)
