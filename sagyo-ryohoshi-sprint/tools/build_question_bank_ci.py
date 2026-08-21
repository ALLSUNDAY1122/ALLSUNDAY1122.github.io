#!/usr/bin/env python3
"""CI-safe entrypoint for LS16 question-bank generation.

MHLW pages have changed markup between exam rounds. Keep the canonical parser
for historical rounds, but pin independently verified official URLs where the
current runner cannot identify the section heading reliably.
"""
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

_original_pdf_links_from_page = bank.pdf_links_from_page


def pdf_links_from_page(page_url):
    if page_url == R60_PAGE:
        return R60_OT_AM, R60_OT_PM, R60_OT_ANSWER
    if page_url == R59_PAGE:
        return R59_OT_AM, R59_OT_PM, CORRECTED_R59_OT_ANSWER
    return _original_pdf_links_from_page(page_url)


def corrected_r59_answer():
    return CORRECTED_R59_OT_ANSWER


bank.pdf_links_from_page = pdf_links_from_page
bank.corrected_r59_answer = corrected_r59_answer

if __name__ == "__main__":
    bank.main()
