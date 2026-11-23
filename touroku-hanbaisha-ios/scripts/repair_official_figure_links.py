#!/usr/bin/env python3
"""Materialize missing original-image names only from SHA-matching source crops.
Never silently substitute a different figure or modify a question/answer.
"""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WEB=ROOT/"touroku-hanbaisha-sprint"
BANK=WEB/"official-kansai/APPROVED_OFFICIAL_BANK.json"
OUT=ROOT/"touroku-hanbaisha-ios/FIGURE_LINK_AUDIT_20261124.json"
bank=json.loads(BANK.read_text())
repairs=[];errors=[];checked=0
for q in bank["questions"]:
    for f in q.get("sourceFigures",[]):
        checked+=1
        requested=WEB/f["webPath"]
        if not str(requested.resolve()).startswith(str((WEB/"official-kansai/layout-crops").resolve())):
            errors.append({"id":q["id"],"reason":"PATH_OUTSIDE_OFFICIAL_ASSET_SCOPE"});continue
        digest=f["sha256"]
        if requested.is_file():
            actual=hashlib.sha256(requested.read_bytes()).hexdigest()
            if actual!=digest:errors.append({"id":q["id"],"reason":"PUBLISHED_SHA_MISMATCH","actual":actual})
            continue
        fallback=requested.with_name(requested.name.replace("-p","-recovery-p",1))
        if not fallback.is_file():
            errors.append({"id":q["id"],"reason":"SOURCE_CROP_MISSING","path":str(fallback.relative_to(ROOT))})
            continue
        actual=hashlib.sha256(fallback.read_bytes()).hexdigest()
        if actual!=digest:
            errors.append({"id":q["id"],"reason":"RECOVERY_CROP_SHA_MISMATCH","expected":digest,"actual":actual})
            continue
        shutil.copyfile(fallback,requested)
        repairs.append({"id":q["id"],"from":str(fallback.relative_to(ROOT)),
                        "to":str(requested.relative_to(ROOT)),"sha256":digest})
out={"status":"PASS" if not errors else "FAIL","bank":bank["count"],
     "figuresChecked":checked,"recovered":len(repairs),"repairs":repairs,"errors":errors}
OUT.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({k:v for k,v in out.items() if k not in ("repairs","errors")},ensure_ascii=False))
if errors:raise SystemExit("Figure SHA verification failed: "+str(errors[:5]))
