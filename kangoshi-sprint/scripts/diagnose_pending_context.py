#!/usr/bin/env python3
"""Evidence record for each still-held shared situation passage.

Keep full parser outputs and uncertain glyph positions for individual review.
Text parser agreement alone does not confirm incorrectly mapped source CMap.
"""
import pathlib,json,re,subprocess,collections
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
H=json.loads((ROOT/"audit/dual-engine-hold-20261124.json").read_text())
P=json.loads((ROOT/"product-content/coordinate-reextracted-pending-20261124.json").read_text())
C=json.loads((ROOT/"product-content/verified-additions-20261124.json").read_text())
verified={q["id"] for q in C["questions"]}
byhold={x["id"]:x for x in H["hold"]}
from sys import path
path.insert(0,str(ROOT/"scripts"))
from boundary_context_verify import context_for_group,equivalent_shared_context,safe_context
from bulk_text_helpers import clean_font
rows=[]
for q in P["questions"]:
    if q["id"] in verified or q["questionNo"]<91:continue
    ex,session,pg,n=q["sourceExam"],q["session"],q["sourcePage"],q["questionNo"]
    pdf=pathlib.Path("/tmp/kangoshi-official")/f"{ex}-{session}.pdf"
    doc=fitz.open(pdf)
    candidates=[]
    for p in range(max(1,pg-3),pg+1):
        py=doc[p-1].get_text("text",sort=False)
        pop=subprocess.run(["pdftotext","-f",str(p),"-l",str(p),"-layout","-nopgbrk","-enc","UTF-8",str(pdf),"-"],capture_output=True,text=True,check=True).stdout
        a=context_for_group(clean_font(py),n)
        b=context_for_group(clean_font(pop),n)
        if not a and not b:continue
        pa=a["passage"] if a else ""
        pb=b["passage"] if b else ""
        eq,compare=equivalent_shared_context(pa,pb) if pa and pb else (False,{})
        good_a,fail_a=safe_context(pa,clean_font)
        good_b,fail_b=safe_context(pb,clean_font)
        unusual=lambda s:[{"index":i,"unicode":f"U+{ord(c):04X}","near":s[max(0,i-22):i+23]} for i,c in enumerate(s) if (ord(c)<32 and c not in "\n\r\t") or c in "!?ïñèêçâ઄¹¼"]
        candidates.append({"page":p,"fitzFound":bool(a),"popplerFound":bool(b),
             "sameText":eq,"equality":compare,"fitzSafe":good_a,"popplerSafe":good_b,
             "fitzUnmappedCodes":fail_a,"popplerUnmappedCodes":fail_b,
             "fitzUnusual":unusual(pa)[:40],"popplerUnusual":unusual(pb)[:40],
             "fitzPassage":pa,"popplerPassage":pb})
    rows.append({"id":q["id"],"exam":ex,"session":session,"number":n,
                 "heldReasons":byhold.get(q["id"],{}).get("reasons",[]),"candidates":candidates})
OUT=ROOT/"audit/context-passage-glyph-diagnostics-20261124.json"
OUT.write_text(json.dumps({"scope":"Remaining prior source-text verified scenario questions","count":len(rows),"items":rows},ensure_ascii=False,indent=2)+"\n")
print("CONTEXT_DETAIL",json.dumps([{"id":x["id"],"candidates":[{"page":y["page"],"same":y["sameText"],"fitzSafe":y["fitzSafe"],"popSafe":y["popplerSafe"],"fitzUnusual":y["fitzUnusual"][:6],"popUnusual":y["popplerUnusual"][:6]} for y in x["candidates"]]} for x in rows],ensure_ascii=False)[:12000])
