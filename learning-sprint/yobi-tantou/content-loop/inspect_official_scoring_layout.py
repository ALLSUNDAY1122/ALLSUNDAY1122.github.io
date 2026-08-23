#!/usr/bin/env python3
import io
import re
import urllib.request
from pypdf import PdfReader

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialScoringAudit/1.0)"
PDFS = {
    "r6_const_admin": "https://www.moj.go.jp/content/001422569.pdf",
    "r6_civil_commercial_cvp": "https://www.moj.go.jp/content/001422570.pdf",
    "r6_criminal_crp": "https://www.moj.go.jp/content/001422571.pdf",
    "r6_general": "https://www.moj.go.jp/content/001422572.pdf",
    "r7_const_admin": "https://www.moj.go.jp/content/001444173.pdf",
    "r7_civil_commercial_cvp": "https://www.moj.go.jp/content/001444174.pdf",
    "r7_criminal_crp": "https://www.moj.go.jp/content/001444175.pdf",
    "r7_general": "https://www.moj.go.jp/content/001444176.pdf",
    "r7_correction": "https://www.moj.go.jp/content/001444169.pdf",
}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.read()


def extract_layout(raw):
    reader = PdfReader(io.BytesIO(raw))
    pages = []
    for page in reader.pages:
        try:
            text = page.extract_text(extraction_mode="layout") or ""
        except TypeError:
            text = page.extract_text() or ""
        pages.append(text)
    return "\n---PAGE---\n".join(pages)


def main():
    for key, url in PDFS.items():
        raw = fetch(url)
        text = extract_layout(raw)
        print(f"LAYOUT_BEGIN {key} url={url} bytes={len(raw)}")
        # Keep whitespace inside rows, remove only long blank runs.
        text = re.sub(r"\n{4,}", "\n\n", text)
        print(text[:30000])
        if len(text) > 30000:
            print(f"...TRUNCATED {len(text)-30000} chars...")
            print(text[-8000:])
        print(f"LAYOUT_END {key}")

if __name__ == "__main__":
    main()
