#!/usr/bin/env python3
import io
import json
import re
import urllib.request
from pathlib import Path

import pdfplumber

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialScoringSummary/1.0)"
HERE = Path(__file__).resolve().parent
OUT = HERE / "official-scoring-table-summary.json"

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
    request = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def clean(value):
    if value is None:
        return None
    text = str(value).replace("\u3000", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def normalized_row(row):
    cells = [clean(cell) for cell in row]
    while cells and cells[-1] is None:
        cells.pop()
    return cells


def useful(row):
    values = [c for c in row if c]
    if not values:
        return False
    joined = " ".join(values)
    return bool(re.search(
        r"(?:憲法|行政法|民法|商法|民事訴訟法|刑法|刑事訴訟法|一般教養|第\s*[0-9０-９]+\s*問|No\.?\s*[0-9０-９]+|Ｎｏ|順不同|部分点|配点|正解|^[0-9０-９]+$)",
        joined,
        re.I,
    ))


def table_candidates(page):
    settings_variants = [
        {
            "vertical_strategy": "lines",
            "horizontal_strategy": "lines",
            "intersection_tolerance": 5,
            "snap_tolerance": 3,
            "join_tolerance": 3,
        },
        {
            "vertical_strategy": "lines_strict",
            "horizontal_strategy": "lines_strict",
            "intersection_tolerance": 6,
            "snap_tolerance": 4,
            "join_tolerance": 4,
        },
    ]
    seen = set()
    result = []
    for variant_index, settings in enumerate(settings_variants, start=1):
        for table_index, table in enumerate(page.extract_tables(table_settings=settings), start=1):
            rows = [normalized_row(row) for row in table]
            rows = [row for row in rows if useful(row)]
            if not rows:
                continue
            signature = json.dumps(rows, ensure_ascii=False, sort_keys=False)
            if signature in seen:
                continue
            seen.add(signature)
            result.append({"variant": variant_index, "table": table_index, "rows": rows})
    return result


def coordinate_tokens(page):
    tokens = []
    for word in page.extract_words(use_text_flow=False, keep_blank_chars=False):
        text = clean(word.get("text"))
        if not text:
            continue
        if re.search(
            r"(?:憲法|行政法|民法|商法|民事訴訟法|刑法|刑事訴訟法|一般教養|No\.?|Ｎｏ|順不同|部分点|配点|正解|第|問|^[0-9０-９]+$)",
            text,
            re.I,
        ):
            tokens.append({
                "text": text,
                "x0": round(float(word["x0"]), 1),
                "top": round(float(word["top"]), 1),
            })
    return tokens


def main():
    result = {"schemaVersion": 1, "source": "Ministry of Justice official answer-and-points PDFs", "documents": {}}
    for key, url in PDFS.items():
        raw = fetch(url)
        doc = {"url": url, "bytes": len(raw), "pages": []}
        with pdfplumber.open(io.BytesIO(raw)) as pdf:
            for page_number, page in enumerate(pdf.pages, start=1):
                tables = table_candidates(page)
                doc["pages"].append({
                    "page": page_number,
                    "tables": tables,
                    "tokens": coordinate_tokens(page),
                })
        result["documents"][key] = doc
        print(f"SUMMARY {key}: pages={len(doc['pages'])} tables={sum(len(p['tables']) for p in doc['pages'])}")

    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"WROTE {OUT} bytes={OUT.stat().st_size}")


if __name__ == "__main__":
    main()
