#!/usr/bin/env python3
"""Robust CI entrypoint for the LS16 58-60 raw official frame."""
import re
import unicodedata
from pypdf import PdfReader
import extract_official as base


def norm(value):
    return unicodedata.normalize("NFKC", value or "").replace("\u3000", " ").strip()


def clean_line(line):
    line = norm(line)
    line = re.sub(r"\s*DKIX[^\s]*.*$", "", line).strip()
    if re.match(r"^DKIX.*indd\s+\d+", line):
        return ""
    return line


def text(pdf):
    # Default extraction preserves question/choice reading order better than the
    # layout mode used by the first gate implementation.
    return "\n".join((page.extract_text() or "") for page in PdfReader(str(pdf)).pages)


def find_starts(lines):
    starts = {}
    expected = 1
    for idx, line in enumerate(lines):
        s = clean_line(line)
        m = re.match(r"^(\d{1,3})\s+(.+)$", s)
        if not m or int(m.group(1)) != expected:
            continue
        rest = m.group(2).strip()
        # Reject answer-sheet numerals/instructions and require Japanese prose.
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
        block_lines = [clean_line(x) for x in lines[starts[n]:stop]]
        block_lines = [x for x in block_lines if x]
        block = " ".join(block_lines)
        block = re.sub(r"^\s*" + str(n) + r"\s+", "", block, count=1)
        stem, choices = split_choices(block)
        combined = stem + " " + " ".join(choices)
        requires_media = (
            len(choices) != 5
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


base.text = text
base.parse_questions = parse_questions

if __name__ == "__main__":
    base.main()
