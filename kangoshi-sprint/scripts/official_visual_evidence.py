#!/usr/bin/env python3
"""Render the original PDF pages for 49 text/choice mismatch cases.
Image pages are review evidence; estimated page selection is NOT a verified correction.
"""
import pathlib,json,re,collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs/visual-evidence";OUT.mkdir(parents=True,exist_ok=True)
summary=[];pages_cache={}
for exam in (115,114,113):
    for sess in ("AM","PM"):
        path=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{sess}.pdf"
        doc=fitz.open(path)
        raw=json.loads((ROOT/f"product-content/raw/set{116-exam}-raw.json").read_text())
        byid={q["id"]:q for q in raw["questions"]}
        original=json.loads((ROOT/f"audit/runs/exam{exam}-{sess}-audit.json").read_text())
        secondary=json.loads((ROOT/f"audit/runs/exam{exam}-{sess}-secondary.json").read_text())
        contexts={x["id"]:x for x in secondary["rows"]}
        for result in original["results"]:
            if result["status"] not in ("HOLD_STEM_MISMATCH","HOLD_CHOICES_MISMATCH"):continue
            q=byid[result["id"]]; context=contexts.get(q["id"],{})
            pg=context.get("nearestContext",{}).get("page")
            method="SECONDARY_TEXT_CONTEXT"
            if not isinstance(pg,int) or pg<1 or pg>len(doc):
                number=int(q["questionNo"])
                hits=[]
                for i,p in enumerate(doc):
                    # Fallback is a search heuristic; never claim source page independently proven.
                    text=p.get_text("text",sort=True)
                    if re.search(r"(?m)^\s*"+str(number)+r"\s*[^\d]",text): hits.append(i+1)
                pg=hits[0] if len(hits)==1 else max(1,min(len(doc),round(7+(number-1)*(len(doc)-7)/120)))
                method="NUMBER_REGEX" if len(hits)==1 else "ESTIMATED_PAGE"
            # jpg full page; no OCR, and do not infer corrected text from text extraction
            image=OUT/f"{q['id']}-page{pg:02d}.jpg"
            pix=doc[pg-1].get_pixmap(matrix=fitz.Matrix(1.65,1.65),alpha=False)
            pix.save(str(image),jpg_quality=73)
            summary.append({"id":q["id"],"originalStatus":result["status"],"pageCandidate":pg,"pageSelectionMethod":method,"imageFile":image.name,"verification":"IMAGE_AVAILABLE_NOT_VISUALLY_SIGNED_OFF","questionInBank":q.get("question"),"choicesInBank":q.get("choices")})
payload={"rendered":len(summary),"expected":49,"cases":summary,"note":"Visual evidence delivered for manual or model visual inspection; page candidates can be wrong when text extraction loses glyphs."}
(OUT/"visual-index.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"rendered":len(summary),"pageSelection":dict(collections.Counter(x["pageSelectionMethod"] for x in summary))},ensure_ascii=False))
