#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from io import BytesIO
from pathlib import Path

import fitz
import requests
from pypdf import PdfReader

import import_and_audit as base

ROOT = Path(__file__).resolve().parent
QUESTIONS = ROOT / "questions.generated.json"
REPORT = ROOT / "content-audit-report.json"
CONFIG = ROOT / "learning-sprint-audit.json"
PROBE = ROOT / "official-pdf-probe.json"
MEDIA_DIR = ROOT / "official-media"
MEDIA_DIR.mkdir(parents=True, exist_ok=True)

PDF_LINKS = {
    2023: {"AM":"https://www.moj.go.jp/content/001400147.pdf","PM":"https://www.moj.go.jp/content/001400148.pdf"},
    2024: {"AM":"https://www.moj.go.jp/content/001422259.pdf","PM":"https://www.moj.go.jp/content/001422260.pdf"},
    2025: {"AM":"https://www.moj.go.jp/content/001444126.pdf","PM":"https://www.moj.go.jp/content/001444127.pdf"},
}
HEADERS={"User-Agent":"Mozilla/5.0","Accept-Language":"ja,en;q=0.7"}
QHEAD=re.compile(r"第\s*([1-9]|[12][0-9]|3[0-7])\s*問")
RIGHTS_TERMS=("出典","引用","©","転載")
LEGAL_TOKEN=re.compile(r"(?:日本国憲法|憲法|民法|刑法|会社法|商法|民事訴訟法|民事保全法|民事執行法|司法書士法|供託法|不動産登記法|商業登記法|不動産登記規則|商業登記規則)[^。\n]{0,40}?(?:第?\s*[0-9]+\s*条(?:の\s*[0-9]+)?(?:第\s*[0-9]+\s*項)?)")


def norm(s:str)->str:
    s=unicodedata.normalize("NFKC",s or "")
    s=s.replace("\x00"," ").replace("\x08"," ").replace("\x0c"," ").replace("\r","\n")
    s=re.sub(r"[ \t]+"," ",s)
    s=re.sub(r"\n{3,}","\n\n",s)
    return s.strip()


def get_pdf(url:str)->bytes:
    r=requests.get(url,headers=HEADERS,timeout=40)
    r.raise_for_status()
    return r.content


def split_questions(page_texts:list[str]):
    parts=[]; page_ranges=[]; pos=0
    for pno,raw in enumerate(page_texts):
        txt=norm(raw)
        parts.append(txt)
        page_ranges.append((pos,pos+len(txt),pno))
        pos += len(txt)+2
    full="\n\n".join(parts)
    hits=[]
    for m in QHEAD.finditer(full):
        q=int(m.group(1))
        hits.append((q,m.start(),m.end()))
    # Use a monotonic 1..35 sequence, skipping duplicated table-of-contents/header hits.
    seq=[]; cursor=-1
    for target in range(1,36):
        candidates=[h for h in hits if h[0]==target and h[1]>cursor]
        if not candidates:
            raise ValueError(f"missing heading Q{target}; detected={[h[0] for h in hits[:80]]}")
        chosen=candidates[0]
        seq.append(chosen); cursor=chosen[1]
    out={}; pages={}
    for i,(q,start,hend) in enumerate(seq):
        end=seq[i+1][1] if i+1<len(seq) else len(full)
        segment=norm(full[hend:end])
        # PM files may append Q36/Q37 after Q35.
        if q==35:
            m=QHEAD.search(segment)
            if m and int(m.group(1))>35:
                segment=segment[:m.start()].strip()
        if len(segment)<35:
            raise ValueError(f"Q{q} segment too short len={len(segment)}")
        out[q]=segment
        pages[q]=[pno for pstart,pend,pno in page_ranges if pstart<end and pend>start]
    return out,pages,hits


def topic(stem:str,subject:str)->str:
    first=stem.split("\n",1)[0].strip()
    m=re.match(r"(.{1,42}?)に関する",first)
    return m.group(1).strip(" 。") if m else subject


def make_explanation(qtopic:str,subject:str,answer_no:int|None,all_correct:bool):
    if all_correct:
        return (
            "法務省の公式取扱いでは、この問題は正答となる選択肢が存在しないため受験者全員を正答としています。本アプリでも正解肢を推測して補わず、公式の採点例外として保持します。",
            "公式の全員正答問題。正解肢を推測して作らない。",
        )
    return (
        f"法務省の出題年度公式正答は選択肢{answer_no}です。論点は「{qtopic}」。本問は出題当時基準の過去問として保持し、現行法としての適否は別の制度監査を経ない限り断定しません。",
        f"{qtopic}：出題当時の公式正答は選択肢{answer_no}。現行法とは分けて覚える。",
    )


def main()->int:
    errors=[]; warnings=[]; probes=[]; questions=[]
    for era,meta in base.YEARS.items():
        for session in ("AM","PM"):
            url=PDF_LINKS[meta["year"]][session]
            try:
                data=get_pdf(url)
                sha=hashlib.sha256(data).hexdigest()
                reader=PdfReader(BytesIO(data))
                raw_pages=[p.extract_text() or "" for p in reader.pages]
                page_texts=[norm(t) for t in raw_pages]
                segments,qpages,hits=split_questions(page_texts)
                all_text="\n".join(page_texts)
                rights=[]
                for term in RIGHTS_TERMS:
                    for m in re.finditer(re.escape(term),all_text):
                        rights.append({"term":term,"context":all_text[max(0,m.start()-60):m.start()+100]})
                if rights:
                    errors.append(f"R{era}-{session}: third-party rights marker requires review {rights[:4]}")
                probes.append({"era":era,"session":session,"url":url,"sha256":sha,"pages":len(page_texts),"chars":len(all_text),"heading_count":len(hits),"rights_hits":rights})
                doc=fitz.open(stream=data,filetype="pdf")
                answers=meta["am_answers"] if session=="AM" else meta["pm_answers"]
                for qno in range(1,36):
                    qid=f"SHOSHI-R{era}-{session}-{qno:02d}"
                    text=segments[qno]
                    subject=base.subject_for(session,qno)
                    qtopic=topic(text,subject)
                    official=answers[qno-1]
                    all_correct=(era==7 and session=="PM" and qno==33)
                    if all_correct and official is not None: errors.append(f"{qid}: all_correct official answer must be null")
                    if not all_correct and official not in {1,2,3,4,5}: errors.append(f"{qid}: invalid official answer {official}")
                    short,memory=make_explanation(qtopic,subject,official,all_correct)
                    tokens=list(dict.fromkeys(norm(m.group(0)) for m in LEGAL_TOKEN.finditer(text)))[:12]
                    if not tokens: warnings.append(f"{qid}: exact statute token not printed; subject-level primary law URL only")
                    media=[]
                    # Only raster images are exported. Text/tables remain in the official extracted segment.
                    for pno in qpages[qno]:
                        if doc[pno].get_images(full=True):
                            pix=doc[pno].get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False)
                            target=MEDIA_DIR/f"{qid}-p{pno+1}.png"
                            pix.save(str(target)); media.append(str(target.relative_to(ROOT)))
                    questions.append({
                        "id":qid,"round":meta["round"],"source_year":meta["year"],"session":session,"source_question_no":qno,
                        "subject":subject,"topic":qtopic,"question":text,
                        "choices":["1","2","3","4","5"],"answer_type":"singleChoice","answer":None if all_correct else official-1,
                        "official_answer_no":official,"scoring_status":"all_correct" if all_correct else "normal",
                        "officialCorrectionStatus":"allCorrect" if all_correct else "none","officialNoticeUrl":meta.get("notice_page") if all_correct else None,
                        "short_explanation":short,"memory_line":memory,
                        "primary_basis":"法務省・当該年度司法書士試験問題PDF＋公式正答","basis_url":meta["answer_page"],
                        "legal_reference_urls":list(base.SUBJECTS[subject]),"legal_reference_candidates":tokens,
                        "law_baseline":meta["baseline"],"current_law_status":"historical","origin_type":"licensed_official",
                        "source_page_url":meta["source_page"],"official_pdf_url":url,"official_pdf_sha256":sha,
                        "official_pdf_pages":[x+1 for x in qpages[qno]],"official_media_assets":media,
                        "rights_basis":"法務省ウェブサイト利用条件＋公共データ利用規約1.0。出典・加工表示を行い、PDF内に第三者権利表示があればFAILして個別監査する。",
                        "rights_checked_at":"2026-08-09","is_modified":True,
                        "explanation_source":"independent_fixed_summary_from_MOJ_official_answer",
                    })
            except Exception as exc:
                errors.append(f"R{era}-{session}: {type(exc).__name__}: {exc}")
    questions.sort(key=lambda q:(q["round"],q["session"],q["source_question_no"]))
    if len(questions)!=210: errors.append(f"total questions {len(questions)}/210")
    ids=[q["id"] for q in questions]
    for qid,c in Counter(ids).items():
        if c>1: errors.append(f"duplicate id {qid} x{c}")
    counts=defaultdict(int); norm_texts=defaultdict(list)
    required=("question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","rights_basis","source_page_url","official_pdf_url","official_pdf_sha256")
    for q in questions:
        counts[(q["round"],q["subject"])]+=1
        for fld in required:
            if q.get(fld) in (None,"",[]): errors.append(f"{q['id']}: missing {fld}")
        if q["choices"] != ["1","2","3","4","5"]: errors.append(f"{q['id']}: UI choices invalid")
        if q["scoring_status"]=="all_correct":
            if q["answer"] is not None: errors.append(f"{q['id']}: all_correct has answer")
        elif not isinstance(q["answer"],int) or not 0<=q["answer"]<5: errors.append(f"{q['id']}: invalid answer {q['answer']}")
        norm_texts[base.normalize(q["question"])].append(q["id"])
    for rnd in range(1,4):
        for subject,expected in base.EXPECTED_PER_ROUND.items():
            got=counts[(rnd,subject)]
            if got!=expected: errors.append(f"round {rnd}/{subject}: {got}/{expected}")
    for qids in norm_texts.values():
        if len(qids)>1: errors.append(f"exact duplicate question text {qids}")
    QUESTIONS.write_text(json.dumps(questions,ensure_ascii=False,indent=2),encoding="utf-8")
    CONFIG.write_text(json.dumps({
        "qualification":"司法書士試験・択一式","questions_file":"questions.generated.json","rounds":3,
        "subjects":base.EXPECTED_PER_ROUND,"similarity_threshold":0.995,
        "required_fields":["id","round","subject","topic","question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","origin_type","rights_basis","source_page_url","rights_checked_at","official_pdf_url","official_pdf_sha256"]
    },ensure_ascii=False,indent=2),encoding="utf-8")
    PROBE.write_text(json.dumps(probes,ensure_ascii=False,indent=2),encoding="utf-8")
    report={"cycle":6,"status":"PASS" if not errors else "FAIL","generated":len(questions),"pdf_sets":len(probes),
            "media_questions":[q["id"] for q in questions if q["official_media_assets"]],"warnings":warnings,"errors":errors,
            "rules":{"question":"MOJ official PDF full question segment, including printed choice mapping","ui_choices":"numeric 1..5 only","answer":"MOJ official annual answer","explanation":"independent fixed summary, no third-party prose","law":"historical baseline only","rights":"PDL + PDF marker audit"}}
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"cycle":6,"status":report["status"],"generated":len(questions),"pdf_sets":len(probes),"media":len(report["media_questions"]),"errors":len(errors),"warnings":len(warnings)},ensure_ascii=False))
    for e in errors[:120]: print("FAIL:",e)
    return 0 if not errors else 1

if __name__=="__main__": sys.exit(main())
