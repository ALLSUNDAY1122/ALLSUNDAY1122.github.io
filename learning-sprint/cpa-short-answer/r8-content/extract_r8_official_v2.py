#!/usr/bin/env python3
import io
import re

from pypdf import PdfReader
import extract_r8_official as ex

# v1初回FAIL修正: Python真偽値 typo をグローバル互換で吸収。
ex.true = True


def split_question_segments_v2(pdf_bytes: bytes, expected_count: int, round_label: str, subject: str):
    reader = PdfReader(io.BytesIO(pdf_bytes))
    pages = []
    for page_no, page in enumerate(reader.pages[4:], start=5):
        txt = page.extract_text() or ""
        pages.append((page_no, ex.clean_page(txt, round_label, subject)))
    full = "\n".join(t for _, t in pages)
    translated = full.translate(ex.FW_DIGITS)
    # pypdfでは行頭に空白が残るPDFと「問 題」の字間が入るPDFがある。
    heading = re.compile(r"(?m)^[ \t　]*問[ \t　]*題[ \t　]*([0-9]{1,2})(?=[ \t　])")
    matches = list(heading.finditer(translated))
    if len(matches) != expected_count:
        found = [int(m.group(1)) for m in matches]
        sample = translated[:1200].replace("\n", "\\n")
        raise ValueError(
            f"{round_label}/{subject}: 問題見出し {len(matches)}/{expected_count} found={found} sample={sample}"
        )
    nums = [int(m.group(1)) for m in matches]
    if nums != list(range(1, expected_count + 1)):
        raise ValueError(f"{round_label}/{subject}: 問題番号連続性FAIL {nums}")
    segments = []
    for i, m in enumerate(matches):
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(full)
        segments.append((nums[i], full[start:end].strip()))
    return segments


ex.split_question_segments = split_question_segments_v2
ex.main()
