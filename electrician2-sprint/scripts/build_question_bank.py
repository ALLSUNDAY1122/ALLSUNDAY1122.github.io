#!/usr/bin/env python3
"""Normalize all twelve Second-Class Electrician sittings (600 questions)."""
import argparse, json, re
from pathlib import Path
LABELS = ["イ", "ロ", "ハ", "ニ"]
DATES = {
 "E2-2022-LA":"2022-10-30","E2-2022-LP":"2022-10-30",
 "E2-2023-LA":"2023-10-29","E2-2023-LP":"2023-10-29",
 "E2-2023-UA":"2023-05-28","E2-2023-UP":"2023-05-28",
 "E2-2024-L":"2024-10-27","E2-2024-U":"2024-05-26",
 "E2-2025-L":"2025-10-26","E2-2025-U":"2025-05-25",
 "E2-2026-L":"2026-10-25","E2-2026-U":"2026-05-24",
}
def source_url(prefix, suffix):
    date = DATES[prefix].replace("-", "")
    afternoon = prefix.endswith("P")
    return f"https://www.shiken.or.jp/construction/upload/{date}_co_second_{'q02' if afternoon else 'q01' if prefix.endswith(('A','U','L')) else 'q01'}.pdf".replace("_q01.pdf", "_q01.pdf")
def normalize(path):
    doc=json.loads(path.read_text(encoding="utf-8"))
    prefix=path.name.replace("-001-050.json","")
    if prefix not in DATES: raise ValueError(f"Unexpected sitting: {prefix}")
    rows=doc if isinstance(doc,list) else doc.get("questions",[])
    if len(rows)!=50: raise ValueError(f"{prefix}: expected 50 questions, got {len(rows)}")
    year,term=prefix.split("-")[1],prefix.split("-")[2]
    half="上期" if term.startswith("U") else "下期"
    session="午前" if term.endswith("A") else "午後" if term.endswith("P") else ""
    doc_meta=doc if isinstance(doc,dict) else {}
    exam_title=doc_meta.get("exam_name") or doc_meta.get("exam") or f"令和{int(year)-2018}年度第二種電気工事士{half}学科試験"+(f"（{session}）" if session else "")
    meta=doc_meta.get("source") or doc_meta.get("sources") or {}
    qpdf=(doc_meta.get("sourceFiles") or {}).get("questionPdf") or meta.get("question_pdf") or meta.get("questionPdf")
    apdf=(doc_meta.get("sourceFiles") or {}).get("answerPdf") or meta.get("answer_pdf") or meta.get("answerPdf")
    if not qpdf:
        date=DATES[prefix].replace("-","")
        qpdf=f"https://www.shiken.or.jp/construction/upload/{date}_co_second_{'q02' if session=='午後' else 'q01'}.pdf"
    if not qpdf.startswith("http"): qpdf="https://www.shiken.or.jp/construction/upload/"+qpdf
    if not apdf: apdf=qpdf.replace("_q","_a")
    elif not apdf.startswith("http"): apdf="https://www.shiken.or.jp/construction/upload/"+apdf
    out=[]
    for q in rows:
        qid=q.get("id") or q.get("question_id")
        if not qid: raise ValueError(f"{prefix}: question id missing")
        m=re.search(r"-(\d{3})$",qid)
        number=int(q.get("questionNumber",q.get("question_number",m.group(1) if m else 0)))
        raw_source=q.get("source") or {}
        raw_audit=q.get("audit") or {}
        raw_choices=q.get("choices",q.get("options"))
        if isinstance(raw_choices,dict):
            choices=[{"label":k,"text":str(raw_choices.get(k,""))} for k in LABELS]
        elif isinstance(raw_choices,list):
            choices=[{"label":x.get("label"),"text":str(x.get("text",""))} for x in raw_choices]
        else: raise ValueError(f"{qid}: choices missing")
        answer=q.get("answerOfficial",q.get("official_answer",q.get("correct_answer",q.get("answer"))))
        if answer not in LABELS: raise ValueError(f"{qid}: invalid answer {answer!r}")
        refs=list(raw_source.get("figureRefs") or [])+list(q.get("figure_refs") or [])
        for key in ("figure_ref","option_figure_ref","choice_figure_ref"):
            value=q.get(key)
            if value and value not in refs: refs.append(value)
        figure=raw_source.get("figure")
        if figure is None: figure=q.get("figure_ref") or q.get("option_figure_ref") or q.get("choice_figure_ref")
        out.append({
          "id":qid,"exam":q.get("exam",exam_title),"examDate":q.get("examDate",DATES[prefix]),
          "section":q.get("section",q.get("category","一般問題" if number <= 30 else "配線図")),"questionNumber":number,
          "question":q.get("question",q.get("question_text","")),"choices":choices,"answerOfficial":answer,
          "hereToRemember":q.get("hereToRemember",q.get("key_point")),"explanation":q.get("explanation"),
          "source":{"title":raw_source.get("title",exam_title),"url":raw_source.get("url") or qpdf,
            "page":raw_source.get("page",q.get("page")),"figure":figure,**({"figureRefs":refs} if refs else {})},
          "audit":{"transcription":raw_audit.get("transcription","転記済み・独立監査未完了"),
            "answer":raw_audit.get("answer","公式正答照合記録は原典データを参照"),
            "figureStatus":raw_audit.get("figureStatus","要個別図版目視監査" if refs or figure else "図版未確認"),
            "independentReview":raw_audit.get("independentReview","未実施"),
            "releaseStatus":raw_audit.get("releaseStatus",q.get("audit_status","PENDING_SOURCE_AND_VISUAL_AUDIT"))},
          "audit_status":q.get("audit_status","PENDING")})
    nums=[q["questionNumber"] for q in out]
    if sorted(nums)!=list(range(1,51)): raise ValueError(f"{prefix}: question numbers must be 1..50")
    return out, {"questionPdf":qpdf,"answerPdf":apdf}
def main():
    p=argparse.ArgumentParser()
    p.add_argument("files",nargs="+")
    p.add_argument("-o","--output",default="electrician2-sprint/ios/Resources/QUESTION_BANK.json")
    p.add_argument("--rights-ledger",default="electrician2-sprint/IMAGE_RIGHTS_LEDGER.json")
    a=p.parse_args()
    ledger=json.loads(Path(a.rights_ledger).read_text(encoding="utf-8"))
    hold_ids={item["question_id"] for item in ledger.get("items",[]) if item.get("rights_class")=="HOLD"}
    if len(hold_ids)!=67 or ledger.get("rights_counts",{}).get("HOLD")!=67:
        raise ValueError(f"Expected exactly 67 HOLD questions in rights ledger, got {len(hold_ids)}")
    if len(a.files)!=12: raise ValueError(f"Expected exactly 12 source files, got {len(a.files)}")
    combined=[]; seen=set(); sources={}
    for f in a.files:
        path=Path(f); rows,src=normalize(path); prefix=path.name.replace("-001-050.json","")
        if prefix in sources: raise ValueError(f"Duplicate sitting: {prefix}")
        sources[prefix]=src
        for q in rows:
            if q["id"] in seen: raise ValueError(f"Duplicate question ID: {q['id']}")
            seen.add(q["id"]); combined.append(q)
    if set(sources)!=set(DATES): raise ValueError(f"Missing/extra sittings: {sorted(set(DATES)^set(sources))}")
    combined.sort(key=lambda q:q["id"])
    if len(combined)!=600: raise ValueError(f"Expected 600 questions, got {len(combined)}")
    for q in combined:
        if not q["question"] or [c["label"] for c in q["choices"]]!=LABELS or any(not c["text"] for c in q["choices"]) or q["answerOfficial"] not in LABELS or not q["source"]["url"]:
            raise ValueError(f"Invalid normalized record: {q['id']}")
        if q["audit_status"]!="PENDING": raise ValueError(f"Unexpected audit status: {q['id']}")
    bank_ids={q["id"] for q in combined}
    if not hold_ids.issubset(bank_ids): raise ValueError(f"HOLD IDs missing from question bank: {sorted(hold_ids-bank_ids)}")
    for q in combined: q["excludedFromQuiz"] = q["id"] in hold_ids
    bank={"schemaVersion":"1.0","dataSet":"E2-ALL-2022-2026","sourceFiles":{"questionPdf":"複数回分（各問題source.urlに原典URLを保持）","answerPdf":"複数回分（各問題audit.answerに照合記録を保持）"},"questionCount":600,"questions":combined}
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Wrote {len(combined)} questions from {len(sources)} sittings to {out}")
if __name__=="__main__": main()
