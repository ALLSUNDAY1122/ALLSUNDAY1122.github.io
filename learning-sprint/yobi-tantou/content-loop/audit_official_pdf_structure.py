#!/usr/bin/env python3
import html
import io
import re
import sys
import urllib.parse
import urllib.request
from collections import defaultdict

from pypdf import PdfReader

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialPDFAudit/1.0)"
GROUP_LABELS = [
    "憲法・行政法",
    "民法・商法・民事訴訟法",
    "刑法・刑事訴訟法",
    "一般教養科目",
]
SUBJECTS = ["憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法", "一般教養科目"]
PAGES = {
    2024: {
        "questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00228.html",
        "answers": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00258.html",
        "correction": None,
    },
    2025: {
        "questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00287.html",
        "answers": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00289.html",
        "correction": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00285.html",
    },
    2026: {
        "questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00317.html",
        "answers": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00315.html",
        "correction": None,
    },
}


def req(url: str, accept: str = "*/*") -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def html_links(url: str):
    raw = req(url, "text/html,application/xhtml+xml")
    body = raw.decode("utf-8", errors="replace")
    out = []
    for match in re.finditer(r'<a\b[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>', body, re.I | re.S):
        href = html.unescape(match.group(1)).strip()
        text = re.sub(r"<[^>]+>", " ", match.group(2))
        text = re.sub(r"\s+", " ", html.unescape(text)).strip()
        out.append((text, urllib.parse.urljoin(url, href)))
    return out


def select_question_pdfs(page_url: str):
    selected = {}
    for text, url in html_links(page_url):
        if text in GROUP_LABELS and url.lower().endswith(".pdf") and text not in selected:
            selected[text] = url
    return selected


def select_answer_pdfs(page_url: str):
    selected = {}
    for text, url in html_links(page_url):
        if text in GROUP_LABELS and url.lower().endswith(".pdf"):
            selected[text] = url
    return selected


def select_correction_pdf(page_url: str | None):
    if not page_url:
        return None
    for text, url in html_links(page_url):
        if "誤記" in text and url.lower().endswith(".pdf"):
            return url
    return None


def fw_to_int(value: str) -> int:
    trans = str.maketrans("０１２３４５６７８９", "0123456789")
    return int(value.translate(trans))


def normalize(text: str) -> str:
    text = text.replace("\u3000", " ")
    return re.sub(r"[ \t]+", " ", text)


def extract_pdf(url: str):
    raw = req(url, "application/pdf")
    reader = PdfReader(io.BytesIO(raw))
    pages = [(page.extract_text() or "") for page in reader.pages]
    return raw, pages


def subject_question_headers(text: str):
    # Keep subject switches and question headings in source order.
    token_re = re.compile(
        r"[［\[]\s*(憲法|行政法|民法|商法|民事訴訟法|刑法|刑事訴訟法|一般教養科目)\s*[］\]]"
        r"|〔\s*第\s*([０-９0-9]+)\s*問\s*〕"
    )
    current = None
    out = defaultdict(list)
    for m in token_re.finditer(text):
        if m.group(1):
            current = m.group(1)
        elif m.group(2) and current:
            out[current].append(fw_to_int(m.group(2)))
    return dict(out)


def answer_numbers(text: str):
    vals = []
    for m in re.finditer(r"(?:No\.?|Ｎｏ\.?)[\s．\.]*([０-９0-9]+)", text, re.I):
        try:
            vals.append(fw_to_int(m.group(1)))
        except ValueError:
            pass
    return vals


def interesting_lines(text: str):
    lines = []
    for raw_line in normalize(text).splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if any(key in line for key in ("第", "No.", "Ｎｏ", "正解", "配点", "憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法", "一般教養", "誤記")):
            lines.append(line)
    return lines


def audit_pdf(year: int, kind: str, label: str, url: str):
    raw, pages = extract_pdf(url)
    text = "\n".join(pages)
    headers = subject_question_headers(text)
    nos = answer_numbers(text)
    print(f"PDF year={year} kind={kind} label={label} pages={len(pages)} bytes={len(raw)} url={url}")
    if headers:
        for subject, nums in headers.items():
            print(f"QUESTIONS year={year} subject={subject} count={len(nums)} headers={nums}")
    if nos:
        print(f"ANSWER_NOS year={year} label={label} count={len(nos)} min={min(nos)} max={max(nos)} unique={len(set(nos))}")
    lines = interesting_lines(text)
    print(f"INTERESTING_BEGIN year={year} kind={kind} label={label}")
    for line in lines[:160]:
        print(line[:500])
    if len(lines) > 160:
        print(f"... {len(lines)-160} more interesting lines omitted ...")
        for line in lines[-40:]:
            print(line[:500])
    print(f"INTERESTING_END year={year} kind={kind} label={label}")
    return headers


def main() -> int:
    errors = []
    for year, pages in PAGES.items():
        try:
            qpdfs = select_question_pdfs(pages["questions"])
        except Exception as e:
            errors.append(f"{year} questions page: {e}")
            qpdfs = {}
        try:
            apdfs = select_answer_pdfs(pages["answers"])
        except Exception as e:
            errors.append(f"{year} answers page: {e}")
            apdfs = {}
        try:
            correction = select_correction_pdf(pages["correction"])
        except Exception as e:
            errors.append(f"{year} correction page: {e}")
            correction = None

        print(f"YEAR {year} question_pdfs={len(qpdfs)} answer_pdfs={len(apdfs)} correction={'yes' if correction else 'no'}")
        for label in GROUP_LABELS:
            if label in qpdfs:
                try:
                    audit_pdf(year, "questions", label, qpdfs[label])
                except Exception as e:
                    errors.append(f"{year} question {label}: {e}")
            else:
                errors.append(f"{year}: missing question PDF {label}")
            if label in apdfs:
                try:
                    audit_pdf(year, "answers", label, apdfs[label])
                except Exception as e:
                    errors.append(f"{year} answer {label}: {e}")
            elif year != 2026:
                errors.append(f"{year}: missing answer PDF {label}")
        if correction:
            try:
                audit_pdf(year, "correction", "誤記訂正", correction)
            except Exception as e:
                errors.append(f"{year} correction PDF: {e}")

    if errors:
        print("AUDIT_WARNINGS")
        for error in errors:
            print(f"- {error}")
        # Missing 2026 answers is expected until MOJ publishes/links them.
        hard = [e for e in errors if not e.startswith("2026")]
        if hard:
            print("FAIL: official PDF structure audit has non-R8 gaps")
            return 1
    print("PASS: official PDF structure audit completed; R8 answer gaps remain non-fatal until officially published")
    return 0


if __name__ == "__main__":
    sys.exit(main())
