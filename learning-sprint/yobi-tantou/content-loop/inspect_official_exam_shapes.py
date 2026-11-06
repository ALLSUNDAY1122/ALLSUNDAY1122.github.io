#!/usr/bin/env python3
import io
import re
import urllib.request
from pypdf import PdfReader

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialShapeAudit/1.0)"
QUESTION_PDFS = {
    2024: {
        "憲法・行政法": "https://www.moj.go.jp/content/001421751.pdf",
        "民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001421752.pdf",
        "刑法・刑事訴訟法": "https://www.moj.go.jp/content/001421753.pdf",
        "一般教養科目": "https://www.moj.go.jp/content/001421754.pdf",
    },
    2025: {
        "憲法・行政法": "https://www.moj.go.jp/content/001443616.pdf",
        "民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001443617.pdf",
        "刑法・刑事訴訟法": "https://www.moj.go.jp/content/001443618.pdf",
        "一般教養科目": "https://www.moj.go.jp/content/001443619.pdf",
    },
    2026: {
        "憲法・行政法": "https://www.moj.go.jp/content/001466957.pdf",
        "民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001466958.pdf",
        "刑法・刑事訴訟法": "https://www.moj.go.jp/content/001466959.pdf",
        "一般教養科目": "https://www.moj.go.jp/content/001466960.pdf",
    },
}
RESULT_PDFS = {
    2024: "https://www.moj.go.jp/content/001422722.pdf",
    2025: "https://www.moj.go.jp/content/001444503.pdf",
}
SUBJECT_RE = re.compile(r"[［\[]\s*(憲法|行政法|民法|商法|民事訴訟法|刑法|刑事訴訟法|一般教養科目)\s*[］\]]")
QUESTION_RE = re.compile(r"〔\s*第\s*([０-９0-9]+)\s*問\s*〕(?:\s*（配点[：:]\s*([０-９0-9]+)）)?")
NO_RE = re.compile(r"[［\[]\s*(?:No\.?|№|Ｎｏ\.?)\s*([０-９0-9]+)\s*[］\]]", re.I)


def fwint(s):
    return int(s.translate(str.maketrans("０１２３４５６７８９", "0123456789")))


def fetch_pdf(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.read()


def text_pdf(url):
    reader = PdfReader(io.BytesIO(fetch_pdf(url)))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def question_shapes(text, group):
    # Track subject and each question block in source order.
    tokens = []
    for m in SUBJECT_RE.finditer(text):
        tokens.append((m.start(), "subject", m.group(1), None))
    for m in QUESTION_RE.finditer(text):
        tokens.append((m.start(), "question", fwint(m.group(1)), fwint(m.group(2)) if m.group(2) else None))
    tokens.sort(key=lambda x: x[0])
    current_subject = None
    questions = []
    for i, token in enumerate(tokens):
        pos, kind, value, points = token
        if kind == "subject":
            current_subject = value
            continue
        if current_subject is None:
            continue
        end = len(text)
        for later in tokens[i+1:]:
            if later[1] in ("question", "subject"):
                end = later[0]
                break
        block = text[pos:end]
        nos = sorted(set(fwint(m.group(1)) for m in NO_RE.finditer(block)))
        if current_subject == "一般教養科目":
            # General education is 3 points each; shared-passage headings can duplicate.
            points = 3
        questions.append((current_subject, value, points, nos))
    # Deduplicate shared-passage reoccurrences by subject/question, preferring block with No.
    out = {}
    for subject, qno, points, nos in questions:
        key = (subject, qno)
        prior = out.get(key)
        candidate = (subject, qno, points, nos)
        if prior is None or (not prior[3] and nos):
            out[key] = candidate
    return [out[k] for k in sorted(out, key=lambda z: (SUBJECT_ORDER.index(z[0]) if z[0] in SUBJECT_ORDER else 99, z[1]))]


SUBJECT_ORDER = ["憲法","行政法","民法","商法","民事訴訟法","刑法","刑事訴訟法","一般教養科目"]


def inspect_results(year, url):
    text = text_pdf(url)
    compact = re.sub(r"\s+", "", text)
    print(f"RESULT_BEGIN year={year} url={url}")
    for pattern in [r"合格点.{0,30}", r"総得点.{0,30}", r"満点.{0,30}", r"([０-９0-9]+)点以上.{0,30}"]:
        for m in re.finditer(pattern, compact):
            print("RESULT_MATCH", m.group(0)[:120])
    # Print short normalized lines containing scoring/result vocabulary.
    for line in text.splitlines():
        line = re.sub(r"\s+", " ", line).strip()
        if line and any(word in line for word in ("合格点", "得点", "満点", "合格者", "受験者")):
            print("RESULT_LINE", line[:500])
    print(f"RESULT_END year={year}")


def main():
    for year, groups in QUESTION_PDFS.items():
        total_legal_points = 0
        print(f"YEAR_SHAPES_BEGIN {year}")
        for group, url in groups.items():
            text = text_pdf(url)
            shapes = question_shapes(text, group)
            for subject, qno, points, nos in shapes:
                if subject != "一般教養科目" and points:
                    total_legal_points += points
                print(f"SHAPE year={year} subject={subject} question={qno} points={points} slots={','.join(map(str,nos)) if nos else '-'} slotCount={len(nos)}")
        print(f"LEGAL_POINTS year={year} total={total_legal_points}")
        print(f"YEAR_SHAPES_END {year}")
    for year, url in RESULT_PDFS.items():
        inspect_results(year, url)

if __name__ == "__main__":
    main()
