#!/usr/bin/env python3
"""Apply only individually visually verified source-PDF glyph repairs.

Exact source PDF SHA and corresponding rendered 2.1x PNG SHA are mandatory.
The bulk verifier still independently verifies question identity, official key,
unmodified question and choices. Never waive scenario, scoring, media or law.
"""
import pathlib,json,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
LED=json.loads((ROOT/"audit/visual-glyph-confirmation-20261124.json").read_text())
OUT=ROOT/"audit/runs/context-control-visual-20261124"
assert len(LED["items"])==3
VERIFIED={q["id"]:q for q in json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())["questions"]}
for evidence in LED["items"]:
    if evidence["id"] in VERIFIED:
        canonical=VERIFIED[evidence["id"]]
        if (canonical["choices"][evidence["choiceIndex"]]!=evidence["expectedChoice"]
            or canonical.get("visualNumericGlyphEvidence",{}).get("pngSha256")!=evidence["pngSha256"]):
            raise ValueError("Previously promoted visual evidence does not match canonical source "+evidence["id"])
        print("GLYPH_ALREADY_VERIFIED",evidence["id"])
        continue
    ex,ss,no=evidence["exam"],evidence["session"],evidence["number"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ss}.pdf"
    if hashlib.sha256(pdf.read_bytes()).hexdigest()!=evidence["pdfSha256"]:
        raise RuntimeError("Source PDF SHA mismatch "+evidence["id"])
    png=OUT/f"{evidence['id']}-p{evidence['page']}.png"
    if hashlib.sha256(png.read_bytes()).hexdigest()!=evidence["pngSha256"]:
        raise RuntimeError("Visual evidence PNG SHA mismatch "+evidence["id"])
    path=ROOT/"product-content/keyed-candidates"/f"exam{ex}-{ss}-draft.json"
    bank=json.loads(path.read_text())
    matched=[q for q in bank["questions"] if q["id"]==evidence["id"] and q["questionNo"]==no and q["sourcePage"]==evidence["page"]]
    if len(matched)!=1:raise ValueError("Question/page mismatch "+evidence["id"])
    q=matched[0]
    choices=q.get("choices") or []
    if len(choices)!=4:raise ValueError("Four options required "+evidence["id"])
    i=evidence["choiceIndex"]
    old=choices[i]
    if old==evidence["expectedChoice"]:continue
    choices[i]=evidence["expectedChoice"]
    q["visualGlyphProof"]={"evidencePath":"audit/visual-glyph-confirmation-20261124.json",
                          "pdfSha256":evidence["pdfSha256"],
                          "pngSha256":evidence["pngSha256"],
                          "page":evidence["page"],"fieldIndex":i+1,
                          "repairedOldValue":old,"repairedValue":choices[i]}
    path.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    print("GLYPH_FIXED",evidence["id"],"choice",i+1,repr(old),"->",repr(choices[i]))
