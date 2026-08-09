#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys

import official_pdf_loop_v3 as v3

FOOTER_RE = re.compile(
    r"\n\s*AQ\s*[-―—–]\s*[A-Z]\s*\n\s*[─━\-―—–]*\s*(?:\d\s*){1,3}[─━\-―—–]*\s*$",
    re.I,
)
FOOTER_ANY_RE = re.compile(r"(?m)^\s*AQ\s*[-―—–]\s*[A-Z]\s*$", re.I)


def clean_footer(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = FOOTER_RE.sub("", text).strip()
    return text


def split_questions(page_texts: list[str]):
    parts=[]; page_ranges=[]; pos=0
    for pno,raw in enumerate(page_texts):
        txt=v3.norm(raw)
        parts.append(txt)
        page_ranges.append((pos,pos+len(txt),pno))
        pos += len(txt)+2
    full="\n\n".join(parts)
    hits=[(int(m.group(1)),m.start(),m.end()) for m in v3.QHEAD.finditer(full)]
    seq=[]; cursor=-1
    for target in range(1,36):
        candidates=[h for h in hits if h[0]==target and h[1]>cursor]
        if not candidates:
            raise ValueError(f"missing heading Q{target}; detected={[h[0] for h in hits[:100]]}")
        chosen=candidates[0]
        seq.append(chosen); cursor=chosen[1]
    out={}; pages={}
    for i,(q,start,hend) in enumerate(seq):
        if i+1<len(seq):
            end=seq[i+1][1]
        else:
            later=[h[1] for h in hits if h[0]>35 and h[1]>start]
            end=min(later) if later else len(full)
        segment=clean_footer(v3.norm(full[hend:end]))
        if len(segment)<35:
            raise ValueError(f"Q{q} segment too short len={len(segment)}")
        out[q]=segment
        pages[q]=[pno for pstart,pend,pno in page_ranges if pstart<end and pend>start]
    return out,pages,hits


v3.split_questions = split_questions


def main():
    rc=v3.main()
    report=json.loads(v3.REPORT.read_text(encoding="utf-8"))
    questions=json.loads(v3.QUESTIONS.read_text(encoding="utf-8"))
    post_errors=[]
    for q in questions:
        if FOOTER_ANY_RE.search(q["question"]):
            post_errors.append(f"{q['id']}: PDF footer remains")
        if len(q.get("official_pdf_pages",[]))>4:
            post_errors.append(f"{q['id']}: suspicious page span {q['official_pdf_pages']}")
        if not q["question"].strip():
            post_errors.append(f"{q['id']}: empty question after cleanup")
    report["cycle"]=7
    report["post_cleanup_audit"]={
        "footer_artifacts": sum(1 for q in questions if FOOTER_ANY_RE.search(q["question"])),
        "page_span_over_4": sum(1 for q in questions if len(q.get("official_pdf_pages",[]))>4),
        "question_count": len(questions),
    }
    if post_errors:
        report["status"]="FAIL"
        report.setdefault("errors",[]).extend(post_errors)
        rc=1
    else:
        report["status"]="PASS" if not report.get("errors") and rc==0 else "FAIL"
    v3.REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"cycle":7,"status":report["status"],"post_errors":len(post_errors),"post_cleanup":report["post_cleanup_audit"]},ensure_ascii=False))
    for e in post_errors[:50]: print("FAIL:",e)
    return 0 if report["status"]=="PASS" else 1


if __name__=="__main__": sys.exit(main())
