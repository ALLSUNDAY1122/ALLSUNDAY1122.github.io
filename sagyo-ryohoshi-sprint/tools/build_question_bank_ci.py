#!/usr/bin/env python3
"""CI-safe entrypoint for LS16 question-bank generation.

MHLW pages and PDF text layouts differ between exam rounds. Keep the canonical
parser where it works, pin independently verified official URLs where needed,
and resolve sources lazily so historical layout differences cannot block newer
licensed-official questions.
"""
import re
import sys
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

_original_pdf_links_from_page = bank.pdf_links_from_page
_original_find_q_starts = bank.find_q_starts


def pdf_links_from_page(page_url):
    if page_url == R60_PAGE:
        return R60_OT_AM, R60_OT_PM, R60_OT_ANSWER
    if page_url == R59_PAGE:
        return R59_OT_AM, R59_OT_PM, CORRECTED_R59_OT_ANSWER
    if page_url == R58_PAGE:
        return R58_OT_AM, R58_OT_PM, R58_OT_ANSWER
    if page_url == R57_PAGE:
        return R57_OT_AM, R57_OT_PM, R57_OT_ANSWER
    return _original_pdf_links_from_page(page_url)


def corrected_r59_answer():
    return CORRECTED_R59_OT_ANSWER


def find_q_starts(lines):
    """Accept both `1 stem...` and `1` + next-line stem PDF layouts.

    Question numbers must still form an exact sequential 1..100 chain. A bare
    number is accepted only when the next nearby non-empty line contains
    Japanese text, which prevents option/page numerals from being treated as
    question starts.
    """
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
    # The MHLW topics index still exposes an obsolete R58 URL; use the current
    # official archive that actually publishes the R58 OT question PDFs.
    pages[58] = R58_PAGE
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
bank.find_q_starts = find_q_starts
bank.build_sources = build_sources

if __name__ == "__main__":
    bank.main()
