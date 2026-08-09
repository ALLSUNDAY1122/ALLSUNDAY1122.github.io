#!/usr/bin/env python3
from __future__ import annotations

import itertools
import json
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
RAW = CONTENT / "raw"
RAW.mkdir(parents=True, exist_ok=True)
SOURCES = json.loads((CONTENT / "official-sources.json").read_text(encoding="utf-8"))
MANIFEST = json.loads((CONTENT / "source-manifest.json").read_text(encoding="utf-8"))
MANDATORY = json.loads((CONTENT / "mandatory-audit-v1.json").read_text(encoding="utf-8"))
THEORY = json.loads((CONTENT / "theory-audit-v1.json").read_text(encoding="utf-8"))
PRACTICAL = json.loads((CONTENT / "practical-audit-v1.json").read_text(encoding="utf-8"))

Q_LINE = re.compile(r"^\s*問\s*([0-9]{1,3})\s*(.*)$")
OPT_LINE = re.compile(r"^\s*([1-6])(?:[\.．、:]|\s)+(.*)$")
PAGE_NO = re.compile(r"^\s*[-―—]?\s*\d{1,3}\s*[-―—]?\s*$")
MEDIA_WORDS = (
    "図を示す", "図に示す", "下図", "次の図", "グラフ", "写真", "画像", "構造式",
    "化学構造", "反応式", "表を示す", "下表", "模式図", "スペクトル", "クロマトグラム",
)
EXAM_DATES = {111:"2026-02-22",110:"2025-02-23",109:"2024-02-18"}


def fetch_pdf(url: str, dst: Path):
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0 learning-sprint/1.0"})
    with urllib.request.urlopen(req, timeout=90) as r, dst.open("wb") as f:
        f.write(r.read())


def pdftotext(pdf: Path) -> str:
    out = pdf.with_suffix(".txt")
    subprocess.run(["pdftotext", "-layout", "-enc", "UTF-8", str(pdf), str(out)], check=True)
    return out.read_text(encoding="utf-8", errors="replace")


def clean(line: str) -> str:
    line = line.replace("\u3000", " ").replace("\ufeff", "")
    return re.sub(r"[ \t]+", " ", line).strip()


def skip_line(line: str) -> bool:
    if not line:
        return False
    if PAGE_NO.match(line):
        return True
    if line.startswith("第") and "回薬剤師国家試験" in line:
        return True
    if "厚生労働省" == line:
        return True
    if ".indd" in line or ".smd" in line:
        return True
    return False


def split_part(text: str, start: int, end: int):
    lines = text.splitlines()
    starts = {}
    expected = start
    for i, raw in enumerate(lines):
        m = Q_LINE.match(clean(raw))
        if not m:
            continue
        n = int(m.group(1))
        if n == expected:
            starts[n] = i
            expected += 1
            if expected > end:
                break
    if len(starts) != end - start + 1:
        missing = [n for n in range(start, end + 1) if n not in starts]
        raise RuntimeError(f"question split failed {start}-{end}: got={len(starts)} missing={missing[:20]}")

    out = {}
    for n in range(start, end + 1):
        s = starts[n]
        e = starts[n + 1] if n < end else len(lines)
        raw_lines = lines[s:e]
        first = clean(raw_lines[0])
        first = Q_LINE.match(first).group(2).strip()
        body = [first] if first else []
        body.extend(clean(x) for x in raw_lines[1:])
        body = [x for x in body if not skip_line(x)]
        out[n] = parse_block(body)
    return out


def find_choice_sequence(lines):
    candidates = []
    for i, line in enumerate(lines):
        m = OPT_LINE.match(line)
        if not m or int(m.group(1)) != 1:
            continue
        expected = 1
        markers = []
        for j in range(i, len(lines)):
            mm = OPT_LINE.match(lines[j])
            if not mm:
                continue
            num = int(mm.group(1))
            if num == expected:
                markers.append((j, num, mm.group(2).strip()))
                expected += 1
                if expected == 7:
                    break
            elif num < expected:
                continue
            elif num > expected:
                break
        if len(markers) >= 2:
            candidates.append(markers)
    if not candidates:
        return []
    # Prefer the sequence with most options; if tied, prefer the latest sequence,
    # since actual answer choices are normally at the end of the stem.
    candidates.sort(key=lambda x: (len(x), x[0][0]))
    return candidates[-1]


def parse_block(lines):
    lines = [x for x in lines if x != ""]
    seq = find_choice_sequence(lines)
    if not seq:
        stem = " ".join(lines).strip()
        return {"question":stem,"choices":[],"rawText":stem,"choiceParseStatus":"no_choice_sequence"}
    first_idx = seq[0][0]
    stem = " ".join(lines[:first_idx]).strip()
    choices = []
    for idx, (_, num, first_text) in enumerate(seq):
        start_line = seq[idx][0]
        end_line = seq[idx + 1][0] if idx + 1 < len(seq) else len(lines)
        parts = [first_text] if first_text else []
        for extra in lines[start_line + 1:end_line]:
            # Stop if a later non-sequential choice marker appears; it belongs to a
            # table/layout fragment and will be handled as media.
            mm = OPT_LINE.match(extra)
            if mm:
                break
            parts.append(extra)
        choices.append(" ".join(x for x in parts if x).strip())
    raw_text = " ".join(lines).strip()
    return {"question":stem,"choices":choices,"rawText":raw_text,"choiceParseStatus":"parsed"}


def exam_obj(rows, exam):
    return next(x for x in rows if int(x["exam"]) == int(exam))


def section_for(n: int):
    if n <= 90: return "必須"
    if n <= 195: return "理論"
    return "実践"


def mandatory_domain(n: int):
    if n <= 15: return "物理・化学・生物"
    if n <= 25: return "衛生"
    if n <= 40: return "薬理"
    if n <= 55: return "薬剤"
    if n <= 70: return "病態・薬物治療"
    if n <= 80: return "法規・制度・倫理"
    return "実務"


def theory_domain(exam: int, n: int):
    row = exam_obj(THEORY["exams"], exam)
    for r in row["subjectRanges"]:
        if int(r["from"]) <= n <= int(r["to"]):
            return r["subject"]
    return "要分類"


def practical_domain(n: int):
    # Current 345-question system: composite practical problems are arranged in
    # paired subject/practice questions, followed by 20 pure practice questions.
    if 196 <= n <= 225:
        return "物理・化学・生物" if (n - 196) % 2 == 0 else "実務"
    if 226 <= n <= 245:
        return "衛生" if (n - 226) % 2 == 0 else "実務"
    if 246 <= n <= 265:
        return "薬理" if (n - 246) % 2 == 0 else "実務"
    if 266 <= n <= 285:
        return "薬剤" if (n - 266) % 2 == 0 else "実務"
    if 286 <= n <= 305:
        return "病態・薬物治療" if (n - 286) % 2 == 0 else "実務"
    if 306 <= n <= 325:
        return "法規・制度・倫理" if (n - 306) % 2 == 0 else "実務"
    if 326 <= n <= 345:
        return "実務"
    return "要分類"


def domain_for(exam: int, n: int):
    if n <= 90: return mandatory_domain(n)
    if n <= 195: return theory_domain(exam, n)
    return practical_domain(n)


def official_answer(exam: int, n: int):
    if n <= 90:
        row = exam_obj(MANDATORY["exams"], exam)
        vals = row["officialAnswers"]
        return [int(vals[n - 1])]
    if n <= 195:
        row = exam_obj(THEORY["exams"], exam)
        vals = row["officialAnswers"].get(str(n), row["officialAnswers"].get(n))
        return [int(x) for x in (vals or [])]
    row = exam_obj(PRACTICAL["exams"], exam)
    vals = row["officialAnswers"][n - 196]
    return [int(x) for x in (vals or [])]


def manifest_exam(exam: int):
    return next(x for x in MANIFEST["exams"] if int(x["exam"]) == int(exam))


def flexible_rule(exam: int, n: int):
    for r in manifest_exam(exam).get("flexibleOfficialAnswers", []):
        if int(r["question"]) == n:
            return r
    return None


def correction_for(exam: int, n: int):
    out = []
    for r in manifest_exam(exam).get("corrections", []):
        if n in [int(x) for x in r.get("questions", [])]:
            out.append(r.get("type"))
    return out


def answer_fields(exam: int, n: int, choices):
    mex = manifest_exam(exam)
    if n in [int(x) for x in mex.get("noOfficialAnswerQuestions", [])]:
        return {"answer_type":"singleChoice","answer":None,"accepted_answers":None,"scoring_status":"excluded","officialAnswerNumbers":[]}
    vals = official_answer(exam, n)
    flex = flexible_rule(exam, n)
    if flex:
        pool = [int(x) - 1 for x in flex["acceptedPool"]]
        combos = [list(x) for x in itertools.combinations(pool, 2)]
        return {"answer_type":"multiChoice","answer":combos[0],"accepted_answers":combos,"scoring_status":"multiple_accepted","officialAnswerNumbers":[int(x) for x in flex["acceptedPool"]]}
    if len(vals) == 1:
        return {"answer_type":"singleChoice","answer":vals[0]-1,"accepted_answers":None,"scoring_status":"normal","officialAnswerNumbers":vals}
    return {"answer_type":"multiChoice","answer":[x-1 for x in vals],"accepted_answers":None,"scoring_status":"normal","officialAnswerNumbers":vals}


def case_group(exam: int, n: int):
    if n < 196:
        return None
    # Most integrated practical questions are paired. Keep the structural pair as a
    # case candidate; a later semantic pass may split pairs that do not share a stem.
    if 196 <= n <= 325:
        first = n if n % 2 == 0 else n - 1
        return f"P{exam}-CASE-{first:03d}"
    return None


def build_exam(src, parsed):
    exam = int(src["exam"])
    result = []
    for n in range(1, 346):
        p = parsed[n]
        section = section_for(n)
        answers = answer_fields(exam, n, p["choices"])
        max_answer = max(answers["officialAnswerNumbers"], default=0)
        choices_ok = len(p["choices"]) >= max_answer and len(p["choices"]) >= 2
        media_by_text = any(word in p["rawText"] for word in MEDIA_WORDS)
        requires_media = media_by_text or not choices_ok or any(not c for c in p["choices"])
        correction = correction_for(exam, n)
        qid = f"P{exam}-{n:03d}"
        result.append({
            "id": qid,
            "round": {111:1,110:2,109:3}[exam],
            "sourceExam": exam,
            "questionNo": n,
            "subject": section,
            "domain": domain_for(exam, n),
            "topic": f"第{exam}回 問{n}",
            "question": p["question"],
            "choices": p["choices"],
            **answers,
            "caseGroupId": case_group(exam, n),
            "sharedStem": None,
            "requires_media": requires_media,
            "mediaAuditStatus": "pending_rebuild_or_source_rights_review" if requires_media else "not_required",
            "choiceParseStatus": p["choiceParseStatus"],
            "correctionStatus": correction or ["none"],
            "explanation": None,
            "memoryPoint": None,
            "primary_source": src["landingUrl"],
            "source_url": next(x["url"] for x in src["parts"] if int(x["from"]) <= n <= int(x["to"])),
            "answer_source_url": src["answerUrl"],
            "effective_date": EXAM_DATES[exam],
            "origin_type": "licensed_official",
            "rights_basis": "MHLW website content under Public Data License 1.0 unless separately indicated; third-party content requires separate review",
            "attribution": f"出典：厚生労働省『第{exam}回薬剤師国家試験問題及び解答』",
            "modification_disclosure": "学習アプリ用の整形・解説付与を行う場合は『加工して作成』と表示",
            "reviewStatus": "official_import_pending_explanation_media_and_semantic_audit",
            "release_status": "blocked"
        })
    return result


def main():
    all_summary = []
    for src in SOURCES["exams"]:
        exam = int(src["exam"])
        parsed = {}
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            for part in src["parts"]:
                pdf = td / f"{exam}-{part['id']}.pdf"
                fetch_pdf(part["url"], pdf)
                text = pdftotext(pdf)
                found = split_part(text, int(part["from"]), int(part["to"]))
                parsed.update(found)
        missing = [n for n in range(1,346) if n not in parsed]
        if missing:
            raise RuntimeError(f"exam {exam}: missing parsed questions {missing[:30]}")
        qs = build_exam(src, parsed)
        out = {
            "schemaVersion":1,
            "exam":exam,
            "sourceQuestionCount":345,
            "importedCount":len(qs),
            "releaseAllowed":False,
            "questions":qs,
        }
        (RAW / f"exam-{exam}-raw.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        summary = {
            "exam":exam,
            "count":len(qs),
            "sections":{s:sum(1 for q in qs if q["subject"]==s) for s in ("必須","理論","実践")},
            "requiresMedia":sum(1 for q in qs if q["requires_media"]),
            "excluded":sum(1 for q in qs if q["scoring_status"]=="excluded"),
            "multipleAccepted":sum(1 for q in qs if q["scoring_status"]=="multiple_accepted"),
            "missingExplanation":sum(1 for q in qs if not q["explanation"]),
            "choiceParseIssues":sum(1 for q in qs if q["choiceParseStatus"]!="parsed"),
        }
        all_summary.append(summary)
        print(json.dumps(summary,ensure_ascii=False))
    report={"schemaVersion":1,"total":sum(x["count"] for x in all_summary),"exams":all_summary,"releaseAllowed":False}
    (RAW / "import-summary.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if report["total"] != 1035:
        raise RuntimeError(f"expected 1035, got {report['total']}")
    print("PASS: imported 1,035 official source slots; release remains blocked pending explanation/media/semantic audits")


if __name__ == "__main__":
    main()
