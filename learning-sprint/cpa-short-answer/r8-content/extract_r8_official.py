#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
from pathlib import Path

import requests
from pypdf import PdfReader

BASE = Path(__file__).resolve().parent
SOURCE_MAP = BASE / "source-map.json"
OUT = BASE / "questions-r8-official.json"
REPORT = BASE / "extraction-report.json"

FW_DIGITS = str.maketrans("０１２３４５６７８９", "0123456789")


def download_pdf(url: str) -> bytes:
    r = requests.get(url, timeout=60, headers={"User-Agent": "learning-sprint-source-audit/1.0"})
    r.raise_for_status()
    if not r.content.startswith(b"%PDF"):
        raise RuntimeError(f"PDFではない応答: {url} content-type={r.headers.get('content-type')}")
    return r.content


def clean_page(text: str, round_label: str, subject: str) -> str:
    kept = []
    for raw in text.splitlines():
        line = raw.replace("\u00a0", " ").strip()
        if not line:
            continue
        # 各頁の繰返しヘッダ/フッタのみ除去。問題本文は変更しない。
        if line.startswith(round_label.replace("第I", "第Ⅰ").replace("第II", "第Ⅱ")) and "短答式" in line and subject in line:
            continue
        if line.startswith("令和８年第") and "短答式" in line and subject in line:
            continue
        if re.fullmatch(r"\d+\s*M\s*\d+\s*[―-]\s*\d+", line):
            continue
        kept.append(line)
    return "\n".join(kept)


def normalize_for_hash(text: str) -> str:
    text = text.translate(FW_DIGITS)
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t　]+", "", text)
    text = re.sub(r"\r?\n+", "", text)
    return text.strip()


def compact_display(text: str) -> str:
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t　]+", " ", text)
    text = re.sub(r"\n+", "", text)
    return text.strip()


def split_question_segments(pdf_bytes: bytes, expected_count: int, round_label: str, subject: str):
    reader = PdfReader(io.BytesIO(pdf_bytes))
    # 問題本文は表紙・注意事項の後（5ページ目以降）。表紙の「問題1～20」等を誤検出しない。
    pages = []
    for page_no, page in enumerate(reader.pages[4:], start=5):
        txt = page.extract_text() or ""
        pages.append((page_no, clean_page(txt, round_label, subject)))
    full = "\n".join(t for _, t in pages)
    translated = full.translate(FW_DIGITS)
    heading = re.compile(r"(?m)^問題[\t 　]*([0-9]{1,2})(?=[\t 　])")
    matches = list(heading.finditer(translated))
    if len(matches) != expected_count:
        found = [int(m.group(1)) for m in matches]
        raise ValueError(f"{round_label}/{subject}: 問題見出し {len(matches)}/{expected_count} found={found}")
    nums = [int(m.group(1)) for m in matches]
    if nums != list(range(1, expected_count + 1)):
        raise ValueError(f"{round_label}/{subject}: 問題番号連続性FAIL {nums}")

    segments = []
    for i, m in enumerate(matches):
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(full)
        # translated/full は同じ文字数（全角数字→半角数字は1対1）なのでoffset共用可。
        raw = full[start:end].strip()
        segments.append((nums[i], raw))
    return segments


def parse_six_choices(segment: str):
    translated = segment.translate(FW_DIGITS)
    markers = list(re.finditer(r"(?<![0-9])([1-6])[\uFF0E．]\s*", translated))
    seq = None
    for i in range(0, len(markers) - 5):
        labels = [int(markers[i + j].group(1)) for j in range(6)]
        if labels == [1, 2, 3, 4, 5, 6]:
            seq = markers[i:i + 6]
    if seq is None:
        # 一部PDF抽出器が全角ピリオドを通常ピリオドへ変換する場合にも対応。
        markers = list(re.finditer(r"(?<![0-9])([1-6])[.]\s*", translated))
        for i in range(0, len(markers) - 5):
            labels = [int(markers[i + j].group(1)) for j in range(6)]
            if labels == [1, 2, 3, 4, 5, 6]:
                seq = markers[i:i + 6]
    if seq is None:
        return None, None
    prompt = segment[:seq[0].start()].strip()
    choices = []
    for i, marker in enumerate(seq):
        s = marker.end()
        e = seq[i + 1].start() if i + 1 < 6 else len(segment)
        choices.append(segment[s:e].strip())
    return prompt, choices


def build_questions(config: dict):
    questions = []
    report = {"stage": "R8公式186問抽出", "status": "PASS", "subjects": [], "errors": []}
    for rnd in config["rounds"]:
        for subject in rnd["subjects"]:
            name = subject["name"]
            try:
                pdf = download_pdf(subject["pdf"])
                pdf_sha256 = hashlib.sha256(pdf).hexdigest()
                segments = split_question_segments(pdf, subject["count"], rnd["label"], name)
                subject_errors = []
                for qno, segment in segments:
                    prompt, choices = parse_six_choices(segment)
                    if prompt is None or choices is None or len(choices) != 6:
                        subject_errors.append(f"Q{qno}: 6選択肢の分割失敗")
                        continue
                    if any(not compact_display(c) for c in choices):
                        subject_errors.append(f"Q{qno}: 空選択肢")
                        continue
                    answer = subject["answers"][qno - 1]
                    points = subject["points"][qno - 1]
                    raw_hash = hashlib.sha256(normalize_for_hash(segment).encode("utf-8")).hexdigest()
                    questions.append({
                        "id": f"CPA-{rnd['key']}-{name}-{qno:03d}",
                        "round": rnd["label"],
                        "round_key": rnd["key"],
                        "exam_date": rnd["exam_date"],
                        "subject": name,
                        "question_no": qno,
                        "question": compact_display(prompt),
                        "choices": [compact_display(c) for c in choices],
                        "correct_choice": answer,
                        "correct_index": answer - 1,
                        "points": points,
                        "source_page_url": rnd["source_page"],
                        "source_pdf_url": subject["pdf"],
                        "answer_pdf_url": rnd["answer_pdf"],
                        "source_pdf_sha256": pdf_sha256,
                        "source_segment_sha256": raw_hash,
                        "origin_type": "licensed_official",
                        "edited": true,
                        "edit_notice": "公認会計士・監査審査会公表の試験問題をアプリ表示用にページヘッダ・フッタ除去、問題単位分割、改行整形。内容・選択肢は追加作問しない。",
                        "rights_review": "PASS_no_explicit_third_party_rights_notice_detected_2026-08-09",
                        "rights_basis": "公認会計士・監査審査会 著作権・リンク等／公共データ利用規約（第1.0版）。出典・加工表示必須。第三者権利表示を将来検知した場合は再監査。",
                        "source_integrity": "generated_directly_from_official_pdf_text_layer"
                    })
                if subject_errors:
                    report["errors"].extend([f"{rnd['label']}/{name}: {e}" for e in subject_errors])
                report["subjects"].append({
                    "round": rnd["label"], "subject": name,
                    "expected": subject["count"], "segments": len(segments),
                    "generated": subject["count"] - len(subject_errors),
                    "pdf_sha256": pdf_sha256,
                    "errors": subject_errors
                })
            except Exception as e:
                report["errors"].append(f"{rnd['label']}/{name}: {type(e).__name__}: {e}")
                report["subjects"].append({"round": rnd["label"], "subject": name, "expected": subject["count"], "generated": 0, "errors": [str(e)]})
    if report["errors"]:
        report["status"] = "FAIL"
    return questions, report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", type=Path, default=SOURCE_MAP)
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("--report", type=Path, default=REPORT)
    args = ap.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    questions, report = build_questions(config)
    args.out.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")
    report["generated_total"] = len(questions)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"generated={len(questions)} status={report['status']}")
    if report["status"] != "PASS":
        for e in report["errors"]:
            print("FAIL:", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
