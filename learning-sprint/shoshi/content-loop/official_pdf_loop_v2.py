#!/usr/bin/env python3
import sys
import official_pdf_loop as loop

PDF_LINKS = {
    2023: {
        "AM": "https://www.moj.go.jp/content/001400147.pdf",
        "PM": "https://www.moj.go.jp/content/001400148.pdf",
    },
    2024: {
        "AM": "https://www.moj.go.jp/content/001422259.pdf",
        "PM": "https://www.moj.go.jp/content/001422260.pdf",
    },
    2025: {
        "AM": "https://www.moj.go.jp/content/001444126.pdf",
        "PM": "https://www.moj.go.jp/content/001444127.pdf",
    },
}


def fixed_links(year_meta):
    return PDF_LINKS[year_meta["year"]]


loop.discover_pdf_links = fixed_links

if __name__ == "__main__":
    sys.exit(loop.main())
