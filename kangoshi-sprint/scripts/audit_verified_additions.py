#!/usr/bin/env python3
"""Independent strict evidence check for 112/111 canonical verified extension. Exits nonzero on any failed item."""
import json, pathlib, hashlib, sys, re, unicodedata, collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILE=ROOT/"product-content/verified-additions-20261124.json"
OUT=ROOT/"audit/runs/verified-additions-12.json"
def normalize(s):
    return re.sub(r"[\s\u200b\ufeff]+","",unicodedata.normalize("NFKC",str(s))).replace("～","~").replace("〜","~").replace("−","-").replace("‐","-")
def main():
    import official_answer_key_audit as keymod
    obj=json.loads(FILE.read_text(encoding="utf-8"))
    answer_keys={exam:keymod.parse(exam)[0] for exam in (111,112)}
    pdfs={}
    rows=[]
    for q in obj["questions"]:
        ident=q["id"];ex=q["sourceExam"];ss=q["session"]
        path=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ss}.pdf"
        if not path.is_file():raise FileNotFoundError(path)
        if (ex,ss) not in pdfs:pdfs[(ex,ss)]=fitz.open(path)
        doc=pdfs[(ex,ss)]
        pg=int(q["evidence"]["sourcePdfPage"])
        page=normalize(doc[pg-1].get_text("text",sort=True))
        stem=normalize(q["question"]);choices=[normalize(x) for x in q["choices"]]
        key=answer_keys[ex].get(ident)
        actual_sha=hashlib.sha256(path.read_bytes()).hexdigest()
        checks={
            "stem_on_original_page":bool(stem) and stem in page,
            "exactly_four_choices":len(choices)==4 and all(choices),
            "all_four_choices_on_original_page":all(x in page for x in choices),
            "pdf_sha256_matches_record":actual_sha==q["evidence"]["sourcePdfSha256"],
            "official_single_key_matches_record":key is not None and key.get("status")=="KEY_SINGLE" and key.get("rawValue")==str(q["answer"]+1),
            "no_special_scoring":q["officialScoringStatus"]=="normal",
            "no_media":q["requiresMedia"] is False,
            "source_and_attribution_present":len(q.get("sourceRefs") or [])==2 and bool(q.get("sourceAttribution")),
            "not_accidentally_released":q["publishable"] is False and q["releaseEligible"] is False
        }
        status="PASS_CANONICAL_TEXT_AND_KEY_ONLY" if all(checks.values()) else "HOLD"
        rows.append({"id":ident,"pdfPage":pg,"checks":checks,"status":status})
    totals=dict(collections.Counter(x["status"] for x in rows))
    report={"schemaVersion":1,"checked":len(rows),"counts":totals,"rows":rows,
            "scope":"Verified source text and official answer only; explanation independent specialist review, runtime compatibility, and app release remain unverified."}
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"checked":len(rows),"counts":totals},ensure_ascii=False))
    return 0 if len(rows)==12 and totals.get("PASS_CANONICAL_TEXT_AND_KEY_ONLY")==12 else 1
if __name__=="__main__":sys.exit(main())
