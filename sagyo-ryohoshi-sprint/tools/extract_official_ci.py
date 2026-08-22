#!/usr/bin/env python3
"""Robust CI entrypoint for the LS16 latest-three raw official frame."""
import json
import re
import unicodedata
from pathlib import Path

import pymupdf
import extract_official as base

MEDIA_PAGE_MARKER = "__LS16_MEDIA_PAGE__"
MEDIA_QUEUE = Path(__file__).resolve().parents[1] / "audit" / "media-audit-queue.json"

R61 = {
    "exam_round": 61,
    "am": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-09a_01.pdf",
    "pm": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-09b_01.pdf",
    "answer": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-09seitou.pdf",
}
R60 = {
    "exam_round": 60,
    "am": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09a_01.pdf",
    "pm": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09b_01.pdf",
    "answer": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09seitou.pdf",
}
R59 = {
    "exam_round": 59,
    "am": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp240424-09a_01.pdf",
    "pm": "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp240424-09b_01.pdf",
    "answer": "https://www.mhlw.go.jp/general/sikaku/successlist/2024/siken08_09-2/dl/OT_seitou.pdf",
}

# LS16-004 requires exactly three complete examinations. Use the newest three
# official rounds so the audit also anchors the bank to the current exam level.
base.SOURCES = {1: R61, 2: R60, 3: R59}


def norm(value):
    return unicodedata.normalize("NFKC", value or "").replace("\u3000", " ").strip()


def clean_line(line):
    line = norm(line)
    line = re.sub(r"\s*DKIX[^\s]*.*$", "", line).strip()
    if re.match(r"^DKIX.*indd\s+\d+", line):
        return ""
    return line


def _page_has_media(page):
    """Conservatively tag pages containing non-text graphics for audit."""
    if page.get_images(full=True):
        return True
    # MuPDF reports vector illustrations as drawings. Ignore tiny printer marks,
    # but retain substantive drawings so image-choice questions do not leak into
    # the text-only bank merely because their stem lacks the word 'figure'.
    try:
        for drawing in page.get_drawings():
            rect = drawing.get("rect")
            if rect and rect.width * rect.height >= 2500:
                return True
    except Exception:
        pass
    return False


def text(pdf):
    """Extract Japanese text with MuPDF and preserve a page-level media flag."""
    doc = pymupdf.open(str(pdf))
    try:
        chunks = []
        for page in doc:
            page_text = page.get_text("text", sort=True) or ""
            if _page_has_media(page):
                page_text = MEDIA_PAGE_MARKER + "\n" + page_text
            chunks.append(page_text)
        return "\n".join(chunks)
    finally:
        doc.close()


def find_starts(lines):
    starts = {}
    expected = 1
    for idx, line in enumerate(lines):
        s = clean_line(line)
        m = re.match(r"^(\d{1,3})\s+(.+)$", s)
        if not m or int(m.group(1)) != expected:
            continue
        rest = m.group(2).strip()
        japanese = sum(
            1 for c in rest
            if "\u3040" <= c <= "\u30ff" or "\u4e00" <= c <= "\u9fff"
        )
        if len(rest) < 3 or japanese == 0 or re.match(r"^(答案|問題番号|問№|正答)", rest):
            continue
        starts[expected] = idx
        expected += 1
        if expected == 101:
            break
    return starts


def trim_tail(value):
    value = norm(value)
    value = re.sub(r"\s+\d+\s*$", "", value)
    return value.strip()


def split_choices(block):
    marks = [
        (int(m.group(1)), m.start(), m.end())
        for m in re.finditer(r"(?<!\d)([1-5])\s*[．.]\s*", block)
    ]
    seq = None
    for i in range(len(marks) - 4):
        candidate = marks[i:i + 5]
        if [x[0] for x in candidate] == [1, 2, 3, 4, 5]:
            seq = candidate
    if not seq:
        return trim_tail(block), []
    stem = trim_tail(block[:seq[0][1]])
    choices = []
    for i, (_, _start, end) in enumerate(seq):
        stop = seq[i + 1][1] if i < 4 else len(block)
        choices.append(trim_tail(block[end:stop]))
    return stem, choices


def parse_questions(raw_text):
    lines = raw_text.splitlines()
    starts = find_starts(lines)
    if len(starts) != 100:
        raise RuntimeError(
            f"detected {len(starts)} question starts, expected 100; "
            f"last={max(starts) if starts else None}"
        )
    out = []
    for n in range(1, 101):
        stop = starts.get(n + 1, len(lines))
        original = [clean_line(x) for x in lines[starts[n]:stop]]
        page_media = MEDIA_PAGE_MARKER in original
        block_lines = [x for x in original if x and x != MEDIA_PAGE_MARKER]
        block = " ".join(block_lines)
        block = re.sub(r"^\s*" + str(n) + r"\s+", "", block, count=1)
        stem, choices = split_choices(block)
        combined = stem + " " + " ".join(choices)
        requires_media = (
            page_media
            or len(choices) != 5
            or bool(re.search(
                r"別冊|図(?:に|を|で|から)|画像|写真|MRI|CT|エックス線|X線|"
                r"グラフ|模式図|標本|①|②|③|④|⑤",
                combined,
            ))
        )
        out.append({
            "number": n,
            "question": stem,
            "choices": choices,
            "requires_media": requires_media,
            "raw_block": "\n".join(block_lines),
        })
    return out


def write_media_audit_queue():
    rows = json.loads(base.OUT.read_text(encoding="utf-8"))
    queue = [row for row in rows if row.get("requires_media")]
    MEDIA_QUEUE.parent.mkdir(parents=True, exist_ok=True)
    MEDIA_QUEUE.write_text(
        json.dumps(queue, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("MEDIA_AUDIT_QUEUE", len(queue), flush=True)


base.text = text
base.parse_questions = parse_questions

if __name__ == "__main__":
    base.main()
    write_media_audit_queue()
