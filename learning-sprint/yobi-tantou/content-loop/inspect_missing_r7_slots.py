#!/usr/bin/env python3
import io
import re
import urllib.request
from pypdf import PdfReader

UA = "Mozilla/5.0 (compatible; LearningSprintR7SlotAudit/1.0)"
TARGETS = {
    "https://www.moj.go.jp/content/001443616.pdf": [("憲法", 10)],
    "https://www.moj.go.jp/content/001443617.pdf": [("民法", 5)],
    "https://www.moj.go.jp/content/001443618.pdf": [("刑法", 2), ("刑法", 9), ("刑事訴訟法", 21), ("刑事訴訟法", 22)],
}
SUBJECTS = ["憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法"]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.read()


def layout_pages(url):
    reader = PdfReader(io.BytesIO(fetch(url)))
    pages = []
    for page in reader.pages:
        try:
            pages.append(page.extract_text(extraction_mode="layout") or "")
        except TypeError:
            pages.append(page.extract_text() or "")
    return pages


def normalize_digits(text):
    return text.translate(str.maketrans("０１２３４５６７８９", "0123456789"))


def subject_at(text_before):
    found = None
    found_pos = -1
    for subject in SUBJECTS:
        for pattern in (rf"[［\[]\s*{re.escape(subject)}\s*[］\]]", re.escape(subject)):
            matches = list(re.finditer(pattern, text_before))
            if matches and matches[-1].start() > found_pos:
                found = subject
                found_pos = matches[-1].start()
    return found


def print_target_blocks(url, targets):
    pages = layout_pages(url)
    joined = "\n<<<PAGE_BREAK>>>\n".join(pages)
    normalized = normalize_digits(joined)
    qmatches = list(re.finditer(r"〔\s*第\s*(\d+)\s*問\s*〕", normalized))
    for subject, qno in targets:
        candidates = []
        for index, match in enumerate(qmatches):
            if int(match.group(1)) != qno:
                continue
            current_subject = subject_at(normalized[:match.start()])
            if current_subject != subject:
                continue
            end = qmatches[index + 1].start() if index + 1 < len(qmatches) else min(len(normalized), match.end() + 6000)
            block = normalized[match.start():end]
            candidates.append(block)
        print(f"TARGET_BEGIN subject={subject} question={qno} candidates={len(candidates)} url={url}")
        for i, block in enumerate(candidates, start=1):
            print(f"CANDIDATE_BLOCK {i}")
            print(block[:12000])
        print(f"TARGET_END subject={subject} question={qno}")


def main():
    for url, targets in TARGETS.items():
        print_target_blocks(url, targets)

if __name__ == "__main__":
    main()
