#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import io
import json
import re
import sys
from pathlib import Path

from pypdf import PdfReader
import extract_r8_official as ex

BASE = Path(__file__).resolve().parent
CONFIG = BASE / "source-map.json"
OUT = BASE / "questions-r8-official.json"
REPORT = BASE / "extraction-report.json"


def sanitize(text: str) -> str:
    text = text.replace("\u2007", " ").replace("\u00a0", " ")
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", " ", text)
    return text


def split_segments(pdf_bytes: bytes, expected: int, round_label: str, subject: str):
    reader = PdfReader(io.BytesIO(pdf_bytes))
    texts = []
    for page in reader.pages[4:]:
        texts.append(ex.clean_page(page.extract_text() or "", round_label, subject))
    full = sanitize("\n".join(texts)).translate(ex.FW_DIGITS)
    heading = re.compile(r"(?m)^[ \t　]*問[ \t　]*題[ \t　]*([0-9]{1,2})(?=[ \t　])")
    matches = list(heading.finditer(full))
    nums = [int(m.group(1)) for m in matches]
    if nums != list(range(1, expected + 1)):
        raise ValueError(f"{round_label}/{subject}: 見出しFAIL {len(nums)}/{expected} nums={nums}")
    out = []
    for i, m in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(full)
        out.append((nums[i], full[m.end():end].strip()))
    return out


def parse_choices(segment: str):
    # 問題資料中の 1. 2. 3. と最終回答肢を区別するため、最後に現れる1始まりの連番群を採用。
    markers = list(re.finditer(r"(?<![0-9])([1-6])[．.]\s*", segment))
    candidates = []
    for i, m in enumerate(markers):
        if int(m.group(1)) != 1:
            continue
        group = [m]
        want = 2
        for j in range(i + 1, len(markers)):
            label = int(markers[j].group(1))
            if label == want:
                group.append(markers[j])
                want += 1
                if want == 7:
                    break
            elif label == 1:
                break
            elif label < want:
                continue
            else:
                break
        if 4 <= len(group) <= 6:
            candidates.append(group)
    if not candidates:
        return None, None
    group = candidates[-1]
    prompt = segment[:group[0].start()].strip()
    choices = []
    for i, marker in enumerate(group):
        start = marker.end()
        end = group[i + 1].start() if i + 1 < len(group) else len(segment)
        choices.append(segment[start:end].strip())
    return prompt, choices


def main():
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    questions = []
    report = {"stage":"R8公式186問抽出v3","status":"PASS","generated_total":0,"subjects":[],"errors":[],"fixes":[
        "PDF制御文字0x07・figure spaceを通常空白へ正規化",
        "問題見出しの字間・空白差を吸収",
        "回答肢は原文どおり5択または6択を保持"
    ]}
    for rnd in cfg["rounds"]:
        for sub in rnd["subjects"]:
            errors = []
            try:
                pdf = ex.download_pdf(sub["pdf"])
                pdf_hash = hashlib.sha256(pdf).hexdigest()
                segments = split_segments(pdf, sub["count"], rnd["label"], sub["name"])
                for qno, segment in segments:
                    prompt, choices = parse_choices(segment)
                    if not prompt or not choices:
                        errors.append(f"Q{qno}: 回答肢分割失敗")
                        continue
                    answer = sub["answers"][qno - 1]
                    if len(choices) not in (5, 6):
                        errors.append(f"Q{qno}: 回答肢数{len(choices)}")
                        continue
                    if answer > len(choices):
                        errors.append(f"Q{qno}: 正解番号{answer}>回答肢数{len(choices)}")
                        continue
                    points = sub["points"][qno - 1]
                    source_hash = hashlib.sha256(ex.normalize_for_hash(segment).encode("utf-8")).hexdigest()
                    questions.append({
                        "id": f"CPA-{rnd['key']}-{sub['name']}-{qno:03d}",
                        "round": rnd["label"],
                        "round_key": rnd["key"],
                        "exam_date": rnd["exam_date"],
                        "subject": sub["name"],
                        "question_no": qno,
                        "question": ex.compact_display(sanitize(prompt)),
                        "choices": [ex.compact_display(sanitize(c)) for c in choices],
                        "choice_count": len(choices),
                        "correct_choice": answer,
                        "correct_index": answer - 1,
                        "points": points,
                        "source_page_url": rnd["source_page"],
                        "source_pdf_url": sub["pdf"],
                        "answer_pdf_url": rnd["answer_pdf"],
                        "source_pdf_sha256": pdf_hash,
                        "source_segment_sha256": source_hash,
                        "origin_type": "licensed_official",
                        "edited": True,
                        "edit_notice": "公認会計士・監査審査会公表の試験問題をアプリ表示用に問題単位分割し、PDF由来のページヘッダ・フッタ・制御文字・改行を整形。内容・回答肢は追加作問しない。",
                        "rights_review": "PASS_no_explicit_third_party_rights_notice_detected_2026-08-09",
                        "rights_basis": "公認会計士・監査審査会 著作権・リンク等／公共データ利用規約（第1.0版）。出典・加工表示必須。第三者権利表示を将来検知した場合は再監査。",
                        "source_integrity": "generated_directly_from_official_pdf_text_layer"
                    })
                report["subjects"].append({"round":rnd["label"],"subject":sub["name"],"expected":sub["count"],"segments":len(segments),"generated":sub["count"]-len(errors),"errors":errors})
            except Exception as e:
                errors.append(f"{type(e).__name__}: {e}")
                report["subjects"].append({"round":rnd["label"],"subject":sub["name"],"expected":sub["count"],"generated":0,"errors":errors})
            report["errors"].extend([f"{rnd['label']}/{sub['name']}: {e}" for e in errors])
    report["generated_total"] = len(questions)
    if report["errors"] or len(questions) != 186:
        report["status"] = "FAIL"
    OUT.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"generated":len(questions),"status":report["status"],"errors":report["errors"]}, ensure_ascii=False))
    if report["status"] != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()
