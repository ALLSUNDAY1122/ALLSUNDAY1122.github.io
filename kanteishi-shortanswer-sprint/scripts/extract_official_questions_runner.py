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

# Some administrative-law PDFs contain artificial inter-glyph spaces from the
# embedded Japanese font. Japanese question text does not depend on those spaces,
# so normalize them away before storing canonical text.
_base_compact = extractor.compact


def compact_without_pdf_spacing(text: str) -> str:
    return re.sub(r"\s+", "", _base_compact(text))


extractor.compact = compact_without_pdf_spacing

# Avoid false positives such as 情報の提供 / 財務諸表 / 公表. Only explicit
# source/credit notation is treated as a possible third-party-rights signal.
extractor.THIRD_PARTY_RE = re.compile(
    r"(?:出典\s*[:：]|転載\s*[:：]|©|Copyright|(?:写真|図版|資料)提供\s*[:：])",
    re.IGNORECASE,
)

# Layout-dependent tables/figures need app rendering review, but a table created
# by MLIT is not itself a third-party-rights failure. Keep the two concerns separate.
extractor.VISUAL_RE = re.compile(
    r"(?:下\s*表|次\s*表|下\s*図|次\s*図|表\s*の\s*[ア-ン]|資料\s*[0-9０-９]+|図\s*に\s*示|表\s*に\s*示)"
)

_base_make_item = extractor.make_item


def make_item_with_separate_layout_review(src, qno, stem, choices, answer):
    item = _base_make_item(src, qno, stem, choices, answer)
    layout_review = bool(item.get("requiresVisualRightsReview"))
    third_party_review = bool(item.get("requiresThirdPartyRightsReview"))
    item["requiresLayoutReview"] = layout_review
    item["requiresVisualRightsReview"] = layout_review
    item["rightsStatus"] = "review_required" if third_party_review else "text_only_pass"
    item["releaseEligible"] = not third_party_review
    return item


extractor.make_item = make_item_with_separate_layout_review

if __name__ == "__main__":
    extractor.main()
