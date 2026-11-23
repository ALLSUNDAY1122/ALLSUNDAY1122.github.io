#!/usr/bin/env python3
"""Independent layout methods to distinguish strict string mismatch from extraction artifacts."""
import json,pathlib,sys,re,unicodedata,difflib,hashlib
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs"
def norm(s):
    return re.sub(r"[\s\u200b\ufeff]+","",unicodedata.normalize("NFKC",str(s))).replace("−","-").replace("‐","-").replace("〜","~").replace("～","~").replace("\x02つ選べ","2つ選べ").replace("઄つ選べ","2つ選べ")
def run():
    summary={}
    for exam in (115,114,113):
        for session in ("AM","PM"):
            source=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
            old=OUT/f"exam{exam}-{session}-audit.json"
            if not (source.exists() and old.exists()):continue
            report=json.loads(old.read_text()); bank=json.loads((ROOT/f"product-content/raw/set{116-exam}-raw.json").read_text())
            indexed={q["id"]:q for q in bank["questions"]}
            doc=fitz.open(source)
            pages=[]
            for p in doc:
                pages.append({
                    "ordered":norm(p.get_text("text",sort=False)),
                    "blocks":norm("".join(b[4] for b in p.get_text("blocks") if len(b)>4 and isinstance(b[4],str))),
                    "words":norm("".join(w[4] for w in sorted(p.get_text("words"),key=lambda w:(round(w[1]/8),w[0]))))
                })
            rows=[]
            for x in report["results"]:
                if x["status"] not in ("HOLD_STEM_MISMATCH","HOLD_CHOICES_MISMATCH","HOLD_INCOMPLETE_DATA"):continue
                q=indexed[x["id"]];stem=norm(q.get("question",""))
                choices=[norm(k) for k in q.get("choices",[])]
                found=[]
                for i,p in enumerate(pages):
                    for mode,s in p.items():
                        if stem and choices and all(choices) and stem in s and all(ch in s for ch in choices):
                            found.append({"page":i+1,"method":mode})
                # find approximate text context; never apply fuzzy candidate as official correction.
                best={"ratio":0,"page":None,"snippet":""}
                if not found and stem:
                    for i,p in enumerate(pages):
                        txt=p["ordered"]
                        if not txt:continue
                        matcher=difflib.SequenceMatcher(None,stem[:100],txt,autojunk=True)
                        match=matcher.find_longest_match(0,len(stem[:100]),0,len(txt))
                        ratio=match.size/max(1,len(stem[:100]))
                        if ratio>best["ratio"] and match.size>=14:
                            best={"ratio":round(ratio,3),"page":i+1,"snippet":txt[max(0,match.b-70):match.b+min(280,len(stem)+140)]}
                verdict="EXTRACTION_ORDER_VARIANT_MATCH" if found else ("DATA_INCOMPLETE" if not stem or not choices else "UNRESOLVED_REQUIRES_PAGE_REVIEW")
                rows.append({"id":q["id"],"prior":x["status"],"verdict":verdict,"alternateMatches":found,"nearestContext":best})
            counts={k:sum(z["verdict"]==k for z in rows) for k in sorted({z["verdict"] for z in rows})}
            output={"exam":exam,"session":session,"questionCount":len(rows),"verdicts":counts,"rows":rows,"policy":"No source text correction until page-level verification"}
            (OUT/f"exam{exam}-{session}-secondary.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
            summary[f"{exam}-{session}"]=counts
    (OUT/"secondary-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False))
if __name__=="__main__":run()
