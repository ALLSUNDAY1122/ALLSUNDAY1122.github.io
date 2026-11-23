#!/usr/bin/env python3
"""Reaudit the 38 historical media assets. File integrity ≠ copyright authorization."""
import json, pathlib, hashlib, xml.etree.ElementTree as ET, re, collections, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONTENT=ROOT/"product-content"
rights=json.loads((CONTENT/"media-rights-audit.json").read_text())
redraw=json.loads((CONTENT/"media-redraw-audit.json").read_text())
redraw_by_id={x["id"]:x for x in redraw["items"]}
data=[]
for item in rights["items"]:
    id=item["id"]
    kind="redraw" if item["status"]=="needs_redraw" else "official"
    path=ROOT/"media"/kind/(id+(".svg" if kind=="redraw" else ".jpg"))
    row={"id":id,"legacyStatus":item["status"],"sourcePdf":item.get("questionPdf"),
         "sourcePageIndex":item.get("questionPageIndex"),"rightsMarkers":item.get("rightsMarkers",[]),
         "path":str(path.relative_to(ROOT)),"exists":path.is_file(),"sha256":None,
         "assetStructuralStatus":"MISSING","rightsStatus":"HOLD_INDIVIDUAL_THIRD_PARTY_REVIEW"}
    if path.is_file():
        b=path.read_bytes()
        row["sha256"]=hashlib.sha256(b).hexdigest()
        row["sizeBytes"]=len(b)
        if kind=="official":
            row["assetStructuralStatus"]="PASS_JPEG_BYTES" if b.startswith(b"\xff\xd8\xff") and b.endswith(b"\xff\xd9") else "HOLD_INVALID_JPEG"
        else:
            r=redraw_by_id.get(id)
            try:
                root=ET.fromstring(b)
                words=b.decode("utf-8","replace").lower()
                external=bool(re.search(r"<(?:image|script|foreignobject)\b|(?:href|xlink:href)\s*=|url\(\s*https?://",words))
                is_svg=root.tag.endswith("svg")
                metadata=(root.attrib.get("data-original-redraw")==id)
                status=(not external and is_svg and metadata and r is not None and r.get("selfContainedSvg") is True)
                row["assetStructuralStatus"]="PASS_SELF_CONTAINED_VECTOR" if status else "HOLD_VECTOR_STRUCTURE"
                row["externalRefsOrEmbeddedImageDetected"]=external
                row["redrawRecordPresent"]=r is not None
            except Exception as e:
                row["assetStructuralStatus"]="HOLD_SVG_PARSE";row["error"]=str(e)
    data.append(row)
total=collections.Counter(x["assetStructuralStatus"] for x in data)
out={"schemaVersion":1,"count":len(data),"byStructure":dict(total),"assetPresent":sum(x["exists"] for x in data),
     "historicalRedraw":23,"historicalOfficialJpg":15,
     "copyrightClearedByThisAudit":0,"note":"Checks asset integrity and self-contained vector syntax, not equivalence to official image or proof of PDL/third-party rights. Copyright and diagram response-position hold remains.","items":data}
output=ROOT/"audit/runs/media-38-structural-reaudit.json"
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"count":len(data),"present":out["assetPresent"],"byStructure":dict(total)},ensure_ascii=False))
sys.exit(0 if out["assetPresent"]==38 and total.get("PASS_SELF_CONTAINED_VECTOR")==23 and total.get("PASS_JPEG_BYTES")==15 else 1)
