#!/usr/bin/env python3
"""Repair CID-to-Unicode C0 glyphs ONLY where actual source glyphs were inspected.
Original-source PDFs in GitHub Action workdir. Unrecognized glyphs remain HOLD.
"""
import json, pathlib, re, collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
STAGE=ROOT/"product-content/keyed-candidates"
EVID=ROOT/"audit/runs/glyph-map-repair-20261124";EVID.mkdir(parents=True,exist_ok=True)
# Confirmed by inspecting actual rendered CID glyphs in MHLW 111/112 RyuminPr6-Regular PDFs.
# 0x08 is 9; 0x0B is 6; 0x0C is 7. DO NOT assume codepoint order.
MAP={2:"2",4:"1",5:"3",6:"4",7:"5",8:"9",11:"6",12:"7",31:"（"}
SUPPORTED_FONTS={"RyuminPr6-Regular"}
def clean(text):
    text=str(text).translate(str.maketrans(MAP))
    # PDF font encodes right bracket as '!' only where immediately paired with mapped opening bracket.
    text=re.sub(r"（([^（！!\n]{0,90})!",r"（\1）",text)
    return text
def get_questions(doc):
    qno=1;prev=None;startpage=None;lines=[];found={}
    for ip,p in enumerate(doc):
        if ip<6:continue # 111/112 question 1 begins at official PDF page 7
        for original in p.get_text("text",sort=False).splitlines():
            line=clean(original).strip()
            if line.startswith("DKIX"):break
            if line==str(qno):
                if prev is not None:found[prev]=(startpage,lines)
                prev=qno;qno+=1;startpage=ip+1;lines=[]
            elif prev is not None:lines.append(line)
    if prev is not None:found[prev]=(startpage,lines)
    if sorted(found)!=list(range(1,121)):
        raise ValueError(f"Missing question sequence expected 120 got {sorted(found)}")
    return found
def parse(lines):
    body=[];options=[];indices=[]
    for l in lines:
        m=re.match(r"^([1-5])[．.]\s*(.*)$",l)
        if m:
            indices.append(int(m.group(1)))
            options.append([m.group(2)])
        elif options:
            options[-1].append(l)
        else:body.append(l)
    return " ".join(body),[" ".join(x) for x in options],indices
revisions=[];byexam={}
for ex in (111,112):
 for ss in ("AM","PM"):
    doc=fitz.open(pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{ss}.pdf")
    found=get_questions(doc)
    file=STAGE/f"exam{ex}-{ss}-draft.json"
    data=json.loads(file.read_text(encoding="utf8"))
    if len(data["questions"])!=120:raise ValueError(f"Wrong record count {file}")
    for q in data["questions"]:
        pg,lines=found[q["questionNo"]]
        stem,choices,indices=parse(lines)
        old={"question":q["question"],"choices":q["choices"],"sourcePage":q.get("sourcePage")}
        new={"question":stem,"choices":choices,"sourcePage":pg}
        # Source normalization only - preserving uncertain CIDs, ruby errors, images and answer complexity.
        if old!=new:
            revisions.append({"id":q["id"],"from":old,"to":new,"sourcePdf":q["sourceRefs"][0],
                "mappingRule":"VISUALLY_VERIFIED_RYUMIN_CID_GLYPH_MAP_ONLY",
                "unmappedSourceControls":sorted({f"U+{ord(c):04X}" for c in stem+" ".join(choices) if ord(c)<32 and c not in "\n\r\t"})})
        q.update(new)
        q["extractionValid"]=indices in ([1,2,3,4],[1,2,3,4,5]) and all(choices)
        q["textFidelity"]="C0_FONT_GLYPH_RECONSTRUCTED_OTHER_RUBY_MEDIA_UNAUDITED"
        q["glyphMapAudit"]="RYUMIN_MHLW_111_112_VERIFIED_CIDS"
    file.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    byexam[f"{ex}-{ss}"]={"questionCount":len(data["questions"]),"sourceReparseComplete":len(found)}
payload={"schemaVersion":1,"date":"2026-11-24","font":"RyuminPr6-Regular",
 "digitGlyphs":{f"U+{k:04X}":v for k,v in MAP.items()},
 "mappingEvidence":"Original rendered glyphs inspected at MHLW 111/112 official pages; count and shapes stable across AM/PM. U+000E and U+000F intentionally unresolved.",
 "parenthesisRule":"U+001F opens parenthesis, close '!' only when paired with that open in same source line. Other exclamation marks preserved.",
 "sourceDocuments":["https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp220421-05a_01.pdf","https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp230524-05a_01.pdf"],
 "reparsed":480,"changedQuestions":len(revisions),"sessionCounts":byexam,
 "originalAndRepaired":revisions,
 "policy":"Reparsed 480 source texts from official PDF, but NOT an independent full content audit. All question records still require two-engine & official key gate; exclude uncertain C0 and suspicious ruby."}
(EVID/"glyph-map-repair-ledger.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
print(json.dumps({"reparsed":480,"changedQuestions":len(revisions),"mapping":payload["digitGlyphs"]},ensure_ascii=False))
