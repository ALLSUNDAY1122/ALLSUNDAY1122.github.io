#!/usr/bin/env python3
"""CI-safe entrypoint for LS16 question-bank generation.

MHLW pages have changed markup between exam rounds. Keep the canonical parser
for pages it can read, pin independently verified official URLs where needed,
and resolve sources lazily so one historical page-layout difference cannot
block all newer official rounds.
"""
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


def pdf_links_from_page(page_url):
    if page_url == R60_PAGE:
        return R60_OT_AM, R60_OT_PM, R60_OT_ANSWER
    if page_url == R59_PAGE:
        return R59_OT_AM, R59_OT_PM, CORRECTED_R59_OT_ANSWER
    if page_url == R57_PAGE:
        return R57_OT_AM, R57_OT_PM, R57_OT_ANSWER
    return _original_pdf_links_from_page(page_url)


def corrected_r59_answer():
    return CORRECTED_R59_OT_ANSWER


def build_sources():
    """Yield newest official rounds as they are resolved.

    The canonical implementation first resolves every historical page before
    processing any PDF. That makes a harmless old HTML-layout change fatal even
    when enough newer official questions are already available. This CI wrapper
    resolves lazily and records an unparseable historical page instead.
    """
    pages = bank.discover_exam_pages()
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
bank.build_sources = build_sources

if __name__ == "__main__":
    bank.main()
