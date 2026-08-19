#!/usr/bin/env python3
"""CI-safe entrypoint for LS16 question-bank generation.

The MHLW correction page renders the OT label and its PDF link in separate table
cells, so searching only the anchor's parent cell can miss the corrected answer.
Use the verified final OT answer PDF directly while retaining the canonical build
and audit logic in build_question_bank.py.
"""
import build_question_bank as bank

CORRECTED_R59_OT_ANSWER = (
    "https://www.mhlw.go.jp/general/sikaku/successlist/2024/"
    "siken08_09-2/dl/OT_seitou.pdf"
)


def corrected_r59_answer():
    return CORRECTED_R59_OT_ANSWER


bank.corrected_r59_answer = corrected_r59_answer

if __name__ == "__main__":
    bank.main()
