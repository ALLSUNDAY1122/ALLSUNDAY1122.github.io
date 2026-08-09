#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys

import official_pdf_loop_v4 as v4

AQ_RE=re.compile(r"^\s*AQ\s*[-―—–]\s*[A-Z]\s*$",re.I)
PAGE_RE=re.compile(r"^\s*[─━\-―—–]*\s*(?:\d\s*){1,3}[─━\-―—–]*\s*$")


def clean_footer_anywhere(text:str)->str:
    lines=text.splitlines()
    out=[]; after_aq=False
    for line in lines:
        if AQ_RE.fullmatch(line):
            after_aq=True
            continue
        if after_aq and PAGE_RE.fullmatch(line):
            after_aq=False
            continue
        after_aq=False
        out.append(line)
    return "\n".join(out).strip()

v4.clean_footer=clean_footer_anywhere


def main():
    rc=v4.main()
    report=json.loads(v4.v3.REPORT.read_text(encoding="utf-8"))
    questions=json.loads(v4.v3.QUESTIONS.read_text(encoding="utf-8"))
    remain=[q["id"] for q in questions if AQ_RE.search(q["question"])]
    report["cycle"]=8
    report["inline_footer_audit"]={"remaining":len(remain),"ids":remain}
    if remain:
        report["status"]="FAIL"
        report.setdefault("errors",[]).extend(f"{qid}: inline PDF footer remains" for qid in remain)
        rc=1
    elif not report.get("errors") and rc==0:
        report["status"]="PASS"
    v4.v3.REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"cycle":8,"status":report["status"],"remaining_inline_footers":len(remain)},ensure_ascii=False))
    return 0 if report["status"]=="PASS" else 1

if __name__=="__main__": sys.exit(main())
