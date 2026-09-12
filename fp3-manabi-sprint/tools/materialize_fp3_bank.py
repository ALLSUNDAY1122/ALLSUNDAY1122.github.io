#!/usr/bin/env python3
"""Materialize the audited FP3 question bank from the canonical HTML source.

Fails closed unless the extracted bank is exactly 180 questions and the compact
UTF-8 JSON payload matches the canonical SHA-256 locked by SOURCE_LOCK.md.
"""
from __future__ import annotations
import argparse, hashlib, json, pathlib, tempfile, os

EXPECTED_QUESTIONS = 180
EXPECTED_PAYLOAD_SHA256 = "bf2a24b354cc5b1714e1c0ef10fb529220b474c8d0b48b2f135ae42b061bda33"
PREFIX = "const BANK = "


def extract_bank(html: str) -> dict:
    start = html.find(PREFIX)
    if start < 0:
        raise ValueError("const BANK assignment not found")
    start += len(PREFIX)
    end = html.find(";", start)
    if end < 0:
        raise ValueError("BANK assignment terminator not found")
    return json.loads(html[start:end])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("source_html", type=pathlib.Path)
    ap.add_argument("output_json", type=pathlib.Path)
    args = ap.parse_args()

    raw = args.source_html.read_bytes()
    try:
        html = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise SystemExit(f"source is not UTF-8: {exc}")

    bank = extract_bank(html)
    questions = bank.get("questions")
    if not isinstance(questions, list) or len(questions) != EXPECTED_QUESTIONS:
        raise SystemExit(f"question count gate failed: {len(questions) if isinstance(questions, list) else 'invalid'}")
    if bank.get("metadata", {}).get("question_count") != EXPECTED_QUESTIONS:
        raise SystemExit("metadata question_count gate failed")

    payload = json.dumps(bank, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_PAYLOAD_SHA256:
        raise SystemExit(f"payload SHA-256 gate failed: {digest}")

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=args.output_json.name + ".", dir=args.output_json.parent)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(payload)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_name, args.output_json)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)

    print(json.dumps({
        "status": "PASS",
        "source_bytes": len(raw),
        "question_count": len(questions),
        "payload_bytes": len(payload),
        "payload_sha256": digest,
        "output": str(args.output_json),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
