#!/usr/bin/env python3
import hashlib
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG = json.loads((HERE / "candidate-source-locks.v1.json").read_text(encoding="utf-8"))
BANK = json.loads((HERE / "questions.candidates.v1.json").read_text(encoding="utf-8"))


def normalize_markup(raw: str) -> str:
    text = re.sub(r"<script\b[^>]*>.*?</script>", "", raw, flags=re.I | re.S)
    text = re.sub(r"<style\b[^>]*>.*?</style>", "", text, flags=re.I | re.S)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    return re.sub(r"\s+", "", text)


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "LearningSprintSourceAudit/1.0"})
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status}")
                return response.read()
        except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
            last_error = error
            if attempt < 2:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"e-Gov fetch failed after retries: {url}: {last_error}")


def main() -> int:
    by_id = {q.get("id"): q for q in BANK}
    configured_ids = [item["id"] for item in CONFIG["candidates"]]
    bank_ids = list(by_id)
    errors = []

    if len(configured_ids) != len(set(configured_ids)):
        errors.append("candidate-source-locks has duplicate IDs")
    if set(configured_ids) != set(bank_ids):
        missing = sorted(set(bank_ids) - set(configured_ids))
        extra = sorted(set(configured_ids) - set(bank_ids))
        errors.append(f"source lock coverage mismatch missing={missing} extra={extra}")

    asof = CONFIG["asOf"]
    law_ids = sorted({item["law_id"] for item in CONFIG["candidates"]})
    normalized_by_law = {}

    for law_id in law_ids:
        url = CONFIG["api"].format(law_id=urllib.parse.quote(law_id), asof=urllib.parse.quote(asof))
        try:
            raw = fetch(url)
        except Exception as error:
            errors.append(str(error))
            continue
        digest = hashlib.sha256(raw).hexdigest()
        normalized = normalize_markup(raw.decode("utf-8", errors="replace"))
        normalized_by_law[law_id] = normalized
        print(f"SOURCE {law_id} asof={asof} bytes={len(raw)} sha256={digest}")

    for item in CONFIG["candidates"]:
        qid = item["id"]
        q = by_id.get(qid)
        if not q:
            continue
        if q.get("reference_date") != asof:
            errors.append(f"{qid}: reference_date {q.get('reference_date')} != source asof {asof}")
        expected_url_suffix = f"/law/{item['law_id']}"
        if expected_url_suffix not in str(q.get("source_url", "")):
            errors.append(f"{qid}: source_url does not match law_id {item['law_id']}")
        source = normalized_by_law.get(item["law_id"])
        if source is None:
            continue
        marker = re.sub(r"\s+", "", item["marker"])
        if marker not in source:
            errors.append(f"{qid}: basis marker not found in e-Gov as-of source: {item['marker']}")
        else:
            print(f"PASS {qid}: exact-date statutory basis marker found")

    if errors:
        print("FAIL: candidate exact-date source audit")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"PASS: {len(configured_ids)} candidates matched e-Gov law text as of {asof}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
