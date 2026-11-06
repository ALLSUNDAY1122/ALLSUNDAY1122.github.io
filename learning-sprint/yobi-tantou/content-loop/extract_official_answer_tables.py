#!/usr/bin/env python3
import io
import json
import re
import urllib.request

import pdfplumber

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialTableAudit/1.0)"
PDFS = {
    "2024-憲法・行政法": "https://www.moj.go.jp/content/001422569.pdf",
    "2024-民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001422570.pdf",
    "2024-刑法・刑事訴訟法": "https://www.moj.go.jp/content/001422571.pdf",
    "2024-一般教養科目": "https://www.moj.go.jp/content/001422572.pdf",
    "2025-憲法・行政法": "https://www.moj.go.jp/content/001444173.pdf",
    "2025-民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001444174.pdf",
    "2025-刑法・刑事訴訟法": "https://www.moj.go.jp/content/001444175.pdf",
    "2025-一般教養科目": "https://www.moj.go.jp/content/001444176.pdf",
}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.read()


def clean(value):
    if value is None:
        return None
    value = re.sub(r"\s+", " ", str(value)).strip()
    return value or None


def main():
    for key, url in PDFS.items():
        raw = fetch(url)
        print(f"TABLE_PDF_BEGIN key={key} bytes={len(raw)} url={url}")
        with pdfplumber.open(io.BytesIO(raw)) as pdf:
            for page_index, page in enumerate(pdf.pages, start=1):
                print(f"TABLE_PAGE_BEGIN key={key} page={page_index} width={page.width} height={page.height}")
                tables = page.extract_tables(
                    table_settings={
                        "vertical_strategy": "lines",
                        "horizontal_strategy": "lines",
                        "intersection_tolerance": 5,
                        "snap_tolerance": 3,
                        "join_tolerance": 3,
                    }
                )
                print(f"TABLE_COUNT key={key} page={page_index} count={len(tables)}")
                for table_index, table in enumerate(tables, start=1):
                    print(f"TABLE_BEGIN key={key} page={page_index} table={table_index} rows={len(table)}")
                    for row_index, row in enumerate(table, start=1):
                        values = [clean(cell) for cell in row]
                        print("ROW " + json.dumps({
                            "key": key,
                            "page": page_index,
                            "table": table_index,
                            "row": row_index,
                            "cells": values,
                        }, ensure_ascii=False, separators=(",", ":")))
                    print(f"TABLE_END key={key} page={page_index} table={table_index}")
                # Also print word-level data around all No./question/scoring tokens so a
                # failed line-table extraction still has a coordinate-backed fallback.
                words = page.extract_words(use_text_flow=False, keep_blank_chars=False)
                interesting = []
                for word in words:
                    text = clean(word.get("text"))
                    if not text:
                        continue
                    if re.search(r"No\.?|Ｎｏ|第|問|配点|部分点|順不同|正解|憲法|行政法|民法|商法|民事訴訟法|刑法|刑事訴訟法|一般教養", text):
                        interesting.append({
                            "text": text,
                            "x0": round(float(word["x0"]), 2),
                            "top": round(float(word["top"]), 2),
                            "x1": round(float(word["x1"]), 2),
                            "bottom": round(float(word["bottom"]), 2),
                        })
                print("WORDS " + json.dumps({"key": key, "page": page_index, "items": interesting}, ensure_ascii=False, separators=(",", ":")))
                print(f"TABLE_PAGE_END key={key} page={page_index}")
        print(f"TABLE_PDF_END key={key}")


if __name__ == "__main__":
    main()
