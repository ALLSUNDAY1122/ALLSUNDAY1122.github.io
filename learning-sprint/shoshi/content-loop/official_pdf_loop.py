#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from io import BytesIO
from pathlib import Path
from urllib.parse import urljoin

import fitz
import requests
from bs4 import BeautifulSoup
from pypdf import PdfReader

import import_and_audit as base

ROOT = Path(__file__).resolve().parent
PDF_DIR = ROOT / "official-pdf"
MEDIA_DIR = ROOT / "official-media"
QUESTIONS = ROOT / "questions.generated.json"
REPORT = ROOT / "content-audit-report.json"
CONFIG = ROOT / "learning-sprint-audit.json"
PROBE = ROOT / "official-pdf-probe.json"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/140 Safari/537.36",
    "Accept-Language": "ja,en-US;q=0.8,en;q=0.6",
}
QHEAD = re.compile(r"第\s*([1-9]|[12]\d|3[0-7])\s*問")
OPT = re.compile(r"(?m)^\s*([1-5])(?:[\s　]+|(?=[アイウエオA-Z]))")
LEGAL_TOKEN = re.compile(r"(?:日本国憲法|憲法|民法|刑法|会社法|商法|民事訴訟法|民事保全法|民事執行法|司法書士法|供託法|不動産登記法|商業登記法|不動産登記規則|商業登記規則)[^。\n]{0,34}?(?:第?\s*\d+\s*条(?:の\s*\d+)?(?:第\s*\d+\s*項)?)")
RIGHTS_MARKERS = ("出典", "引用", "©", "著作権", "転載")


def get(url: str, binary=False):
    r = requests.get(url, headers=HEADERS, timeout=35)
    r.raise_for_status()
    return r.content if binary else r.text


def discover_pdf_links(year_meta: dict) -> dict[str, str]:
    html = get(year_meta["source_page"])
    soup = BeautifulSoup(html, "html.parser")
    found = {}
    all_pdf = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        context = " ".join(a.stripped_strings)
        parent = " ".join(a.parent.stripped_strings) if a.parent else context
        label = (context + " " + parent).strip()
        absolute = urljoin(year_meta["source_page"], href)
        if ".pdf" not in absolute.lower():
            continue
        all_pdf.append({"label": label[:180], "url": absolute})
        if "午前" in label and "AM" not in found:
            found["AM"] = absolute
        if "午後" in label and "答案" not in label and "PM" not in found:
            found["PM"] = absolute
    if set(found) != {"AM", "PM"}:
        raise ValueError(f"official PDF links not resolved found={found} all={all_pdf[:12]}")
    return found


def normalize_text(text: str) -> str:
    text = text.replace("\u3000", " ").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def parse_question_segments(page_texts: list[str]) -> tuple[dict[int, str], dict[int, list[int]]]:
    full_parts = []
    offsets = []
    pos = 0
    for page_no, txt in enumerate(page_texts):
        clean = normalize_text(txt)
        offsets.append((pos, pos + len(clean), page_no))
        full_parts.append(clean)
        pos += len(clean) + 2
    full = "\n\n".join(full_parts)
    heads = [(int(m.group(1)), m.start(), m.end()) for m in QHEAD.finditer(full)]
    # Keep the first monotonic occurrence of each question heading.
    first = {}
    for qno, start, end in heads:
        first.setdefault(qno, (start, end))
    missing = [q for q in range(1, 36) if q not in first]
    if missing:
        raise ValueError(f"question headings missing={missing} found={sorted(first)}")
    segments = {}
    pages = {}
    ordered = [(q, *first[q]) for q in range(1, 36)]
    for idx, (qno, start, hend) in enumerate(ordered):
        end = ordered[idx + 1][1] if idx + 1 < len(ordered) else len(full)
        seg = normalize_text(full[hend:end])
        # Afternoon PDFs can contain Q36/Q37 after Q35; cut if present.
        mnext = QHEAD.search(seg)
        if mnext and int(mnext.group(1)) > 35:
            seg = seg[:mnext.start()].strip()
        segments[qno] = seg
        qpages = []
        for pstart, pend, pno in offsets:
            if pstart < end and pend > start:
                qpages.append(pno)
        pages[qno] = qpages
    return segments, pages


def parse_choices(segment: str) -> tuple[str, list[str]]:
    matches = list(OPT.finditer(segment))
    # Need an ordered 1..5 run. Prefer the final run because stems can contain numbered conditions.
    candidate = None
    for i in range(len(matches) - 4):
        run = matches[i:i+5]
        if [int(m.group(1)) for m in run] == [1,2,3,4,5]:
            candidate = run
    if candidate is None:
        # Fallback for PDF extraction where numerals are inline but separated by whitespace.
        inline = re.compile(r"(?:^|\n|\s{2,})([1-5])\s+", re.M)
        ims = list(inline.finditer(segment))
        for i in range(len(ims) - 4):
            run = ims[i:i+5]
            if [int(m.group(1)) for m in run] == [1,2,3,4,5]:
                candidate = run
    if candidate is None:
        raise ValueError(f"ordered options 1..5 not found excerpt={segment[-900:]}")
    first = candidate[0].start()
    stem = segment[:first].strip()
    choices = []
    for i, mat in enumerate(candidate):
        start = mat.end()
        end = candidate[i+1].start() if i < 4 else len(segment)
        choice = normalize_text(segment[start:end])
        # Remove common page footer fragments after option 5.
        choice = re.sub(r"\n?-\s*\d+\s*-\s*$", "", choice).strip()
        choices.append(choice)
    if len(stem) < 25 or any(len(c) < 1 for c in choices):
        raise ValueError(f"stem/choice too short stem={len(stem)} choices={[len(c) for c in choices]}")
    return stem, choices


def subject_for(session: str, qno: int) -> str:
    return base.subject_for(session, qno)


def primary_urls(subject: str) -> list[str]:
    return list(base.SUBJECTS[subject])


def explanation(topic: str, subject: str, official: int | None, choices: list[str], all_correct: bool) -> tuple[str, str]:
    if all_correct:
        return (
            "法務省の公式取扱いでは、この問題は正答となる選択肢が存在しないため全員正答です。特定の肢を正解として補完せず、採点例外として保持します。",
            "正答なし・全員正答の公式例外。推測で正解肢を作らない。",
        )
    selected = choices[official - 1]
    short = f"出題年度の法務省公式正答は選択肢{official}です。論点は「{topic}」。出題当時の{subject}の法令・判例・登記先例等を基準にすると、この選択肢が正答になります。現行法としての扱いは年度基準と分けて確認します。"
    mem = f"{topic}：出題当時の公式正答は選択肢{official}。原則・例外と判例／先例を分けて確認する。"
    return short, mem


def main() -> int:
    PDF_DIR.mkdir(parents=True, exist_ok=True)
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    errors = []
    warnings = []
    probes = []
    questions = []

    for era, meta in base.YEARS.items():
        try:
            links = discover_pdf_links(meta)
        except Exception as exc:
            errors.append(f"R{era}: official source page/PDF discovery failed: {type(exc).__name__}: {exc}")
            continue
        for session in ("AM", "PM"):
            url = links[session]
            try:
                data = get(url, binary=True)
                pdf_path = PDF_DIR / f"R{era}-{session}.pdf"
                pdf_path.write_bytes(data)
                sha = hashlib.sha256(data).hexdigest()
                reader = PdfReader(BytesIO(data))
                texts = [p.extract_text() or "" for p in reader.pages]
                segments, qpages = parse_question_segments(texts)
                doc = fitz.open(stream=data, filetype="pdf")
                rights_hits = sorted({marker for marker in RIGHTS_MARKERS if marker in "\n".join(texts)})
                probes.append({"era": era, "session": session, "url": url, "sha256": sha, "pages": len(texts), "chars": sum(map(len,texts)), "rights_markers": rights_hits})
                if rights_hits:
                    errors.append(f"R{era}-{session}: third-party rights marker review required {rights_hits}")
                answers = meta["am_answers"] if session == "AM" else meta["pm_answers"]
                for qno in range(1, 36):
                    qid = f"SHOSHI-R{era}-{session}-{qno:02d}"
                    seg = segments[qno]
                    try:
                        stem, choices = parse_choices(seg)
                    except Exception as exc:
                        errors.append(f"{qid}: official PDF option parse failed: {type(exc).__name__}: {exc}")
                        continue
                    subject = subject_for(session, qno)
                    topic = base.topic_from(stem, subject)
                    official = answers[qno-1]
                    all_correct = era == 7 and session == "PM" and qno == 33
                    if all_correct and official is not None:
                        errors.append(f"{qid}: all-correct answer must be None")
                    if not all_correct and official not in {1,2,3,4,5}:
                        errors.append(f"{qid}: invalid official answer {official}")
                    short, memory = explanation(topic, subject, official, choices, all_correct)
                    legal_tokens = list(dict.fromkeys(m.group(0).replace(" ", "") for m in LEGAL_TOKEN.finditer(stem)))[:12]
                    # Render pages only when the PDF page actually contains raster/vector image objects.
                    media_assets = []
                    for pno in qpages[qno]:
                        page = doc[pno]
                        if page.get_images(full=True):
                            pix = page.get_pixmap(matrix=fitz.Matrix(1.6,1.6), alpha=False)
                            target = MEDIA_DIR / f"{qid}-p{pno+1}.png"
                            pix.save(str(target))
                            media_assets.append(str(target.relative_to(ROOT)))
                    q = {
                        "id": qid,
                        "round": meta["round"],
                        "source_year": meta["year"],
                        "session": session,
                        "source_question_no": qno,
                        "subject": subject,
                        "topic": topic,
                        "question": stem,
                        "choices": choices,
                        "answer_type": "singleChoice",
                        "answer": None if all_correct else official - 1,
                        "official_answer_no": official,
                        "scoring_status": "all_correct" if all_correct else "normal",
                        "officialCorrectionStatus": "allCorrect" if all_correct else "none",
                        "officialNoticeUrl": meta.get("notice_page") if all_correct else None,
                        "short_explanation": short,
                        "memory_line": memory,
                        "primary_basis": "法務省・当該年度司法書士試験問題＋公式正答",
                        "basis_url": meta["answer_page"],
                        "legal_reference_urls": primary_urls(subject),
                        "legal_reference_candidates": legal_tokens,
                        "law_baseline": meta["baseline"],
                        "current_law_status": "historical",
                        "origin_type": "licensed_official",
                        "source_page_url": meta["source_page"],
                        "official_pdf_url": url,
                        "official_pdf_sha256": sha,
                        "official_pdf_pages": [x+1 for x in qpages[qno]],
                        "official_media_assets": media_assets,
                        "rights_basis": "法務省ウェブサイト利用条件＋公共データ利用規約1.0。出典・加工表示を行い、第三者権利表示をPDF単位で監査する。",
                        "rights_checked_at": "2026-08-09",
                        "is_modified": True,
                        "explanation_source": "independent_fixed_summary_from_MOJ_official_answer",
                    }
                    questions.append(q)
            except Exception as exc:
                errors.append(f"R{era}-{session}: official PDF processing failed: {type(exc).__name__}: {exc}")

    questions.sort(key=lambda q:(q["round"], q["session"], q["source_question_no"]))
    if len(questions) != 210:
        errors.append(f"total questions {len(questions)}/210")
    ids = [q["id"] for q in questions]
    if len(ids) != len(set(ids)):
        errors.append(f"duplicate IDs { [x for x,c in Counter(ids).items() if c>1] }")
    counts = defaultdict(int)
    for q in questions:
        counts[(q["round"],q["subject"])] += 1
        for fld in ("question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","rights_basis","source_page_url","official_pdf_url","official_pdf_sha256"):
            if not q.get(fld): errors.append(f"{q['id']}: missing {fld}")
        if len(q["choices"]) != 5: errors.append(f"{q['id']}: choices {len(q['choices'])}/5")
        if q["scoring_status"] == "all_correct":
            if q["answer"] is not None: errors.append(f"{q['id']}: all_correct has answer")
        elif not isinstance(q["answer"],int) or not 0 <= q["answer"] < 5:
            errors.append(f"{q['id']}: invalid answer {q['answer']}")
        if not q["legal_reference_candidates"]:
            warnings.append(f"{q['id']}: exact statute token absent in official question; official answer + subject primary law used")
    for rnd in range(1,4):
        for subject, expected in base.EXPECTED_PER_ROUND.items():
            if counts[(rnd,subject)] != expected:
                errors.append(f"round {rnd}/{subject}: {counts[(rnd,subject)]}/{expected}")
    norm = defaultdict(list)
    for q in questions:
        norm[base.normalize(q["question"])].append(q["id"])
    for qids in norm.values():
        if len(qids)>1: errors.append(f"exact duplicate question text {qids}")

    QUESTIONS.write_text(json.dumps(questions,ensure_ascii=False,indent=2),encoding="utf-8")
    config = {
        "qualification":"司法書士試験・択一式",
        "questions_file":"questions.generated.json",
        "rounds":3,
        "subjects":base.EXPECTED_PER_ROUND,
        "similarity_threshold":0.995,
        "required_fields":["id","round","subject","topic","question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","origin_type","rights_basis","source_page_url","rights_checked_at","official_pdf_url","official_pdf_sha256"]
    }
    CONFIG.write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding="utf-8")
    PROBE.write_text(json.dumps(probes,ensure_ascii=False,indent=2),encoding="utf-8")
    report = {
        "cycle":4,
        "status":"PASS" if not errors else "FAIL",
        "generated":len(questions),
        "official_pdf_sets":len(probes),
        "media_questions":[q["id"] for q in questions if q["official_media_assets"]],
        "warnings":warnings,
        "errors":errors,
        "rules":{
            "question_and_choices":"MOJ official PDF direct extraction",
            "official_answers":"MOJ annual official answer manifest",
            "all_correct":"R7 PM Q33 answer=null",
            "rights":"PDF markers scanned; PDL attribution/edit notice required",
            "explanation":"independent fixed summary; third-party explanation prose not used",
            "law":"historical baseline; no current-law assertion"
        }
    }
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"cycle":4,"status":report["status"],"generated":len(questions),"pdf_sets":len(probes),"media":len(report["media_questions"]),"errors":len(errors),"warnings":len(warnings)},ensure_ascii=False))
    for e in errors[:120]: print("FAIL:",e)
    return 0 if not errors else 1

if __name__ == "__main__":
    sys.exit(main())
