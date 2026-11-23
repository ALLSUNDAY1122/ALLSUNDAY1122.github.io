#!/usr/bin/env python3
"""Capture official answer-key text and coordinates without inferring answer semantics."""
import json,pathlib,hashlib
import fitz
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs/key-diagnostics"
OUT.mkdir(parents=True,exist_ok=True)
for exam in (115,114,113,112,111):
    path=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-KEY.pdf"
    if not path.exists():continue
    doc=fitz.open(path)
    o={"exam":exam,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"pages":len(doc),"pageContent":[]}
    for i,p in enumerate(doc):
        words=p.get_text("words")
        o["pageContent"].append({"page":i+1,"text":p.get_text("text",sort=True),
              "firstWords":[{"x":round(w[0],1),"y":round(w[1],1),"text":w[4]} for w in words[:120]]})
    (OUT/f"answer{exam}-layout.json").write_text(json.dumps(o,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    print("EXAM",exam,"PAGES",len(doc),"FIRST",repr(o["pageContent"][0]["text"][:350]))
