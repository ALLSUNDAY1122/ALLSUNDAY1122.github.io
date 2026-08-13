#!/usr/bin/env python3
"""Build a structured 240-question corpus from MLIT official short-answer PDFs.

This is a reproducibility/maintenance tool, not the final release gate. It downloads
MLIT-published question/answer PDFs, extracts text with pdftotext, pairs each item
with the official answer, and emits per-exam canonical candidates plus a rights
review queue for items that appear to depend on figures/tables/third-party material.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

CHECKED_DATE = "2026-08-13"
PDL_URL = "https://www.digital.go.jp/resources/open_data/public_data_license_v1.0"
MLIT_TERMS_URL = "https://www.mlit.go.jp/link.html"

ADMIN = "不動産に関する行政法規"
THEORY = "不動産の鑑定評価に関する理論"


@dataclass(frozen=True)
class SourceSet:
    edition: int
    round_no: int
    label: str
    subject: str
    subject_code: str
    reference_date: str
    question_url: str
    answer_url: str


SOURCES = [
    SourceSet(2026, 1, "令和8年", ADMIN, "HOREI", "2025-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/002001126.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/002001133.pdf"),
    SourceSet(2026, 1, "令和8年", THEORY, "RIRON", "2025-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/002001127.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/002001131.pdf"),
    SourceSet(2025, 2, "令和7年", ADMIN, "HOREI", "2024-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001889650.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001889652.pdf"),
    SourceSet(2025, 2, "令和7年", THEORY, "RIRON", "2024-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001889654.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001889655.pdf"),
    SourceSet(2024, 3, "令和6年", ADMIN, "HOREI", "2023-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001743657.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001743661.pdf"),
    SourceSet(2024, 3, "令和6年", THEORY, "RIRON", "2023-09-01",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001743659.pdf",
              "https://www.mlit.go.jp/totikensangyo/kanteishi/content/001743666.pdf"),
]

ADMIN_TOPICS = [
    "土地基本法", "不動産の鑑定評価に関する法律", "地価公示法", "国土利用計画法",
    "都市計画法", "土地区画整理法", "建築基準法", "宅地建物取引業法", "農地法",
    "森林法", "自然公園法", "土壌汚染対策法", "文化財保護法", "国有財産法",
    "公有地の拡大の推進に関する法律", "都市再生特別措置法", "マンションの建替え等の円滑化に関する法律",
    "所有者不明土地", "所得税法", "法人税法", "租税特別措置法", "地方税法", "相続税法",
]
THEORY_TOPICS = [
    "鑑定評価の基本的考察", "不動産の種別", "不動産の類型", "価格形成要因", "価格形成の諸原則",
    "地域分析", "個別分析", "鑑定評価の条件", "対象不動産の確定", "資料の収集", "資料の検討",
    "原価法", "取引事例比較法", "収益還元法", "DCF法", "開発法", "正常価格", "限定価格",
    "特定価格", "特殊価格", "賃料", "積算法", "賃貸事例比較法", "収益分析法", "鑑定評価報告書",
]

VISUAL_RE = re.compile(r"(下図|次の図|図[をにの]|グラフ|写真|地図|別図|次表|下表|表[をにの]|別表)")
THIRD_PARTY_RE = re.compile(r"(出典|提供|転載|新聞|雑誌|株式会社|有限会社|協会作成|国土地理院)")
QUESTION_MARKER_RE = re.compile(r"〔\s*問題\s*([0-9０-９]+)\s*〕")
CHOICE_LINE_RE = re.compile(r"(?m)^\s*\(([1-5])\)\s*")
ANSWER_RE = re.compile(r"問\s*題\s*([0-9０-９]+)\s*\(([1-5])\)")


def ascii_digits(value: str) -> int:
    table = str.maketrans("０１２３４５６７８９", "0123456789")
    return int(value.translate(table))


def download(url: str, path: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 learning-sprint-audit/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response, path.open("wb") as out:
        out.write(response.read())


def pdf_to_text(path: Path) -> str:
    proc = subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", str(path), "-"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return proc.stdout.decode("utf-8", errors="replace")


def remove_page_noise(text: str) -> str:
    text = text.replace("\x0c", "\n")
    lines = []
    for raw in text.splitlines():
        line = raw.rstrip()
        if re.fullmatch(r"\s*[-–—]\s*\d+\s*[-–—]\s*", line):
            continue
        if re.fullmatch(r"\s*-\s*\d+\s*--\s*\d+\s*-\s*", line):
            continue
        lines.append(line)
    return "\n".join(lines)


def compact(text: str) -> str:
    text = remove_page_noise(text)
    parts = [p.strip() for p in text.splitlines() if p.strip()]
    joined = "".join(parts)
    joined = re.sub(r"\s+", " ", joined)
    joined = re.sub(r"\s+([、。）」』】])", r"\1", joined)
    joined = re.sub(r"([（「『【])\s+", r"\1", joined)
    return joined.strip()


def parse_answers(text: str) -> dict[int, int]:
    normalized = remove_page_noise(text)
    found: dict[int, int] = {}
    for q, a in ANSWER_RE.findall(normalized):
        found[ascii_digits(q)] = int(a)
    if len(found) != 40:
        # Fallback for extractors that collapse '問題' spacing differently.
        for q, a in re.findall(r"問題\s*([0-9０-９]+)\s*\(([1-5])\)", normalized):
            found[ascii_digits(q)] = int(a)
    if set(found) != set(range(1, 41)):
        raise ValueError(f"answer parse failed: got {len(found)} items, keys={sorted(found)}")
    return found


def parse_questions(text: str) -> dict[int, tuple[str, list[str]]]:
    normalized = remove_page_noise(text)
    markers = list(QUESTION_MARKER_RE.finditer(normalized))
    if len(markers) != 40:
        raise ValueError(f"question marker parse failed: expected 40, got {len(markers)}")

    result: dict[int, tuple[str, list[str]]] = {}
    for idx, marker in enumerate(markers):
        qno = ascii_digits(marker.group(1))
        start = marker.end()
        end = markers[idx + 1].start() if idx + 1 < len(markers) else len(normalized)
        chunk = normalized[start:end]
        choice_markers = list(CHOICE_LINE_RE.finditer(chunk))
        if len(choice_markers) != 5:
            # Some PDFs may place a choice immediately after wrapped text; allow a looser fallback.
            loose = re.compile(r"\(([1-5])\)\s*")
            choice_markers = list(loose.finditer(chunk))
        if len(choice_markers) != 5:
            raise ValueError(f"question {qno}: expected 5 choices, got {len(choice_markers)}")

        stem = compact(chunk[:choice_markers[0].start()])
        choices: list[str] = []
        for cidx, cmark in enumerate(choice_markers):
            cstart = cmark.end()
            cend = choice_markers[cidx + 1].start() if cidx + 1 < len(choice_markers) else len(chunk)
            choices.append(compact(chunk[cstart:cend]))
        if not stem or any(not c for c in choices):
            raise ValueError(f"question {qno}: empty stem/choice")
        result[qno] = (stem, choices)

    if set(result) != set(range(1, 41)):
        raise ValueError(f"question parse failed: keys={sorted(result)}")
    return result


def infer_topic(subject: str, text: str) -> str:
    if subject == ADMIN:
        for topic in ADMIN_TOPICS:
            if topic in text:
                return topic
        return "行政法規横断"
    for topic in THEORY_TOPICS:
        if topic in text:
            return topic
    if "鑑定評価基準" in text:
        return "不動産鑑定評価基準"
    return "鑑定理論"


def normalize_for_hash(value: str) -> str:
    return re.sub(r"\s+", "", value)


def item_hash(question: str, choices: Iterable[str]) -> str:
    payload = normalize_for_hash(question + "|" + "|".join(choices)).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def make_item(src: SourceSet, qno: int, stem: str, choices: list[str], answer: int) -> dict:
    topic = infer_topic(src.subject, stem + "".join(choices))
    correct_text = choices[answer - 1]
    visual = bool(VISUAL_RE.search(stem + "".join(choices)))
    third_party = bool(THIRD_PARTY_RE.search(stem + "".join(choices)))
    rights_review = visual or third_party
    inverse = "誤っている" in stem or "誤り" in stem
    mode_hint = "逆問（誤りを選ぶ）" if inverse else "正答を選ぶ"

    qid = f"KANTEI-R{src.round_no}-{src.subject_code}-{qno:03d}"
    rights_basis = (
        "国土交通省ウェブサイトで公表された不動産鑑定士試験問題を、"
        "公共データ利用規約（PDL1.0）に準拠して利用。出典を明記し、"
        "アプリ表示用に改行・構造のみ整形。第三者権利は問題単位で監査する。"
    )
    explanation = (
        f"正解は({answer})です。正解肢は「{correct_text}」。"
        f"国土交通省が公表した{src.label}不動産鑑定士試験短答式試験の正解表で、"
        f"本問の正解は({answer})とされています。本問は「{topic}」を扱う公式過去問です。"
        f"{src.reference_date}時点の出題基準で、問題文が『正しいもの』か『誤っているもの』かを確認して判断します。"
    )
    return {
        "id": qid,
        "round": src.round_no,
        "edition": src.edition,
        "editionLabel": src.label,
        "questionNo": qno,
        "officialQuestionNo": qno,
        "subject": src.subject,
        "domain": topic,
        "topic": topic,
        "question": stem,
        "choices": choices,
        "correctIndex": answer - 1,
        "correct_index": answer - 1,
        "officialAnswer": answer,
        "correctChoiceText": correct_text,
        "memoryLine": f"{topic}：公式正解は({answer})。{mode_hint}問題かを先に確認する。",
        "shortExplanation": f"国土交通省公式正解は({answer})。本問の論点は{topic}です。",
        "detailExplanation": explanation,
        "sourceURL": src.question_url,
        "source_url": src.question_url,
        "answerSourceURL": src.answer_url,
        "referenceDate": src.reference_date,
        "reference_date": src.reference_date,
        "evidenceCheckedDate": CHECKED_DATE,
        "originType": "licensed_official",
        "origin_type": "licensed_official",
        "rightsBasis": rights_basis,
        "rights_basis": rights_basis,
        "rightsCheckedDate": CHECKED_DATE,
        "license": "PDL1.0",
        "licenseURL": PDL_URL,
        "mlitTermsURL": MLIT_TERMS_URL,
        "attribution": f"出典：国土交通省 {src.label}不動産鑑定士試験短答式試験（{src.subject}）／PDL1.0。アプリ表示用に構造化。",
        "editedNotice": "国土交通省公表PDFをもとに、改行除去・選択肢分離・JSON構造化を実施。設問内容の意味は改変しない。",
        "requiresVisualRightsReview": visual,
        "requiresThirdPartyRightsReview": third_party,
        "rightsStatus": "review_required" if rights_review else "text_only_pass",
        "releaseEligible": not rights_review,
        "questionHash": item_hash(stem, choices),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    all_items: list[dict] = []
    source_report: list[dict] = []

    with tempfile.TemporaryDirectory(prefix="kanteishi-official-") as td:
        temp = Path(td)
        for src in SOURCES:
            qpdf = temp / f"{src.edition}-{src.subject_code}-questions.pdf"
            apdf = temp / f"{src.edition}-{src.subject_code}-answers.pdf"
            download(src.question_url, qpdf)
            download(src.answer_url, apdf)
            qtext = pdf_to_text(qpdf)
            atext = pdf_to_text(apdf)
            questions = parse_questions(qtext)
            answers = parse_answers(atext)
            items = [make_item(src, qno, *questions[qno], answers[qno]) for qno in range(1, 41)]
            all_items.extend(items)
            source_report.append({
                "edition": src.edition,
                "subject": src.subject,
                "questions": len(items),
                "question_url": src.question_url,
                "answer_url": src.answer_url,
                "reference_date": src.reference_date,
                "visual_review_candidates": sum(1 for x in items if x["requiresVisualRightsReview"]),
                "third_party_review_candidates": sum(1 for x in items if x["requiresThirdPartyRightsReview"]),
            })

    if len(all_items) != 240:
        raise SystemExit(f"expected 240 items, got {len(all_items)}")
    ids = [q["id"] for q in all_items]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate IDs detected")

    for edition in (2026, 2025, 2024):
        items = [q for q in all_items if q["edition"] == edition]
        payload = {
            "schemaVersion": 1,
            "contentVersion": f"official-{edition}-2026-08-13.1",
            "qualification": "不動産鑑定士試験・短答式",
            "sourceCheckedAt": CHECKED_DATE,
            "edition": edition,
            "questions": items,
        }
        (args.out / f"exam-{edition}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    rights_queue = [
        {
            "id": q["id"],
            "edition": q["edition"],
            "subject": q["subject"],
            "officialQuestionNo": q["officialQuestionNo"],
            "question": q["question"],
            "requiresVisualRightsReview": q["requiresVisualRightsReview"],
            "requiresThirdPartyRightsReview": q["requiresThirdPartyRightsReview"],
            "source_url": q["source_url"],
        }
        for q in all_items if q["rightsStatus"] == "review_required"
    ]
    (args.out / "rights-review-queue.json").write_text(
        json.dumps(rights_queue, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    combined = {
        "schemaVersion": 1,
        "contentVersion": "official-240-2026-08-13.1",
        "qualification": "不動産鑑定士試験・短答式",
        "sourceCheckedAt": CHECKED_DATE,
        "productionTargetCount": 240,
        "questions": all_items,
    }
    (args.out / "questions-240.json").write_text(
        json.dumps(combined, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    hashes: dict[str, list[str]] = {}
    for q in all_items:
        hashes.setdefault(q["questionHash"], []).append(q["id"])
    exact_duplicates = [ids for ids in hashes.values() if len(ids) > 1]

    report = {
        "generatedAt": CHECKED_DATE,
        "total": len(all_items),
        "byEdition": {str(y): sum(1 for q in all_items if q["edition"] == y) for y in (2026, 2025, 2024)},
        "bySubject": {s: sum(1 for q in all_items if q["subject"] == s) for s in (ADMIN, THEORY)},
        "releaseEligibleBeforeRightsReview": sum(1 for q in all_items if q["releaseEligible"]),
        "rightsReviewQueue": len(rights_queue),
        "exactDuplicateGroups": exact_duplicates,
        "sources": source_report,
        "license": "PDL1.0",
        "licenseURL": PDL_URL,
        "mlitTermsURL": MLIT_TERMS_URL,
    }
    (args.out / "extraction-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
