#!/usr/bin/env python3
import html
import re
import sys
import urllib.parse
import urllib.request

PAGES = {
    "r6_questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00228.html",
    "r6_results": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00258.html",
    "r7_questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00287.html",
    "r7_short_results": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00289.html",
    "r7_results_parent": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00285.html",
    "r8_questions": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00317.html",
    "r8_results_parent": "https://www.moj.go.jp/jinji/shihoushiken/jinji07_00315.html",
}

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialSourceAudit/1.0)"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html,application/xhtml+xml"})
    with urllib.request.urlopen(req, timeout=30) as res:
        raw = res.read()
        charset = res.headers.get_content_charset() or "utf-8"
    return raw.decode(charset, errors="replace")


def main() -> int:
    failures = []
    found = 0
    for key, url in PAGES.items():
        try:
            body = fetch(url)
        except Exception as e:
            failures.append(f"{key}: {type(e).__name__}: {e}")
            continue
        print(f"PAGE {key} bytes={len(body.encode('utf-8'))} url={url}")
        links = []
        for m in re.finditer(r'<a\b[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>', body, flags=re.I | re.S):
            href = html.unescape(m.group(1)).strip()
            text = re.sub(r"<[^>]+>", " ", m.group(2))
            text = re.sub(r"\s+", " ", html.unescape(text)).strip()
            absolute = urllib.parse.urljoin(url, href)
            if ".pdf" in absolute.lower() or "content/" in absolute.lower():
                links.append((text, absolute))
        if not links:
            failures.append(f"{key}: no PDF/content links discovered")
            continue
        for text, absolute in links:
            print(f"LINK {key}\t{text}\t{absolute}")
            found += 1

    if failures:
        print("WARNINGS:")
        for f in failures:
            print(f"- {f}")
    if found == 0:
        print("FAIL: no official PDF links could be discovered from CI runner")
        return 1
    print(f"PASS: discovered {found} official PDF/content links")
    return 0


if __name__ == "__main__":
    sys.exit(main())
