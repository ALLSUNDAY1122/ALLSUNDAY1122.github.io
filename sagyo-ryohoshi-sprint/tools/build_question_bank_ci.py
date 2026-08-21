#!/usr/bin/env python3
"""CI-safe entrypoint for LS16 question-bank generation.

MHLW pages and PDF text layouts differ between exam rounds. Keep the canonical
parser where it works, pin independently verified official URLs where needed,
use a PDF extractor that handles newer Japanese font encodings, normalize both
legacy A001/B001 and newer AM1/PM1 answer-table labels, and resolve sources
lazily so historical layout differences cannot block licensed-official items.
"""
import re
import sys
import pymupdf
import build_question_bank as bank

R60_PAGE = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/"
    "tp250428-08_09.html"
)
R60_OT_AM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp250428-09a_01.pdf"
)
R60_OT_PM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp250428-09b_01.pdf"
)
R60_OT_ANSWER = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp250428-09seitou.pdf"
)
R59_PAGE = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/"
    "tp240424-08_09.html"
)
R59_OT_AM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp240424-09a_01.pdf"
)
R59_OT_PM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp240424-09b_01.pdf"
)
CORRECTED_R59_OT_ANSWER = (
    "https://www.mhlw.go.jp/general/sikaku/successlist/2024/"
    "siken08_09-2/dl/OT_seitou.pdf"
)
R58_PAGE = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/"
    "tp230524-08_09.html"
)
R58_OT_AM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp230524-09a_01.pdf"
)
R58_OT_PM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp230524-09b_01.pdf"
)
R58_OT_ANSWER = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp230524-09seitou.pdf"
)
R57_PAGE = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/"
    "tp220421-08_09.html"
)
R57_OT_AM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp220421-09a_01.pdf"
)
R57_OT_PM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp220421-09b_01.pdf"
)
R57_OT_ANSWER = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp220421-09seitou.pdf"
)
R56_PAGE = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/"
    "tp210416-08_09.html"
)
R56_OT_AM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp210416-09a_01.pdf"
)
R56_OT_PM = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp210416-09b_01.pdf"
)
R56_OT_ANSWER = (
    "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/"
    "tp210416-09seitou.pdf"
)

_original_pdf_links_from_page = bank.pdf_links_from_page
_original_find_q_starts = bank.find_q_starts


def pdf_links_from_page(page_url):
    pinned = {
        R60_PAGE: (R60_OT_AM, R60_OT_PM, R60_OT_ANSWER),
        R59_PAGE: (R59_OT_AM, R59_OT_PM, CORRECTED_R59_OT_ANSWER),
        R58_PAGE: (R58_OT_AM, R58_OT_PM, R58_OT_ANSWER),
        R57_PAGE: (R57_OT_AM, R57_OT_PM, R57_OT_ANSWER),
        R56_PAGE: (R56_OT_AM, R56_OT_PM, R56_OT_ANSWER),
    }
    return pinned.get(page_url) or _original_pdf_links_from_page(page_url)


def corrected_r59_answer():
    return CORRECTED_R59_OT_ANSWER


def pdf_text(url, tmpdir):
    """Extract Japanese PDF text with MuPDF rather than pypdf font maps."""
    data = bank.get(url, binary=True)
    doc = pymupdf.open(stream=data, filetype="pdf")
    try:
        return "\n".join(page.get_text("text", sort=True) or "" for page in doc)
    finally:
        doc.close()


def answer_map(text):
    """Parse both A001/B001 and AM1/PM1 official answer-table labels."""
    text = bank.norm(text)
    matches = list(re.finditer(r"(?:A\d{3}|B\d{3}|AM\d{1,3}|PM\d{1,3})", text))
    out = {}
    for i, match in enumerate(matches):
        raw_key = match.group(0)
        if raw_key.startswith("AM"):
            key = f"A{int(raw_key[2:]):03d}"
        elif raw_key.startswith("PM"):
            key = f"B{int(raw_key[2:]):03d}"
        else:
            key = raw_key
        segment = text[match.end() : (matches[i + 1].start() if i + 1 < len(matches) else len(text))]
        values = []
        for token in re.findall(r"(?<!\d)([1-5]{1,2})(?!\d)", segment):
            digits = [int(x) for x in token]
            if len(set(digits)) != len(digits) or not all(1 <= x <= 5 for x in digits):
                continue
            if digits not in values:
                values.append(digits)
        out[key] = values
    return out


def find_q_starts(lines):
    """Accept both `1 stem...` and `1` + next-line stem PDF layouts."""
    starts = _original_find_q_starts(lines)
    if len(starts) == 100:
        return starts

    starts = {}
    expected = 1
    for i, raw in enumerate(lines):
        s = bank.clean_line(raw)
        m = re.match(r"^(\d{1,3})(?:\s+(.+))?$", s)
        if not m or int(m.group(1)) != expected:
            continue
        trailing = (m.group(2) or "").strip()
        if not trailing:
            nxt = ""
            for j in range(i + 1, min(i + 5, len(lines))):
                nxt = bank.clean_line(lines[j])
                if nxt:
                    break
            if not nxt or not re.search(r"[ぁ-んァ-ヶ一-龠]", nxt):
                continue
            if re.fullmatch(r"\d{1,3}", nxt):
                continue
        starts[expected] = i
        expected += 1
        if expected == 101:
            break
    return starts


def build_sources():
    """Yield newest official rounds as they are resolved."""
    pages = bank.discover_exam_pages()
    # Pin current official archive pages where the index/markup is obsolete.
    pages.update({60: R60_PAGE, 59: R59_PAGE, 58: R58_PAGE, 57: R57_PAGE, 56: R56_PAGE})
    fix = None
    for exam in range(60, 44, -1):
        page_url = pages.get(exam)
        if not page_url:
            continue
        try:
            am_url, pm_url, answer_url = pdf_links_from_page(page_url)
            if exam == 59:
                fix = fix or corrected_r59_answer()
                answer_url = fix
        except Exception as exc:
            print(f"SOURCE_LINK_FAIL R{exam}: {exc}", file=sys.stderr)
            continue
        yield bank.Source(exam, page_url, am_url, pm_url, answer_url)


bank.pdf_links_from_page = pdf_links_from_page
bank.corrected_r59_answer = corrected_r59_answer
bank.pdf_text = pdf_text
bank.answer_map = answer_map
bank.find_q_starts = find_q_starts
bank.build_sources = build_sources

if __name__ == "__main__":
    bank.main()
