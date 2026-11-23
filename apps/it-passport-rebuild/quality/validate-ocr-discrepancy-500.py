#!/usr/bin/env python3
"""Audit 500 per-question OCR discrepancies; never translate OCR similarity into release PASS."""
import base64,collections,hashlib,json,zlib
from pathlib import Path
p=Path(__file__).resolve().parents[1]/"questions"
a=json.loads((p/"official-ocr-discrepancy-audit-500.json").read_text(encoding="utf-8"))
data=zlib.decompress(base64.b64decode(a["codes_zlib_base64"])).decode("ascii")
assert len(data)==a["questions"]==500
assert hashlib.sha256(data.encode()).hexdigest()==a["codes_sha256"]
assert set(data)<=set("EHML")
assert dict(collections.Counter(data))==a["counts"]
assert a["textual_source_independent_visual_pass"]==a["promoted_to_release"]==0
assert len(json.loads((p/"official-verbatim.json").read_text(encoding="utf-8")))==0
for offset,year in enumerate(range(2022,2027)):
    codes=data[offset*100:(offset+1)*100]
    assert len(codes)==100
    print(year,dict(collections.Counter(codes)),"low-priority-IDs",[i+1 for i,c in enumerate(codes) if c=="L"])
print("PASS: 500 OCR discrepancy classifications, 12 exact OCR agreements; all 500 still await independent image/text audits")
