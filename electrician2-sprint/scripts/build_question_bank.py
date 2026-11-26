#!/usr/bin/env python3
"""Normalize six Second-Class Electrician question JSON variants into QUESTION_BANK.json."""
import argparse
import json
import re
from pathlib import Path

SITTINGS = {
    "E2-2026-U": ("2026", "U", "2026-05-24", "令和8年度第二種電気工事士上期学科試験", "https://www.shiken.or.jp/construction/upload/20260524_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20260524_co_second_a01.pdf"),
    "E2-2026-L": ("2026", "L", "2026-10-25", "令和8年度第二種電気工事士下期学科試験", "https://www.shiken.or.jp/construction/upload/20261025_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20261025_co_second_a01.pdf"),
    "E2-2025-U": ("2025", "U", "2025-05-25", "令和7年度第二種電気工事士上期学科試験", "https://www.shiken.or.jp/construction/upload/20250525_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20250525_co_second_a01.pdf"),
    "E2-2025-L": ("2025", "L", "2025-10-26", "令和7年度第二種電気工事士下期学科試験", "https://www.shiken.or.jp/construction/upload/20251026_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20251026_co_second_a01.pdf"),
    "E2-2024-U": ("2024", "U", "2024-05-26", "令和6年度第二種電気工事士上期学科試験", "https://www.shiken.or.jp/construction/upload/20240526_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20240526_co_second_a01.pdf"),
    "E2-2024-L": ("2024", "L", "2024-10-27", "令和6年度第二種電気工事士下期学科試験", "https://www.shiken.or.jp/construction/upload/20241027_co_second_q01.pdf", "https://www.shiken.or.jp/construction/upload/20241027_co_second_a01.pdf"),
}
LABELS = ["イ", "ロ", "ハ", "ニ"]

def get_dataset(doc, path):
    ds = doc.get("dataSet") if isinstance(doc, dict) else None
    if ds in SITTINGS:
        return ds
    items = doc if isinstance(doc, list) else doc.get("questions", [])
    for q in items:
        qid = q.get("id", "")
        m = re.match(r"^(E2-\d{4}-[UL])-\d{3}$", qid)
        if m:
            return m.group(1)
    m = re.search(r"(E2-\d{4}-[UL])", Path(path).name)
    if m:
        return m.group(1)
    raise ValueError(f"Cannot identify sitting from {path}")

def choices_as_list(raw):
    if isinstance(raw, list):
        result = [{"label": x["label"], "text": x["text"]} for x in raw]
    elif isinstance(raw, dict):
        result = [{"label": label, "text": raw[label]} for label in LABELS if label in raw]
    else:
        raise ValueError("choices/options must be an array of {label,text} or a label-keyed object")
    if [x["label"] for x in result] != LABELS or any(not x["text"] for x in result):
        raise ValueError("Each question must have four non-empty choices in イ・ロ・ハ・ニ order")
    return result

def normalize_question(q, dataset, source_files):
    year, term, exam_date, exam_title, official_qpdf, official_apdf = SITTINGS[dataset]
    qid = q["id"]
    number = q.get("questionNumber", q.get("question_number"))
    if number is None:
        m = re.search(r"-(\d{3})$", qid)
        if not m:
            raise ValueError(f"Missing question number: {qid}")
        number = int(m.group(1))
    raw_source = q.get("source") or {}
    raw_audit = q.get("audit") or {}
    options = q.get("choices", q.get("options"))
    answer = q.get("answerOfficial", q.get("official_answer", q.get("correct_answer", q.get("answer"))))
    if not isinstance(answer, str) or answer not in LABELS:
        raise ValueError(f"Invalid official answer for {qid}: {answer!r}")
    refs = list(raw_source.get("figureRefs") or [])
    for key in ("figure_ref", "option_figure_ref", "choice_figure_ref"):
        value = q.get(key)
        if value and value not in refs:
            refs.append(value)
    figure = raw_source.get("figure")
    if figure is None:
        figure = q.get("figure_ref") or q.get("option_figure_ref") or q.get("choice_figure_ref")
    release = raw_audit.get("releaseStatus", q.get("audit_status", "PENDING_SOURCE_AND_VISUAL_AUDIT"))
    audit_status = q.get("audit_status", "PENDING")
    return {
        "id": qid,
        "exam": q.get("exam", exam_title),
        "examDate": q.get("examDate", exam_date),
        "section": q.get("section", q.get("category", "区分未設定")),
        "questionNumber": int(number),
        "question": q.get("question", ""),
        "choices": choices_as_list(options),
        "answerOfficial": answer,
        "hereToRemember": q.get("hereToRemember", q.get("key_point")),
        "explanation": q.get("explanation"),
        "source": {
            "title": raw_source.get("title", f"{year}年度 {term}期 第二種電気工事士 学科試験問題"),
            "url": raw_source.get("url", source_files["questionPdf"]),
            "page": raw_source.get("page"),
            "figure": figure,
            **({"figureRefs": refs} if refs else {}),
        },
        "audit": {
            "transcription": raw_audit.get("transcription", "転記済み・独立監査未完了"),
            "answer": raw_audit.get("answer", "公式正答照合記録は原典データを参照"),
            "figureStatus": raw_audit.get("figureStatus", "要個別図版目視監査" if refs or figure else "図版未確認"),
            "independentReview": raw_audit.get("independentReview", "未実施"),
            "releaseStatus": release,
        },
        "audit_status": audit_status,
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+", help="One or more per-sitting JSON files")
    ap.add_argument("-o", "--output", default="electrician2-sprint/ios/Resources/QUESTION_BANK.json")
    ap.add_argument("--allow-partial", action="store_true", help="Allow fewer than six complete sittings")
    args = ap.parse_args()

    combined, sources, seen = [], {}, set()
    datasets = set()
    for filename in args.files:
        path = Path(filename)
        doc = json.loads(path.read_text(encoding="utf-8"))
        ds = get_dataset(doc, path)
        if ds in datasets:
            raise ValueError(f"Duplicate sitting input: {ds}")
        datasets.add(ds)
        year, term, date, title, official_qpdf, official_apdf = SITTINGS[ds]
        source_files = (doc.get("sourceFiles") or {}) if isinstance(doc, dict) else {}
        if isinstance(source_files, dict) and "questionPdf" in source_files:
            qpdf, apdf = source_files.get("questionPdf", ""), source_files.get("answerPdf", "")
        else:
            qpdf, apdf = "", ""
        if not qpdf:
            qpdf = next((q.get("source", {}).get("url") for q in (doc if isinstance(doc, list) else doc.get("questions", [])) if q.get("source", {}).get("url")), official_qpdf)
        if not apdf:
            apdf = official_apdf
        sources[ds] = {"questionPdf": qpdf, "answerPdf": apdf}
        questions = doc if isinstance(doc, list) else doc.get("questions", [])
        if len(questions) != 50:
            raise ValueError(f"{ds} must contain 50 questions; got {len(questions)}")
        normalized = [normalize_question(q, ds, sources[ds]) for q in questions]
        numbers = [q["questionNumber"] for q in normalized]
        if sorted(numbers) != list(range(1, 51)):
            raise ValueError(f"{ds} question numbers must be exactly 1..50")
        for q in normalized:
            if q["id"] in seen:
                raise ValueError(f"Duplicate question ID: {q['id']}")
            seen.add(q["id"])
        combined.extend(normalized)

    if not args.allow_partial and datasets != set(SITTINGS):
        missing = sorted(set(SITTINGS) - datasets)
        raise ValueError(f"All six sittings are required; missing: {', '.join(missing)}")
    combined.sort(key=lambda q: (q["id"].split("-")[1], q["id"].split("-")[2], q["questionNumber"]))
    bank = {
        "schemaVersion": "1.0",
        "dataSet": "E2-ALL-2024-2026",
        "sourceFiles": {
            "questionPdf": "複数回分（各問題source.urlに原典URLを保持）",
            "answerPdf": "複数回分（各問題audit.answerに照合記録を保持）",
        },
        "questionCount": len(combined),
        "questions": combined,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(combined)} questions from {len(datasets)} sittings to {output}")

if __name__ == "__main__":
    main()
