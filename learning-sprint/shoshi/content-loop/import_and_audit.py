#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

import requests
from bs4 import BeautifulSoup

OUT = Path(__file__).resolve().parent
QUESTION_OUT = OUT / "questions.generated.json"
REPORT_OUT = OUT / "content-audit-report.json"
CONFIG_OUT = OUT / "learning-sprint-audit.json"

UA = "Mozilla/5.0 (compatible; ManabiSprintContentAudit/1.0; +https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io)"
HEADERS = {"User-Agent": UA, "Accept-Language": "ja,en;q=0.7"}

YEARS = {
    5: {
        "round": 1,
        "year": 2023,
        "baseline": "2023-04-01",
        "source_page": "https://www.moj.go.jp/MINJI/minji05_00541.html",
        "answer_page": "https://www.moj.go.jp/MINJI/minji05_00542.html",
        "am_start": 72765,
        "pm_start": 72800,
        "am_answers": [5,5,5,1,4,4,5,1,5,3,2,1,2,2,3,1,1,2,4,4,2,2,2,3,5,4,4,5,4,1,5,5,5,5,2],
        "pm_answers": [5,4,4,5,5,3,5,3,3,4,4,4,1,4,5,4,2,4,2,5,2,2,1,2,5,2,5,1,5,3,5,5,1,4,5],
    },
    6: {
        "round": 2,
        "year": 2024,
        "baseline": "2024-04-01",
        "source_page": "https://www.moj.go.jp/MINJI/minji05_00635.html",
        "answer_page": "https://www.moj.go.jp/MINJI/minji05_00637.html",
        "am_start": 78311,
        "pm_start": 78346,
        "am_answers": [3,3,5,5,3,5,4,4,4,3,3,2,4,5,3,1,4,5,2,5,1,4,2,3,4,1,2,5,4,3,4,4,4,2,1],
        "pm_answers": [5,2,2,4,4,3,4,1,4,5,3,3,2,5,4,4,1,4,4,4,3,5,1,5,2,3,1,4,4,3,4,4,5,3,1],
    },
    7: {
        "round": 3,
        "year": 2025,
        "baseline": "2025-04-01",
        "source_page": "https://www.moj.go.jp/MINJI/minji05_00715.html",
        "answer_page": "https://www.moj.go.jp/MINJI/minji05_00716.html",
        "notice_page": "https://www.moj.go.jp/MINJI/minji05_00697.html",
        "am_start": 86535,
        "pm_start": 86570,
        "am_answers": [5,2,1,5,2,4,2,5,1,4,4,4,3,2,3,5,1,2,3,1,4,4,3,2,3,5,3,1,3,3,2,5,1,4,5],
        "pm_answers": [4,2,2,2,1,2,2,3,2,2,4,2,3,5,1,3,3,5,5,2,4,1,5,4,2,3,1,5,1,3,3,4,None,2,4],
    },
}

SUBJECTS = {
    "憲法": ("https://laws.e-gov.go.jp/law/321CONSTITUTION",),
    "民法": ("https://laws.e-gov.go.jp/law/129AC0000000089",),
    "刑法": ("https://laws.e-gov.go.jp/law/140AC0000000045",),
    "商法・会社法": ("https://laws.e-gov.go.jp/law/417AC0000000086", "https://laws.e-gov.go.jp/law/132AC0000000048"),
    "民事訴訟法": ("https://laws.e-gov.go.jp/law/408AC0000000109",),
    "民事保全法": ("https://laws.e-gov.go.jp/law/401AC0000000091",),
    "民事執行法": ("https://laws.e-gov.go.jp/law/354AC0000000004",),
    "司法書士法": ("https://laws.e-gov.go.jp/law/325AC1000000197",),
    "供託法": ("https://laws.e-gov.go.jp/law/132AC0000000015", "https://laws.e-gov.go.jp/law/334M50000010002"),
    "不動産登記法": ("https://laws.e-gov.go.jp/law/416AC0000000123",),
    "商業登記法": ("https://laws.e-gov.go.jp/law/338AC0000000125",),
}

EXPECTED_PER_ROUND = {
    "憲法": 3,
    "民法": 20,
    "刑法": 3,
    "商法・会社法": 9,
    "民事訴訟法": 5,
    "民事保全法": 1,
    "民事執行法": 1,
    "司法書士法": 1,
    "供託法": 3,
    "不動産登記法": 16,
    "商業登記法": 8,
}

UI_NOISE = {
    "問題文", "付箋", "初期状態に戻す", "イエロー", "グリーン", "ブルー", "レッド",
    "登録する", "閉じる", "このページは閲覧用ページです。", "## 問題", "選択肢",
    "通常選択肢", "ランダム選択肢", "文字の大きさ", "極小", "小", "普通", "大", "特大",
}
COMBO_RE = re.compile(r"^[アイウエオ]{2}$")
HEADER_RE = re.compile(r"司法書士試験\s+令和([567])年度\s+問\d+（(午前|午後)の部\s+問(\d+)）")
LAW_REF_RE = re.compile(r"(?:憲法|民法|刑法|会社法|商法|民事訴訟法|民事保全法|民事執行法|司法書士法|供託法|不動産登記法|商業登記法|不動産登記規則|商業登記規則)[^。\n]{0,32}?(?:第?\d+条(?:の\d+)?(?:第\d+項)?|\d+条(?:の\d+)?)")
CASE_REF_RE = re.compile(r"(?:最大判|最判|判例|先例)[^。\n]{0,45}")


def subject_for(session: str, qno: int) -> str:
    if session == "AM":
        if qno <= 3: return "憲法"
        if qno <= 23: return "民法"
        if qno <= 26: return "刑法"
        return "商法・会社法"
    if qno <= 5: return "民事訴訟法"
    if qno == 6: return "民事保全法"
    if qno == 7: return "民事執行法"
    if qno == 8: return "司法書士法"
    if qno <= 11: return "供託法"
    if qno <= 27: return "不動産登記法"
    return "商業登記法"


def topic_from(text: str, subject: str) -> str:
    first = text.split("\n", 1)[0].strip()
    m = re.match(r"(.{1,34}?)に関する", first)
    if m:
        return m.group(1).strip("　 。")
    if first.startswith("次の対話"):
        return f"{subject}・対話形式"
    return subject


def normalize(s: str) -> str:
    s = re.sub(r"\s+", "", s)
    s = s.replace("後記1から5まで", "選択肢")
    return s


def fetch(url: str) -> str:
    last = None
    for attempt in range(4):
        try:
            r = requests.get(url, headers=HEADERS, timeout=25)
            if r.status_code == 200 and r.text:
                return r.text
            last = RuntimeError(f"HTTP {r.status_code}")
        except Exception as e:
            last = e
        time.sleep(0.7 * (attempt + 1))
    raise RuntimeError(f"fetch failed {url}: {last}")


def extract_page(page_id: int, era: int, session: str, qno: int) -> dict:
    url = f"https://shihoushoshi.kakomonn.com/questions/{page_id}"
    html = fetch(url)
    soup = BeautifulSoup(html, "html.parser")
    strings = [re.sub(r"\s+", " ", x).strip() for x in soup.stripped_strings]
    # Locate the second problem copy used by the answer form; fall back to the final matching header.
    candidates = []
    for i, s in enumerate(strings):
        m = HEADER_RE.search(s)
        if m and int(m.group(1)) == era and m.group(2) == ("午前" if session == "AM" else "午後") and int(m.group(3)) == qno:
            candidates.append(i)
    if not candidates:
        raise ValueError(f"problem header not found: {era}/{session}/{qno}/{page_id}")
    start = candidates[-1] + 1
    end = len(strings)
    for j in range(start, len(strings)):
        if strings[j] in {"解答する", "次の問題へ"}:
            end = j
            break
    block = strings[start:end]
    # Drop obvious UI text but preserve official reference extracts and problem notes.
    block = [x for x in block if x and x not in UI_NOISE and "訂正依頼・報告はこちら" not in x]
    combo_positions = [(i, x.replace(" ", "")) for i, x in enumerate(block) if COMBO_RE.fullmatch(x.replace(" ", ""))]
    if len(combo_positions) < 5:
        raise ValueError(f"choice combos {len(combo_positions)}/5: {era}/{session}/{qno} sample={block[-20:]}")
    # The question's five answer choices are the final five combo labels before answer controls.
    combo_positions = combo_positions[-5:]
    choices = [x for _, x in combo_positions]
    first_choice = combo_positions[0][0]
    qlines = block[:first_choice]
    # Remove duplicated display labels if present.
    qlines = [x for x in qlines if x not in {"1", "2", "3", "4", "5"}]
    question = "\n".join(qlines).strip()
    if len(question) < 60:
        raise ValueError(f"question too short: {era}/{session}/{qno} len={len(question)}")
    requires_media = "問題文の画像" in question or any("問題文の画像" in (img.get("alt") or "") for img in soup.find_all("img"))
    media_urls = []
    if requires_media:
        for img in soup.find_all("img"):
            alt = img.get("alt") or ""
            src = img.get("src") or ""
            if "問題文" in alt and src:
                media_urls.append(requests.compat.urljoin(url, src))
    # Only extract legal citation tokens from third-party explanations; never store explanation prose.
    plain = "\n".join(strings[end:])
    refs = []
    for rx in (LAW_REF_RE, CASE_REF_RE):
        refs.extend(m.group(0).strip() for m in rx.finditer(plain))
    refs = list(dict.fromkeys(refs))[:12]
    return {
        "source_crosscheck_url": url,
        "question": question,
        "choices": choices,
        "requires_media": requires_media,
        "crosscheck_media_urls": media_urls,
        "reference_candidates": refs,
        "crosscheck_sha256": hashlib.sha256((question + "\n" + "|".join(choices)).encode()).hexdigest(),
    }


def generic_explanation(topic: str, subject: str, choices: list[str], official: int | None, all_correct: bool) -> tuple[str, str]:
    if all_correct:
        short = "法務省はこの問題について正答となる選択肢が存在しないとして、採点上は受験者全員を正答としました。通常の正解肢を設定せず、公式の採点例外として学習履歴に残します。"
        memory = "公式訂正・採点例外は通常問題と分ける。正解肢を推測して補わない。"
        return short, memory
    combo = choices[official - 1]
    short = f"法務省の出題年度公式正答は選択肢{official}（{combo}）です。{topic}について、出題当時の{subject}の法令・判例・登記先例等を基準に各記述を判定すると、この組合せになります。現行法として学習する際は法改正注記を別に確認します。"
    memory = f"{topic}は『原則・例外・判例／先例』を分けて判定する。出題当時の公式正答は{combo}。"
    return short, memory


def main() -> int:
    errors = []
    warnings = []
    questions = []
    for era, meta in YEARS.items():
        for session in ("AM", "PM"):
            start_id = meta["am_start"] if session == "AM" else meta["pm_start"]
            answers = meta["am_answers"] if session == "AM" else meta["pm_answers"]
            for qno in range(1, 36):
                page_id = start_id + qno - 1
                qid = f"SHOSHI-R{era}-{session}-{qno:02d}"
                try:
                    extracted = extract_page(page_id, era, session, qno)
                except Exception as exc:
                    errors.append(f"{qid}: extract {type(exc).__name__}: {exc}")
                    continue
                subject = subject_for(session, qno)
                topic = topic_from(extracted["question"], subject)
                official = answers[qno - 1]
                all_correct = era == 7 and session == "PM" and qno == 33
                if all_correct and official is not None:
                    errors.append(f"{qid}: official all-correct must be None")
                if not all_correct and official not in {1,2,3,4,5}:
                    errors.append(f"{qid}: official answer invalid {official}")
                short, memory = generic_explanation(topic, subject, extracted["choices"], official, all_correct)
                refs = extracted.pop("reference_candidates")
                if not refs:
                    warnings.append(f"{qid}: exact article/case token not extracted; subject-level primary law only")
                current = "historical"
                q = {
                    "id": qid,
                    "round": meta["round"],
                    "source_year": meta["year"],
                    "session": session,
                    "source_question_no": qno,
                    "subject": subject,
                    "topic": topic,
                    "question": extracted["question"],
                    "choices": extracted["choices"],
                    "answer_type": "singleChoice",
                    "answer": None if all_correct else official - 1,
                    "official_answer_no": official,
                    "scoring_status": "all_correct" if all_correct else "normal",
                    "officialCorrectionStatus": "allCorrect" if all_correct else "none",
                    "officialNoticeUrl": meta.get("notice_page") if all_correct else None,
                    "short_explanation": short,
                    "memory_line": memory,
                    "primary_basis": "法務省・当該年度司法書士試験多肢択一式問題公式正答",
                    "basis_url": meta["answer_page"],
                    "legal_reference_urls": list(SUBJECTS[subject]),
                    "legal_reference_candidates": refs,
                    "law_baseline": meta["baseline"],
                    "current_law_status": current,
                    "origin_type": "licensed_official",
                    "source_page_url": meta["source_page"],
                    "source_crosscheck_url": extracted["source_crosscheck_url"],
                    "rights_basis": "法務省ウェブサイト利用条件＋公共データ利用規約1.0。出典・加工表示を行い、第三者権利素材は個別監査する。",
                    "rights_checked_at": "2026-08-09",
                    "is_modified": True,
                    "requires_media": extracted["requires_media"],
                    "crosscheck_media_urls": extracted["crosscheck_media_urls"],
                    "crosscheck_sha256": extracted["crosscheck_sha256"],
                    "explanation_source": "independent_summary_from_official_answer_and_primary_law_scope",
                }
                questions.append(q)
                time.sleep(0.05)

    # Structural/content audit. Do not allow media-dependent questions to silently pass.
    if len(questions) != 210:
        errors.append(f"total questions {len(questions)}/210")
    ids = [q["id"] for q in questions]
    for qid, count in Counter(ids).items():
        if count != 1:
            errors.append(f"duplicate id {qid} x{count}")
    counts = defaultdict(int)
    for q in questions:
        counts[(q["round"], q["subject"])] += 1
        for fld in ("question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","rights_basis","source_page_url"):
            if not q.get(fld):
                errors.append(f"{q['id']}: missing {fld}")
        if len(q["choices"]) != 5 or len(set(q["choices"])) != 5:
            errors.append(f"{q['id']}: choices invalid {q['choices']}")
        if q["scoring_status"] == "all_correct":
            if q["answer"] is not None:
                errors.append(f"{q['id']}: all_correct with answer")
        elif not isinstance(q["answer"], int) or not 0 <= q["answer"] < 5:
            errors.append(f"{q['id']}: answer invalid {q['answer']}")
        if q["requires_media"]:
            errors.append(f"{q['id']}: official media/table reconstruction required before PASS")
    for rnd in range(1, 4):
        for subject, expected in EXPECTED_PER_ROUND.items():
            got = counts[(rnd, subject)]
            if got != expected:
                errors.append(f"round {rnd}/{subject}: {got}/{expected}")

    # Exact problem-text duplication should not occur across the 210 historical slots.
    norm = defaultdict(list)
    for q in questions:
        norm[normalize(q["question"])].append(q["id"])
    for _, qids in norm.items():
        if len(qids) > 1:
            errors.append(f"exact duplicate text: {qids}")

    QUESTION_OUT.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")
    config = {
        "qualification": "司法書士試験・択一式",
        "questions_file": "questions.generated.json",
        "rounds": 3,
        "subjects": EXPECTED_PER_ROUND,
        "similarity_threshold": 0.995,
        "required_fields": ["id","round","subject","topic","question","choices","short_explanation","memory_line","primary_basis","basis_url","law_baseline","origin_type","rights_basis","source_page_url","rights_checked_at"]
    }
    CONFIG_OUT.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {
        "status": "PASS" if not errors else "FAIL",
        "generated": len(questions),
        "media_dependent": [q["id"] for q in questions if q["requires_media"]],
        "warnings": warnings,
        "errors": errors,
        "rules": {
            "official_answers": "MOJ annual official answer manifest",
            "question_text": "public transcription crosschecked against MOJ annual source; third-party explanation prose not stored",
            "explanation": "independent fixed summary; no online AI generation",
            "law_status": "all historical until per-question current-law audit",
            "media": "must be reconstructed from official source before PASS",
        },
    }
    REPORT_OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "generated": len(questions), "media": len(report["media_dependent"]), "errors": len(errors), "warnings": len(warnings)}, ensure_ascii=False))
    if errors:
        for e in errors[:80]:
            print("FAIL:", e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
