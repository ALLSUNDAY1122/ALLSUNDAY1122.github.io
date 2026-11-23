#!/usr/bin/env python3
"""Additional conservative recovery for duplicate kanji, using PDF appearance order.

Never use ordinal matching unless PDF/candidate occurrence cardinalities agree,
ruby strings can be assigned bijectively, and all unrelated geometry holds are absent.
"""
import argparse,collections,json,re
from auto_diff_pdf import B,download,norm
from geometry_second_gate import first_question_clip
from reconstruct_ruby import chars_from_pdf, pdf_exact_glyph, ISOLATED

def candidate_parts(fields,assocs,chars):
    # Keep all reading lines anchored to a single field; no synthetic reading guesses.
    placements=[];errors=[]
    for assoc in assocs:
        glyph,err=pdf_exact_glyph(assoc,chars)
        if err:
            errors.append(err);continue
        read=assoc["ruby"];character=glyph["char"]
        fields_with_read=[i for i,f in enumerate(fields) if ISOLATED(read).search(f)]
        if len(fields_with_read)!=1:
            errors.append("RUBY_FIELD_NOT_UNIQUE");continue
        i=fields_with_read[0]
        placements.append({"field":i,"ruby":read,"kanji":character,"glyph":glyph,
                           "pdfPage":glyph["page"],"rubyBBox":assoc["rubyBBox"]})
    if errors or len(placements)!=len(assocs):
        return None,sorted(set(errors+["ANCHOR_NOT_BIJECTIVE"]))
    enriched=[]
    for i,original in enumerate(fields):
        related=[p for p in placements if p["field"]==i]
        if not related:
            enriched.append([{"text":original}]);continue
        # Order of ruby is physically determined in PDF, not inferred from pronunciation.
        related.sort(key=lambda p:(p["pdfPage"],p["glyph"]["bbox"][1],p["glyph"]["bbox"][0]))
        cleaned=original
        for reading in sorted({p["ruby"] for p in related},key=len,reverse=True):
            a=list(ISOLATED(reading).finditer(cleaned))
            count=sum(p["ruby"]==reading for p in related)
            if len(a)!=count:
                errors.append("DETACHED_READING_COUNT_MISMATCH");break
            for span in reversed(a):
                cleaned=cleaned[:span.start()]+cleaned[span.end():]
        if errors:break
        # Source and candidate may have repeated ideographs. All occurrences must
        # be accounted for. Use unique source glyph sequence after position dedup.
        for k in {p["kanji"] for p in related}:
            glyphs=[g for g in chars if g["char"]==k]
            unique={(g["page"],tuple(round(x,1) for x in g["bbox"])):g for g in glyphs}
            glyphs=sorted(unique.values(),key=lambda g:(g["page"],g["bbox"][1],g["bbox"][0]))
            if len(glyphs)!=cleaned.count(k):
                errors.append("PDF_APP_KANJI_CARDINALITY_MISMATCH");break
            positions=[m.start() for m in re.finditer(re.escape(k),cleaned)]
            for p in related:
                key=(p["glyph"]["page"],tuple(round(x,1) for x in p["glyph"]["bbox"]))
                rank=next((idx for idx,g in enumerate(glyphs) if (g["page"],tuple(round(x,1) for x in g["bbox"]))==key),None)
                if rank is None or rank>=len(positions):
                    errors.append("RUBY_GLYPH_ORDINAL_UNCERTAIN");break
                p["offset"]=positions[rank]
            if errors:break
        if errors:break
        offsets=[p["offset"] for p in related]
        if len(set(offsets))!=len(offsets):
            errors.append("MULTIPLE_READINGS_SAME_POSITION");break
        if offsets!=sorted(offsets):
            errors.append("SOURCE_RUBY_ORDER_DIFFERS_FROM_CANDIDATE");break
        parts=[];cursor=0
        for p in related:
            pos=p["offset"]
            if pos<cursor or cleaned[pos:pos+1]!=p["kanji"]:
                errors.append("POSITION_NOT_EXACT_KANJI");break
            parts.extend([{"text":cleaned[cursor:pos]},
                          {"rubyBase":p["kanji"],"rubyText":p["ruby"],"sourcePage":p["pdfPage"]}])
            cursor=pos+1
        if errors:break
        parts.append({"text":cleaned[cursor:]})
        if "".join(v.get("text",v.get("rubyBase","")) for v in parts)!=cleaned:
            errors.append("RICH_CONTENT_ROUNDTRIP_FAIL");break
        enriched.append(parts)
    if errors:return None,sorted(set(errors))
    return {"questionParts":enriched[0],"choicesParts":enriched[1:],
            "placements":[{"field":p["field"],"kanji":p["kanji"],"ruby":p["ruby"],
                           "pdfPage":p["pdfPage"],"glyphBBox":[round(z,2) for z in p["glyph"]["bbox"]]} for p in placements]},[]
def run(year):
    prior=json.loads((B/f"RUBY_RECON_{year}.json").read_text())
    geo=json.loads((B/f"GEOMETRY_AUDIT_{year}.json").read_text())
    candidates=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    source=next(x for x in json.loads((B/"SOURCES_2022_2026.json").read_text())["years"] if x["year"]==year)
    shas=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    pdf={}
    for half,url in (("first_half",source["question_pdf_first_half"]),("second_half",source["question_pdf_second_half"])):
        pdf[half]=download(url,B/f".tmp_{year}_{half}.pdf",next(x["sha256"] for x in shas if x["half"]==half))
    records=[];reasons=collections.Counter()
    for q,old,g in zip(candidates,prior["records"],geo["questions"]):
        if q["id"]!=old["id"] or q["id"]!=g["id"]:raise ValueError("not aligned")
        result={"id":q["id"],"status":"NOT_TARGET","reasons":[]}
        if old["status"]!="HOLD" or "RUBY_RENDER_NOT_CERTIFIED" not in g["reasons"]:
            records.append(result);continue
        other=[x for x in g["reasons"] if x!="RUBY_RENDER_NOT_CERTIFIED"]
        if other:
            result.update(status="HOLD",reasons=["OTHER_SOURCE_LAYOUT_HOLD"])
            reasons.update(result["reasons"]);records.append(result);continue
        assoc=(g.get("ruby") or {}).get("associations") or []
        if not assoc or (g.get("ruby") or {}).get("issues"):
            result.update(status="HOLD",reasons=["PDF_RUBY_SOURCE_AMBIGUOUS"])
            reasons.update(result["reasons"]);records.append(result);continue
        doc=pdf["first_half" if q["questionNo"]<=60 else "second_half"]
        clips=first_question_clip(doc,None,q)
        if not clips:
            result.update(status="HOLD",reasons=["QUESTION_PDF_REGION_AMBIGUOUS"])
            reasons.update(result["reasons"]);records.append(result);continue
        parts,errs=candidate_parts([q["question"],*q["choices"]],assoc,chars_from_pdf(doc,clips))
        if errs:
            result.update(status="HOLD",reasons=errs)
            reasons.update(errs)
        else:
            result.update(status="ORDERED_RUBY_PASS",reasons=[],
                          **parts,method="EXACT_PDF_GLYPH_OCCURRENCE_ORDER_AND_COUNT")
        records.append(result)
    for doc in pdf.values():doc.close()
    passed=sum(x["status"]=="ORDERED_RUBY_PASS" for x in records)
    out={"year":year,"total":120,"recoveryPass":passed,
         "recoveryHold":sum(x["status"]=="HOLD" for x in records),
         "reasonCounts":dict(reasons),"candidateGitBlob":prior["candidateGitBlob"],
         "records":records,
         "safety":"Only matching physical PDF glyph occurrence count and exact candidate kanji ordinal may resolve duplicate characters. Existing ruby and visual holds preserved."}
    (B/f"ORDERED_RUBY_{year}.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"recovered":passed,"holds":out["recoveryHold"],"reasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--year",type=int,required=True,choices=range(2022,2027))
    run(ap.parse_args().year)
