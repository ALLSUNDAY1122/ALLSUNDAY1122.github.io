#!/usr/bin/env python3
"""Compatibility runner for MLIT PDF layout variations."""

import re

import extract_official_questions as extractor

# pdftotext may omit the Japanese corner brackets or insert layout spacing.
# Digits must follow 問題 immediately (apart from whitespace), so this does not
# match prose such as 問題用紙.
extractor.QUESTION_MARKER_RE = re.compile(
    r"(?:〔\s*)?問\s*題\s*([0-9０-９]+)(?:\s*〕)?"
)

if __name__ == "__main__":
    extractor.main()
